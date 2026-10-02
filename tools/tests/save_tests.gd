extends RefCounted
## 戦績と設定の保存(GameDesign.md 9.7節)。本物のセーブには触らず、テスト用のファイルで往復させる。

const T = preload("res://tools/tests/test_util.gd")
const PATH := "user://test_unit_save.cfg"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_record_counts_results_and_best_profit()
	_test_round_trip()
	_test_stars()
	_test_hints()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _result(winner: int, profit: int) -> MatchResult:
	var m := T.new_match(&"idol", &"veteran")
	m.stores[0].sales = profit
	var result := MatchResult.new()
	result.stores = m.stores
	result.winner = winner
	return result


func _test_record_counts_results_and_best_profit() -> void:
	var save := SaveData.new(PATH)
	_assert.call(save.games_played() == 0, "a new save has no games")
	_assert.call(save.record(_result(0, 1000), 0), "the first game sets the best")
	_assert.call(not save.record(_result(1, 500), 0), "a lower profit is not a new best")
	_assert.call(save.record(_result(MatchResult.DRAW, 2000), 0), "a higher profit is a new best")
	_assert.call(save.wins == 1 and save.losses == 1 and save.draws == 1, "win, loss and draw")
	_assert.call(save.best_for(&"idol") == 2000, "best profit per manager")
	_assert.call(save.best_for(&"veteran") == 0, "other managers have no best yet")


func _test_stars() -> void:
	var save := SaveData.new(PATH)
	_assert.call(not save.has_star(&"idol", &"easy"), "a new save has no stars")
	_assert.call(save.add_star(&"idol", &"easy"), "the first win against a level adds a star")
	_assert.call(not save.add_star(&"idol", &"easy"), "the same star is not added twice")
	_assert.call(not save.has_star(&"idol", &"hard"), "stars are per cpu level")
	_assert.call(not save.has_star(&"veteran", &"easy"), "stars are per manager")
	save.save_file()
	var loaded := SaveData.new(PATH)
	loaded.load_file()
	_assert.call(loaded.has_star(&"idol", &"easy"), "the stars survive")


func _test_hints() -> void:
	var save := SaveData.new(PATH)
	_assert.call(not save.has_shown_hint(&"forecast"), "a new save has shown no hints")
	save.mark_hint(&"forecast")
	save.mark_hint(&"forecast")
	_assert.call(save.shown_hints.size() == 1, "a hint is recorded once")
	save.save_file()
	var loaded := SaveData.new(PATH)
	loaded.load_file()
	_assert.call(loaded.has_shown_hint(&"forecast"), "shown hints survive")
	loaded.clear_hints()
	_assert.call(not loaded.has_shown_hint(&"forecast"), "how-to clears the shown hints")


func _test_round_trip() -> void:
	var save := SaveData.new(PATH)
	save.record(_result(0, 1234), 0)
	save.cpu_profile_id = &"hard"
	save.bgm_volume = 0.25
	save.save_file()
	var loaded := SaveData.new(PATH)
	loaded.load_file()
	_assert.call(loaded.wins == 1 and loaded.best_for(&"idol") == 1234, "the record survives")
	_assert.call(loaded.cpu_profile_id == &"hard", "the cpu level survives")
	_assert.call(is_equal_approx(loaded.bgm_volume, 0.25), "the volume survives")
	_assert.call(is_equal_approx(loaded.se_volume, SaveData.DEFAULT_VOLUME), "defaults stay")
