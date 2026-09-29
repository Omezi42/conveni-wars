class_name CategoryData
extends Resource
## 商品のカテゴリ(GameDesign.md 3.1節)。

@export var id: StringName
@export var display_name: String
## 画面に並べる順番
@export var order: int
@export var color: Color
## 日持ちしない(届いてから時間がたつと廃棄される)か
@export var perishable: bool
