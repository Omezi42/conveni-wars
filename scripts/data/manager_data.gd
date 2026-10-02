class_name ManagerData
extends Resource
## 店長(GameDesign.md 7章)。

@export var id: StringName
@export var display_name: String
## 選択画面に並べる順番
@export var order: int
@export var passive_kind: SkillKinds.Passive
@export var passive_params: Dictionary
@export_multiline var passive_description: String
## 店長選択のカードに出す、計算の用語を使わない短い言葉(GameDesign.md 7.1節)
@export var passive_short: String
@export var active_kind: SkillKinds.Active
@export var active_params: Dictionary
@export var active_name: String
@export_multiline var active_description: String
@export var active_short: String
@export var color: Color
@export var portrait: Texture2D
