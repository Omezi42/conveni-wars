# 開発時の落とし穴(Pitfalls)

このプロジェクトで踏んだ穴を書く。**コードやシーンを触る前に一度読む。**
ここが育つまでは、Godot全般の落とし穴を `砂時計pvp/docs/Pitfalls.md` で確認する
(書き出した版でだけ壊れる穴・GDScriptの型・`.tscn` の扱いなど、このプロジェクトにもそのまま当てはまる)。

## 素材

- **SVGは `width`/`height` の大きさでテクスチャになる。**`viewBox` だけのSVG(Twemojiは36×36)は小さく読み込まれ、
  拡大するとぼやける。取り込むときにルート要素へ `width="128" height="128"` を足す

## 検証

- `tools/check.sh` は `GODOT` 環境変数で実行ファイルを差し替えられる。Windows以外では PATH 上の gdformat/gdlint を使う
- スクリーンショット(`tools/capture_screens.gd`)はウィンドウが要る。Linuxでは `xvfb-run` の上で
  `--rendering-driver opengl3` を付けて動かす
