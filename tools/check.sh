#!/usr/bin/env bash
# 変更後の検証を1コマンドにまとめる: gdformat → gdlint → フォントの字 → ヘッドレステスト → 画面の通し → 起動スモーク。
# 引数なし: git で変更のある .gd だけを整形・lint する。 --all: scripts/ と tools/ の全 .gd。
# 出力は要点だけに絞る(ログ全文は logs/check_*.log)。
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
# 1回の実行の上限(秒)。コンパイルエラーはログで見つけ次第止めるので、これは想定外に固まったとき用。
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

# Web版にはOSのフォントが無く、絞ったフォントに無い字は豆腐になる(Architecture.md 6章)
echo "== font glyphs"
python tools/subset_font.py --check || status=1

# 登録されていない class_name を1行ずつ出す。.godot はgit管理外なので、新しい class_name を足すと古くなる
missing_classes() {
  (git ls-files 'scripts/*.gd' 'tools/*.gd'; git ls-files --others --exclude-standard 'scripts/*.gd' 'tools/*.gd') | sort -u | while read -r f; do [ -f "$f" ] && grep -h '^class_name ' "$f"; done | tr -d '' | awk '{print $2}' | while read -r c; do grep -q "\"class\": &\"$c\"" "$CLASS_CACHE" 2>/dev/null || echo "$c"; done
}

# Godot を動かし、コンパイルに失敗したらその場で止める(失敗したスクリプトは quit() まで届かず終わらないため)。
# 戻り値: 0=正常終了 / 1=コンパイルエラーで停止 / 124=時間切れ / その他=Godot の終了コード
run_godot() {
  local log=$1
  shift
  "$GODOT" "$@" > "$log" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if grep -qE "$COMPILE_ERROR" "$log"; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      echo "コンパイルエラーで止めた ($log)"
      return 1
    fi
    if [ "$waited" -ge "$GODOT_TIMEOUT" ]; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      echo "時間切れ ${GODOT_TIMEOUT}秒 ($log)"
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

# class_name の登録が古いと、テストはコンパイルに失敗する。足りなければ登録し直し、直らなければ Godot を回さず NG にする(Pitfalls.md)
CLASS_CACHE=.godot/global_script_class_cache.cfg
COMPILE_ERROR="Parse Error|Compile Error|Failed to load script"
missing=$(missing_classes)
if [ -n "$missing" ] || [ ! -f "$CLASS_CACHE" ]; then
  echo "== class_name の登録を更新: $(echo $missing)"
  run_godot logs/check_import.log --headless --path . --import
  missing=$(missing_classes)
  if [ -n "$missing" ] || [ ! -f "$CLASS_CACHE" ]; then
    echo "登録されなかった: $(echo $missing) (logs/check_import.log)"
    echo "== NG (logs/check_*.log)"
    exit 1
  fi
fi

echo "== headless tests"
run_godot logs/check_tests.log --headless --path . --script res://tools/tests/run_tests.gd
grep -E "tests passed|FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log | head -20
grep -qE "FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log && status=1
grep -q "tests passed" logs/check_tests.log || status=1

echo "== screen flow"
run_godot logs/check_flow.log --headless --path . --script res://tools/tests/screen_flow_smoke.gd
grep -E "screen flow|SCRIPT ERROR|Parse Error|ERROR" logs/check_flow.log | head -10
grep -q "screen flow passed" logs/check_flow.log || status=1
grep -qE "SCRIPT ERROR|Parse Error" logs/check_flow.log && status=1

echo "== startup smoke"
run_godot logs/check_smoke.log --headless --path . --quit-after 60
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10 | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10
  status=1
else
  echo "ok"
fi

[ $status -eq 0 ] && echo "== ALL OK" || echo "== NG (logs/check_*.log)"
exit $status
