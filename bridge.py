"""Local-only HTTP relay between Roblox Studio plugin and filesystem command jobs."""
from __future__ import annotations
import argparse
import json
import os
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import socket

ROOT = Path(__file__).resolve().parent
TOKEN = (ROOT / "token.txt").read_text(encoding="utf-8").strip()
PORT = 48765
QUEUED = ROOT / "jobs"
INFLIGHT = ROOT / "inflight"
RESULTS = ROOT / "results"
for folder in (QUEUED, INFLIGHT, RESULTS):
    folder.mkdir(exist_ok=True)

STATE = {"last_heartbeat": None, "studio": None}
LOCK = threading.Lock()


def json_response(handler, status, value):
    raw = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(raw)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(raw)


class ExclusiveBridgeServer(ThreadingHTTPServer):
    # No SO_REUSEADDR: prevents two servers from sharing port 48765.
    allow_reuse_address = False

    def server_bind(self):
        if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print("[HTTP] " + format % args, flush=True)

    def authenticated(self):
        if self.headers.get("X-Bridge-Token") != TOKEN:
            json_response(self, 403, {"error": "invalid token"})
            return False
        return True

    def read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 < length <= 2_000_000:
            raise ValueError("payload size must be between 1 and 2MB")
        payload = json.loads(self.rfile.read(length))
        if not isinstance(payload, dict):
            raise ValueError("JSON object expected")
        return payload

    def do_GET(self):
        if not self.authenticated():
            return
        if self.path == "/health":
            with LOCK:
                data = dict(STATE)
            data.update({"ok": True, "queued": len(list(QUEUED.glob("*.json"))),
                         "inflight": len(list(INFLIGHT.glob("*.json")))})
            return json_response(self, 200, data)
        if self.path == "/next":
            with LOCK:
                files = sorted(QUEUED.glob("*.json"), key=lambda item: item.stat().st_mtime_ns)
                if not files:
                    return json_response(self, 200, {"job": None})
                path = files[0]
                target = INFLIGHT / path.name
                try:
                    path.rename(target)
                    job = json.loads(target.read_text(encoding="utf-8"))
                except Exception as e:
                    return json_response(self, 500, {"error": str(e)})
            return json_response(self, 200, {"job": job})
        return json_response(self, 404, {"error": "unknown route"})

    def do_POST(self):
        if not self.authenticated():
            return
        try:
            payload = self.read_json()
            if self.path == "/heartbeat":
                with LOCK:
                    STATE["last_heartbeat"] = datetime.now(timezone.utc).isoformat()
                    STATE["studio"] = payload
                return json_response(self, 200, {"ok": True})
            if self.path == "/result":
                job_id = payload.get("id", "")
                if not (isinstance(job_id, str) and len(job_id) == 32 and all(c in "0123456789abcdef" for c in job_id)):
                    return json_response(self, 400, {"error": "invalid id"})
                with LOCK:
                    incoming = INFLIGHT / (job_id + ".json")
                    if not incoming.exists():
                        return json_response(self, 409, {"error": "job not inflight"})
                    output = RESULTS / (job_id + ".json")
                    scratch = RESULTS / (job_id + ".tmp")
                    scratch.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
                    scratch.replace(output)
                    incoming.unlink()
                print(f"[JOB] {job_id} {'OK' if payload.get('ok') else 'ERROR'}", flush=True)
                return json_response(self, 200, {"ok": True})
            return json_response(self, 404, {"error": "unknown route"})
        except (ValueError, json.JSONDecodeError) as e:
            return json_response(self, 400, {"error": str(e)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()
    if args.host not in ("127.0.0.1", "localhost"):
        raise SystemExit("only loopback hosts are supported")
    try:
        server = ExclusiveBridgeServer((args.host, args.port), Handler)
    except OSError as exc:
        raise SystemExit(f"Bridge could not bind {args.host}:{args.port}; close the duplicate server: {exc}") from exc
    print(f"ChatGPT Studio Bridge on http://{args.host}:{args.port}", flush=True)
    print("Open Roblox Studio > Plugins > ChatGPT Bridge > CONECTAR", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
