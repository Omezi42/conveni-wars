class_name UiSelection
extends RefCounted
## 在庫一覧でタップして選んだ商品(次にタップした棚のマスへ置く。GameDesign.md 6.3節)。

signal changed

var product_id: StringName = &""


func toggle(id: StringName) -> void:
	product_id = &"" if product_id == id else id
	changed.emit()


func clear() -> void:
	if product_id != &"":
		product_id = &""
		changed.emit()


func has_selection() -> bool:
	return product_id != &""
