class_name ManagerSelectScreen
extends Control
## 店長の選択(GameDesign.md 7章・9.5節)。カードをタップして選び、「決定」で開店する。
## CPUは残りから選ばれる(8.1節)。

const MATCH_SCENE := "res://scenes/match.tscn"
const STORE_ICON := preload("res://assets/icons/ui/store.svg")
const HEADER_POS := Vector2(96, 70)
const HEADER_OUTLINE := 10
const HEADER_ICON_CENTER := Vector2(62, 56)
const HEADER_ICON_RADIUS := 22.0
const LEAD_POS := Vector2(96, 100)
const CARD_SIZE := Vector2(290, 440)
const CARD_GAP := 16.0
const CARD_Y := 124.0
const SELECTED_LIFT := 8.0
const PAD := 16.0
const PORTRAIT_AREA := 168.0
const PORTRAIT_RADIUS := 66.0
const PORTRAIT_LIGHTEN := 0.6
const NAME_BAND := 40.0
const PILL_SIZE := Vector2(76, 22)
const PILL_GAP := 8.0
## ラベルの下端から見出しのベースラインまでの持ち上げ
const HEADING_DROP := 4.0
const SECTION_TOP := 18.0
const SECTION_GAP := 16.0
const DESC_LINES := 3
const BUTTON_SIZE := Vector2(300, 64)
const BUTTON_Y := 600.0
const SELECTED_EDGE := 5
const SHADOW_OFFSET := Vector2(0, 6)
const SHADOW := Color(0, 0, 0, 0.3)

var _selected := -1
var _start: Button


func _ready() -> void:
	_start = UiDraw.make_button("決定 ›", UiPalette.ACCENT, UiPalette.FONT_HEAD, UiPalette.ACCENT_INK)
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
	var y := CARD_Y - (SELECTED_LIFT if index == _selected else 0.0)
	return Rect2(Vector2(x, y), CARD_SIZE)


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
	UiDraw.backdrop(self, Rect2(Vector2.ZERO, size), UiPalette.SCRIM)
	draw_circle(HEADER_ICON_CENTER, HEADER_ICON_RADIUS + 3.0, UiPalette.INK_ON_DARK)
	UiDraw.texture_at(self, STORE_ICON, HEADER_ICON_CENTER, HEADER_ICON_RADIUS)
	UiDraw.text_outlined(
		self,
		HEADER_POS,
		"店長を選ぼう",
		UiPalette.FONT_HUGE,
		UiPalette.INK_ON_DARK,
		HEADER_OUTLINE,
		UiPalette.BAR
	)
	var lead := "パッシブは試合中ずっと効き、アクティブは試合中に1回だけ使える。"
	UiDraw.text(self, LEAD_POS, lead, UiPalette.FONT_BODY, UiPalette.INK)
	var managers := _managers()
	for i in managers.size():
		_draw_card(_card_rect(i), managers[i], i == _selected)


func _draw_card(rect: Rect2, manager: ManagerData, selected: bool) -> void:
	var radius := UiPalette.PANEL_RADIUS
	UiDraw.panel(
		self, Rect2(rect.position + SHADOW_OFFSET, rect.size), SHADOW, Color.TRANSPARENT, 0, radius
	)
	if selected:
		UiDraw.panel(
			self,
			rect.grow(SELECTED_EDGE),
			UiPalette.ACCENT,
			Color.TRANSPARENT,
			0,
			radius + SELECTED_EDGE
		)
	UiDraw.panel(self, rect, UiPalette.CARD, Color.TRANSPARENT, 0, radius)
	var top := Rect2(rect.position, Vector2(rect.size.x, PORTRAIT_AREA))
	var top_box := UiDraw.box(manager.color.lightened(PORTRAIT_LIGHTEN)).duplicate() as StyleBoxFlat
	top_box.corner_radius_bottom_left = 0
	top_box.corner_radius_bottom_right = 0
	top_box.draw(get_canvas_item(), top)
	var portrait := top.get_center() + Vector2(0, NAME_BAND / 4.0)
	if manager.portrait != null:
		UiDraw.texture_at(self, manager.portrait, portrait, PORTRAIT_RADIUS)
	else:
		UiDraw.portrait(self, portrait, PORTRAIT_RADIUS, manager)
	var band := Rect2(rect.position.x, top.end.y, rect.size.x, NAME_BAND)
	draw_rect(band, manager.color)
	UiDraw.text_centered(
		self, band, manager.display_name, UiPalette.FONT_HEAD, UiPalette.INK_ON_DARK
	)
	var y := band.end.y + SECTION_TOP
	y = _draw_section(rect, y, "パッシブ", "", manager.passive_description, manager.color)
	_draw_section(rect, y, "アクティブ", manager.active_name, manager.active_description, manager.color)


## 色付きのラベルと、その横の見出し・下の本文。次の節の上端を返す
func _draw_section(
	rect: Rect2, y: float, label: String, heading: String, body: String, color: Color
) -> float:
	var x := rect.position.x + PAD
	var width := rect.size.x - PAD * 2.0
	var pill := Rect2(Vector2(x, y), PILL_SIZE)
	UiDraw.panel(self, pill, color, Color.TRANSPARENT, 0, int(PILL_SIZE.y / 2.0))
	UiDraw.text_centered(self, pill, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK)
	if heading != "":
		var heading_pos := Vector2(pill.end.x + PILL_GAP, pill.end.y - HEADING_DROP)
		UiDraw.text(self, heading_pos, heading, UiPalette.FONT_LARGE, UiPalette.CARD_INK)
	var body_y := pill.end.y + UiPalette.FONT_BODY + 6.0
	var font := UiDraw.font()
	var font_size := UiPalette.FONT_BODY
	var left := HORIZONTAL_ALIGNMENT_LEFT
	draw_multiline_string(
		font, Vector2(x, body_y), body, left, width, font_size, DESC_LINES, UiPalette.CARD_INK
	)
	var lines := font.get_multiline_string_size(body, left, width, font_size, DESC_LINES).y
	return body_y + lines + SECTION_GAP - UiPalette.FONT_BODY


func _on_start() -> void:
	if _selected < 0:
		return
	GameSession.prepare_match(_managers()[_selected].id)
	get_tree().change_scene_to_file(MATCH_SCENE)
