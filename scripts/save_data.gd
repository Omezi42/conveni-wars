class_name SaveData
extends RefCounted
## 端末に保存する戦績と設定(GameDesign.md 9.7節、Architecture.md 4.3節)。

const DEFAULT_PATH := "user://save.cfg"
const RECORD := "record"
const SETTINGS := "settings"
const DEFAULT_VOLUME := 0.8

var wins := 0
var losses := 0
var draws := 0
## 店長id → 自己ベストの利益
var best_profit: Dictionary = {}
## 店長id → 勝ったことのあるCPUの強さのidの列(勝ち星。GameDesign.md 9.7節)
var stars: Dictionary = {}
## 最後に選んだCPUの強さ。まだ選んでいなければ空
var cpu_profile_id: StringName = &""
## 出したヒントのid(GameDesign.md 9.7節)
var shown_hints: Array = []
var bgm_volume := DEFAULT_VOLUME
var se_volume := DEFAULT_VOLUME

var _path: String


func _init(path := DEFAULT_PATH) -> void:
	_path = path


func load_file() -> void:
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return
	wins = file.get_value(RECORD, "wins", 0)
	losses = file.get_value(RECORD, "losses", 0)
	draws = file.get_value(RECORD, "draws", 0)
	best_profit = file.get_value(RECORD, "best_profit", {})
	stars = file.get_value(RECORD, "stars", {})
	cpu_profile_id = StringName(file.get_value(RECORD, "cpu_profile_id", ""))
	shown_hints = file.get_value(RECORD, "shown_hints", [])
	bgm_volume = file.get_value(SETTINGS, "bgm_volume", DEFAULT_VOLUME)
	se_volume = file.get_value(SETTINGS, "se_volume", DEFAULT_VOLUME)


func save_file() -> void:
	var file := ConfigFile.new()
	file.set_value(RECORD, "wins", wins)
	file.set_value(RECORD, "losses", losses)
	file.set_value(RECORD, "draws", draws)
	file.set_value(RECORD, "best_profit", best_profit)
	file.set_value(RECORD, "stars", stars)
	file.set_value(RECORD, "cpu_profile_id", String(cpu_profile_id))
	file.set_value(RECORD, "shown_hints", shown_hints)
	file.set_value(SETTINGS, "bgm_volume", bgm_volume)
	file.set_value(SETTINGS, "se_volume", se_volume)
	file.save(_path)


func games_played() -> int:
	return wins + losses + draws


func best_for(manager_id: StringName) -> int:
	return int(best_profit.get(String(manager_id), 0))


func has_star(manager_id: StringName, cpu_profile_id: StringName) -> bool:
	var won: Array = stars.get(String(manager_id), [])
	return won.has(String(cpu_profile_id))


## 勝ち星を足す。初めての星なら true
func add_star(manager_id: StringName, cpu_profile_id: StringName) -> bool:
	if has_star(manager_id, cpu_profile_id):
		return false
	var key := String(manager_id)
	var won: Array = stars.get(key, [])
	won.append(String(cpu_profile_id))
	stars[key] = won
	return true


func has_shown_hint(id: StringName) -> bool:
	return shown_hints.has(String(id))


func mark_hint(id: StringName) -> void:
	if not has_shown_hint(id):
		shown_hints.append(String(id))


## タイトルの「遊び方」から始めたとき、ヒントを全部出し直す
func clear_hints() -> void:
	shown_hints.clear()


## 試合の結果を戦績に足す。自己ベストを更新したら true
func record(result: MatchResult, player_index: int) -> bool:
	if result.winner == MatchResult.DRAW:
		draws += 1
	elif result.winner == player_index:
		wins += 1
	else:
		losses += 1
	var store := result.stores[player_index]
	var key := String(store.manager.id)
	var had_best := best_profit.has(key)
	if had_best and store.profit() <= best_for(store.manager.id):
		return false
	best_profit[key] = store.profit()
	return true
