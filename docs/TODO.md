# 開発タスク・進捗(TODO)

## 運用ルール

- **今やっている/次にやるタスクだけ**を残す。完了したら削除する(チェックを付けて残さない)
- 経緯・知見はここに書かない。設計は `Architecture.md`、仕様は `GameDesign.md`、落とし穴は `Pitfalls.md` へ
- 実機で人が確かめる項目はここに書かない(スクリーンショットをその場で渡して済ませる)

---

## 1. 土台

- [ ] Godotプロジェクトを作る(1280×720・`canvas_items`・Web書き出しの設定。GameDesign.md 10章)
- [ ] `tools/check.sh` と `gdlintrc` を `砂時計pvp` を手本に用意する(Architecture.md 6章)

## 2. データ(Architecture.md 2章)

- [ ] Resourceクラス7種と `GameDatabase`
- [ ] 初期データの `.tres`:カテゴリ9・商品13・客層10(時間帯6+イベント4)・時間帯4・セット5・イベント4・店長4・`balance.tres`

## 3. ロジック(Architecture.md 3章)

- [ ] `MatchState` / `StoreState` と進行(時計・時間帯・配送・廃棄・客の到着)
- [ ] `ShelfBonus` と `Attraction`(魅力度・店の選択・買い物・取り逃した客)
- [ ] `EventScheduler`(抽選・予告・イベント客)
- [ ] コマンド5種
- [ ] `ManagerSkills`(パッシブ4・アクティブ4)
- [ ] ヘッドレステスト

## 4. CPUとシミュレーション(Architecture.md 5章・6章)

- [ ] `CpuPlayer` と `CpuProfile`(GameDesign.md 8.2節・8.3節)
- [ ] `tools/simulate.gd` で CPU 対 CPU を回し、数値の極端な偏りと、イベントが売上に占める割合を見る

## 5. 画面(Architecture.md 4章)

- [ ] 試合画面(棚・発注・在庫一覧・値段ボタン・HUD・予報とイベント予告・来店数カウンタ・スキル)
- [ ] タイトル・店長選択・結果
- [ ] 人の流れと取り逃した客の吹き出し
- [ ] 演出(`FxLayer`:売上の飛び出し・カットイン・大口獲得・逆転)
