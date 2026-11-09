"""Command interface for ChatGPT -> Desktop Commander -> Roblox Studio Bridge."""
from __future__ import annotations
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ENDPOINT = "http://127.0.0.1:48765"
MAX_HEARTBEAT_AGE = 12


def health():
    token = (ROOT / "token.txt").read_text(encoding="utf-8").strip()
    req = urllib.request.Request(
        ENDPOINT + "/health", headers={"X-Bridge-Token": token}
    )
    try:
        with urllib.request.urlopen(req, timeout=2) as r:
            state = json.load(r)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return {"ok": False, "reason": "bridge_offline", "detail": str(exc)}
    last = state.get("last_heartbeat")
    seconds = None
    if last:
        try:
            seconds = (datetime.now(timezone.utc) -
                       datetime.fromisoformat(last.replace("Z", "+00:00"))).total_seconds()
        except ValueError:
            pass
    state["heartbeat_age_seconds"] = round(seconds, 1) if seconds is not None else None
    state["connected"] = bool(
        (state.get("studio") or {}).get("enabled") and
        seconds is not None and 0 <= seconds <= MAX_HEARTBEAT_AGE
    )
    return state


def emit(data, exit_code=0):
    print(json.dumps(data, ensure_ascii=False, indent=2), flush=True)
    return exit_code


def start_server():
    state = health()
    if state.get("ok"):
        return emit({"ok": True, "already_running": True, "status": state})
    flags = 0
    if os.name == "nt":
        flags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    log = open(ROOT / "bridge_server.log", "ab", buffering=0)
    try:
        subprocess.Popen([sys.executable, str(ROOT / "bridge.py")],
                         cwd=ROOT, stdin=subprocess.DEVNULL,
                         stdout=log, stderr=subprocess.STDOUT,
                         creationflags=flags)
    finally:
        log.close()
    for _ in range(20):
        time.sleep(0.15)
        state = health()
        if state.get("ok"):
            return emit({"ok": True, "started": True, "status": state})
    return emit({"ok": False, "reason": "bridge_start_failed", "status": state}, 2)


def run(command, expected_place=None, timeout=30):
    state = health()
    if not state.get("connected"):
        return emit({"ok": False, "reason": "studio_not_connected",
                     "status": state, "queued": False}, 3)
    place = state.get("studio", {}).get("place")
    if expected_place and place != expected_place:
        return emit({"ok": False, "reason": "different_project",
                     "expected": expected_place, "connected": place,
                     "queued": False}, 4)
    if not isinstance(command, dict) or not isinstance(command.get("op"), str):
        return emit({"ok": False, "reason": "invalid_command", "queued": False}, 5)
    job_id = uuid.uuid4().hex
    jobs = ROOT / "jobs"
    jobs.mkdir(exist_ok=True)
    filename = job_id + ".json"
    tmp = jobs / (filename + ".tmp")
    queued = jobs / filename
    tmp.write_text(json.dumps({"id": job_id, "command": command}, ensure_ascii=False),
                   encoding="utf-8")
    tmp.replace(queued)
    result_path = ROOT / "results" / filename
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if result_path.is_file():
            result = json.loads(result_path.read_text(encoding="utf-8"))
            result["place"] = place
            result["job_id"] = job_id
            return emit(result, 0 if result.get("ok") else 1)
        time.sleep(0.2)
    if queued.exists():
        queued.unlink()
        return emit({"ok": False, "reason": "timeout_cancelled_before_delivery",
                     "job_id": job_id, "queued": False}, 6)
    return emit({"ok": False, "reason": "timeout_inflight_check_results_do_not_retry",
                 "job_id": job_id, "queued": False}, 7)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="action", required=True)
    sub.add_parser("status")
    sub.add_parser("start")
    run_parser = sub.add_parser("run")
    src = run_parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--file")
    src.add_argument("--json")
    run_parser.add_argument("--expected-place")
    run_parser.add_argument("--timeout", type=int, default=30)
    inspect = sub.add_parser("inspect")
    inspect.add_argument("--root", default="Workspace")
    inspect.add_argument("--depth", type=int, default=2)
    inspect.add_argument("--expected-place")
    inspect.add_argument("--timeout", type=int, default=30)
    args = ap.parse_args()
    if args.action == "status":
        state = health()
        return emit(state, 0 if state.get("connected") else 3)
    if args.action == "start":
        return start_server()
    if args.action == "inspect":
        return run({"op": "tree", "path": [args.root], "depth": args.depth},
                   args.expected_place, args.timeout)
    command = json.loads(
        Path(args.file).read_text(encoding="utf-8")
        if args.file else args.json
    )
    return run(command, args.expected_place, args.timeout)


if __name__ == "__main__":
    sys.exit(main())
