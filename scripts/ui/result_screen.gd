class_name ResultScreen
extends Control
## 結果(GameDesign.md 9.4節)。勝ち負けと、両店の売上・来店した客の数・取り逃した客・廃棄した個数・客層ごとの来店数、
## その下に主な差分(自店−相手)。

const MATCH_SCENE := "res://scenes/match.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const VERDICT_Y := 96.0
const VERDICT_OUTLINE := 14
const CARD_SIZE := Vector2(450, 316)
const CARD_GAP := 100.0
const CARD_Y := 120.0
const PAD := 20.0
const HEADER_HEIGHT := 48.0
const PORTRAIT_RADIUS := 26.0
const LINE := 30.0
const TYPE_LINE := 21.0
const TYPE_COLUMNS := 2
const ICON_RADIUS := 8.0
const ICON_GAP := 6.0
const VALUE_WIDTH := 160.0
const DIVIDER := Color("#d5dde8")
const VS_SIZE := 56
const DIFF_RECT := Rect2(240, 456, 800, 96)
const DIFF_TITLE_BASELINE := 22.0
const DIFF_LABEL_BASELINE := 50.0
const DIFF_VALUE_BASELINE := 82.0
const BUTTON_SIZE := Vector2(260, 60)
const BUTTON_Y := 600.0
const BUTTON_GAP := 24.0
const SECONDARY := Color("#2a3d66")

var _result: MatchResult


func _ready() -> void:
	_result = GameSession.last_result
	var again := UiDraw.make_button(
		"もう一度 ›", UiPalette.ACCENT, UiPalette.FONT_LARGE, UiPalette.ACCENT_INK
	)
	var title := UiDraw.make_button("タイトルへ", SECONDARY, UiPalette.FONT_LARGE)
	var buttons: Array[Button] = [again, title]
	var total := BUTTON_SIZE.x * buttons.size() + BUTTON_GAP * (buttons.size() - 1)
	for i in buttons.size():
		add_child(buttons[i])
		buttons[i].size = BUTTON_SIZE
		var x := (size.x - total) / 2.0 + i * (BUTTON_SIZE.x + BUTTON_GAP)
		buttons[i].position = Vector2(x, BUTTON_Y)
	again.pressed.connect(_on_again)
	title.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _draw() -> void:
	UiDraw.backdrop(self, Rect2(Vector2.ZERO, size), UiPalette.SCRIM)
	if _result == null:
		_draw_verdict("結果なし", UiPalette.INK)
		return
	if _result.winner == MatchController.PLAYER:
		_draw_verdict("WIN!", UiPalette.ACCENT)
	elif _result.winner == MatchController.CPU:
		_draw_verdict("LOSE…", UiPalette.STORE_COLORS[MatchController.CPU].lightened(0.3))
	else:
		_draw_verdict("DRAW", UiPalette.INK)
	var total := CARD_SIZE.x * 2.0 + CARD_GAP
	for i in _result.stores.size():
		var x := (size.x - total) / 2.0 + i * (CARD_SIZE.x + CARD_GAP)
		_draw_store(Rect2(Vector2(x, CARD_Y), CARD_SIZE), _result.stores[i])
	var vs_width := UiDraw.text_width("VS", VS_SIZE)
	var vs_pos := Vector2((size.x - vs_width) / 2.0, CARD_Y + CARD_SIZE.y / 2.0 + VS_SIZE / 2.0)
	UiDraw.text_outlined(
		self, vs_pos, "VS", VS_SIZE, UiPalette.ACCENT, VERDICT_OUTLINE / 2, UiPalette.BAR
	)
	_draw_diff(_result.stores[MatchController.PLAYER], _result.stores[MatchController.CPU])


func _draw_verdict(label: String, color: Color) -> void:
	var font_size := UiPalette.FONT_TITLE
	var x := (size.x - UiDraw.text_width(label, font_size)) / 2.0
	UiDraw.text_outlined(
		self, Vector2(x, VERDICT_Y), label, font_size, color, VERDICT_OUTLINE, UiPalette.BAR
	)


