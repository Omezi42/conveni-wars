class_name ProductData
extends Resource
## 商品(GameDesign.md 3.2節)。

@export var id: StringName
@export var display_name: String
@export var category_id: StringName
@export var list_price: int
## 発注するときに払う1個あたりの値段
@export var cost: int
@export var icon: Texture2D
