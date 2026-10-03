# コンビニウォーズ ルール設計書

仕様(ルール・数値・UI・演出)の唯一の情報源。本文は章ごとに `docs/design/` へ分けてある。
コードやドキュメントに書かれた「GameDesign.md N章」は、この表の N章 のファイルを指す。
章番号は安定した識別子として扱い、章の追加は末尾へ、削除は番号を欠番にする(振り直さない)。

| 章 | 内容 | ファイル |
|---|---|---|
| — | コンセプト | [`design/00_concept.md`](design/00_concept.md) |
| 1章 | 試合の流れ(時間帯・資金・勝敗) | [`design/01_match_flow.md`](design/01_match_flow.md) |
| 2章 | 客層と来店 | [`design/02_customers.md`](design/02_customers.md) |
| 3章 | 商品とカテゴリ | [`design/03_products.md`](design/03_products.md) |
| 4章 | 棚とボーナス | [`design/04_shelf.md`](design/04_shelf.md) |
| 5章 | 値段 | [`design/05_price.md`](design/05_price.md) |
| 6章 | 発注と在庫 | [`design/06_order.md`](design/06_order.md) |
| 7章 | 店長キャラ | [`design/07_managers.md`](design/07_managers.md) |
| 8章 | CPU戦 | [`design/08_cpu.md`](design/08_cpu.md) |
| 9章 | 画面構成・UI・演出・見た目・ヒント・戦績・音・一時停止 | [`design/09_ui.md`](design/09_ui.md) |
| 10章 | 技術方針 | [`design/10_tech_policy.md`](design/10_tech_policy.md) |
| 11章 | 突発イベント | [`design/11_events.md`](design/11_events.md) |
| 12章 | 天気 | [`design/12_weather.md`](design/12_weather.md) |
| 99章 | 未決事項 | [`design/99_open_issues.md`](design/99_open_issues.md) |

数値はすべて仮の値。CPU戦を動かしながら調整し、確定した値をここへ反映する。
数値の実体は `data/balance.tres` などのデータにあり、本書の値と食い違ったら本書を正とする。
