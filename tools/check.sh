#!/usr/bin/env bash
# 変更後の検証を1コマンドにまとめる: gdformat → gdlint → ヘッドレステスト → 画面の通し → 起動スモーク。
# 引数なし: git で変更のある .gd だけを整形・lint する。 --all: scripts/ と tools/ の全 .gd。
# 出力は要点だけに絞る(ログ全文は logs/check_*.log)。
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
# 1回の実行の上限(秒)。コンパイルに失敗したスクリプトは quit() まで届かず終わらないため。
GODOT_TIMEOUT="${GODOT_TIMEOUT:-600}"
PY_SCRIPTS="C:/Users/omezi/AppData/Roaming/Python/Python314/Scripts"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

if [ "${1:-}" = "--all" ]; then
  FILES=$( (git ls-files 'scripts/*.gd' 'tools/*.gd' 'tools/**/*.gd'; git ls-files --others --exclude-standard 'scripts/*.gd' 'tools/*.gd') | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done)
else
  FILES=$( (git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard) | sort -u | grep '\.gd$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
fi

# headless-godot-skill-kit から写したパッチツールは手を入れないため対象から外す
FILES=$(echo "$FILES" | grep -v '^tools/godot_apply_patch.gd$' || true)

status=0
if [ -n "$FILES" ]; then
  echo "== gdformat/gdlint ($(echo "$FILES" | wc -l) files)"
  "$PY_SCRIPTS/gdformat.exe" $FILES >/dev/null 2>&1 || true
  "$PY_SCRIPTS/gdlint.exe" $FILES > logs/check_lint.log 2>&1 || { status=1; cat logs/check_lint.log; }
else
  echo "== gdformat/gdlint: 変更された .gd なし"
fi

# class_name の登録(.godot はgit管理外)が古いと、テストはコンパイルに失敗したまま固まる。
# 足りなければ登録し直す(Pitfalls.md)。
CLASS_CACHE=.godot/global_script_class_cache.cfg
missing=$( (git ls-files 'scripts/*.gd' 'tools/*.gd'; git ls-files --others --exclude-standard 'scripts/*.gd' 'tools/*.gd') | sort -u | while read -r f; do [ -f "$f" ] && grep -h '^class_name ' "$f"; done | awk '{print $2}' | while read -r c; do grep -q "\"class\": &\"$c\"" "$CLASS_CACHE" 2>/dev/null || echo "$c"; done)
if [ -n "$missing" ] || [ ! -f "$CLASS_CACHE" ]; then
  echo "== class_name の登録を更新"
  timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --import > logs/check_import.log 2>&1
fi

echo "== headless tests"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/tests/run_tests.gd > logs/check_tests.log 2>&1
grep -E "tests passed|FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log | head -20
grep -qE "FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log && status=1
grep -q "tests passed" logs/check_tests.log || status=1

echo "== screen flow"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/tests/screen_flow_smoke.gd > logs/check_flow.log 2>&1
grep -E "screen flow|SCRIPT ERROR|Parse Error|ERROR" logs/check_flow.log | head -10
grep -q "screen flow passed" logs/check_flow.log || status=1
grep -qE "SCRIPT ERROR|Parse Error" logs/check_flow.log && status=1

echo "== startup smoke"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --quit-after 60 > logs/check_smoke.log 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10 | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10
  status=1
else
  echo "ok"
fi

[ $status -eq 0 ] && echo "== ALL OK" || echo "== NG (logs/check_*.log)"
exit $status
