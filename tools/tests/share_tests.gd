extends RefCounted
## 結果の共有の文・ファイル名・切り抜く範囲(GameDesign.md 9.4節)。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_share_text()
	_test_file_name()
	_test_content_rect_skips_letterbox()


func _test_share_text() -> void:
	var win := ResultShare.share_text(ResultShare.PLAYER, "つよい", 12345)
	_assert.call(win == "コンビニウォーズでCPU(つよい)に勝ち! 利益 ¥12,345 #コンビニウォーズ", "win text")
	var lose := ResultShare.share_text(ResultShare.CPU, "ふつう", 100)
	_assert.call(lose.contains("に負け…"), "lose text")
	var draw := ResultShare.share_text(MatchResult.DRAW, "やさしい", 0)
	_assert.call(draw.contains("と引き分け"), "draw text")


func _test_file_name() -> void:
	var now := {"year": 2026, "month": 10, "day": 3, "hour": 9, "minute": 5, "second": 7}
	var name := ResultShare.file_name(now)
	_assert.call(name == "conveni-wars_20261003_090507.png", "file name carries the time")


func _test_content_rect_skips_letterbox() -> void:
	var base := Vector2(ResultShare.IMAGE_SIZE)
	var xform := Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2(0, 60))
	var rect := ResultShare.content_rect(xform, base, Vector2i(1920, 1200))
	_assert.call(rect == Rect2i(0, 60, 1920, 1080), "the black bars are cut away")
