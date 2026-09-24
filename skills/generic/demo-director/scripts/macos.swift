import AppKit
import ApplicationServices
import AVFoundation
import Darwin
import Foundation
import ScreenCaptureKit

// Build with a macOS 15+ SDK: swiftc -parse-as-library macos.swift -o demo-native

private struct Failure: Error {
    let code: String
    let message: String
}

private func require(_ condition: Bool, _ code: String, _ message: String) throws {
    if !condition { throw Failure(code: code, message: message) }
}

private func failureJSON(_ error: Error) -> [String: Any] {
    if let error = error as? Failure {
        return ["code": error.code, "message": error.message]
    }
    let error = error as NSError
    // Framework descriptions can contain unrelated paths or application content.
    return ["code": "framework_error", "message": "A macOS API failed.",
            "domain": error.domain, "os_code": error.code]
}

private func emit(_ object: [String: Any]) {
    do {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([10]))
    } catch {
        FileHandle.standardOutput.write(Data(
            "{\"status\":\"failure\",\"error\":{\"code\":\"json_encoding\",\"message\":\"Cannot encode result.\"}}\n".utf8))
    }
}

private let geometryTolerance = 1.0
private let maximumChildren = 512
private let maximumDepth = 24
private let maximumNodes = 1_000

private struct Bounds: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    var json: [String: Double] { ["x": x, "y": y, "width": width, "height": height] }
    var valid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite)
            && abs(x) <= 1_000_000 && abs(y) <= 1_000_000
            && width > 1 && height > 1 && width <= 32_768 && height <= 32_768
    }
}

private func sameBounds(_ a: CGRect, _ b: CGRect) -> Bool {
    let lhs = Bounds(a)
    let rhs = Bounds(b)
    return lhs.valid && rhs.valid
        && abs(lhs.x - rhs.x) <= geometryTolerance
        && abs(lhs.y - rhs.y) <= geometryTolerance
        && abs(lhs.width - rhs.width) <= geometryTolerance
        && abs(lhs.height - rhs.height) <= geometryTolerance
}

private struct WindowConfig: Codable {
    let pid: Int32
    let bundle_id: String
    let window_id: UInt32
    let window_title: String
    let expected_bounds: Bounds

    func validate() throws {
        try require(pid > 0 && window_id > 0, "invalid_identity", "PID and window ID must be positive.")
        try validateBundle(bundle_id)
        try require(!window_title.isEmpty && window_title.utf8.count <= 4_096,
                    "invalid_title", "An exact nonempty observed window title is required (at most 4096 bytes).")
        try require(expected_bounds.valid, "invalid_bounds", "Window bounds must be finite, positive and bounded.")
    }

    var json: [String: Any] {
        ["pid": pid, "bundle_id": bundle_id, "window_id": window_id,
         "window_title": window_title, "expected_bounds": expected_bounds.json]
    }
}

private func validateBundle(_ value: String) throws {
    try require(!value.isEmpty && value.utf8.count <= 255
                && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
                && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                "invalid_bundle", "Supply one exact nonempty bundle identifier; wildcards are not supported.")
    try require(!value.contains("*"), "invalid_bundle", "Wildcards are not supported.")
}

private func absoluteURL(_ path: String) throws -> URL {
    try require((path as NSString).isAbsolutePath && !path.utf8.contains(0),
                "absolute_path_required", "Config and output paths must be absolute, with no NUL bytes.")
    return URL(fileURLWithPath: path).standardizedFileURL
}

private func loadConfig(_ path: String) throws -> WindowConfig {
    let url = try absoluteURL(path)
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    try require(values.isRegularFile == true && (values.fileSize ?? Int.max) <= 65_536,
                "invalid_config", "Config must be a regular JSON file no larger than 64 KiB.")
    let data = try Data(contentsOf: url)
    try require(data.count <= 65_536, "invalid_config", "Config exceeds 64 KiB.")
    let config: WindowConfig
    do { config = try JSONDecoder().decode(WindowConfig.self, from: data) }
    catch {
        throw Failure(code: "invalid_config",
                      message: "Config requires pid, bundle_id, window_id, window_title and expected_bounds {x,y,width,height}.")
    }
    try config.validate()
    return config
}

private func validateOutput(_ url: URL) throws {
    try require(url.pathExtension.lowercased() == "mp4", "invalid_output", "Output must have an .mp4 extension.")
    var info = stat()
    let result = url.path.withCString { lstat($0, &info) }
    try require(result != 0 && errno == ENOENT, "output_exists",
                "Refusing an existing output, including a dangling symlink, or an inaccessible output path.")
    let parent = url.deletingLastPathComponent()
    let values = try parent.resourceValues(forKeys: [.isDirectoryKey])
    try require(values.isDirectory == true && FileManager.default.isWritableFile(atPath: parent.path),
                "invalid_output_parent", "Output parent must already exist and be writable.")
}

private func dimensions(width: Int, bounds: Bounds) throws -> (Int, Int) {
    try require((1_280...4_096).contains(width) && width.isMultiple(of: 2),
                "invalid_width", "Width must be an even integer from 1280 through 4096.")
    try require(bounds.valid, "invalid_bounds", "Cannot size a recording from invalid bounds.")
    let height = (Double(width) * bounds.height / bounds.width / 2).rounded() * 2
    try require(height.isFinite && height >= 2 && height <= 8_192
                && Double(width) * height <= 16_777_216,
                "invalid_capture_size", "Aspect-preserving height must be 2–8192 pixels and area at most 16 megapixels.")
    return (width, Int(height))
}

private func parsePath(_ path: String) throws -> [Int] {
    let parts = path.split(separator: ".", omittingEmptySubsequences: false)
    try require(parts.first == "w" && parts.count > 1 && parts.count <= maximumDepth + 1,
                "invalid_ax_path", "Use an observed window-relative path, such as w.0.2 (maximum depth 24).")
    return try parts.dropFirst().map {
        guard let index = Int($0), String(index) == $0, (0..<maximumChildren).contains(index) else {
            throw Failure(code: "invalid_ax_path", message: "Path indices must be canonical integers from 0 through 511.")
        }
        return index
    }
}

private struct Invocation {
    let command: String
    var bundle: String?
    var config: WindowConfig?
    var path: String?
    var label: String?
    var seconds: Double?
    var output: URL?
    var width: Int = 1_920

