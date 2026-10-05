extends Node
## 画面間の受け渡し(選んだ店長・CPUの強さ・試合結果)と、戦績と設定の保存を持つ
## (Architecture.md 4章)。

const PLAYER := 0
## 初めての試合のCPUの強さ(GameDesign.md 8.3節)
const FIRST_CPU_PROFILE_ID := &"easy"
## 初めての試合で、店長選択を飛ばして使う店長(GameDesign.md 9.1節)
const FIRST_MANAGER_ID := &"veteran"
## 初めての試合の天気(GameDesign.md 12.1節)
const FIRST_WEATHER_ID := &"sunny"

var player_manager_id: StringName = &""
var cpu_manager_id: StringName = &""
var match_seed := 0
## 試合の天気。空なら MatchState が種から引く
var weather_id: StringName = &""
var last_result: MatchResult
## 直前の試合で自己ベストを更新したか
var last_new_best := false
## 直前の試合で増えた勝ち星のCPUの強さ。増えていなければ空
var last_new_star: StringName = &""
var save := SaveData.new()
## オンライン対戦の試合か(GameDesign.md 13章)。部屋で2人がそろったら立て、タイトルへ戻ったら下ろす
var online := false
## オンライン対戦の自分の店の番号(部屋を作った側が0)
var online_own := 0
## オンライン対戦の両店の店長(店0・店1の順)
var online_manager_ids: Array[StringName] = []

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
	weather_id = FIRST_WEATHER_ID if is_first_match() else &""
	last_result = null


## 部屋を作った側が決めた種と両店の店長で、オンライン対戦の試合を用意する(天気は種から引く)
func prepare_online_match(seed_value: int, ids: Array[StringName]) -> void:
	online_manager_ids = ids.duplicate()
	player_manager_id = ids[online_own]
	match_seed = seed_value
	weather_id = &""
	last_result = null


## 自分の店の番号(CPU戦は0)
func own_store() -> int:
	return online_own if online else PLAYER


func manager_ids() -> Array[StringName]:
	if online:
		return online_manager_ids.duplicate()
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


## 戦績が1試合も無いか(タイトルの「はじめる」で店長選択を飛ばす。GameDesign.md 9.1節)
func is_first_match() -> bool:
	return save.games_played() == 0


## オンライン対戦の結果を残す。peer_left なら相手が抜けたので利益にかかわらず自分の勝ちにする(GameDesign.md 13.3節)
func finish_online_match(result: MatchResult, peer_left: bool) -> void:
	if peer_left:
		result.winner = online_own
	last_result = result
	last_new_best = false
	last_new_star = &""
	save.record_online(result.winner, online_own)
	save.save_file()


## 降参したオンライン対戦を負けとして残す
func resign_online_match() -> void:
	save.record_online(1 - online_own, online_own)
	save.save_file()


func finish_match(result: MatchResult) -> void:
	last_result = result
	last_new_best = save.record(result, PLAYER)
	last_new_star = &""
	if result.winner == PLAYER:
		var manager_id := result.stores[PLAYER].manager.id
		if save.add_star(manager_id, cpu_profile_id()):
			last_new_star = cpu_profile_id()
	save.save_file()
