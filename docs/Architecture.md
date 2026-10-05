# コンビニウォーズ 実装設計書(Architecture)

`docs/GameDesign.md` の仕様を Godot 4.x / GDScript 2.0 でどう実装するかの方針。
仕様(ルール・数値・UI)は GameDesign.md が唯一の情報源であり、本書はその実装設計だけを扱う。
本文は章・節ごとに `docs/arch/` へ分けてあり、「Architecture.md N章」はこの表の N章 のファイルを指す。

| 章・節 | 内容 | ファイル |
|---|---|---|
| 1章 | 設計方針(層の分け方・フォルダ構成) | [`arch/01_policy.md`](arch/01_policy.md) |
| 2章 | データ構造(Resource設計) | [`arch/02_data.md`](arch/02_data.md) |
| 3章 | ロジック層(試合の状態と進行) | [`arch/03_logic.md`](arch/03_logic.md) |
| 4章 | シーン構成 | [`arch/04_scenes.md`](arch/04_scenes.md) |
| 5章 | CPUの実装 | [`arch/05_cpu.md`](arch/05_cpu.md) |
| 6章 | テストと検証 | [`arch/06_testing.md`](arch/06_testing.md) |
| 7章 | オンライン対戦(中継サーバー・ロックステップ) | [`arch/07_net.md`](arch/07_net.md) |