    static func parse(_ args: [String]) throws -> Invocation {
        guard let command = args.first else { throw Failure(code: "usage", message: "Use --help for the command interface.") }
        var result = Invocation(command: command)
        switch command {
        case "--help", "--self-test":
            try require(args.count == 1, "usage", "This option takes no arguments.")
        case "list":
            try require(args.count == 2, "usage", "Usage: demo-native list BUNDLE_ID")
            try validateBundle(args[1])
            result.bundle = args[1]
        case "preflight", "tree":
            try require(args.count == 2, "usage", "Usage: demo-native \(command) /absolute/CONFIG.json")
            result.config = try loadConfig(args[1])
        case "move", "click":
            try require(args.count == 4, "usage", "Usage: demo-native \(command) /absolute/CONFIG.json AX_PATH EXACT_LABEL")
            _ = try parsePath(args[2])
            try require(!args[3].isEmpty && args[3].utf8.count <= 1_024,
                        "invalid_label", "An exact observed label of 1–1024 bytes is required.")
            result.config = try loadConfig(args[1])
            result.path = args[2]
            result.label = args[3]
        case "record":
            try require((4...5).contains(args.count), "usage",
                        "Usage: demo-native record /absolute/CONFIG.json SECONDS /absolute/OUTPUT.mp4 [WIDTH]")
            guard let seconds = Double(args[2]), seconds.isFinite, (1...600).contains(seconds),
                  let width = args.count == 5 ? Int(args[4]) : 1_920 else {
                throw Failure(code: "invalid_recording_arguments",
                              message: "Duration must be finite and 1–600 seconds; width must be an even integer 1280–4096.")
            }
            try require((1_280...4_096).contains(width) && width.isMultiple(of: 2),
                        "invalid_width", "Width must be an even integer from 1280 through 4096.")
            let output = try absoluteURL(args[3])
            try validateOutput(output)
            let config = try loadConfig(args[1])
            _ = try dimensions(width: width, bounds: config.expected_bounds)
            result.config = config
            result.seconds = seconds
            result.output = output
            result.width = width
        default:
            throw Failure(code: "usage", message: "Unknown command. Use --help.")
        }
        return result
    }
}

private enum LockState: String {
    case locked, unlocked, unknown
}

private func lockState(from dictionary: [String: Any]?) -> LockState {
    guard let value = dictionary?["CGSSessionScreenIsLocked"] as? NSNumber,
          CFGetTypeID(value) == CFBooleanGetTypeID() else { return .unknown }
    return value.boolValue ? .locked : .unlocked
}

private func lockState() -> LockState {
    lockState(from: CGSessionCopyCurrentDictionary() as? [String: Any])
}

private func permissionJSON() -> [String: Bool] {
    ["screen_recording": CGPreflightScreenCaptureAccess(),
     "accessibility": AXIsProcessTrusted(),
     "post_events": CGPreflightPostEventAccess()]
}

private func environmentalGuard(control: Bool = false) throws {
    try require(lockState() == .unlocked, "session_not_unlocked",
                "Session is locked or its lock state is unknown. A missing lock key is not proof of an unlocked session.")
    try require(CGPreflightScreenCaptureAccess(), "screen_recording_permission",
                "Screen Recording permission is unavailable. This helper never requests permission.")
    try require(AXIsProcessTrusted(), "accessibility_permission",
                "Accessibility permission is unavailable. This helper never requests permission.")
    if control {
        try require(CGPreflightPostEventAccess(), "post_event_permission",
                    "Permission to post input events is unavailable. No permission request was made.")
    }
}

private final class OneShot<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }

    func finish(_ result: Result<T, Error>) {
        lock.lock()
        let current = continuation
        continuation = nil
        lock.unlock()
        current?.resume(with: result)
    }
}

@MainActor
private func bounded<T>(_ seconds: Double, _ label: String,
                        start: (@escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        let gate = OneShot<T>(continuation)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds) {
            gate.finish(.failure(Failure(code: "api_timeout", message: "\(label) timed out.")))
        }
        start { gate.finish($0) }
    }
}

@available(macOS 15.0, *)
@MainActor
private func shareableContent() async throws -> SCShareableContent {
    // Preflight first: SCK discovery itself can otherwise trigger a permission prompt.
    try require(CGPreflightScreenCaptureAccess(), "screen_recording_permission",
                "Screen Recording permission is unavailable. No permission request was made.")
    return try await bounded(2, "ScreenCaptureKit discovery") { finish in
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, error in
            if let error { finish(.failure(error)) }
            else if let content { finish(.success(content)) }
            else { finish(.failure(Failure(code: "missing_content", message: "ScreenCaptureKit returned no content."))) }
        }
    }
}

private func axAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

private func axString(_ element: AXUIElement, _ name: String) -> String? {
    axAttribute(element, name) as? String
}

