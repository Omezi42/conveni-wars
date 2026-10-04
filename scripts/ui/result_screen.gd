class_name ResultScreen
extends Control
## 結果(GameDesign.md 9.4節・9.5節)。閉店後の夜空の下に、両店の成績をレシートの形で並べ、勝った店に「勝」の判を押す。
## 利益・売上・仕入れ・来店した客の数・取られた客(負けた理由が付いた客)・廃棄した個数を出す。
## 2枚のレシートのあいだに、ふりかえりの利益の折れ線(ProfitChart)を置く。

const MATCH_SCENE := "res://scenes/match.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const SELECT_SCENE := "res://scenes/manager_select.tscn"
const VERDICT_Y := 92.0
const VERDICT_BURST_RADIUS := 220.0
const VERDICT_BURST_RAYS := 20
const VERDICT_BURST_SPIN := 0.05
const VERDICT_BURST_ALPHA := 0.22
## ベースラインから文字の見た目の中央までの高さ(文字の大きさに対する割合)
const VERDICT_MID := 0.35
const LOSE_LIGHTEN := 0.2
const RECEIPT_SIZE := Vector2(340, 484)
const RECEIPT_GAP := 20.0
const CHART_SIZE := Vector2(500, 476)
const RECEIPT_Y := 128.0
const RECEIPT_PAPER := Color("#ffffff")
const TOOTH := Vector2(16, 9)
const PAD := 24.0
const STORE_Y := 42.0
const MANAGER_Y := 66.0
const RULE_GAP := 14.0
const DASH := Vector2(8, 5)
const DASH_WIDTH := 1.5
const SALES_LABEL_Y := 22.0
const SALES_Y := 66.0
const LINE := 52.0
const STAMP_OFFSET := Vector2(-58, 62)
const STAMP_RADIUS := 46.0
const STAMP_RING := 5.0
const STAMP_ANGLE := -0.22
const STAMP_INK := Color(0.86, 0.13, 0.15, 0.85)
const STAMP_SEGMENTS := 48
## 内側の細い輪の太さ(外側の輪に対する割合)
const STAMP_INNER_RING := 0.4
const BUTTON_SIZE := Vector2(250, 70)
## 自店のレシートの左上に掛ける「自己ベスト更新!」の札
## 勝ち星が増えたときの札は、自己ベストの札の右に並べる
const BEST_SIZE := Vector2(196, 38)
const BEST_OFFSET := Vector2(-18, -16)
const BADGE_GAP := 6.0
const BUTTON_Y := 622.0
const BUTTON_GAP := 28.0
## 「CPUならどうしたか」の計算に1フレームで使う時間(マイクロ秒)
const REVIEW_BUDGET_USEC := 25000
## 共有する画像で、ボタンの代わりに下の帯へ描く題字とCPUの強さ
const SHARE_TITLE_Y := 684.0
const SHARE_GAP := 24.0
const SAVED_SECONDS := 2.0
const SAVED_HEIGHT := 40.0
const SAVED_RISE := 30.0

var _result: MatchResult
var _chart: ProfitChart
var _buttons: Array[PopButton] = []
var _share: PopButton
## 共有する画像を撮る間だけ立てる
var _sharing := false
var _saved_until := 0


func _ready() -> void:
	_result = GameSession.last_result
	AudioDirector.play_bgm(&"menu")
	if _result != null and _result.winner == MatchController.PLAYER:
		AudioDirector.play_se(&"win")
	elif _result != null and _result.winner == MatchController.CPU:
		AudioDirector.play_se(&"lose")
	var again := PopButton.create("もう一度", UiPalette.MONEY, UiPalette.INK, UiPalette.FONT_HEAD)
	var select := PopButton.create("店長を選ぶ", UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_HEAD)
	var title := PopButton.create("タイトルへ", UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_HEAD)
	_share = PopButton.create(
		ResultShare.button_label(), UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_HEAD
	)
	var buttons: Array[PopButton] = [again, select, title, _share]
	_buttons = buttons
	var total := BUTTON_SIZE.x * buttons.size() + BUTTON_GAP * (buttons.size() - 1)
	for i in buttons.size():
		add_child(buttons[i])
		buttons[i].size = BUTTON_SIZE
		var x := (size.x - total) / 2.0 + i * (BUTTON_SIZE.x + BUTTON_GAP)
		buttons[i].position = Vector2(x, BUTTON_Y)
	if _result != null:
		_chart = ProfitChart.new()
		add_child(_chart)
		_chart.size = CHART_SIZE
		_chart.position = Vector2((size.x - CHART_SIZE.x) / 2.0, RECEIPT_Y)
		_chart.setup(_result)
		if _result.record != null and not _result.record.snapshots.is_empty():
			var db := GameDatabase.get_default()
			_chart.review = CpuReview.new(_result, db, MatchController.PLAYER)
	again.pressed.connect(_on_again)
	select.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
	title.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	_share.pressed.connect(_on_share)
	_share.disabled = not _review_done()


