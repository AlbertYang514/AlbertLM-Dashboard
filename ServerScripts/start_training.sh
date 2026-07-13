#!/bin/bash

SESSION="albertlm"
ROOT="/data/AlbertLM"

cd "$ROOT"

mkdir -p logs
touch logs/train.log logs/metrics.jsonl logs/system.jsonl

if tmux has-session -t $SESSION 2>/dev/null; then
    echo "Training session already exists"
    exit 1
fi

TRAIN_COMMAND='cd /data/AlbertLM
source .venv/bin/activate
mkdir -p logs
./scripts/system_monitor.sh &
MONITOR_PID=$!
cleanup() {
    kill "$MONITOR_PID" 2>/dev/null || true
    wait "$MONITOR_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
set -o pipefail
PYTHONPATH=. python -u train/pretrain.py 2>&1 | tee -a logs/train.log'

tmux new-session -d \
    -s "$SESSION" \
    "bash -lc $(printf '%q' "$TRAIN_COMMAND")"

echo "Started training in tmux session: $SESSION"
