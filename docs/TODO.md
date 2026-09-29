# 開発タスク・進捗(TODO)

## 運用ルール

- **今やっている/次にやるタスクだけ**を残す。完了したら削除する(チェックを付けて残さない)
- 経緯・知見はここに書かない。設計は `Architecture.md`、仕様は `GameDesign.md`、落とし穴は `Pitfalls.md` へ
- 実機で人が確かめる項目はここに書かない(スクリーンショットをその場で渡して済ませる)

---

## 1. 設計書の追随(実装で決めたことを Architecture.md へ)

- [ ] 2章: GameDatabase を autoload ではなく `GameDatabase.get_default()` にしたこと、追加したフィールド(`order` `color` `short_name` `cutin_text` 店長の説明文)、`data/cpu/`
- [ ] 3章: シグナルの引数の変更(`purchased` の個数と金額、`customer_arrived` の is_event、`event_announced` の店番号、`opened` `ordered` `skill_ended`)
- [ ] 5章: CPUの需要の見積もり方、6章: `screen_flow_smoke.gd` `capture_screens.gd` `simulate.gd` の使い方
- [ ] Pitfalls.md: .tres は辞書のキーを並べ替えて保存する/`--script` の本体はautoload登録前にコンパイルされる

## 2. 仕様の判断待ち(提案)

- [ ] シミュレーション結果への対応(売上の想定・元アイドルの勝率・資金が余る)
- [ ] 握手会で自店の魅力度が0の客の扱い
