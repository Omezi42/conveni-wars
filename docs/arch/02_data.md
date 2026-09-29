# 2章 データ構造(Resource設計)

参照はすべて `id`(`StringName`)で行う。表示名はデータ側に持つ。

| クラス | 置き場所 | 主なフィールド | 仕様 |
|---|---|---|---|
| `CategoryData` | `data/categories/` | `id` `display_name` `color` `perishable`(日持ちしないか) | GameDesign.md 3.1節 |
| `ProductData` | `data/products/` | `id` `display_name` `category_id` `list_price` `cost` `icon` | 3.2節 |
| `CustomerTypeData` | `data/customers/` | `id` `display_name` `wants: Dictionary`(カテゴリid→重み) `price_sensitivity` `buy_count` `icon` | 2.1節・11.3節 |
| `TimeBandData` | `data/bands/` | `id` `display_name` `order` `duration` `customer_count` `clock_start` `clock_end`(店の時計の時刻) `mix: Dictionary`(客層id→重み) | 1.2節・2.2節 |
| `ComboData` | `data/combos/` | `id` `display_name` `category_a` `category_b` | 4.3節 |
| `EventData` | `data/events/` | `id` `display_name` `customer_type_id` `band_ids`(起きてよい時間帯) | 11章 |
| `ManagerData` | `data/managers/` | `id` `display_name` `passive_kind` `passive_params` `active_kind` `active_params` `portrait` | 7章 |
| `BalanceConfig` | `data/balance.tres`(1つだけ) | 開店準備・開始資金・選択の指数・ロット数・配送秒数・廃棄までの秒数・在庫が少ないとみなす個数・値段段階・値段の冷却秒数・値段補正の係数・目玉/コーナー/セットの倍率・イベントの間隔(最小/最大)・予告秒数・イベントの客数と来る秒数・イベントの買う個数の倍率と1商品の上限 | 1・2・4・5・6・11章の数値 |

- 店長スキルの `*_kind` は `ManagerSkills`(3章)が解釈する列挙。効果の種類はコード、数値は `*_params` に持つ
- イベントだけに来る客層は、どの時間帯の `mix` にも入れない
- 時間帯の順番は `order` で決める(ファイル名の並びに頼らない)
- 試合時間と来店の総数は持たない。時間帯の `duration` と `customer_count` の合計から求める(二重に持つと食い違うため)

## 2.1 読み込み

`GameDatabase`(autoload)が起動時に各フォルダの `.tres` をすべて読み、id→Resource の辞書を持つ。
フォルダの列挙には `ResourceLoader.list_directory()` を使う(書き出した版では `.tres` が `.remap` になり、
`DirAccess` の列挙では拾えないため)。

データを足すときは `.tres` を置くだけでよく、コードは変えない。
