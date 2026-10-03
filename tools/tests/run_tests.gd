extends SceneTree
## ヘッドレステストの入口(Architecture.md 6章)。個々のスイートは別ファイルに置き、ここは呼び出しと判定だけを持つ。

const DataTests = preload("res://tools/tests/data_tests.gd")
const ShelfAttractionTests = preload("res://tools/tests/shelf_attraction_tests.gd")
const StockTests = preload("res://tools/tests/stock_tests.gd")
const AutoOrderTests = preload("res://tools/tests/auto_order_tests.gd")
const CustomerTests = preload("res://tools/tests/customer_tests.gd")
const EventTests = preload("res://tools/tests/event_tests.gd")
const SkillTests = preload("res://tools/tests/skill_tests.gd")
const CpuTests = preload("res://tools/tests/cpu_tests.gd")
const SaveTests = preload("res://tools/tests/save_tests.gd")
const HistoryTests = preload("res://tools/tests/history_tests.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DataTests.new().run(_assert_true)
	ShelfAttractionTests.new().run(_assert_true)
	StockTests.new().run(_assert_true)
	AutoOrderTests.new().run(_assert_true)
	CustomerTests.new().run(_assert_true)
	EventTests.new().run(_assert_true)
	SkillTests.new().run(_assert_true)
	CpuTests.new().run(_assert_true)
	SaveTests.new().run(_assert_true)
	HistoryTests.new().run(_assert_true)
	if _failures == 0:
		print("tests passed (%d checks)" % _checks)
		quit(0)
	else:
		printerr("tests FAILED: %d of %d checks" % [_failures, _checks])
		quit(1)


func _assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAILED: ", message)
