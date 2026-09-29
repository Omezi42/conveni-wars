class_name ManagerSelectScreen
extends Control
## 店長の選択(GameDesign.md 7章)。カードをタップして選び、開店する。CPUは残りから選ばれる(8.1節)。

const MATCH_SCENE := "res://scenes/match.tscn"
const HEADER_Y := 70.0
const CARD_SIZE := Vector2(290, 400)
const CARD_GAP := 16.0
const CARD_Y := 110.0
const PAD := 16.0
const PORTRAIT_RADIUS := 44.0
const PORTRAIT_Y := 70.0
const NAME_Y := 150.0
const SECTION_GAP := 26.0
const DESC_LINES := 4
const BUTTON_SIZE := Vector2(300, 64)
const BUTTON_Y := 580.0
const SELECTED_EDGE := 4
const PORTRAIT_TEXT_RATIO := 0.9

var _selected := -1
var _start: Button


func _ready() -> void:
	_start = UiDraw.make_button("この店長で開店", UiPalette.STORE_COLORS[0], UiPalette.FONT_HEAD)
	add_child(_start)
	_start.size = BUTTON_SIZE
	_start.position = Vector2((size.x - BUTTON_SIZE.x) / 2.0, BUTTON_Y)
	_start.disabled = true
	_start.pressed.connect(_on_start)


func _managers() -> Array[ManagerData]:
	return GameDatabase.get_default().sorted_managers()


func _card_rect(index: int) -> Rect2:
	var count := _managers().size()
	var total := CARD_SIZE.x * count + CARD_GAP * (count - 1)
	var x := (size.x - total) / 2.0 + index * (CARD_SIZE.x + CARD_GAP)
	return Rect2(Vector2(x, CARD_Y), CARD_SIZE)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _managers().size():
		if _card_rect(i).has_point(press.position):
			_selected = i
			_start.disabled = false
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.BACKGROUND)
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var header := "店長を選ぶ"
	UiDraw.text(
		self, Vector2(0, HEADER_Y), header, UiPalette.FONT_HUGE, UiPalette.INK, center, size.x
	)
	var managers := _managers()
	for i in managers.size():
		_draw_card(_card_rect(i), managers[i], i == _selected)


func _draw_card(rect: Rect2, manager: ManagerData, selected: bool) -> void:
	UiDraw.shadowed_panel(self, rect, UiPalette.PANEL)
	if selected:
		draw_rect(rect.grow(2.0), manager.color, false, SELECTED_EDGE)
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var portrait := rect.position + Vector2(rect.size.x / 2.0, PORTRAIT_Y)
	if manager.portrait != null:
		var side := Vector2.ONE * PORTRAIT_RADIUS * 2.0
		draw_texture_rect(manager.portrait, Rect2(portrait - side / 2.0, side), false)
	else:
		draw_circle(portrait, PORTRAIT_RADIUS, manager.color)
		var cell := Rect2(
			portrait - Vector2.ONE * PORTRAIT_RADIUS, Vector2.ONE * PORTRAIT_RADIUS * 2.0
		)
		var letter := manager.display_name.left(1)
		var letter_size := int(PORTRAIT_RADIUS * PORTRAIT_TEXT_RATIO)
		UiDraw.text_centered(self, cell, letter, letter_size, UiPalette.INK_ON_DARK)
	var name_pos := Vector2(rect.position.x, rect.position.y + NAME_Y)
	UiDraw.text(
		self,
		name_pos,
		manager.display_name,
		UiPalette.FONT_HEAD,
		UiPalette.INK,
		center,
		rect.size.x
	)
	var y := rect.position.y + NAME_Y + SECTION_GAP * 1.5
	y = _draw_section(rect, y, "パッシブ(ずっと効く)", manager.passive_description, manager.color)
	var active_text := "%s:%s" % [manager.active_name, manager.active_description]
	_draw_section(rect, y, "アクティブ(1回だけ)", active_text, manager.color)


func _draw_section(rect: Rect2, y: float, label: String, body: String, color: Color) -> float:
	var x := rect.position.x + PAD
	var width := rect.size.x - PAD * 2.0
	UiDraw.text(self, Vector2(x, y), label, UiPalette.FONT_SMALL, color)
	var body_y := y + SECTION_GAP * 0.9
	var font := UiDraw.font()
	var font_size := UiPalette.FONT_BODY
	var left := HORIZONTAL_ALIGNMENT_LEFT
	draw_multiline_string(
		font, Vector2(x, body_y), body, left, width, font_size, DESC_LINES, UiPalette.INK
	)
	var lines := font.get_multiline_string_size(body, left, width, font_size, DESC_LINES).y
	return body_y + lines + SECTION_GAP


func _on_start() -> void:
	if _selected < 0:
		return
	GameSession.prepare_match(_managers()[_selected].id)
	get_tree().change_scene_to_file(MATCH_SCENE)