private func axElement(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = axAttribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

private func axBounds(_ element: AXUIElement) -> CGRect? {
    guard let p = axAttribute(element, kAXPositionAttribute),
          let s = axAttribute(element, kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
          AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    let rect = CGRect(origin: point, size: size)
    return Bounds(rect).valid ? rect : nil
}

private func axArray(_ element: AXUIElement, _ name: String, limit: Int) throws -> ([AXUIElement], Bool) {
    var count: CFIndex = 0
    let result = AXUIElementGetAttributeValueCount(element, name as CFString, &count)
    if result == .attributeUnsupported || result == .noValue { return ([], false) }
    try require(result == .success && count >= 0, "ax_unavailable", "Accessibility children could not be read.")
    if count == 0 { return ([], false) }
    var values: CFArray?
    try require(AXUIElementCopyAttributeValues(element, name as CFString, 0, min(count, limit), &values) == .success,
                "ax_unavailable", "Accessibility children changed or could not be read.")
    guard let children = values as? [AXUIElement] else {
        throw Failure(code: "ax_unavailable", message: "Accessibility returned invalid children.")
    }
    return (children, count > limit)
}

private func exactLabel(_ element: AXUIElement) -> (String, String)? {
    for attribute in [kAXTitleAttribute, kAXDescriptionAttribute] {
        if let text = axString(element, attribute), !text.isEmpty {
            return text.utf8.count <= 1_024 ? (text, attribute) : nil
        }
    }
    return nil
}

private func isPrivateOrMenu(_ element: AXUIElement) -> Bool {
    let role = axString(element, kAXRoleAttribute) ?? ""
    return [kAXMenuBarRole, kAXMenuRole, kAXMenuItemRole, "AXSecureTextField"].contains(role)
        || axString(element, kAXSubroleAttribute) == "AXSecureTextField"
}

private func matchingAXWindows(_ windows: [AXUIElement], config: WindowConfig) throws -> [AXUIElement] {
    let deadline = uptime() + 1
    var matches = [AXUIElement]()
    for window in windows {
        try require(uptime() < deadline, "ax_inspection_timeout", "Exact AX window matching exceeded its one-second budget.")
        if axString(window, kAXRoleAttribute) == kAXWindowRole
            && axString(window, kAXTitleAttribute) == config.window_title
            && axBounds(window).map({ sameBounds($0, config.expected_bounds.rect) }) == true {
            matches.append(window)
        }
    }
    try require(uptime() < deadline, "ax_inspection_timeout", "Exact AX window matching exceeded its one-second budget.")
    return matches
}

@MainActor
private final class Diagnostics {
    var data: [String: Any]

    init(config: WindowConfig) {
        data = ["window": config.json,
                "geometry": ["expected": config.expected_bounds.json,
                             "screen_capture_kit": NSNull(), "accessibility": NSNull(), "core_graphics": NSNull()]]
    }

    func geometry(_ source: String, _ rect: CGRect) {
        var values = data["geometry"] as? [String: Any] ?? [:]
        values[source] = Bounds(rect).valid ? Bounds(rect).json : NSNull()
        data["geometry"] = values
    }
}

@available(macOS 15.0, *)
@MainActor
private final class GuardedWindow {
    let config: WindowConfig
    let application: NSRunningApplication
    let axApplication: AXUIElement
    let axWindow: AXUIElement
    let axSystem: AXUIElement
    let diagnostics: Diagnostics

    private init(config: WindowConfig, app: NSRunningApplication,
                 root: AXUIElement, window: AXUIElement, system: AXUIElement, diagnostics: Diagnostics) {
        self.config = config
        application = app
        axApplication = root
        axWindow = window
        axSystem = system
        self.diagnostics = diagnostics
    }

    static func bind(_ config: WindowConfig, diagnostics: Diagnostics) async throws -> GuardedWindow {
        try environmentalGuard()
        guard let app = NSRunningApplication(processIdentifier: config.pid),
              !app.isTerminated, app.bundleIdentifier == config.bundle_id else {
            throw Failure(code: "app_identity_mismatch", message: "The configured PID is not the exact running bundle.")
        }
        let content = try await shareableContent()
        _ = try selectSCK(content, config: config, diagnostics: diagnostics)
        // Never recreate this proxy during an invocation or silently select a replacement AX window.
        let root = AXUIElementCreateApplication(config.pid)
        let system = AXUIElementCreateSystemWide()
        // This is local to this helper process. A timeout on root alone would not cover child proxies.
        try require(AXUIElementSetMessagingTimeout(system, 0.2) == .success,
                    "ax_timeout_unavailable", "Cannot bound Accessibility messaging.")
        let (windows, truncated) = try axArray(root, kAXWindowsAttribute, limit: 128)
        try require(!truncated, "too_many_windows", "Application has more than 128 AX windows; refusing ambiguous discovery.")
        let matches = try matchingAXWindows(windows, config: config)
        try require(matches.count == 1, "ax_window_mismatch",
                    "Exactly one AXWindow must match the observed title and bounds; rediscover rather than guessing.")
        let result = GuardedWindow(config: config, app: app, root: root, window: matches[0],
                                   system: system, diagnostics: diagnostics)
        try result.checkFast()
        return result
    }

    private static func selectSCK(_ content: SCShareableContent, config: WindowConfig,
                                  diagnostics: Diagnostics) throws -> SCWindow {
        guard let window = content.windows.first(where: { $0.windowID == config.window_id }) else {
            throw Failure(code: "window_missing", message: "The configured ScreenCaptureKit window no longer exists.")
        }
        diagnostics.geometry("screen_capture_kit", window.frame)
        try require(window.owningApplication?.processID == config.pid
                    && window.owningApplication?.bundleIdentifier == config.bundle_id
                    && window.title == config.window_title && window.windowLayer == 0,
                    "window_identity_mismatch", "ScreenCaptureKit PID, bundle, exact title or normal-window layer changed.")
        try require(window.isOnScreen && sameBounds(window.frame, config.expected_bounds.rect),
                    "window_geometry_mismatch", "The selected window is off-screen or its observed bounds changed.")
        // Public AX APIs do not guarantee a CGWindowID attribute. Fail closed on an ambiguous mapping.
        let equivalents = content.windows.filter {
            $0.owningApplication?.processID == config.pid && $0.title == config.window_title
                && sameBounds($0.frame, config.expected_bounds.rect)
        }
        try require(equivalents.count == 1, "ambiguous_window",
                    "Multiple SCK windows have this PID, title and geometry; exact AX-to-SCK binding is ambiguous.")
        return window
    }

    func refresh() async throws -> SCWindow {
        try checkFast()
        let window = try Self.selectSCK(await shareableContent(), config: config, diagnostics: diagnostics)
        let (windows, truncated) = try axArray(axApplication, kAXWindowsAttribute, limit: 128)
        try require(!truncated && windows.contains(where: { CFEqual($0, axWindow) }),
                    "ax_window_replaced", "The originally bound AXWindow is no longer in this application's window list.")
        let equivalents = try matchingAXWindows(windows, config: config)
        try require(equivalents.count == 1 && CFEqual(equivalents[0], axWindow),
                    "ax_window_replaced", "AX identity became ambiguous or changed.")
        try checkFast()
        return window
    }

    func checkFast(control: Bool = false) throws {
        try environmentalGuard(control: control)
        try require(!application.isTerminated
                    && application.processIdentifier == config.pid
                    && application.bundleIdentifier == config.bundle_id
                    && NSRunningApplication(processIdentifier: config.pid)?.bundleIdentifier == config.bundle_id,
                    "app_identity_mismatch", "The original running application exited or changed identity.")
        var pid: pid_t = 0
        try require(AXUIElementGetPid(axApplication, &pid) == .success && pid == config.pid,
                    "ax_app_mismatch", "The locked Accessibility application proxy changed identity.")
        try require(AXUIElementGetPid(axWindow, &pid) == .success && pid == config.pid
                    && axString(axWindow, kAXRoleAttribute) == kAXWindowRole
                    && axString(axWindow, kAXTitleAttribute) == config.window_title,
                    "ax_window_mismatch", "The locked AXWindow no longer has the exact PID, role and title.")
        guard let rect = axBounds(axWindow) else {
            throw Failure(code: "ax_geometry_unavailable", message: "AXWindow geometry is unavailable or invalid.")
        }
        diagnostics.geometry("accessibility", rect)
        try require(sameBounds(rect, config.expected_bounds.rect), "ax_geometry_mismatch", "AXWindow geometry changed.")
        try require(axAttribute(axWindow, kAXMinimizedAttribute) as? Bool == false,
                    "window_minimized", "The selected window is minimized or its minimized state is unknown.")
        guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, config.window_id) as? [[String: Any]],
              let item = info.first(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == config.window_id }),
              let rawBounds = item[kCGWindowBounds as String] as? [String: Any],
              let cgRect = CGRect(dictionaryRepresentation: rawBounds as CFDictionary) else {
            throw Failure(code: "cg_window_unavailable", message: "Core Graphics cannot identify the selected window.")
        }
        diagnostics.geometry("core_graphics", cgRect)
        try require((item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == config.pid
                    && item[kCGWindowName as String] as? String == config.window_title
                    && (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
                    && (item[kCGWindowIsOnscreen as String] as? Bool) == true
                    && sameBounds(cgRect, config.expected_bounds.rect),
                    "cg_window_mismatch", "Core Graphics window identity, on-screen state, layer or bounds changed.")
        if control { try checkFocus() }
    }

    func checkFocus() throws {
        try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == config.pid
                    && axAttribute(axApplication, kAXFrontmostAttribute) as? Bool == true,
                    "focus_lost", "The explicitly selected application is not frontmost.")
        guard let focused = axElement(axApplication, kAXFocusedWindowAttribute) else {
            throw Failure(code: "focused_window_unknown", message: "The application's focused AXWindow is unavailable.")
        }
        try require(CFEqual(focused, axWindow), "focused_window_mismatch", "A different window in this application has focus.")
    }

    func resolve(_ path: String) throws -> AXUIElement {
        var node = axWindow
        let deadline = uptime() + 0.25
        for index in try parsePath(path) {
            try require(uptime() < deadline, "ax_inspection_timeout", "AX path lookup stalled; refusing stale input.")
            try require(!isPrivateOrMenu(node), "unsupported_target", "Menu and secure-input subtrees are excluded.")
            let (children, _) = try axArray(node, kAXChildrenAttribute, limit: maximumChildren)
            try require(children.indices.contains(index), "ax_path_changed", "Observed AX path no longer exists; inspect a fresh tree.")
            node = children[index]
            try require(axString(node, kAXRoleAttribute) != kAXWindowRole,
                        "nested_window", "An observed path may not cross into another AXWindow.")
        }
        return node
    }

    func owns(_ node: AXUIElement, target: AXUIElement? = nil) throws {
        var current: AXUIElement? = node
        var foundTarget = target == nil
        var visited = Set<AXUIElement>()
        let deadline = uptime() + 0.25
        for _ in 0..<64 {
            try require(uptime() < deadline, "ax_inspection_timeout", "AX ancestry inspection stalled; refusing stale input.")
            guard let value = current, visited.insert(value).inserted else { break }
            var pid: pid_t = 0
            try require(AXUIElementGetPid(value, &pid) == .success && pid == config.pid,
                        "hit_wrong_app", "Accessibility ancestry belongs to a different application.")
            if let target, CFEqual(value, target) { foundTarget = true }
            if axString(value, kAXRoleAttribute) == kAXWindowRole {
                try require(CFEqual(value, axWindow) && foundTarget, "hit_wrong_window_or_target",
                            "A different window or control covers the target, including another window in the same application.")
                return
            }
            current = axElement(value, kAXParentAttribute)
        }
        throw Failure(code: "unproven_ancestry", message: "Cannot prove that the target belongs to the exact selected AXWindow.")
    }

    func hitTest(_ point: CGPoint, target: AXUIElement) throws {
        var hit: AXUIElement?
        try require(AXUIElementCopyElementAtPosition(axSystem,
                                                    Float(point.x), Float(point.y), &hit) == .success && hit != nil,
                    "hit_test_failed", "The target is not hit-testable.")
        try owns(hit!, target: target)
    }

    func activateForControl(_ cancellation: Cancellation) async throws {
        try cancellation.check()
        try checkFast()
        try environmentalGuard(control: true)
        try require(application.activate(options: []), "activation_failed", "The allowed application could not be activated.")
        try require(AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString) == .success,
                    "raise_failed", "The exact allowed AXWindow could not be raised.")
        let deadline = uptime() + 2
        while uptime() < deadline {
            try cancellation.check()
            try checkFast()
            if (try? checkFocus()) != nil {
                _ = try await refresh()
                try checkFocus()
                return
            }
            try await pause(0.05)
        }
        throw Failure(code: "activation_stale", message: "Activation did not establish the exact focused window in two seconds.")
    }
}

