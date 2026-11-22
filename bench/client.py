"""Thin black-box client for the PictuRAS public API, used by the NFR benchmarks.

It only talks to what a browser talks to: the API gateway behind nginx
(`/api-gateway/`) and the Socket.IO gateway (`/socket.io`). No service code is
imported, so the same scripts run unchanged before and after the refactoring.

Timing conventions (all wall-clock seconds from time.time()):
- submitted:      just before `POST /process` is sent
- first_progress: first non-preview `video-progress` event for the project
                  (the video worker emits it after ~2% of the frames, so it marks
                  "the job has started running", not "the job was dequeued")
- finished:       first poll in which `GET /process/url` lists the expected results
                  (the orchestrator only exposes results after the run is committed)
- error:          a `process-error` event for the user (one project per user)
"""
from __future__ import annotations

import json
import mimetypes
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path

import requests
import socketio
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DEFAULT_BASE = "https://localhost:8080"
VIDEO_EXTENSIONS = {".mp4", ".mov", ".webm"}


class ApiError(RuntimeError):
    pass


def _check(resp: requests.Response, what: str) -> requests.Response:
    if resp.status_code >= 400:
        raise ApiError(f"{what} failed: HTTP {resp.status_code} {resp.text[:300]}")
    return resp


class BenchUser:
    """A freshly registered user with its own Socket.IO connection.

    Each benchmark job uses its own user so that `process-error` events (which
    carry no project id) can be attributed unambiguously.
    """

    def __init__(self, base: str = DEFAULT_BASE, premium: bool = True):
        self.base = base.rstrip("/")
        self.api = f"{self.base}/api-gateway"
        self.http = requests.Session()
        self.http.verify = False
        self.events: list[tuple[float, str, dict]] = []
        self._lock = threading.Lock()

        email = f"bench-{uuid.uuid4().hex[:12]}@bench.local"
        body = {
            "name": "bench",
            "email": email,
            "password": "bench-password",
            "type": "premium" if premium else "free",
        }
        data = _check(self.http.post(f"{self.api}/users/", json=body, timeout=30), "register").json()
        self.user_id = data["user"]["_id"]
        self.jwt = data["jwt"]
        self.http.headers["Authorization"] = f"Bearer {self.jwt}"

        self.sio = socketio.Client(ssl_verify=False, reconnection=True)
        for name in ("video-progress", "process-error", "process-update", "preview-ready", "preview-error"):
            self.sio.on(name, self._recorder(name))
        # Several users connect at once when a batch is prepared; a slow TLS
        # handshake must not abort the whole run, so retry a few times.
        for attempt in range(4):
            try:
                self.sio.connect(self.base, transports=["websocket"], auth={"token": self.jwt},
                                 socketio_path="socket.io", wait_timeout=30)
                break
            except socketio.exceptions.ConnectionError:
                if attempt == 3:
                    raise
                time.sleep(2 * (attempt + 1))

    def _recorder(self, name):
        def handler(payload=None):
            with self._lock:
                self.events.append((time.time(), name, payload if isinstance(payload, dict) else {"raw": payload}))
        return handler

    def events_since(self, t0: float, name: str | None = None) -> list[tuple[float, str, dict]]:
        with self._lock:
            return [e for e in self.events if e[0] >= t0 and (name is None or e[1] == name)]

    def create_project(self, name: str | None = None) -> "BenchProject":
        name = name or f"bench-{uuid.uuid4().hex[:8]}"
        d = _check(self.http.post(f"{self.api}/projects/{self.user_id}", json={"name": name}, timeout=30),
                   "create project").json()
        return BenchProject(self, d["_id"], int(d.get("version", 0)))

    def close(self):
        try:
            self.sio.disconnect()
        except Exception:  # noqa: BLE001 - best effort
            pass


@dataclass
class JobOutcome:
    status: str  # done | error | timeout
    submitted: float
    first_progress: float | None
    finished: float | None
    error: dict | None = None
    results: int = 0

    @property
    def wait_s(self) -> float | None:
        return None if self.first_progress is None else self.first_progress - self.submitted

    @property
    def total_s(self) -> float | None:
        return None if self.finished is None else self.finished - self.submitted


