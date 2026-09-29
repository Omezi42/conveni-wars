class_name CustomerTypeData
extends Resource
## 客層(GameDesign.md 2.1節・11.3節)。

@export var id: StringName
@export var display_name: String
## 画面に並べる順番
@export var order: int
## カテゴリid → 欲しさの重み
@export var wants: Dictionary
## 0〜1。大きいほど値下げに寄ってきて、値上げを嫌う
@export var price_sensitivity: float
@export var buy_count: int
@export var color: Color
@export var icon: Texture2D


func weight_of(category_id: StringName) -> int:
	return int(wants.get(category_id, 0))


## いちばん欲しがるカテゴリ(同じ重みならidの辞書順で先のもの。.tres は辞書のキーを並べ替えて保存するため)
func top_category() -> StringName:
	var best: StringName = &""
	var best_weight := 0
	for category_id: StringName in wants:
		if int(wants[category_id]) > best_weight:
			best_weight = int(wants[category_id])
			best = category_id
	return best