private func uptime() -> Double { ProcessInfo.processInfo.systemUptime }

private func pause(_ seconds: Double) async throws {
    if seconds > 0 { try await Task.sleep(nanoseconds: UInt64(min(seconds, 600) * 1_000_000_000)) }
}

private final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var sources = [DispatchSourceSignal]()

    init() {
        for number in [SIGINT, SIGTERM] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .global(qos: .userInitiated))
            source.setEventHandler { [weak self] in
                guard let self else { return }
                self.lock.lock()
                self.cancelled = true
                self.lock.unlock()
            }
            source.resume()
            sources.append(source)
        }
    }

    func check() throws {
        lock.lock()
        let value = cancelled
        lock.unlock()
        try require(!value, "cancelled", "Interrupted; no further control events will be posted.")
    }
}

private func ease(_ t: Double) -> Double {
    let t = min(1, max(0, t))
    return t * t * t * (t * (6 * t - 15) + 10)
}

private func motionDuration(_ distance: Double) -> Double {
    min(1.25, max(0.35, distance / 1_000))
}

private func pointBetween(_ start: CGPoint, _ end: CGPoint, fraction: Double) -> CGPoint {
    let t = ease(fraction)
    return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
}

private func pointer() throws -> CGPoint {
    guard let point = CGEvent(source: nil)?.location, point.x.isFinite, point.y.isFinite else {
        throw Failure(code: "pointer_unavailable", message: "Cannot read the current pointer position.")
    }
    return point
}

