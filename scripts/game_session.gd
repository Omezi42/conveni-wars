extends Node
## 画面間の受け渡し(選んだ店長・試合結果)を持つ(Architecture.md 4章)。

const CPU_PROFILE_ID := &"standard"

var player_manager_id: StringName = &""
var cpu_manager_id: StringName = &""
var match_seed := 0
var last_result: MatchResult

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## プレイヤーの店長を決め、CPUは選ばれなかった店長からランダムに1人選ぶ(GameDesign.md 8.1節)
func prepare_match(manager_id: StringName) -> void:
	player_manager_id = manager_id
	var others: Array[StringName] = []
	for manager in GameDatabase.get_default().sorted_managers():
		if manager.id != manager_id:
			others.append(manager.id)
	cpu_manager_id = others[_rng.randi_range(0, others.size() - 1)]
	match_seed = _rng.randi()
	last_result = null


func manager_ids() -> Array[StringName]:
	if player_manager_id == &"":
		prepare_match(GameDatabase.get_default().sorted_managers()[0].id)
	var ids: Array[StringName] = [player_manager_id, cpu_manager_id]
	return ids
