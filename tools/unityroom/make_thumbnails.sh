#!/usr/bin/env bash
# unityroom に載せる絵を build/unityroom/ へ作る(tools/unityroom/README.md)。
#   icon_512.gif   … ゲームのサムネイル(正方形 512x512・512KB以下)。売れ始め → 昼ラッシュ → 勝ち!
#   play_640.gif   … 紹介文や告知に貼る横長の動き(タイトル → 試合 → 結果)
#   screen_*.png   … スクリーンショット(1280x720)
# コマは record_thumbnail.gd が書き出す。--reuse を付けると前回のコマを使い回す(エンコードだけやり直す)。
set -e
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FRAMES="$ROOT/logs/thumbnail"
OUT="$ROOT/build/unityroom"
## サムネイルの容量の上限(unityroom)
ICON_LIMIT_KB=512
## 1280x720 から正方形に切り抜く範囲(自店の棚の右半分・通り・相手の店。カットインの文字が中央に来る)
ICON_CROP="720x720+280+0"
ICON_COLORS=48
## GIFの1コマの長さ(1/100秒)。コマは10fpsで書き出してあり、サムネイルは1枚おきに使って少し早回しにする
ICON_DELAY=12
WIDE_DELAY=10
WIDE_COLORS=128

mkdir -p "$OUT" "$ROOT/logs"
touch "$ROOT/build/.gdignore" "$ROOT/logs/.gdignore"

if [ "${1:-}" != "--reuse" ]; then
  rm -rf "$FRAMES"
  "$GODOT" --path "$ROOT" --fixed-fps 30 --script res://tools/unityroom/record_thumbnail.gd -- "$FRAMES" \
    > "$ROOT/logs/record_thumbnail.log" 2>&1
  grep -q "recorded to" "$ROOT/logs/record_thumbnail.log" || { echo "録画に失敗 (logs/record_thumbnail.log)"; exit 1; }
fi

# 全コマ共通の色表で量子化し、コマ間で色が揺れて差分が膨らまないようにする
encode() {
  local out=$1 colors=$2 delay=$3 geometry=$4
  shift 4
  magick "$@" $geometry +append -colors "$colors" -unique-colors "$FRAMES/palette.png"
  magick -delay "$delay" -loop 0 "$@" $geometry -dither None -remap "$FRAMES/palette.png" \
    -layers OptimizeFrame -layers OptimizeTransparency "$out"
}

every_other() { ls "$FRAMES/$1"/f*.png | awk -v from="$2" -v to="$3" 'NR >= from && NR <= to && NR % 2 == 0'; }

encode "$OUT/icon_512.gif" $ICON_COLORS $ICON_DELAY "-crop $ICON_CROP +repage -resize 512x512" \
  $(every_other 2_open 10 40) $(every_other 3_rush 1 30) $(every_other 5_result 10 30)
encode "$OUT/play_640.gif" $WIDE_COLORS $WIDE_DELAY "-resize 640x360" \
  "$FRAMES"/1_title/f*.png "$FRAMES"/2_open/f*.png "$FRAMES"/3_rush/f*.png \
  "$FRAMES"/4_close/f*.png "$FRAMES"/5_result/f*.png

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
