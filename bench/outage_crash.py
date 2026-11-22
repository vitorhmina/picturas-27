"""Broker outage + orchestrator crash (recoverability).

A job is submitted while RabbitMQ is paused, so its messages cannot be published;
projects is then killed before the broker comes back. The job's records are saved
but were never published: the recovery watchdog must publish them after projects
restarts. Without it the job never finishes.

Usage: python outage_crash.py   (prints OK/FAIL; needs the stack running)
"""
import subprocess
import time

from client import BenchUser
from common import ROOT
from prepare_samples import image_paths

dc = lambda *a: subprocess.run(["docker", "compose", *a], cwd=ROOT, capture_output=True, text=True, check=True)

u = BenchUser()
try:
    p = u.create_project("outage-crash")
    for img in image_paths(3):
        p.upload(img)
    p.add_tool("brightness", {"brightness": 1.2})
    p.add_tool("contrast", {"contrastFactor": 1.2})
    dc("pause", "rabbitmq")
    t = time.time(); p.process(); print(f"process request answered in {time.time()-t:.1f}s with the broker down")
    time.sleep(3)
    dc("kill", "projects"); print("projects killed before publishing")
    dc("unpause", "rabbitmq")
    while subprocess.run(["docker", "inspect", "-f", "{{.State.Health.Status}}", "picturas-rabbitmq-1"],
                         capture_output=True, text=True).stdout.strip() != "healthy":
        time.sleep(2)
    dc("start", "projects"); print("projects restarted")
    out = p.wait(3, timeout_s=240)
    print(f"{'OK' if out.status == 'done' else 'FAIL'} status={out.status} results={out.results} "
          f"total={out.total_s and round(out.total_s, 1)}s")
finally:
    subprocess.run(["docker", "compose", "unpause", "rabbitmq"], cwd=ROOT, capture_output=True)
    subprocess.run(["docker", "compose", "start", "projects"], cwd=ROOT, capture_output=True)
    u.close()