private func noHeldInput() throws {
    let flags = CGEventSource.flagsState(.combinedSessionState)
    let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]
    try require(flags.intersection(modifiers).isEmpty,
                "input_in_progress", "A modifier key is held; refusing to interfere with live input.")
    for index in UInt32(0)...UInt32(4) {
        if let button = CGMouseButton(rawValue: index) {
            try require(!CGEventSource.buttonState(.combinedSessionState, button: button),
                        "input_in_progress", "A mouse button is held; refusing to drag or interfere with live input.")
        }
    }
}

@available(macOS 15.0, *)
@MainActor
private struct Target {
    let node: AXUIElement
    let path: String
    let label: String
    let labelSource: String
    let title: String?
    let role: String
    let bounds: CGRect
    var point: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    static func bind(_ guardWindow: GuardedWindow, path: String, label: String, click: Bool) throws -> Target {
        let node = try guardWindow.resolve(path)
        let role = axString(node, kAXRoleAttribute) ?? ""
        let clickable = [kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole]
        let movable = clickable + [kAXTextFieldRole, kAXTextAreaRole]
        try require((click ? clickable : movable).contains(role) && !isPrivateOrMenu(node),
                    "unsupported_target", "Only buttons, checkboxes and radio buttons support clicks; text fields/areas support move only.")
        guard let observed = exactLabel(node), observed.0 == label else {
            throw Failure(code: "label_mismatch", message: "The exact observed AXTitle (or AXDescription when title is empty) must match.")
        }
        guard let bounds = axBounds(node) else {
            throw Failure(code: "target_geometry_invalid", message: "Target geometry is unavailable, nonfinite or only one pixel high/wide.")
        }
        try require(guardWindow.config.expected_bounds.rect.contains(bounds),
                    "target_outside_window", "Target bounds must be fully inside the selected window; off-screen sentinel nodes are not usable.")
        try require(axAttribute(node, kAXEnabledAttribute) as? Bool == true,
                    "target_disabled", "Target is disabled or its enabled state is unknown.")
        try guardWindow.owns(node)
        return Target(node: node, path: path, label: label, labelSource: observed.1,
                      title: axString(node, kAXTitleAttribute), role: role, bounds: bounds)
    }

    func verify(_ guardWindow: GuardedWindow) throws {
        let current = try guardWindow.resolve(path)
        let observed = exactLabel(current)
        try require(CFEqual(current, node) && axString(current, kAXRoleAttribute) == role
                    && observed?.0 == label && observed?.1 == labelSource
                    && axString(current, kAXTitleAttribute) == title,
                    "target_changed", "Observed AX path, node, role, exact title or label changed.")
        // Unlike window pixel rounding, a control must not move at all before a click.
        try require(axBounds(current) == bounds && guardWindow.config.expected_bounds.rect.contains(bounds)
                    && axAttribute(current, kAXEnabledAttribute) as? Bool == true,
                    "target_changed", "Target bounds or enabled state changed.")
        try guardWindow.owns(current)
        try guardWindow.hitTest(point, target: current)
    }
}

@available(macOS 15.0, *)
@MainActor
private func control(_ window: GuardedWindow, invocation: Invocation, cancellation: Cancellation) async throws {
    let click = invocation.command == "click"
    let target = try Target.bind(window, path: invocation.path!, label: invocation.label!, click: click)
    try await window.activateForControl(cancellation)
    try noHeldInput()
    try window.checkFast(control: true)
    try target.verify(window)
    let start = try pointer()
    let distance = hypot(target.point.x - start.x, target.point.y - start.y)
    try require(distance.isFinite && distance <= 100_000, "invalid_pointer_distance", "Pointer distance is not safely bounded.")
    let duration = motionDuration(distance)
    let began = uptime()
    var last = start
    var updates = 0
    var nextFrame = began
    var lastFrame = began
    while true {
        try await pause(max(0, nextFrame - uptime()))
        try cancellation.check()
        try noHeldInput()
        try window.checkFast(control: true)
        try target.verify(window)
        let actual = try pointer()
        try require(hypot(actual.x - last.x, actual.y - last.y) <= 3,
                    "pointer_interrupted", "Pointer moved independently; motion was cancelled without clicking.")
        let now = uptime()
        try require(now - lastFrame <= 0.25 && now - began <= duration + 0.25,
                    "motion_stalled", "Safety checks or input stalled; motion was cancelled rather than jumping.")
        let fraction = min(1, (now - began) / duration)
        let point = pointBetween(start, target.point, fraction: fraction)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else {
            throw Failure(code: "event_creation_failed", message: "Could not construct a pointer motion event.")
        }
        try cancellation.check()
        try noHeldInput()
        try window.checkFocus()
        event.flags = []
        event.post(tap: .cghidEventTap)
        last = point
        lastFrame = now
        updates += 1
        if fraction >= 1 { break }
        // Never burst late frames to catch up. Recompute position using elapsed time.
        nextFrame = max(nextFrame + 1 / 60, now + 1 / 60)
    }
    _ = try await window.refresh()
    let settleUntil = uptime() + 0.1
    repeat {
        try await pause(1 / 60)
        try cancellation.check()
        try noHeldInput()
        try window.checkFast(control: true)
        try target.verify(window)
        let actual = try pointer()
        try require(hypot(actual.x - target.point.x, actual.y - target.point.y) <= 2,
                    "pointer_interrupted", "Pointer did not stay at the target; refusing to click.")
    } while uptime() < settleUntil
    if click {
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                 mouseCursorPosition: target.point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                               mouseCursorPosition: target.point, mouseButton: .left) else {
            throw Failure(code: "event_creation_failed", message: "Could not construct both click events; neither was posted.")
        }
        try cancellation.check()
        try noHeldInput()
        try window.checkFast(control: true)
        try target.verify(window)
        try cancellation.check()
        try noHeldInput()
        try window.checkFocus()
        let actual = try pointer()
        try require(hypot(actual.x - target.point.x, actual.y - target.point.y) <= 2,
                    "pointer_interrupted", "Pointer changed immediately before the click; no click was posted.")
        down.flags = []
        up.flags = []
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        // Post a complete pair without suspension: cancellation must never leave a button held.
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    emit(["status": "completed", "command": invocation.command, "window": window.config.json,
          "path": target.path, "label": target.label, "role": target.role,
          "target_bounds": Bounds(target.bounds).json, "planned_motion_seconds": duration,
          "elapsed_seconds": uptime() - began, "motion_updates": updates,
          "click_posted": click, "application_effect_verified": false])
}

