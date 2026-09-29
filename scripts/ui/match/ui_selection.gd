class_name UiSelection
extends RefCounted
## 画面の選択状態。
## - product_id: 商品タイルでタップして選んだ商品(次にタップした棚のマスへ置く。GameDesign.md 6.3節)
## - focus_product / focus_slot: 値付けパネルに出している商品と、それを選んだ棚のマス(タイルから選んだら -1。9.2節)

signal changed

const NO_SLOT := -1

var product_id: StringName = &""
var focus_product: StringName = &""
var focus_slot := NO_SLOT


func toggle(id: StringName) -> void:
	product_id = &"" if product_id == id else id
	if product_id != &"":
		focus(product_id)
	changed.emit()


func clear() -> void:
	if product_id != &"":
		product_id = &""
		changed.emit()


func has_selection() -> bool:
	return product_id != &""


func focus(id: StringName, slot := NO_SLOT) -> void:
	focus_product = id
	focus_slot = slot
	changed.emit()


func clear_focus() -> void:
	focus(&"")