func _draw_store(rect: Rect2, store: StoreState) -> void:
	UiDraw.shadowed_panel(self, rect, UiPalette.CARD, UiPalette.PANEL_RADIUS)
	var color := UiPalette.STORE_COLORS[store.index]
	var header := Rect2(rect.position, Vector2(rect.size.x, HEADER_HEIGHT))
	var header_box := (
		UiDraw.box(color, Color.TRANSPARENT, 0, UiPalette.PANEL_RADIUS).duplicate() as StyleBoxFlat
	)
	header_box.corner_radius_bottom_left = 0
	header_box.corner_radius_bottom_right = 0
	header_box.draw(get_canvas_item(), header)
	var portrait := header.position + Vector2(PAD + PORTRAIT_RADIUS, HEADER_HEIGHT / 2.0)
	UiDraw.portrait(self, portrait, PORTRAIT_RADIUS, store.manager)
	var name := "%s 店長:%s" % [UiPalette.STORE_TITLES[store.index], store.manager.display_name]
	UiDraw.text_centered(self, header, name, UiPalette.FONT_LARGE, UiPalette.INK_ON_DARK)
	var y := header.end.y + LINE
	y = _row(rect, y, "売上", UiDraw.yen(store.sales), UiPalette.FONT_HEAD)
	y = _row(rect, y, "来店した客", "%d人" % store.visitor_total, UiPalette.FONT_LARGE)
	y = _row(rect, y, "取り逃した客", "%d人" % store.lost_total, UiPalette.FONT_LARGE)
	y = _row(rect, y, "廃棄した個数", "%d個" % store.wasted_count, UiPalette.FONT_LARGE)
	var divider_y := y - LINE * 0.55
	draw_line(
		Vector2(rect.position.x + PAD, divider_y),
		Vector2(rect.end.x - PAD, divider_y),
		DIVIDER,
		1.0
	)
	_draw_types(rect, y, store)


## 客層ごとの来店数(来た客層だけ、2列)
func _draw_types(rect: Rect2, top: float, store: StoreState) -> void:
	var column_width := (rect.size.x - PAD * 2.0) / TYPE_COLUMNS
	var index := 0
	for customer in GameDatabase.get_default().sorted_customer_types():
		var count := int(store.visitors.get(customer.id, 0))
		if count == 0:
			continue
		var x := rect.position.x + PAD + (index % TYPE_COLUMNS) * column_width
		@warning_ignore("integer_division")
		var y := top + (index / TYPE_COLUMNS) * TYPE_LINE
		UiDraw.customer_icon(
			self, Vector2(x + ICON_RADIUS, y - TYPE_LINE * 0.3), ICON_RADIUS, customer
		)
		var label_pos := Vector2(x + ICON_RADIUS * 2.0 + ICON_GAP, y)
		UiDraw.text(self, label_pos, customer.display_name, UiPalette.FONT_BODY, UiPalette.CARD_INK)
		var value_width := column_width - PAD
		UiDraw.text(
			self,
			Vector2(x, y),
			"%d人" % count,
			UiPalette.FONT_BODY,
			UiPalette.CARD_INK,
			HORIZONTAL_ALIGNMENT_RIGHT,
			value_width
		)
		index += 1


func _row(rect: Rect2, y: float, label: String, value: String, font_size: int) -> float:
	var label_pos := Vector2(rect.position.x + PAD, y)
	UiDraw.text(self, label_pos, label, UiPalette.FONT_BODY, UiPalette.CARD_INK_SOFT)
	var value_pos := Vector2(rect.end.x - PAD - VALUE_WIDTH, y)
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	UiDraw.text(self, value_pos, value, font_size, UiPalette.CARD_INK, align, VALUE_WIDTH)
	return y + LINE


## 主な差分(自店−相手)。良い向きは緑、悪い向きは赤(取り逃しと廃棄は少ないほうが良い)
func _draw_diff(own: StoreState, rival: StoreState) -> void:
	UiDraw.glass_panel(self, DIFF_RECT)
	var title_pos := DIFF_RECT.position + Vector2(PAD, DIFF_TITLE_BASELINE)
	UiDraw.panel_title(self, title_pos, "主な差分(自店−相手)")
	var items := [
		["売上", own.sales - rival.sales, "¥", true],
		["来店した客", own.visitor_total - rival.visitor_total, "人", true],
		["取り逃した客", own.lost_total - rival.lost_total, "人", false],
		["廃棄した個数", own.wasted_count - rival.wasted_count, "個", false],
	]
	var width := (DIFF_RECT.size.x - PAD * 2.0) / items.size()
	var center := HORIZONTAL_ALIGNMENT_CENTER
	for i in items.size():
		var item: Array = items[i]
		var x := DIFF_RECT.position.x + PAD + i * width
		var label_pos := Vector2(x, DIFF_RECT.position.y + DIFF_LABEL_BASELINE)
		UiDraw.text(
			self, label_pos, item[0], UiPalette.FONT_SMALL, UiPalette.INK_SOFT, center, width
		)
		var diff: int = item[1]
		var good: bool = diff > 0 if item[3] else diff < 0
		var color := UiPalette.INK
		if diff != 0:
			color = UiPalette.GOOD_BRIGHT if good else UiPalette.BAD_BRIGHT
		var value_pos := Vector2(x, DIFF_RECT.position.y + DIFF_VALUE_BASELINE)
		UiDraw.text(
			self, value_pos, _signed(diff, item[2]), UiPalette.FONT_HEAD, color, center, width
		)


static func _signed(value: int, unit: String) -> String:
	var sign := "+" if value > 0 else ""
	if unit == "¥":
		return sign + UiDraw.yen(value)
	return "%s%d%s" % [sign, value, unit]


func _on_again() -> void:
	GameSession.prepare_match(GameSession.player_manager_id)
	get_tree().change_scene_to_file(MATCH_SCENE)
