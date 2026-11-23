"""Background-work usability benchmark (U1-U3), driven through the real web UI.

It measures what a user can do while a project is being processed, using a
headless Chromium (Playwright) on the public site, so the same script runs
unchanged before and after the refactoring. Projects are prepared through the
public API (client.py); everything that is measured happens in the browser.

  U1 blocking:  click Apply and probe every PROBE_S whether the header's
                "Download project" button can still be clicked (Playwright's
                actionability check fails while something covers it).
                Records the time the UI was blocked and the job's duration.
  U2 reload:    click Apply, reload the page while the job runs, then check
                whether a progress bar and a cancel control are shown, and
                whether the page shows the results by itself once the job ends.
  U3 new tab:   click Apply, open the same project in a second tab, and check
                whether that tab shows the progress.

Selectors are deliberately generic (role=progressbar, a button named
"Cancel"/"Cancelar", the `mode=results` URL) so they hold for any UI that
shows the same information.

Usage:
  python -m playwright install chromium        # once
  python background_ui.py --label baseline --runs 5
"""
from __future__ import annotations

import argparse
import json
import re
import time

from playwright.sync_api import Error as PwError
from playwright.sync_api import sync_playwright

from client import DEFAULT_BASE, BenchUser
from common import SHORT_VIDEO, environment, single_instance, summary, write_result
from prepare_samples import image_paths

PROBE_S = 0.25
CANCEL = re.compile(r"^\s*(cancel|cancelar)", re.I)
TOOLS = [("brightness", {"brightness": 1.3}), ("contrast", {"contrastFactor": 1.3}),
         ("saturation", {"saturationFactor": 1.3})]
WORKLOADS = {
    # name: (media, tools, expected results)
    "video": ([SHORT_VIDEO], TOOLS[:1], 1),
    "images": (image_paths(3), TOOLS, 3),
}


def prepare(base: str, workload: str):
    media, tools, expected = WORKLOADS[workload]
    user = BenchUser(base)
    project = user.create_project(f"ui-{workload}")
    for m in media:
        project.upload(m)
    for proc, params in tools:
        project.add_tool(proc, params)
    return user, project, expected


def session_json(user: BenchUser) -> str:
    u = user.profile
    return json.dumps({"user": {"_id": str(u["_id"]), "name": u.get("name"), "email": u.get("email"),
                                "type": u.get("type"), "operations": u.get("operations"),
                                "remaining_operations": u.get("remaining_operations")},
                       "token": user.jwt})


def open_page(browser, base: str, user: BenchUser, project_id: str):
    ctx = browser.new_context(ignore_https_errors=True, viewport={"width": 1600, "height": 900})
    ctx.add_init_script(f"if (!localStorage.getItem('session')) localStorage.setItem('session', {json.dumps(session_json(user))});")
    page = ctx.new_page()
    page.goto(f"{base}/dashboard/{project_id}", wait_until="domcontentloaded")
    page.get_by_role("button", name=re.compile(r"apply", re.I)).wait_for(timeout=60_000)
    return ctx, page


def results_count(project) -> int:
    try:
        return len(project.results().get("imgs", []))
    except Exception:  # noqa: BLE001 - keep polling
        return 0


def click_apply(page) -> float:
    t = time.time()
    page.get_by_role("button", name=re.compile(r"apply", re.I)).click()
    return t


def blocked(page) -> bool:
    try:
        page.locator('button[title="Download project"]').click(trial=True, timeout=int(PROBE_S * 1000 * 0.6))
        return False
    except PwError:
        return True


