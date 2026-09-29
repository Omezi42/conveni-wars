# 開発タスク・進捗(TODO)

## 運用ルール

- **今やっている/次にやるタスクだけ**を残す。完了したら削除する(チェックを付けて残さない)
- 経緯・知見はここに書かない。設計は `Architecture.md`、仕様は `GameDesign.md`、落とし穴は `Pitfalls.md` へ
- 実機で人が確かめる項目はここに書かない(スクリーンショットをその場で渡して済ませる)

---

## 1. 設計書の追随(実装で決めたことを Architecture.md へ)

- [ ] 2章: GameDatabase を autoload ではなく `GameDatabase.get_default()` にしたこと、追加したフィールド(`order` `color` `short_name` `cutin_text` 店長の説明文)、`data/cpu/`
- [ ] 3章: シグナルの引数の変更(`purchased` の個数と金額、`customer_arrived` の is_event、`event_announced` の店番号、`opened` `ordered` `skill_ended`)
- [ ] 4章: `MatchPart` `UiSelection`、資金は `SkillButton` に同居
- [ ] 5章: CPUの需要の見積もり方、6章: `screen_flow_smoke.gd` `capture_screens.gd` `simulate.gd` の使い方
- [ ] Pitfalls.md: .tres は辞書のキーを並べ替えて保存する/`--script` の本体はautoload登録前にコンパイルされる

## 2. レビューの改善(GameDesign.md 更新済み)

- [ ] 勝敗を利益に(1.3節・1.4節)。結果・上端のバー
- [ ] simulate.gd に戦略の差し替えと1.5節の目標の判定
- [ ] 強気の勝率を測り、30%未満なら「値段は相手の同じカテゴリと比べる」に変える(承認済み。5.2節)
- [ ] カテゴリを12種に(カップ麺・スイーツ・アイス)。絵はユーザーが生成(9.6節)
- [ ] 1.5節の調整の目標に合わせて数値を調整(元アイドルなど)。1.3節の売上の実測を書き戻す
- [ ] CPUの強さ3段階(8.3節)
- [ ] 戦績と設定の保存・自己ベスト(9.7節)
- [ ] 音(9.8節)
- [ ] 初回ガイド(9.7節)

## 3. 仕様の判断待ち(提案)

- [ ] 握手会で自店の魅力度が0の客の扱い
