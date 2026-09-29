class_name EventData
extends Resource
## 突発イベント(GameDesign.md 11章)。

@export var id: StringName
@export var display_name: String
@export var customer_type_id: StringName
## 起きてよい時間帯のid
@export var band_ids: Array[StringName]
