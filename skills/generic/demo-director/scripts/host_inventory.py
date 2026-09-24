"""Minimal host identification, gated on the user's explicit discovery approval."""

import argparse
import json
import platform


def inventory(approved):
    if approved is not True:
        raise PermissionError("Ask the user before identifying the hardware or OS.")
    return {
        "os": platform.system(),
        "os_release": platform.release(),
        "architecture": platform.machine(),
        "scope": "Agent execution host only; confirm whether it is the recording computer.",
        "not_collected": [
            "hostname", "username", "serial numbers", "device IDs", "network addresses",
            "environment variables", "application inventory", "window titles",
        ],
        "still_ask": [
            "Is this the actual capture host?",
            "Laptop, desktop, remote, virtual, or headless?",
            "Which display and scaling should be recorded?",
            "Power connection, lid/dock configuration, and remote-session persistence?",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--approved", action="store_true",
        help="Use only after the user explicitly approves limited read-only identification.",
    )
    args = parser.parse_args()
    if not args.approved:
        parser.error("User approval is required; ask before running with --approved.")
    print(json.dumps(inventory(args.approved), indent=2))


if __name__ == "__main__":
    main()