@available(macOS 15.0, *)
@MainActor
private func tree(_ window: GuardedWindow) async throws {
    let deadline = uptime() + 15
    var nodes = [[String: Any]]()
    var seen = Set<AXUIElement>()
    var truncated = false
    func visit(_ node: AXUIElement, path: String, depth: Int) throws {
        if nodes.count >= maximumNodes || depth > maximumDepth || uptime() > deadline {
            truncated = true
            return
        }
        guard seen.insert(node).inserted, !isPrivateOrMenu(node) else { return }
        if depth > 0 && axString(node, kAXRoleAttribute) == kAXWindowRole { return }
        let role = axString(node, kAXRoleAttribute) ?? ""
        let label = exactLabel(node)
        var row: [String: Any] = ["path": path, "role": role, "label": label?.0 as Any? ?? NSNull(),
                                  "label_source": label?.1 as Any? ?? NSNull()]
        if let rect = axBounds(node) {
            row["bounds"] = Bounds(rect).json
            row["inside_window"] = window.config.expected_bounds.rect.contains(rect)
        }
        row["enabled"] = (axAttribute(node, kAXEnabledAttribute) as? Bool) as Any? ?? NSNull()
        nodes.append(row)
        let (children, capped) = try axArray(node, kAXChildrenAttribute, limit: maximumChildren)
        truncated = truncated || capped
        for (index, child) in children.enumerated() {
            if nodes.count >= maximumNodes || uptime() > deadline { truncated = true; break }
            try visit(child, path: "\(path).\(index)", depth: depth + 1)
        }
    }
    try visit(window.axWindow, path: "w", depth: 0)
    _ = try await window.refresh()
    emit(["status": "completed", "command": "tree", "window": window.config.json,
          "nodes": nodes, "truncated": truncated,
          "limits": ["nodes": maximumNodes, "depth": maximumDepth, "children_per_node": maximumChildren]])
}

@available(macOS 15.0, *)
private final class RecordingObserver: NSObject, SCRecordingOutputDelegate, SCStreamDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var finished = false
    private var failure: Error?
    private var startReturnedAt: Double?

    @MainActor
    func beginCapture(_ stream: SCStream) {
        stream.startCapture { [self] error in captureStartReturned(error) }
    }

    func captureStartReturned(_ error: Error?) {
        lock.lock()
        startReturnedAt = uptime()
        if failure == nil { failure = error }
        lock.unlock()
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        lock.lock()
        started = true
        lock.unlock()
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        lock.lock()
        finished = true
        lock.unlock()
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { fail(error) }
    func stream(_ stream: SCStream, didStopWithError error: Error) { fail(error) }

    private func fail(_ error: Error) {
        lock.lock()
        if failure == nil { failure = error }
        lock.unlock()
    }

    func state() -> (started: Bool, finished: Bool, failure: Error?, startReturnedAt: Double?) {
        lock.lock()
        defer { lock.unlock() }
        return (started, finished, failure, startReturnedAt)
    }
}

