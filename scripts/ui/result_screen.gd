class_name ResultScreen
extends Control
## 結果(GameDesign.md 9.4節・9.5節)。閉店後の夜空の下に、両店の成績をレシートの形で並べ、勝った店に「勝」の判を押す。
## 利益・売上・仕入れ・来店した客の数・取り逃した客・廃棄した個数・客層ごとの来店数を出す。

const MATCH_SCENE := "res://scenes/match.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const VERDICT_Y := 92.0
const VERDICT_BURST_RADIUS := 220.0
const VERDICT_BURST_RAYS := 20
const VERDICT_BURST_SPIN := 0.05
const VERDICT_BURST_ALPHA := 0.22
## ベースラインから文字の見た目の中央までの高さ(文字の大きさに対する割合)
const VERDICT_MID := 0.35
const LOSE_LIGHTEN := 0.2
const RECEIPT_SIZE := Vector2(400, 484)
const RECEIPT_GAP := 60.0
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
const LINE := 30.0
const TYPE_LINE := 24.0
const TYPE_COLUMNS := 2
const TYPE_ICON_RADIUS := 8.0
const TYPE_ICON_GAP := 6.0
## 客層アイコンを文字の中ほどへ上げる量(半径に対する割合)
const TYPE_ICON_RAISE := 0.6
const STAMP_OFFSET := Vector2(-58, 62)
const STAMP_RADIUS := 46.0
const STAMP_RING := 5.0
const STAMP_ANGLE := -0.22
const STAMP_INK := Color(0.86, 0.13, 0.15, 0.85)
const STAMP_SEGMENTS := 48
## 内側の細い輪の太さ(外側の輪に対する割合)
const STAMP_INNER_RING := 0.4
const BUTTON_SIZE := Vector2(250, 70)
const BUTTON_Y := 622.0
const BUTTON_GAP := 28.0

var _result: MatchResult


func _ready() -> void:
	_result = GameSession.last_result
	var again := PopButton.create("もう一度", UiPalette.MONEY, UiPalette.INK, UiPalette.FONT_HEAD)
	var title := PopButton.create("タイトルへ", UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_HEAD)
	var buttons: Array[PopButton] = [again, title]
	var total := BUTTON_SIZE.x * buttons.size() + BUTTON_GAP * (buttons.size() - 1)
	for i in buttons.size():
		add_child(buttons[i])
		buttons[i].size = BUTTON_SIZE
		var x := (size.x - total) / 2.0 + i * (BUTTON_SIZE.x + BUTTON_GAP)
		buttons[i].position = Vector2(x, BUTTON_Y)
	again.pressed.connect(_on_again)
	title.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _process(_delta: float) -> void:
	queue_redraw()


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
	var total := RECEIPT_SIZE.x * _result.stores.size() + RECEIPT_GAP * (_result.stores.size() - 1)
	for i in _result.stores.size():
		var x := (size.x - total) / 2.0 + i * (RECEIPT_SIZE.x + RECEIPT_GAP)
		var rect := Rect2(Vector2(x, RECEIPT_Y), RECEIPT_SIZE)
		_draw_receipt(rect, _result.stores[i])
		if _result.winner == i:
			_draw_stamp(Vector2(rect.end.x, rect.position.y) + STAMP_OFFSET)


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
	y = _row(inner_x, width, y, "取り逃した客", "%d人" % store.lost_total)
	y = _row(inner_x, width, y, "廃棄した個数", "%d個" % store.wasted_count)
	y += RULE_GAP - LINE + UiPalette.FONT_LARGE * 0.5
	_dashed(inner_x, y, width)
	y += TYPE_LINE
	_draw_types(inner_x, width, y, store)


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
	UiDraw.text(self, Vector2(x, y), label, UiPalette.FONT_BODY, UiPalette.INK_SOFT)
	UiDraw.text(
		self,
		Vector2(x, y),
		value,
		UiPalette.FONT_LARGE,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_RIGHT,
		width
	)
	return y + LINE


## 客層ごとの来店数(2列)
func _draw_types(x: float, width: float, top: float, store: StoreState) -> void:
	var column_width := width / TYPE_COLUMNS
	var index := 0
	for customer in GameDatabase.get_default().sorted_customer_types():
		var count := int(store.visitors.get(customer.id, 0))
		if count == 0:
			continue
		@warning_ignore("integer_division")
		var row := index / TYPE_COLUMNS
		var column_x := x + column_width * (index % TYPE_COLUMNS)
		var y := top + row * TYPE_LINE
		var icon := Vector2(column_x + TYPE_ICON_RADIUS, y - TYPE_ICON_RADIUS * TYPE_ICON_RAISE)
		UiDraw.customer_icon(self, icon, TYPE_ICON_RADIUS, customer)
		var name_x := column_x + TYPE_ICON_RADIUS * 2.0 + TYPE_ICON_GAP
		UiDraw.text(
			self, Vector2(name_x, y), customer.display_name, UiPalette.FONT_SMALL, UiPalette.INK
		)
		var value_width := column_width - TYPE_ICON_GAP * 2.0
		UiDraw.text(
			self,
			Vector2(column_x, y),
			"%d人" % count,
			UiPalette.FONT_SMALL,
			UiPalette.INK,
			HORIZONTAL_ALIGNMENT_RIGHT,
			value_width
		)
		index += 1


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
