# 1章 設計方針

## 1.1 層の分け方

| 層 | 置き場所 | 責務 |
|---|---|---|
| データ | `data/` の `.tres`、`scripts/data/` のResourceクラス | 商品・客層・時間帯・セット・店長・数値設定。読むだけで書き換えない |
| ロジック | `scripts/logic/` | 試合の状態と進行。`RefCounted` だけで作り、Nodeやシーンに依存しない |
| 画面 | `scenes/`、`scripts/ui/` | ロジックの状態を表示し、入力をロジックのコマンドへ変える |
| CPU | `scripts/cpu/` | プレイヤーと同じコマンドだけでロジックを操作する |

- 画面はロジックの状態を直接書き換えない。操作はすべて `MatchState` のコマンド(3章)を通す
- ロジックは固定の刻み(`advance(delta)`)で進み、乱数は `MatchState` が持つ `RandomNumberGenerator` だけを使う。
  種を固定すれば同じ試合が再現できる(GameDesign.md 10章)

## 1.2 フォルダ構成

```
data/          商品・客層などの .tres(2章)
scenes/        .tscn
scripts/data/  Resourceクラス
scripts/logic/ 試合ロジック
scripts/cpu/   CPU
scripts/ui/    画面のスクリプト
scripts/net/   オンライン対戦の接続と進め方(7章)
server/        オンライン対戦の中継サーバー(Cloudflare Worker。.gdignore で書き出しから外す)
assets/        イラスト・背景・フォント
tools/         check.sh・テスト・シミュレーション
```