@available(macOS 15.0, *)
@MainActor
private func record(_ window: GuardedWindow, invocation: Invocation, cancellation: Cancellation) async throws -> Int32 {
    let output = invocation.output!
    let seconds = invocation.seconds!
    let (width, height) = try dimensions(width: invocation.width, bounds: window.config.expected_bounds)
    let selected = try await window.refresh()
    try cancellation.check()
    try validateOutput(output)
    let configuration = SCStreamConfiguration()
    configuration.width = width
    configuration.height = height
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
    configuration.showsCursor = true
    configuration.capturesAudio = false
    configuration.captureMicrophone = false
    configuration.ignoreShadowsSingleWindow = true
    configuration.queueDepth = 3
    let recordingConfiguration = SCRecordingOutputConfiguration()
    recordingConfiguration.outputURL = output
    recordingConfiguration.outputFileType = .mp4
    recordingConfiguration.videoCodecType = .h264
    try require(recordingConfiguration.availableVideoCodecTypes.contains(.h264)
                && recordingConfiguration.availableOutputFileTypes.contains(.mp4),
                "encoding_unavailable", "This system does not offer H.264 MP4 recording.")
    let observer = RecordingObserver()
    let recording = SCRecordingOutput(configuration: recordingConfiguration, delegate: observer)
    let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: selected),
                          configuration: configuration, delegate: observer)
    var attemptedStart = false
    var stopCompleted = false
    var lastWatchdog = uptime()
    var recordedStart: Double?
    let metadata: [String: Any] = [
        "command": "record", "window": window.config.json, "output": output.path,
        "width": width, "height": height, "fps": 30, "codec": "h264", "container": "mp4",
        "cursor_visible": true, "system_audio": false, "microphone": false,
        "shadows": false, "requested_duration_seconds": seconds
    ]
    func report(_ status: String, extras: [String: Any] = [:]) {
        var result = metadata
        result["status"] = status
        let duration = CMTimeGetSeconds(recording.recordedDuration)
        result["recorded_duration_seconds"] = duration.isFinite ? max(0, duration) : 0
        result["recorded_bytes"] = max(0, recording.recordedFileSize)
        result["elapsed_since_ready_seconds"] = recordedStart.map { max(0, uptime() - $0) } ?? 0
        result.merge(extras) { _, new in new }
        emit(result)
    }
    func watchdog(force: Bool = false) async throws {
        try cancellation.check()
        if force || uptime() - lastWatchdog >= 0.5 {
            _ = try await window.refresh()
            lastWatchdog = uptime()
        }
        if let error = observer.state().failure { throw error }
    }
    func stop() async throws {
        let _: Void = try await bounded(5, "Stopping capture") { finish in
            stream.stopCapture { error in
                if let error { finish(.failure(error)) } else { finish(.success(())) }
            }
        }
        stopCompleted = true
    }
    do {
        try stream.addRecordingOutput(recording)
        try await watchdog(force: true)
        try validateOutput(output)
        attemptedStart = true
        let startAPIDeadline = uptime() + 5
        observer.beginCapture(stream)
        while observer.state().startReturnedAt == nil || !observer.state().started {
            try await watchdog()
            let state = observer.state()
            try require(!state.finished, "recording_ended_early", "Recording finished before start was acknowledged.")
            if let returnedAt = state.startReturnedAt {
                try require(uptime() < returnedAt + 8, "recording_start_timeout", "Recording delegate did not acknowledge start.")
            } else {
                try require(uptime() < startAPIDeadline, "api_timeout", "Starting capture timed out.")
            }
            try await pause(0.05)
        }
        try await watchdog(force: true)
        try require(!observer.state().finished, "recording_ended_early", "Recording finished before READY.")
        recordedStart = uptime()
        report("started", extras: ["ready": true])
        let end = uptime() + seconds
        while uptime() < end {
            try await watchdog()
            try require(!observer.state().finished, "recording_ended_early", "Recording finished before the requested stop.")
            try await pause(min(0.05, max(0, end - uptime())))
        }
        try await watchdog(force: true)
        try await stop()
        let finishDeadline = uptime() + 8
        while !observer.state().finished {
            try cancellation.check()
            if let error = observer.state().failure { throw error }
            try require(uptime() < finishDeadline, "recording_finish_timeout", "Recording did not finish finalizing.")
            try await pause(0.05)
        }
        if let error = observer.state().failure { throw error }
        let actualDuration = CMTimeGetSeconds(recording.recordedDuration)
        let values = try output.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try require(actualDuration.isFinite && actualDuration > 0 && recording.recordedFileSize > 0
                    && values.isRegularFile == true && values.isSymbolicLink != true && (values.fileSize ?? 0) > 0,
                    "empty_recording", "Finalized output has no valid recorded duration or file data.")
        report("completed", extras: ["ready": false, "file_finalized": true])
        return 0
    } catch {
        var cleanup: [String: Any] = [:]
        if attemptedStart && !stopCompleted {
            // A recording-output failure does not itself guarantee the stream stopped.
            do { try await stop() }
            catch { cleanup["stop_error"] = failureJSON(error) }
        }
        cleanup["stop_completed"] = stopCompleted
        cleanup["error"] = failureJSON(error)
        cleanup["ready"] = false
        cleanup["partial_file_kept"] = FileManager.default.fileExists(atPath: output.path)
        cleanup["file_finalized"] = false
        report("failure", extras: cleanup)
        return 1
    }
}

@available(macOS 15.0, *)
@MainActor
private func run(_ invocation: Invocation) async -> Int32 {
    if invocation.command == "list" {
        do {
            let content = try await shareableContent()
            let bundle = invocation.bundle!
            let windows: [[String: Any]] = content.windows
                .filter { $0.owningApplication?.bundleIdentifier == bundle && $0.windowLayer == 0 }
                .sorted { $0.windowID < $1.windowID }
                .compactMap { window in
                    guard let app = window.owningApplication, let title = window.title, !title.isEmpty,
                          NSRunningApplication(processIdentifier: app.processID)?.bundleIdentifier == bundle,
                          Bounds(window.frame).valid else { return nil }
                    var row = WindowConfig(pid: app.processID, bundle_id: bundle, window_id: window.windowID,
                                           window_title: title, expected_bounds: Bounds(window.frame)).json
                    row["on_screen"] = window.isOnScreen
                    return row
                }
            emit(["status": "completed", "command": "list", "bundle_id": bundle,
                  "windows": windows, "permissions": permissionJSON(), "session_lock": lockState().rawValue])
            return 0
        } catch {
            emit(["status": "failure", "command": "list", "bundle_id": invocation.bundle!,
                  "error": failureJSON(error), "permissions": permissionJSON(), "session_lock": lockState().rawValue])
            return 1
        }
    }
    let config = invocation.config!
    let diagnostics = Diagnostics(config: config)
    do {
        let window = try await GuardedWindow.bind(config, diagnostics: diagnostics)
        _ = try await window.refresh()
        switch invocation.command {
        case "preflight":
            var data = diagnostics.data
            let frontmost = (try? window.checkFocus()) != nil
            data.merge(["status": "completed", "command": "preflight", "permissions": permissionJSON(),
                        "session_lock": lockState().rawValue, "viable": true,
                        "recording_viable": true, "control_viable": CGPreflightPostEventAccess(),
                        "exact_window_frontmost": frontmost, "control_requires_activation": !frontmost,
                        "geometry_tolerance_points": geometryTolerance]) { _, new in new }
            emit(data)
            return 0
        case "tree":
            try await tree(window)
            return 0
        case "move", "click":
            try await control(window, invocation: invocation, cancellation: Cancellation())
            return 0
        case "record":
            return try await record(window, invocation: invocation, cancellation: Cancellation())
        default:
            throw Failure(code: "usage", message: "Unknown command.")
        }
    } catch {
        var data = diagnostics.data
        data.merge(["status": "failure", "command": invocation.command, "viable": false,
                    "recording_viable": false, "control_viable": false, "error": failureJSON(error),
                    "permissions": permissionJSON(), "session_lock": lockState().rawValue]) { _, new in new }
        if invocation.command == "record", let output = invocation.output, let seconds = invocation.seconds,
           let size = try? dimensions(width: invocation.width, bounds: config.expected_bounds) {
            data.merge(["output": output.path, "width": size.0, "height": size.1,
                        "requested_duration_seconds": seconds, "recorded_duration_seconds": 0,
                        "recorded_bytes": 0, "capture_started": false, "ready": false]) { _, new in new }
        }
        emit(data)
        return 1
    }
}

