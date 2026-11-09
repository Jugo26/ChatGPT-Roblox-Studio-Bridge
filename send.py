"""Queue a command for the Roblox Studio Bridge, optionally await the response."""
from __future__ import annotations
import argparse
import json
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    ap = argparse.ArgumentParser(description="Queue Roblox Studio edit command")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--json", help="JSON command string")
    src.add_argument("--file", help="Path to command JSON file")
    ap.add_argument("--wait", action="store_true", help="Wait for Studio response")
    ap.add_argument("--timeout", type=int, default=30)
    args = ap.parse_args()
    raw = args.json if args.json is not None else Path(args.file).read_text(encoding="utf-8")
    command = json.loads(raw)
    if not isinstance(command, dict) or not isinstance(command.get("op"), str):
        ap.error("command must be a JSON object with op")
    job_id = uuid.uuid4().hex
    job = {"id": job_id, "command": command}
    queue = ROOT / "jobs"
    queue.mkdir(exist_ok=True)
    tmp = queue / (job_id + ".tmp")
    dest = queue / (job_id + ".json")
    tmp.write_text(json.dumps(job, ensure_ascii=False), encoding="utf-8")
    tmp.replace(dest)
    print("QUEUED", job_id, flush=True)
    if args.wait:
        output = ROOT / "results" / (job_id + ".json")
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            if output.exists():
                result = json.loads(output.read_text(encoding="utf-8"))
                print(json.dumps(result, ensure_ascii=False, indent=2))
                sys.exit(0 if result.get("ok") else 1)
            time.sleep(0.25)
        print("TIMEOUT - job may run when Studio connects", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
