"""Platform-neutral approval/timing and final MP4 checks; no capture or OS probes."""

import argparse
from decimal import Decimal, InvalidOperation
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys

AUDIO = {"silent", "voiceover", "system", "voiceover+system"}


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def positive_int(value):
    return type(value) is int and value > 0


def load_plan(path, approved=False):
    plan = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(plan, dict):
        raise ValueError("The plan must be a JSON object.")
    errors, warnings = [], []
    if plan.get("schema_version") != 1:
        errors.append("schema_version must be 1.")
    for name in ("title", "version"):
        if not isinstance(plan.get(name), str) or not plan[name].strip():
            errors.append(f"{name} must be a nonempty string.")
    for name in ("fps", "width", "height"):
        if not positive_int(plan.get(name)):
            errors.append(f"{name} must be a positive integer.")
    for name in ("width", "height"):
        if positive_int(plan.get(name)) and plan[name] % 2:
            errors.append(f"{name} must be even for yuv420p.")
    expected_frames = None
    try:
        seconds = Decimal(str(plan.get("target_seconds")))
        frame_total = seconds * Decimal(str(plan.get("fps")))
        if not seconds.is_finite() or seconds <= 0 or not frame_total.is_finite():
            raise ValueError("Non-positive or non-finite duration.")
        if frame_total != frame_total.to_integral_value():
            raise ValueError("Duration is not an integral frame count.")
        expected_frames = int(frame_total)
    except (InvalidOperation, ValueError, TypeError):
        errors.append("target_seconds * fps must be a positive integral frame count.")
    if not isinstance(plan.get("audio"), str) or plan["audio"] not in AUDIO:
        errors.append("Explicit audio choice required: silent, voiceover, system, or voiceover+system.")
    hardware = plan.get("hardware")
    if not isinstance(hardware, dict):
        errors.append("hardware must record the user's host decision.")
    else:
        if hardware.get("method") not in ("provided", "approved-discovery"):
            errors.append("hardware.method must be provided or approved-discovery.")
        if hardware.get("method") == "approved-discovery" and hardware.get("discovery_approved") is not True:
            errors.append("Host discovery must have the user's explicit approval.")
        for name in ("os", "capture_host"):
            if not isinstance(hardware.get(name), str) or not hardware[name].strip():
                errors.append(f"hardware.{name} must be identified by the user or approved discovery.")
    if plan.get("capture_mode") not in ("browser", "native", "mixed", "remote"):
        errors.append("capture_mode must be browser, native, mixed, or remote.")
    if plan.get("evidence_mode") not in ("live", "prepared-real", "verified-replay", "illustrative", "mixed"):
        errors.append("An explicit evidence_mode is required.")
    scenes = plan.get("scenes")
    total_words, pause_frames, previous_end = 0, 0, 0
    ids = set()
    if not isinstance(scenes, list) or not scenes:
        errors.append("scenes must be a nonempty array.")
        scenes = []
    for index, scene in enumerate(scenes):
        prefix = f"Scene {index + 1}"
        if not isinstance(scene, dict):
            errors.append(f"{prefix} must be an object.")
            continue
        identifier = scene.get("id")
        if not isinstance(identifier, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", identifier):
            errors.append(f"{prefix} needs a kebab-case id.")
        elif identifier in ids:
            errors.append(f"{prefix} duplicates id {identifier}.")
        else:
            ids.add(identifier)
        start, end, pause = (scene.get(key) for key in ("start_frame", "end_frame", "pause_frames"))
        if not all(type(value) is int for value in (start, end, pause)):
            errors.append(f"{prefix} frame boundaries and pause_frames must be integers.")
            continue
        if start != previous_end or end <= start:
            errors.append(f"{prefix} is not contiguous or has non-positive duration.")
        if pause < 0 or pause > end - start:
            errors.append(f"{prefix} has an invalid pause.")
        previous_end = end
        pause_frames += pause
        for name in ("direction", "expected_result"):
            if not isinstance(scene.get(name), str) or not scene[name].strip():
                errors.append(f"{prefix} needs {name}.")
        narration = scene.get("narration")
        if not isinstance(narration, str):
            errors.append(f"{prefix} narration must be a string (empty for deliberate silence).")
            continue
        words = len(re.findall(r"\b[\w]+(?:['-][\w]+)*\b", narration))
        total_words += words
        speaking_frames = end - start - pause
        if words and speaking_frames <= 0:
            errors.append(f"{prefix} has narration but no speaking time.")
        elif words and positive_int(plan.get("fps")):
            wpm = words * 60 * plan["fps"] / speaking_frames
            if wpm > 170:
                warnings.append(f"{prefix}: {wpm:.0f} words/minute; rehearse or simplify the narration.")
    if expected_frames is not None and previous_end != expected_frames:
        errors.append(f"Scenes end at frame {previous_end}, expected {expected_frames}.")
    if approved:
        script = plan.get("script")
        if not isinstance(script, dict):
            errors.append("An approved script record is required.")
        else:
            if script.get("approved") is not True or not isinstance(script.get("approval_note"), str) or not script["approval_note"].strip():
                errors.append("Record explicit user approval, not an inferred approval.")
            path_value = script.get("path")
            if not isinstance(path_value, str) or not path_value:
                errors.append("script.path must name the approved file.")
            else:
                script_path = Path(path_value)
                if not script_path.is_absolute():
                    script_path = path.parent / script_path
                if not script_path.is_file():
                    errors.append("The approved script file is missing.")
                elif script.get("sha256") != sha256(script_path):
                    errors.append("The script differs from the approved SHA-256 binding.")
        if re.search(r"replace with|replace-with|<[^>]+>", json.dumps(plan), re.IGNORECASE):
            errors.append("Template placeholders remain in the approved plan.")
    summary = {
        "expected_frames": expected_frames,
        "spoken_words": total_words,
        "pause_frames": pause_frames,
        "audio": plan.get("audio"),
        "errors": errors, "warnings": warnings, "passed": not errors,
    }
    return plan, summary


def mp4_faststart(path):
    atoms = []
    length = path.stat().st_size
    with path.open("rb") as source:
        while source.tell() < length:
            position = source.tell()
            header = source.read(8)
            if len(header) != 8:
                raise ValueError("Truncated MP4 atom.")
            size, kind = struct.unpack(">I4s", header)
            header_length = 8
            if size == 1:
                extended = source.read(8)
                if len(extended) != 8:
                    raise ValueError("Truncated extended MP4 atom.")
                size = struct.unpack(">Q", extended)[0]
                header_length = 16
            elif size == 0:
                size = length - position
            if size < header_length or position + size > length:
                raise ValueError("Invalid MP4 atom size.")
            atoms.append(kind)
            source.seek(position + size)
    if b"moov" not in atoms or b"mdat" not in atoms:
        raise ValueError("MP4 moov/mdat atoms missing.")
    return atoms.index(b"moov") < atoms.index(b"mdat")


def check_streams(metadata, plan, expected_frames):
    errors = []
    streams = metadata.get("streams", [])
    videos = [stream for stream in streams if stream.get("codec_type") == "video"]
    audio = [stream for stream in streams if stream.get("codec_type") == "audio"]
    if len(videos) != 1:
        return ["Exactly one video stream is required."]
    video = videos[0]
    for name, expected in (("codec_name", "h264"), ("pix_fmt", "yuv420p"),
                           ("width", plan["width"]), ("height", plan["height"])):
        if video.get(name) != expected:
            errors.append(f"{name}: expected {expected}, found {video.get(name)}.")
    for name in ("r_frame_rate", "avg_frame_rate"):
        try:
            if Fraction(video[name]) != Fraction(plan["fps"]):
                errors.append(f"{name} differs from the planned frame rate.")
        except (ValueError, KeyError, ZeroDivisionError, TypeError):
            errors.append(f"{name} is unavailable or invalid.")
    try:
        if int(video["nb_read_frames"]) != expected_frames:
            errors.append("Decoded frame count differs from the plan.")
    except (ValueError, KeyError, TypeError):
        errors.append("Decoded frame count is unavailable.")
    for scope, fields in (("video", video), ("container", metadata.get("format", {}))):
        try:
            duration = Decimal(str(fields["duration"]))
            if not duration.is_finite() or abs(duration - Decimal(str(plan["target_seconds"]))) > Decimal("0.5") / plan["fps"]:
                errors.append(f"{scope} duration differs by more than half a frame.")
        except (InvalidOperation, ValueError, KeyError, TypeError):
            errors.append(f"{scope} duration is unavailable or invalid.")
    if video.get("sample_aspect_ratio") != "1:1":
        errors.append("Sample aspect ratio must be 1:1.")
    for data in video.get("side_data_list", []):
        if data.get("rotation", 0) != 0:
            errors.append("Unexpected rotation metadata.")
    if plan["audio"] == "silent" and audio:
        errors.append("Silent delivery must not contain an audio stream.")
    if plan["audio"] != "silent" and not audio:
        errors.append("The agreed audio stream is missing.")
    if len(streams) != len(videos) + len(audio):
        errors.append("Unexpected non-audio/video streams; review the export specification.")
    return errors


def check_video(path, plan_path, ffmpeg_name, ffprobe_name):
    plan, report = load_plan(plan_path, approved=True)
    if report["errors"]:
        return report
    tools = {}
    for name, executable in (("ffmpeg", ffmpeg_name), ("ffprobe", ffprobe_name)):
        resolved = shutil.which(executable)
        if not resolved:
            raise FileNotFoundError(f"{name} is missing. Do not auto-install; use the project's existing tooling or ask.")
        tools[name] = resolved
    before = sha256(path)
    result = subprocess.run([
        tools["ffprobe"], "-v", "error", "-count_frames", "-show_streams",
        "-show_format", "-of", "json", str(path),
    ], capture_output=True, text=True, check=True)
    report["errors"].extend(check_streams(json.loads(result.stdout), plan, report["expected_frames"]))
    if not mp4_faststart(path):
        report["errors"].append("MP4 is not faststart (moov must precede mdat).")
    subprocess.run([
        tools["ffmpeg"], "-hide_banner", "-v", "error", "-xerror", "-nostdin",
        "-i", str(path), "-map", "0", "-f", "null", "-",
    ], capture_output=True, text=True, check=True)
    if before != sha256(path):
        report["errors"].append("The video changed during verification.")
    report.update({
        "video": str(path.resolve()), "video_sha256": before,
        "plan_sha256": sha256(plan_path), "full_decode": "passed",
        "passed": not report["errors"],
        "remaining_review": [
            "Content/source truth and exact prompts", "All-scene legibility and transitions",
            "Privacy and forbidden on-screen content", "Complete audio review if requested",
            "Theme/variant parity if requested", "Final still hold and meaningful nonblank footage",
        ],
    })
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    plan_command = commands.add_parser("plan", help="Check scene timing and required decisions.")
    plan_command.add_argument("path", type=Path)
    plan_command.add_argument("--approved", action="store_true")
    video_command = commands.add_parser("video", help="Verify a final H.264/yuv420p MP4 against its approved plan.")
    video_command.add_argument("path", type=Path)
    video_command.add_argument("--plan", type=Path, required=True)
    video_command.add_argument("--ffmpeg", default="ffmpeg")
    video_command.add_argument("--ffprobe", default="ffprobe")
    args = parser.parse_args()
    try:
        if args.command == "plan":
            _, report = load_plan(args.path, approved=args.approved)
        else:
            report = check_video(args.path, args.plan, args.ffmpeg, args.ffprobe)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = error.stderr if isinstance(error, subprocess.CalledProcessError) else str(error)
        print(json.dumps({"passed": False, "errors": [detail or str(error)]}, indent=2))
        return 1
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