def settle(page, timeout_s: float = 10.0) -> bool:
    """Waits until the probe finds the page usable; False if it never does."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if not blocked(page):
            return True
        time.sleep(PROBE_S)
    return False


def visible(locator, timeout_s: float) -> bool:
    try:
        locator.first.wait_for(state="visible", timeout=int(timeout_s * 1000))
        return True
    except PwError:
        return False


def u1_blocking(browser, base: str, workload: str) -> dict:
    user, project, expected = prepare(base, workload)
    ctx, page = open_page(browser, base, user, project.project_id)
    try:
        # control: the probe must find the page usable before Apply, or it measures nothing
        # (right after loading, the page is still settling for a moment)
        free_before = settle(page)
        t0 = click_apply(page)
        project.submitted = t0
        done_at = None
        blocked_s, probes, blocked_probes = 0.0, 0, 0
        deadline = t0 + 600
        while time.time() < deadline:
            t = time.time()
            b = blocked(page)
            probes += 1
            if b:
                blocked_probes += 1
            if done_at is None and results_count(project) >= expected:
                done_at = time.time()
            dt = max(PROBE_S - (time.time() - t), 0)
            time.sleep(dt)
            if b:
                blocked_s += time.time() - t
            # stop once the job is done and the UI has been free for a few probes
            if done_at is not None and not b and time.time() - done_at > 3:
                break
        return {"workload": workload, "free_before_apply": free_before, "job_s": None if done_at is None else done_at - t0,
                "blocked_s": blocked_s, "probes": probes, "blocked_probes": blocked_probes,
                "blocked_pct": 100.0 * blocked_probes / probes if probes else None,
                "completed": done_at is not None}
    finally:
        ctx.close()
        user.close()


def u2_reload(browser, base: str, reload_after_s: float = 3.0) -> dict:
    user, project, expected = prepare(base, "video")
    ctx, page = open_page(browser, base, user, project.project_id)
    try:
        t0 = click_apply(page)
        project.submitted = t0
        # control: the selectors must find the progress and cancel controls before the reload
        progress_before = visible(page.get_by_role("progressbar"), reload_after_s)
        cancel_before = visible(page.get_by_role("button", name=CANCEL), 1)
        time.sleep(max(0, t0 + reload_after_s - time.time()))
        running_at_reload = results_count(project) < expected
        page.reload(wait_until="domcontentloaded")
        page.get_by_role("button", name=re.compile(r"apply|download", re.I)).first.wait_for(timeout=60_000)
        progress = visible(page.get_by_role("progressbar"), 5)
        cancel = visible(page.get_by_role("button", name=CANCEL), 1)
        done_at = None
        while time.time() < t0 + 600:
            if results_count(project) >= expected:
                done_at = time.time()
                break
            time.sleep(0.5)
        # does the page notice the end of the job without a manual reload?
        shown_at = None
        if done_at is not None:
            try:
                page.wait_for_url(re.compile(r"mode=results"), timeout=15_000)
                shown_at = time.time()
            except PwError:
                pass
        return {"progress_before_reload": progress_before, "cancel_before_reload": cancel_before,
                "running_at_reload": running_at_reload, "progress_after_reload": progress,
                "cancel_after_reload": cancel, "completed": done_at is not None,
                "results_shown_without_reload": shown_at is not None,
                "results_shown_delay_s": None if shown_at is None else shown_at - done_at}
    finally:
        ctx.close()
        user.close()


def u3_second_tab(browser, base: str, open_after_s: float = 3.0) -> dict:
    user, project, expected = prepare(base, "video")
    ctx, page = open_page(browser, base, user, project.project_id)
    try:
        t0 = click_apply(page)
        project.submitted = t0
        time.sleep(open_after_s)
        running = results_count(project) < expected
        second = ctx.new_page()
        second.goto(f"{base}/dashboard/{project.project_id}", wait_until="domcontentloaded")
        second.get_by_role("button", name=re.compile(r"apply|download", re.I)).first.wait_for(timeout=60_000)
        progress = visible(second.get_by_role("progressbar"), 5)
        cancel = visible(second.get_by_role("button", name=CANCEL), 1)
        while time.time() < t0 + 600 and results_count(project) < expected:
            time.sleep(0.5)
        return {"running_when_opened": running, "progress_in_second_tab": progress,
                "cancel_in_second_tab": cancel}
    finally:
        ctx.close()
        user.close()


def rate(runs: list[dict], key: str) -> float | None:
    vals = [r[key] for r in runs if isinstance(r.get(key), bool)]
    return 100.0 * sum(vals) / len(vals) if vals else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--label", default="baseline")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--base", default=DEFAULT_BASE)
    args = ap.parse_args()

    single_instance()
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        out = {"environment": environment(), "probe_s": PROBE_S, "runs": {}}
        try:
            for name, fn in [("u1_video", lambda: u1_blocking(browser, args.base, "video")),
                             ("u1_images", lambda: u1_blocking(browser, args.base, "images")),
                             ("u2_reload", lambda: u2_reload(browser, args.base)),
                             ("u3_second_tab", lambda: u3_second_tab(browser, args.base))]:
                runs = []
                for i in range(args.runs):
                    try:
                        r = fn()
                    except Exception as exc:  # noqa: BLE001 - record and continue
                        r = {"error": repr(exc)}
                    print(name, i + 1, json.dumps(r, default=str), flush=True)
                    runs.append(r)
                out["runs"][name] = runs
        finally:
            browser.close()

    r = out["runs"]
    out["summary"] = {
        "u1_video_blocked_s": summary([x.get("blocked_s") for x in r["u1_video"]]),
        "u1_video_blocked_pct": summary([x.get("blocked_pct") for x in r["u1_video"]]),
        "u1_video_job_s": summary([x.get("job_s") for x in r["u1_video"]]),
        "u1_images_blocked_s": summary([x.get("blocked_s") for x in r["u1_images"]]),
        "u1_images_blocked_pct": summary([x.get("blocked_pct") for x in r["u1_images"]]),
        "u1_images_job_s": summary([x.get("job_s") for x in r["u1_images"]]),
        "u1_free_before_apply_pct": rate(r["u1_video"] + r["u1_images"], "free_before_apply"),
        "u2_progress_before_reload_pct": rate(r["u2_reload"], "progress_before_reload"),
        "u2_cancel_before_reload_pct": rate(r["u2_reload"], "cancel_before_reload"),
        "u2_progress_after_reload_pct": rate(r["u2_reload"], "progress_after_reload"),
        "u2_cancel_after_reload_pct": rate(r["u2_reload"], "cancel_after_reload"),
        "u2_results_shown_without_reload_pct": rate(r["u2_reload"], "results_shown_without_reload"),
        "u2_running_at_reload_pct": rate(r["u2_reload"], "running_at_reload"),
        "u3_progress_in_second_tab_pct": rate(r["u3_second_tab"], "progress_in_second_tab"),
        "u3_cancel_in_second_tab_pct": rate(r["u3_second_tab"], "cancel_in_second_tab"),
        "u3_running_when_opened_pct": rate(r["u3_second_tab"], "running_when_opened"),
    }
    print(json.dumps(out["summary"], indent=2))
    print("  ->", write_result(args.label, "background-ui", out))


if __name__ == "__main__":
    main()
