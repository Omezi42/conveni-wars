class_name TimeBandData
extends Resource
## 時間帯(GameDesign.md 1.2節・2.2節)。

@export var id: StringName
@export var display_name: String
@export var order: int
## 試合の中での長さ(秒)
@export var duration: float
## 両店あわせた来店数
@export var customer_count: int
## 店の時計の時刻(時)
@export var clock_start: int
@export var clock_end: int
## 客層id → 来る割合の重み
@export var mix: Dictionary
## 時間帯が変わるときのカットインの文言(GameDesign.md 9.3節)
@export var cutin_text: String


func mix_total() -> int:
	var total := 0
	for type_id: StringName in mix:
		total += int(mix[type_id])
	return total
