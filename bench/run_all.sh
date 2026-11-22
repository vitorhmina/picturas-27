#!/usr/bin/env bash
# Run every benchmark scenario in sequence and log progress.
#   bash bench/run_all.sh baseline        # or: final
# Progress: tail -f bench/results/<label>/run.log
set -u
LABEL="${1:-baseline}"
RUNS="${RUNS:-5}"
VIDEO_SERVICES="${VIDEO_SERVICES:-}"   # e.g. video_effects_tool,video_subtitles_tool,video_frames_tool after the split
cd "$(dirname "$0")"
PY=.venv/Scripts/python; [ -x "$PY" ] || PY=.venv/bin/python
# One suite at a time: mkdir is atomic, and a lock left by a dead run is reclaimed.
LOCKDIR=.run_all.lock
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  old=$(cat "$LOCKDIR/pid" 2>/dev/null)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    echo "a benchmark suite is already running (pid $old); not starting another" >&2
    exit 1
  fi
  rm -rf "$LOCKDIR" && mkdir "$LOCKDIR"
fi
echo $$ > "$LOCKDIR/pid"
trap 'rm -rf "$LOCKDIR"' EXIT

mkdir -p "results/$LABEL"
LOG="results/$LABEL/run.log"

step() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] START $*" | tee -a "$LOG"
  "$PY" -u "$@" >> "$LOG" 2>&1
  local rc=$?
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] END   $* (exit $rc)" | tee -a "$LOG"
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] label=$LABEL runs=$RUNS commit=$(git rev-parse --short HEAD)" | tee -a "$LOG"
step elasticity.py --label "$LABEL" --runs "$RUNS"
for target in none image-tool video projects; do
  extra=()
  if [ "$target" = video ] && [ -n "$VIDEO_SERVICES" ]; then extra=(--services "$VIDEO_SERVICES"); fi
  step chaos.py --label "$LABEL" --target "$target" --runs "$RUNS" "${extra[@]}"
done
step summarize.py "$LABEL"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALL DONE" | tee -a "$LOG"
