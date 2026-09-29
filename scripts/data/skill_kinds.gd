class_name SkillKinds
extends RefCounted
## 店長スキルの効果の種類(GameDesign.md 7章)。効果はコード、数値は ManagerData の params に持つ。
## `.tres` は enum を整数で保存するため、**新しい値は必ず末尾へ足す**(並べ替えると既存の店長の効果がずれる)。

enum Passive { ORDER_DISCOUNT, CUSTOMER_APPEAL, SALE_BOOST, FORECAST }
enum Active { BULK_ORDER, HANDSHAKE, TIME_SALE, PRICE_LOCK }
