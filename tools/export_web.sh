#!/usr/bin/env bash
# Web版を build/web/ へ書き出し、ファイルごとの大きさ(そのまま / gzip)を出す(GameDesign.md 10章)。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"
mkdir -p "$OUT" "$ROOT/logs"
touch "$ROOT/build/.gdignore"

"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html" > "$ROOT/logs/export_web.log" 2>&1
"$GODOT" --headless --main-pack "$OUT/index.pck" --script res://tools/tests/run_tests.gd 2>&1 | grep -E "tests passed|FAILED" || true

echo "--- 大きさ(KB): そのまま / gzip ---"
total=0
total_gz=0
for f in "$OUT"/*; do
  raw=$(wc -c < "$f")
  gz=$(gzip -9 -c "$f" | wc -c)
  total=$((total + raw))
  total_gz=$((total_gz + gz))
  printf "%-36s %8d / %8d\n" "$(basename "$f")" $((raw / 1024)) $((gz / 1024))
done
printf "%-36s %8d / %8d\n" "合計" $((total / 1024)) $((total_gz / 1024))