private func selfTest() throws {
    var checks = 0
    func check(_ value: Bool, _ message: String) throws {
        try require(value, "self_test_failed", message)
        checks += 1
    }
    func rejected(_ body: () throws -> Void) throws {
        do { try body() }
        catch { checks += 1; return }
        throw Failure(code: "self_test_failed", message: "Invalid input was accepted.")
    }
    try check(ease(0) == 0 && ease(1) == 1 && ease(-1) == 0 && ease(2) == 1, "Easing endpoints or clamping.")
    var previous = 0.0
    for step in 0...10_000 {
        let value = ease(Double(step) / 10_000)
        try check(value >= previous - 1e-12 && value >= -1e-12 && value <= 1 + 1e-12, "Easing monotonicity or bounds.")
        previous = value
    }
    for distance in [0.0, 1, 350, 1_000, 1_250, 100_000] {
        try check((0.35...1.25).contains(motionDuration(distance)), "Motion duration bounds.")
    }
    let a = CGPoint(x: -300, y: 20), b = CGPoint(x: 900, y: -10)
    try check(pointBetween(a, b, fraction: 0) == a && pointBetween(a, b, fraction: 1) == b, "Motion endpoints.")
    let bounds = Bounds(CGRect(x: -400, y: 0, width: 1_600, height: 900))
    let size = try dimensions(width: 1_920, bounds: bounds)
    try check(size.0 == 1_920 && size.1 == 1_080, "Aspect ratio calculation.")
    try check(!Bounds(CGRect(x: 0, y: 0, width: 1, height: 1)).valid, "One-pixel sentinel bounds.")
    try check(!Bounds(CGRect(x: 0, y: 0, width: -100, height: 100)).valid, "Negative bounds.")
    try check(!Bounds(CGRect(x: Double.infinity, y: 0, width: 100, height: 100)).valid, "Nonfinite bounds.")
    try check(sameBounds(bounds.rect, bounds.rect.offsetBy(dx: 1, dy: -1)), "Geometry rounding tolerance.")
    try check(!sameBounds(bounds.rect, bounds.rect.offsetBy(dx: 2, dy: 0)), "Geometry changes.")
    try check(lockState(from: nil) == .unknown && lockState(from: [:]) == .unknown, "Missing lock state.")
    try check(lockState(from: ["CGSSessionScreenIsLocked": "false"]) == .unknown, "Invalid lock state.")
    try check(lockState(from: ["CGSSessionScreenIsLocked": NSNumber(value: 0)]) == .unknown, "Numeric lock state.")
    try check(lockState(from: ["CGSSessionScreenIsLocked": false]) == .unlocked, "Unlocked state.")
    try check(lockState(from: ["CGSSessionScreenIsLocked": true]) == .locked, "Locked state.")
    try check(try parsePath("w.0.511") == [0, 511], "Observed AX path.")
    for path in ["w", "w.", "w.-1", "w.01", "w.512", "app.0", "w.0..1"] {
        try rejected { _ = try parsePath(path) }
    }
    for width in [0, 1_279, 1_281, 4_097] {
        try rejected { _ = try dimensions(width: width, bounds: bounds) }
    }
    try rejected { _ = try dimensions(width: 4_096, bounds: Bounds(CGRect(x: 0, y: 0, width: 2, height: 32_768))) }
    try rejected { _ = try absoluteURL("relative/config.json") }
    try rejected { _ = try Invocation.parse(["record", "/invalid/config.json", "nan", "/invalid/output.mp4"]) }
    try rejected { _ = try Invocation.parse(["record", "/invalid/config.json", "601", "/invalid/output.mp4"]) }
    emit(["status": "completed", "command": "--self-test", "checks": checks,
          "live_api_calls": false, "permissions_requested": false, "input_events_posted": false])
}

private let help = """
demo-native — optional macOS-only window recording and pointer-control adapter

Not required by the platform-neutral skill; not a Windows or Linux implementation.
Use only after the user identifies/approves a macOS capture host.
Ask for hardware/OS details or approval for limited read-only identification first.
Do not auto-detect the platform. list/preflight/tree require scoped inspection approval;
existing macOS privacy permissions are not task authorization.
Requires macOS 15+ and an SDK with ScreenCaptureKit SCRecordingOutput.
Build: swiftc -parse-as-library macos.swift -o demo-native

  demo-native --help
  demo-native --self-test
  demo-native list BUNDLE_ID
  demo-native preflight /absolute/CONFIG.json
  demo-native tree /absolute/CONFIG.json
  demo-native move /absolute/CONFIG.json w.OBSERVED.INDICES 'EXACT OBSERVED LABEL'
  demo-native click /absolute/CONFIG.json w.OBSERVED.INDICES 'EXACT OBSERVED LABEL'
  demo-native record /absolute/CONFIG.json SECONDS /absolute/OUTPUT.mp4 [WIDTH]

Config: pid, bundle_id, window_id, window_title, expected_bounds {x,y,width,height}.
Copy exact identity and point-space bounds from scoped list output, never a screenshot.
Seconds: finite 1–600. Width: even 1280–4096 (default 1920); aspect ratio preserved.
Recording: H.264 MP4, 30 fps, visible cursor, no shadows, no system audio or microphone.
Existing output paths are refused; failures retain partial output and exit nonzero.
Move/click alone authorize activation and raising of the configured exact window.
Click: AXButton/AXCheckBox/AXRadioButton. AXTextField/AXTextArea: move only.
No typing, coordinate input, permission requests, preferences, or sleep inhibition.
SIGINT/SIGTERM cancel input or stop capture; SIGKILL cannot finalize output.
All operational results are JSON Lines. Exit: 0 success, 1 runtime refusal, 2 invalid input.
"""

@main
private struct DemoNative {
    static func main() {
        let invocation: Invocation
        do {
            invocation = try Invocation.parse(Array(CommandLine.arguments.dropFirst()))
            if invocation.command == "--help" { print(help); return }
            if invocation.command == "--self-test" { try selfTest(); return }
        } catch {
            emit(["status": "failure", "error": failureJSON(error)])
            exit(2)
        }
        guard #available(macOS 15.0, *) else {
            emit(["status": "failure", "error": ["code": "unsupported_os", "message": "macOS 15 or later is required."]])
            exit(1)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in exit(await run(invocation)) }
        app.run()
    }
}
