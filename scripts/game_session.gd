extends Node
## 画面間の受け渡し(選んだ店長・CPUの強さ・試合結果・初回ガイドを出すか)と、戦績と設定の保存を持つ
## (Architecture.md 4章)。

const PLAYER := 0
## 初めての試合のCPUの強さ(GameDesign.md 8.3節)
const FIRST_CPU_PROFILE_ID := &"easy"

var player_manager_id: StringName = &""
var cpu_manager_id: StringName = &""
var match_seed := 0
var last_result: MatchResult
## 直前の試合で自己ベストを更新したか
var last_new_best := false
## 次の試合で初回ガイドを出すか(タイトルの「遊び方」から始めたとき)
var guide_requested := false
var save := SaveData.new()

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	save.load_file()


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


func cpu_profile_id() -> StringName:
	if save.cpu_profile_id == &"":
		return FIRST_CPU_PROFILE_ID
	return save.cpu_profile_id


func set_cpu_profile_id(id: StringName) -> void:
	save.cpu_profile_id = id
	save.save_file()


## 初回ガイドを出すか(戦績が無いとき、または「遊び方」から始めたとき。GameDesign.md 9.7節)
func wants_guide() -> bool:
	return guide_requested or save.games_played() == 0


func finish_match(result: MatchResult) -> void:
	last_result = result
	guide_requested = false
	last_new_best = save.record(result, PLAYER)
	save.save_file()
