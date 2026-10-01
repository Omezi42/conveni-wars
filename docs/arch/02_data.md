# 2章 データ構造(Resource設計)

参照はすべて `id`(`StringName`)で行う。表示名はデータ側に持つ。

| クラス | 置き場所 | 主なフィールド | 仕様 |
|---|---|---|---|
| `CategoryData` | `data/categories/` | `id` `display_name` `order`(並べる順) `color` `perishable`(日持ちしないか) | GameDesign.md 3.1節 |
| `ProductData` | `data/products/` | `id` `display_name` `short_name`(棚のマスのような狭い所に出す名前) `category_id` `list_price` `cost` `icon` | 3.2節 |
| `CustomerTypeData` | `data/customers/` | `id` `display_name` `order` `wants: Dictionary`(カテゴリid→重み) `price_sensitivity` `buy_count` `color` `icon` | 2.1節・11.3節 |
| `TimeBandData` | `data/bands/` | `id` `display_name` `order` `duration` `customer_count` `clock_start` `clock_end`(店の時計の時刻) `mix: Dictionary`(客層id→重み) `cutin_text` `sky_top` `sky_bottom` `night`(背景の空の色と、月と星を出すか) | 1.2節・2.2節・9.5節 |
| `ComboData` | `data/combos/` | `id` `display_name` `category_a` `category_b` | 4.3節 |
| `EventData` | `data/events/` | `id` `display_name` `customer_type_id` `band_ids`(起きてよい時間帯) | 11章 |
| `ManagerData` | `data/managers/` | `id` `display_name` `order` `passive_kind` `passive_params` `passive_description` `active_kind` `active_params` `active_name` `active_description` `passive_short` `active_short`(カードに出す短い言葉。7.1節) `color` `portrait` |
| `CpuProfile` | `data/cpu/` | `id` `display_name` `order` 考える間隔・予告への反応の遅れ・読み違える確率・在庫を持つ秒数・自店へ来ると見込む割合・スキルを使う時機 | 8章 | 7章 |
| `BalanceConfig` | `data/balance.tres`(1つだけ) | 開店時の棚(`opening_shelf`:9マスぶんの商品id、空きは `&""`)と在庫のロット数・開始資金・選択の指数・ロット数・配送秒数・廃棄までの秒数・在庫が少ないとみなす個数・値段段階・値段の冷却秒数・値段補正の係数・目玉/コーナー/セットの倍率・イベントの間隔(最小/最大)・予告秒数・イベントの客数と来る秒数・イベントの買う個数の倍率と1商品の上限 | 1・2・4・5・6・11章の数値 |

- 店長スキルの `*_kind` は `ManagerSkills`(3章)が解釈する列挙。効果の種類はコード、数値は `*_params` に持つ
- イベントだけに来る客層は、どの時間帯の `mix` にも入れない
- 時間帯の順番は `order` で決める(ファイル名の並びに頼らない)
- 試合時間と来店の総数は持たない。時間帯の `duration` と `customer_count` の合計から求める(二重に持つと食い違うため)

## 2.1 読み込み

`GameDatabase`(RefCounted)が各フォルダの `.tres` をすべて読み、id→Resource の辞書と、`order` で並べた一覧を持つ。
autoload にはせず、画面・テスト・シミュレーションのどこからでも `GameDatabase.get_default()` で同じものを使う
(`--script` で動かすテストやシミュレーションは autoload より先にコンパイルされるため。Pitfalls.md)。
フォルダの列挙には `ResourceLoader.list_directory()` を使う(書き出した版では `.tres` が `.remap` になり、
`DirAccess` の列挙では拾えないため)。

データを足すときは `.tres` を置くだけでよく、コードは変えない。