@dataclass
class BenchProject:
    user: BenchUser
    project_id: str
    version: int
    media: list[dict] = field(default_factory=list)
    submitted: float | None = None

    @property
    def _url(self) -> str:
        return f"{self.user.api}/projects/{self.user.user_id}/{self.project_id}"

    def _vh(self) -> dict:
        return {"X-Project-Version": str(self.version)}

    def _bump(self, resp: requests.Response):
        header = resp.headers.get("X-Project-Version")
        if header is not None:
            self.version = int(header)
        else:
            self.refresh()

    def refresh(self) -> dict:
        d = _check(self.user.http.get(self._url, timeout=60), "get project").json()
        self.version = int(d.get("version", self.version))
        self.media = d.get("imgs", [])
        return d

    def upload(self, path: str | Path):
        path = Path(path)
        kind = "video" if path.suffix.lower() in VIDEO_EXTENSIONS else "image"
        endpoint = "video" if kind == "video" else "img"
        mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        with path.open("rb") as fh:
            resp = self.user.http.post(f"{self._url}/{endpoint}", files={kind: (path.name, fh, mime)},
                                       headers=self._vh(), timeout=600)
        _check(resp, f"upload {path.name}")
        self._bump(resp)

    def add_tool(self, procedure: str, params: dict | None = None):
        resp = self.user.http.post(f"{self._url}/tool", json={"procedure": procedure, "params": params or {}},
                                   headers=self._vh(), timeout=60)
        _check(resp, f"add tool {procedure}")
        self._bump(resp)

    def media_id(self, index: int = 0) -> str:
        if not self.media:
            self.refresh()
        return str(self.media[index]["_id"])

    def process(self) -> bool:
        """Start the batch. Returns True if the server completed it synchronously."""
        self.submitted = time.time()
        resp = _check(self.user.http.post(f"{self._url}/process", json={}, headers=self._vh(), timeout=600),
                      "process")
        self._bump(resp)
        try:
            body = resp.json()  # usually the JSON string "Created"
        except ValueError:
            return False
        return isinstance(body, dict) and bool(body.get("completed"))

    def preview(self, media_index: int = 0, timeout_s: float = 600.0) -> dict:
        """Requests a preview and waits for `preview-ready` (or `preview-error`)."""
        t0 = time.time()
        _check(self.user.http.post(f"{self._url}/preview/{self.media_id(media_index)}", json={}, timeout=120),
               "preview")
        while time.time() < t0 + timeout_s:
            ready = self.user.events_since(t0, "preview-ready")
            if ready:
                raw = ready[0][2].get("raw")
                return {"status": "done", "urls": json.loads(raw) if isinstance(raw, str) else ready[0][2],
                        "total_s": ready[0][0] - t0}
            failed = self.user.events_since(t0, "preview-error")
            if failed:
                return {"status": "error", "error": failed[0][2], "total_s": failed[0][0] - t0}
            time.sleep(0.5)
        return {"status": "timeout", "total_s": None}

    def results(self) -> dict:
        resp = self.user.http.get(f"{self._url}/process/url", timeout=60)
        if resp.status_code >= 400:
            return {"imgs": [], "texts": []}
        return resp.json()

    def wait(self, expected_results: int, timeout_s: float, poll_s: float = 1.0) -> JobOutcome:
        assert self.submitted is not None, "process() first"
        t0 = self.submitted
        deadline = t0 + timeout_s
        while True:
            now = time.time()
            progress = [e for e in self.user.events_since(t0, "video-progress")
                        if e[2].get("projectId") == self.project_id and not e[2].get("preview")]
            first = progress[0][0] if progress else None
            errors = self.user.events_since(t0, "process-error")
            if errors:
                return JobOutcome("error", t0, first, errors[0][0], errors[0][2])
            try:
                n = len(self.results().get("imgs", []))
            except requests.RequestException:
                n = 0  # gateway/projects may be down during chaos runs; keep polling
            if n >= expected_results:
                return JobOutcome("done", t0, first, time.time(), results=n)
            if now >= deadline:
                return JobOutcome("timeout", t0, first, None, results=n)
            time.sleep(poll_s)
