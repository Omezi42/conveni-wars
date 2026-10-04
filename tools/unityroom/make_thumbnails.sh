#!/usr/bin/env bash
# unityroom に載せる絵を build/unityroom/ へ作る(tools/unityroom/README.md)。
#   icon_512.gif   … ゲームのサムネイル(正方形 512x512・512KB以下)。題字と2軒の店へ客が入るループ(thumbnail_art.gd)
#   icon_512.png   … サムネイルの静止画(GIFを受け付けない所に使う)
#   play_640.gif   … 紹介文や告知に貼る横長の動き(タイトル → 試合 → 結果)
#   screen_*.png   … スクリーンショット(1280x720)
# コマはサムネイルを record_icon.gd、試合を record_thumbnail.gd が書き出す。
# --reuse を付けると前回のコマを使い回す(エンコードだけやり直す)。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FRAMES="$ROOT/logs/thumbnail"
ICON_FRAMES="$ROOT/logs/icon"
OUT="$ROOT/build/unityroom"
## サムネイルの容量の上限(unityroom)
ICON_LIMIT_KB=512
ICON_COLORS=64
## GIFの1コマの長さ(1/100秒)。サムネイルは15fps、試合は10fpsで書き出してある
ICON_DELAY=7
WIDE_DELAY=10
WIDE_COLORS=128

mkdir -p "$OUT" "$ROOT/logs"
touch "$ROOT/build/.gdignore" "$ROOT/logs/.gdignore"

if [ "${1:-}" != "--reuse" ]; then
  rm -rf "$FRAMES" "$ICON_FRAMES"
  "$GODOT" --path "$ROOT" --script res://tools/unityroom/record_icon.gd -- "$ICON_FRAMES" \
    > "$ROOT/logs/record_icon.log" 2>&1
  grep -q "recorded to" "$ROOT/logs/record_icon.log" || { echo "サムネイルの書き出しに失敗 (logs/record_icon.log)"; exit 1; }
  "$GODOT" --path "$ROOT" --fixed-fps 30 --script res://tools/unityroom/record_thumbnail.gd -- "$FRAMES" \
    > "$ROOT/logs/record_thumbnail.log" 2>&1
  grep -q "recorded to" "$ROOT/logs/record_thumbnail.log" || { echo "録画に失敗 (logs/record_thumbnail.log)"; exit 1; }
fi

# 全コマ共通の色表で量子化し、コマ間で色が揺れて差分が膨らまないようにする
encode() {
  local out=$1 colors=$2 delay=$3 geometry=$4
  shift 4
  magick "$@" $geometry +append -colors "$colors" -unique-colors "$ROOT/logs/palette.png"
  magick -delay "$delay" -loop 0 "$@" $geometry -dither None -remap "$ROOT/logs/palette.png" \
    -layers OptimizeFrame -layers OptimizeTransparency "$out"
}

encode "$OUT/icon_512.gif" $ICON_COLORS $ICON_DELAY "-resize 512x512" "$ICON_FRAMES"/f*.png
encode "$OUT/play_640.gif" $WIDE_COLORS $WIDE_DELAY "-resize 640x360" \
  "$FRAMES"/1_title/f*.png "$FRAMES"/2_open/f*.png "$FRAMES"/3_rush/f*.png \
  "$FRAMES"/4_close/f*.png "$FRAMES"/5_result/f*.png

magick "$ICON_FRAMES/f0030.png" -resize 512x512 "$OUT/icon_512.png"
cp "$FRAMES/1_title/f0010.png" "$OUT/screen_1_title.png"
cp "$FRAMES/2_open/f0030.png" "$OUT/screen_2_match.png"
cp "$FRAMES/3_rush/f0008.png" "$OUT/screen_3_rush.png"
cp "$FRAMES/5_result/f0030.png" "$OUT/screen_4_result.png"

icon_kb=$(($(wc -c < "$OUT/icon_512.gif") / 1024))
echo "icon_512.gif ${icon_kb}KB / play_640.gif $(($(wc -c < "$OUT/play_640.gif") / 1024))KB → $OUT"
if [ "$icon_kb" -gt "$ICON_LIMIT_KB" ]; then
  echo "!!! icon_512.gif が ${ICON_LIMIT_KB}KB を超えた。コマを減らすか ICON_COLORS を下げる"
  exit 1
fi