func _process(_delta: float) -> void:
	queue_redraw()
	if _chart != null and _chart.review != null and not _chart.review.is_done():
		if _chart.review.process(REVIEW_BUDGET_USEC):
			_chart.queue_redraw()
	_share.disabled = not _review_done()


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	SkyBackdrop.paint(self, screen, UiPalette.RESULT_SKY_TOP, UiPalette.RESULT_SKY_BOTTOM, 1.0)
	if _result == null:
		_draw_verdict("結果なし", UiPalette.INK_ON_DARK, false)
		return
	var verdict := "引き分け"
	var color := UiPalette.INK_ON_DARK
	if _result.winner == MatchController.PLAYER:
		verdict = "勝ち!"
		color = UiPalette.MONEY
	elif _result.winner == MatchController.CPU:
		verdict = "負け…"
		color = UiPalette.STORE_COLORS[MatchController.CPU].lightened(LOSE_LIGHTEN)
	_draw_verdict(verdict, color, _result.winner == MatchController.PLAYER)
	var total := RECEIPT_SIZE.x * 2.0 + CHART_SIZE.x + RECEIPT_GAP * 2.0
	for i in _result.stores.size():
		var x := (size.x - total) / 2.0 + i * (total - RECEIPT_SIZE.x)
		var rect := Rect2(Vector2(x, RECEIPT_Y), RECEIPT_SIZE)
		_draw_receipt(rect, _result.stores[i])
		if _result.winner == i:
			_draw_stamp(Vector2(rect.end.x, rect.position.y) + STAMP_OFFSET)
		if i == MatchController.PLAYER:
			_draw_badges(rect.position + BEST_OFFSET)
	if _sharing:
		_draw_share_footer()
	elif Time.get_ticks_msec() < _saved_until:
		var center := _share.position + Vector2(_share.size.x * 0.5, -SAVED_RISE)
		UiDraw.pill(
			self,
			center,
			"画像を保存しました",
			UiPalette.FONT_BODY,
			UiPalette.MONEY,
			UiPalette.INK,
			SAVED_HEIGHT
		)


func _draw_verdict(label: String, color: Color, burst: bool) -> void:
	var center := Vector2(size.x * 0.5, VERDICT_Y - UiPalette.FONT_TITLE * VERDICT_MID)
	if burst:
		var tint := UiPalette.MONEY
		tint.a = VERDICT_BURST_ALPHA
		var angle := Time.get_ticks_msec() / 1000.0 * TAU * VERDICT_BURST_SPIN
		UiDraw.burst(self, center, VERDICT_BURST_RADIUS, VERDICT_BURST_RAYS, angle, tint)
	var pos := Vector2(0, VERDICT_Y)
	UiDraw.text_outlined(
		self,
		pos,
		label,
		UiPalette.FONT_TITLE,
		color,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x
	)


## レシート:下端がぎざぎざの白い紙。店名・売上・客数などを印字する
func _draw_receipt(rect: Rect2, store: StoreState) -> void:
	var paper := _receipt_outline(rect)
	var shadow := PackedVector2Array()
	for point in paper:
		shadow.append(point + Vector2(0, UiPalette.SHADOW_DROP))
	draw_colored_polygon(shadow, UiPalette.SHADOW)
	draw_colored_polygon(paper, RECEIPT_PAPER)
	var ring := paper.duplicate()
	ring.append(paper[0])
	draw_polyline(ring, UiPalette.INK, UiPalette.OUTLINE, true)
	var inner_x := rect.position.x + PAD
	var width := rect.size.x - PAD * 2.0
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var store_color := UiPalette.STORE_COLORS[store.index]
	var store_pos := Vector2(rect.position.x, rect.position.y + STORE_Y)
	UiDraw.text(
		self,
		store_pos,
		UiPalette.STORE_NAMES[store.index],
		UiPalette.FONT_HEAD,
		store_color,
		center,
		rect.size.x
	)
	var manager := "店長 " + store.manager.display_name
	var manager_pos := Vector2(rect.position.x, rect.position.y + MANAGER_Y)
	UiDraw.text(
		self, manager_pos, manager, UiPalette.FONT_BODY, UiPalette.INK_SOFT, center, rect.size.x
	)
	var y := rect.position.y + MANAGER_Y + RULE_GAP
	_dashed(inner_x, y, width)
	UiDraw.text(
		self, Vector2(inner_x, y + SALES_LABEL_Y), "利益", UiPalette.FONT_BODY, UiPalette.INK_SOFT
	)
	var sales_pos := Vector2(inner_x, y + SALES_Y)
	UiDraw.text(
		self,
		sales_pos,
		UiDraw.yen(store.profit()),
		UiPalette.FONT_HUGE,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_RIGHT,
		width
	)
	y += SALES_Y + RULE_GAP
	_dashed(inner_x, y, width)
	y += LINE
	y = _row(inner_x, width, y, "売上", UiDraw.yen(store.sales))
	y = _row(inner_x, width, y, "仕入れ", UiDraw.yen(-store.spent))
	y = _row(inner_x, width, y, "来店した客", "%d人" % store.visitor_total)
	y = _row(inner_x, width, y, "取られた客", "%d人" % store.losses.total)
	_row(inner_x, width, y, "廃棄した個数", "%d個" % store.wasted_count)


