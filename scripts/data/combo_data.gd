class_name ComboData
extends Resource
## 棚のセット(GameDesign.md 4.3節)。隣り合う2マスのカテゴリの組み合わせ。

@export var id: StringName
@export var display_name: String
@export var category_a: StringName
@export var category_b: StringName


func matches(first: StringName, second: StringName) -> bool:
	return (
		(first == category_a and second == category_b)
		or (first == category_b and second == category_a)
	)
