#!/usr/bin/env bash
# オンライン対戦の通し(Architecture.md 6章): 中継サーバーを通して2つの Godot で1試合を回し、両方の終わりの状態が同じか比べる。
# 使い方: bash tools/online_e2e.sh [ws://127.0.0.1:8787] [random](先に server/ で npx wrangler dev を起こしておく。random でランダムマッチを通す)
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs
export CONVENI_SERVER="${1:-ws://127.0.0.1:8787}"
CODE=$(printf "%04d" $((RANDOM % 10000)))
[ "${2:-}" = "random" ] && CODE=random
"$GODOT" --headless --path . --script res://tools/online_e2e.gd -- host "$CODE" > logs/e2e_host.log 2>&1 &
HOST_PID=$!
"$GODOT" --headless --path . --script res://tools/online_e2e.gd -- guest "$CODE" > logs/e2e_guest.log 2>&1
wait $HOST_PID
HOST=$(grep "^E2E" logs/e2e_host.log)
GUEST=$(grep "^E2E" logs/e2e_guest.log)
echo "host : $HOST"
echo "guest: $GUEST"
if [ -n "$HOST" ] && [ "$HOST" = "$GUEST" ] && echo "$HOST" | grep -q checksum && ! grep -q "E2E desync" logs/e2e_*.log; then
  echo "== online e2e OK"
else
  echo "== online e2e NG (logs/e2e_*.log)"
  exit 1
fi