## 上端はまっすぐ、下端はぎざぎざの外周
func _receipt_outline(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	var teeth := int(rect.size.x / TOOTH.x)
	var tooth := rect.size.x / teeth
	for i in range(teeth, 0, -1):
		points.append(Vector2(rect.position.x + tooth * i, rect.end.y))
		points.append(Vector2(rect.position.x + tooth * (i - 0.5), rect.end.y - TOOTH.y))
	points.append(Vector2(rect.position.x, rect.end.y))
	return points


func _dashed(x: float, y: float, width: float) -> void:
	var at := x
	while at < x + width:
		draw_line(
			Vector2(at, y), Vector2(minf(at + DASH.x, x + width), y), UiPalette.INK_SOFT, DASH_WIDTH
		)
		at += DASH.x + DASH.y


func _row(x: float, width: float, y: float, label: String, value: String) -> float:
	UiDraw.text(self, Vector2(x, y), label, UiPalette.FONT_LARGE, UiPalette.INK_SOFT)
	UiDraw.text(
		self,
		Vector2(x, y),
		value,
		UiPalette.FONT_HEAD,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_RIGHT,
		width
	)
	return y + LINE


## 自己ベスト更新と、増えた勝ち星(9.4節)の札
func _draw_badges(at: Vector2) -> void:
	var labels: Array[String] = []
	if GameSession.last_new_best:
		labels.append("自己ベスト更新!")
	if GameSession.last_new_star != &"":
		var level := GameDatabase.get_default().cpu_profile(GameSession.last_new_star)
		labels.append("★ %sに初勝利!" % level.display_name)
	for i in labels.size():
		var badge := Rect2(at + Vector2((BEST_SIZE.x + BADGE_GAP) * i, 0), BEST_SIZE)
		UiDraw.card(self, badge, UiPalette.MONEY, int(BEST_SIZE.y * 0.5), UiPalette.OUTLINE_THIN)
		UiDraw.text_centered(self, badge, labels[i], UiPalette.FONT_BODY, UiPalette.INK)


## 勝った店のレシートに押す赤い判
func _draw_stamp(center: Vector2) -> void:
	draw_set_transform(center, STAMP_ANGLE)
	draw_arc(Vector2.ZERO, STAMP_RADIUS, 0.0, TAU, STAMP_SEGMENTS, STAMP_INK, STAMP_RING, true)
	var inner := STAMP_RADIUS - STAMP_RING * 2.0
	draw_arc(
		Vector2.ZERO,
		inner,
		0.0,
		TAU,
		STAMP_SEGMENTS,
		STAMP_INK,
		STAMP_RING * STAMP_INNER_RING,
		true
	)
	var cell := Rect2(-Vector2.ONE * STAMP_RADIUS, Vector2.ONE * STAMP_RADIUS * 2.0)
	UiDraw.text_centered(self, cell, "勝", UiPalette.FONT_HUGE, STAMP_INK)
	draw_set_transform(Vector2.ZERO)


func _on_again() -> void:
	GameSession.prepare_match(GameSession.player_manager_id)
	get_tree().change_scene_to_file(MATCH_SCENE)


## 撮るのは「CPUならどうしたか」まで出そろってから(9.4節)
func _review_done() -> bool:
	if _result == null:
		return false
	return _chart.review == null or _chart.review.is_done()


## 共有する画像の下の帯:ボタンの代わりに題字とCPUの強さ
func _draw_share_footer() -> void:
	var title := "コンビニウォーズ"
	var cpu := "CPU " + _cpu_name()
	var title_width := UiDraw.text_width(title, UiPalette.FONT_HEAD)
	var total := title_width + SHARE_GAP + UiDraw.text_width(cpu, UiPalette.FONT_LARGE)
	var x := (size.x - total) / 2.0
	UiDraw.text_outlined(
		self, Vector2(x, SHARE_TITLE_Y), title, UiPalette.FONT_HEAD, UiPalette.MONEY
	)
	UiDraw.text(
		self,
		Vector2(x + title_width + SHARE_GAP, SHARE_TITLE_Y),
		cpu,
		UiPalette.FONT_LARGE,
		UiPalette.INK_ON_DARK
	)


func _cpu_name() -> String:
	return GameDatabase.get_default().cpu_profile(GameSession.cpu_profile_id()).display_name


func _on_share() -> void:
	if _sharing or not _review_done():
		return
	var image: Image = await share_image()
	var profit := _result.stores[MatchController.PLAYER].profit()
	var text := ResultShare.share_text(_result.winner, _cpu_name(), profit)
	if ResultShare.deliver(image, text) == ResultShare.Delivery.SAVED:
		_saved_until = Time.get_ticks_msec() + int(SAVED_SECONDS * 1000.0)


## ボタンを隠し下の帯に題字を描いた1フレームを撮る
func share_image() -> Image:
	_sharing = true
	for button in _buttons:
		button.visible = false
	queue_redraw()
	await RenderingServer.frame_post_draw
	var image := ResultShare.capture(get_viewport())
	_sharing = false
	for button in _buttons:
		button.visible = true
	return image
