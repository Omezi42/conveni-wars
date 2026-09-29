class_name ResultScreen
extends Control
## 結果(GameDesign.md 9.4節)。両店の売上・来店した客の数・客層ごとの来店数・取り逃した客・廃棄した個数と勝ち負け。

const MATCH_SCENE := "res://scenes/match.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const VERDICT_Y := 84.0
const COLUMN_SIZE := Vector2(420, 460)
const COLUMN_GAP := 40.0
const COLUMN_Y := 120.0
const PAD := 20.0
const HEADER_HEIGHT := 40.0
const LINE := 28.0
const TYPE_LINE := 22.0
const ICON_RADIUS := 8.0
const ICON_GAP := 6.0
const VALUE_WIDTH := 160.0
const BUTTON_SIZE := Vector2(240, 60)
const BUTTON_Y := 610.0
const BUTTON_GAP := 24.0
const TEXT_BASELINE := 0.72

var _result: MatchResult


func _ready() -> void:
	_result = GameSession.last_result
	var again := UiDraw.make_button("もう一度", UiPalette.STORE_COLORS[0], UiPalette.FONT_LARGE)
	var title := UiDraw.make_button("タイトルへ", UiPalette.INK_SOFT, UiPalette.FONT_LARGE)
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
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.BACKGROUND)
	var center := HORIZONTAL_ALIGNMENT_CENTER
	if _result == null:
		UiDraw.text(
			self, Vector2(0, VERDICT_Y), "結果なし", UiPalette.FONT_HUGE, UiPalette.INK, center, size.x
		)
		return
	var verdict := "引き分け"
	var color := UiPalette.INK
	if _result.winner == MatchController.PLAYER:
		verdict = "勝ち!"
		color = UiPalette.STORE_COLORS[MatchController.PLAYER]
	elif _result.winner == MatchController.CPU:
		verdict = "負け…"
		color = UiPalette.STORE_COLORS[MatchController.CPU]
	UiDraw.text(self, Vector2(0, VERDICT_Y), verdict, UiPalette.FONT_HUGE, color, center, size.x)
	var total := COLUMN_SIZE.x * 2.0 + COLUMN_GAP
	for i in _result.stores.size():
		var x := (size.x - total) / 2.0 + i * (COLUMN_SIZE.x + COLUMN_GAP)
		_draw_store(Rect2(Vector2(x, COLUMN_Y), COLUMN_SIZE), _result.stores[i])


func _draw_store(rect: Rect2, store: StoreState) -> void:
	UiDraw.shadowed_panel(self, rect, UiPalette.PANEL)
	var color := UiPalette.STORE_COLORS[store.index]
	var header := Rect2(rect.position, Vector2(rect.size.x, HEADER_HEIGHT))
	UiDraw.panel(self, header, color)
	var name := "%s 店長:%s" % [UiPalette.STORE_NAMES[store.index], store.manager.display_name]
	UiDraw.text_centered(self, header, name, UiPalette.FONT_LARGE, UiPalette.INK_ON_DARK)
	var y := header.end.y + LINE
	y = _row(rect, y, "売上", UiDraw.yen(store.sales), UiPalette.FONT_HEAD)
	y = _row(rect, y, "来店した客", "%d人" % store.visitor_total, UiPalette.FONT_LARGE)
	y = _row(rect, y, "取り逃した客", "%d人" % store.lost_total, UiPalette.FONT_LARGE)
	y = _row(rect, y, "廃棄した個数", "%d個" % store.wasted_count, UiPalette.FONT_LARGE)
	y += LINE * 0.5
	for customer in GameDatabase.get_default().sorted_customer_types():
		var count := int(store.visitors.get(customer.id, 0))
		if count == 0:
			continue
		var mid := y - TYPE_LINE * 0.3
		UiDraw.customer_icon(
			self, Vector2(rect.position.x + PAD + ICON_RADIUS, mid), ICON_RADIUS, customer
		)
		var label_pos := Vector2(rect.position.x + PAD + ICON_RADIUS * 2.0 + ICON_GAP, y)
		UiDraw.text(self, label_pos, customer.display_name, UiPalette.FONT_BODY, UiPalette.INK)
		var value_pos := Vector2(rect.end.x - PAD - VALUE_WIDTH, y)
		var align := HORIZONTAL_ALIGNMENT_RIGHT
		UiDraw.text(
			self, value_pos, "%d人" % count, UiPalette.FONT_BODY, UiPalette.INK, align, VALUE_WIDTH
		)
		y += TYPE_LINE


func _row(rect: Rect2, y: float, label: String, value: String, font_size: int) -> float:
	UiDraw.text(
		self, Vector2(rect.position.x + PAD, y), label, UiPalette.FONT_BODY, UiPalette.INK_SOFT
	)
	var value_pos := Vector2(rect.end.x - PAD - VALUE_WIDTH, y)
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	UiDraw.text(self, value_pos, value, font_size, UiPalette.INK, align, VALUE_WIDTH)
	return y + LINE


func _on_again() -> void:
	GameSession.prepare_match(GameSession.player_manager_id)
	get_tree().change_scene_to_file(MATCH_SCENE)
