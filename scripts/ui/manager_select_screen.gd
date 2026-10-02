class_name ManagerSelectScreen
extends Control
## 店長の選択(GameDesign.md 7章・9.5節)。店長は社員証の形のカードで並べる。
## カードをタップして選び(浮き上がって黄色い枠が付く)、開店する。CPUは残りから選ばれる(8.1節)。
## 店長の色の地の右下に、CPUの強さごとの勝ち星(9.7節)を並べる。
## 左下でCPUの強さ(8.3節)を選ぶ。スキルは短い言葉で出し、カーソルを乗せた(タッチでは押した)カードだけ正確な効果を出す(7.1節)。

const MATCH_SCENE := "res://scenes/match.tscn"
const HEADER_RECT := Rect2(490, 22, 300, 52)
const CARD_SIZE := Vector2(272, 448)
const CARD_GAP := 18.0
const CARD_Y := 104.0
const CARD_RADIUS := 16
const LIFT := 10.0
const HOVER_LIFT := 4.0
const PAD := 16.0
const STRAP := Vector2(44, 9)
const STRAP_Y := 12.0
const BADGE_TOP := 30.0
const BADGE_HEIGHT := 106.0
const PORTRAIT_RADIUS := 44.0
const PORTRAIT_RING := 5.0
const PORTRAIT_TEXT := 40
const PORTRAIT_DARKEN := 0.2
const NAME_Y := 172.0
const SECTION_Y := 190.0
const LABEL_HEIGHT := 26.0
const BODY_GAP := 8.0
const SECTION_GAP := 10.0
const PASSIVE_LINES := 3
const ACTIVE_LINES := 4
## 勝ち星(店長の色の地の右下からの位置)
const STAR_RADIUS := 10.0
const STAR_SPACING := 24.0
const STAR_INSET := Vector2(16, 16)
const SELECT_RING := 5.0
const RIBBON_SIZE := Vector2(96, 28)
const BUTTON_RECT := Rect2(460, 582, 360, 78)
const GROUND_Y := 680.0
const LEVEL_LEFT := 60.0
const LEVEL_SIZE := Vector2(120, 58)
const LEVEL_GAP := 12.0
## CPUの強さのボタンの上の見出し(ボタンの上端からベースラインまで)
const LEVEL_HEADING_GAP := 10.0
const LEVEL_HEADING := "CPUの強さ"

var _selected := -1
var _hover := -1
var _start: PopButton
var _levels: Array[PopButton] = []


func _ready() -> void:
	AudioDirector.play_bgm(&"menu")
	_start = PopButton.create("この店長で開店!", UiPalette.MONEY, UiPalette.INK, UiPalette.FONT_HEAD)
	add_child(_start)
	_start.position = BUTTON_RECT.position
	_start.size = BUTTON_RECT.size
	_start.disabled = true
	_start.pressed.connect(_on_start)
	var profiles := GameDatabase.get_default().sorted_cpu_profiles()
	for i in profiles.size():
		var button := PopButton.create(
			profiles[i].display_name, UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_LARGE
		)
		add_child(button)
		button.size = LEVEL_SIZE
		button.position = Vector2(
			LEVEL_LEFT + i * (LEVEL_SIZE.x + LEVEL_GAP), BUTTON_RECT.end.y - LEVEL_SIZE.y
		)
		button.pressed.connect(_on_level_pressed.bind(profiles[i].id))
		_levels.append(button)
	_show_level()


func _show_level() -> void:
	var current := GameSession.cpu_profile_id()
	var profiles := GameDatabase.get_default().sorted_cpu_profiles()
	for i in _levels.size():
		_levels[i].chosen = profiles[i].id == current


func _on_level_pressed(id: StringName) -> void:
	GameSession.set_cpu_profile_id(id)
	_show_level()


func _managers() -> Array[ManagerData]:
	return GameDatabase.get_default().sorted_managers()


func _card_rect(index: int) -> Rect2:
	var count := _managers().size()
	var total := CARD_SIZE.x * count + CARD_GAP * (count - 1)
	var x := (size.x - total) / 2.0 + index * (CARD_SIZE.x + CARD_GAP)
	return Rect2(Vector2(x, CARD_Y), CARD_SIZE)


func _card_at(pos: Vector2) -> int:
	for i in _managers().size():
		if _card_rect(i).grow_individual(0, LIFT, 0, 0).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var hover := _card_at(motion.position)
		if hover != _hover:
			_hover = hover
			mouse_default_cursor_shape = CURSOR_POINTING_HAND if hover >= 0 else CURSOR_ARROW
			queue_redraw()
		return
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _card_at(press.position)
	if index >= 0:
		_selected = index
		_start.disabled = false
		queue_redraw()


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	SkyBackdrop.paint(self, screen, UiPalette.MENU_SKY_TOP, UiPalette.MENU_SKY_BOTTOM, 0.0)
	draw_rect(Rect2(0, GROUND_Y, size.x, size.y - GROUND_Y), UiPalette.SIDEWALK)
	draw_line(Vector2(0, GROUND_Y), Vector2(size.x, GROUND_Y), UiPalette.INK, UiPalette.OUTLINE)
	UiDraw.panel(
		self, HEADER_RECT, UiPalette.INK, Color.TRANSPARENT, 0, int(HEADER_RECT.size.y * 0.5)
	)
	UiDraw.text_centered(self, HEADER_RECT, "店長を選ぶ", UiPalette.FONT_HEAD, UiPalette.INK_ON_DARK)
	var heading_y := BUTTON_RECT.end.y - LEVEL_SIZE.y - LEVEL_HEADING_GAP
	UiDraw.text_outlined(
		self,
		Vector2(LEVEL_LEFT, heading_y),
		LEVEL_HEADING,
		UiPalette.FONT_LARGE,
		UiPalette.INK_ON_DARK,
		UiPalette.INK
	)
	var managers := _managers()
	for i in managers.size():
		var rect := _card_rect(i)
		if i == _selected:
			rect.position.y -= LIFT
		elif i == _hover:
			rect.position.y -= HOVER_LIFT
		_draw_card(rect, managers[i], i == _selected, i == _hover)


func _draw_card(rect: Rect2, manager: ManagerData, selected: bool, detailed: bool) -> void:
	if selected:
		var ring := rect.grow(SELECT_RING)
		UiDraw.panel(
			self,
			ring,
			UiPalette.MONEY,
			UiPalette.INK,
			UiPalette.OUTLINE_THIN,
			CARD_RADIUS + int(SELECT_RING)
		)
	UiDraw.card(self, rect, UiPalette.PAPER, CARD_RADIUS)
	var strap := Rect2(
		rect.get_center().x - STRAP.x * 0.5, rect.position.y + STRAP_Y, STRAP.x, STRAP.y
	)
	UiDraw.panel(
		self, strap, UiPalette.PAPER_DIM, UiPalette.INK, UiPalette.OUTLINE_THIN, int(STRAP.y * 0.5)
	)
	var badge := Rect2(
		rect.position.x + PAD * 0.75,
		rect.position.y + BADGE_TOP,
		rect.size.x - PAD * 1.5,
		BADGE_HEIGHT
	)
	UiDraw.panel(
		self, badge, manager.color, UiPalette.INK, UiPalette.OUTLINE_THIN, UiPalette.RADIUS
	)
	_draw_portrait(badge.get_center(), manager)
	_draw_stars(badge, manager)
	var name_pos := Vector2(rect.position.x, rect.position.y + NAME_Y)
	UiDraw.text(
		self,
		name_pos,
		manager.display_name,
		UiPalette.FONT_HEAD,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x
	)
	var y := rect.position.y + SECTION_Y
	var passive := manager.passive_description if detailed else manager.passive_short
	var active := manager.active_description if detailed else manager.active_short
	var body_size := UiPalette.FONT_BODY if detailed else UiPalette.FONT_LARGE
	y = _draw_section(rect, y, "パッシブ", UiPalette.INK_SOFT, "", passive, body_size, PASSIVE_LINES)
	y += SECTION_GAP
	_draw_section(
		rect, y, "アクティブ", manager.color, manager.active_name, active, body_size, ACTIVE_LINES
	)
	if selected:
		var ribbon := Rect2(
			rect.end.x - RIBBON_SIZE.x + PAD * 0.5,
			rect.position.y - RIBBON_SIZE.y * 0.5,
			RIBBON_SIZE.x,
			RIBBON_SIZE.y
		)
		UiDraw.card(self, ribbon, UiPalette.MONEY, int(RIBBON_SIZE.y * 0.5), UiPalette.OUTLINE_THIN)
		UiDraw.text_centered(self, ribbon, "選択中", UiPalette.FONT_BODY, UiPalette.INK)


## 勝ったCPUの強さの星だけ黄色く塗る(左から やさしい・ふつう・つよい)
func _draw_stars(badge: Rect2, manager: ManagerData) -> void:
	var profiles := GameDatabase.get_default().sorted_cpu_profiles()
	var right := badge.end - STAR_INSET
	for i in profiles.size():
		var center := right - Vector2(STAR_SPACING * (profiles.size() - 1 - i), 0)
		var won: bool = GameSession.save.has_star(manager.id, profiles[i].id)
		var fill := UiPalette.MONEY if won else UiPalette.PAPER_DIM
		UiDraw.star(self, center, STAR_RADIUS, fill, UiPalette.INK)


func _draw_portrait(center: Vector2, manager: ManagerData) -> void:
	draw_circle(center, PORTRAIT_RADIUS + PORTRAIT_RING + UiPalette.OUTLINE_THIN, UiPalette.INK)
	draw_circle(center, PORTRAIT_RADIUS + PORTRAIT_RING, UiPalette.INK_ON_DARK)
	if manager.portrait != null:
		var side := Vector2.ONE * PORTRAIT_RADIUS * 2.0
		draw_texture_rect(manager.portrait, Rect2(center - side / 2.0, side), false)
		return
	draw_circle(center, PORTRAIT_RADIUS, manager.color.darkened(PORTRAIT_DARKEN))
	var cell := Rect2(center - Vector2.ONE * PORTRAIT_RADIUS, Vector2.ONE * PORTRAIT_RADIUS * 2.0)
	UiDraw.text_centered(
		self,
		cell,
		manager.display_name.left(1),
		PORTRAIT_TEXT,
		UiPalette.INK_ON_DARK,
		UiPalette.INK
	)


## 札(パッシブ/アクティブ)と、その右に名前、下に説明。描き終えた下端を返す
func _draw_section(
	rect: Rect2,
	y: float,
	label: String,
	color: Color,
	title: String,
	body: String,
	font_size: int,
	max_lines: int
) -> float:
	var x := rect.position.x + PAD
	var width := rect.size.x - PAD * 2.0
	var label_width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + PAD
	var chip := Rect2(x, y, label_width, LABEL_HEIGHT)
	UiDraw.panel(self, chip, color, UiPalette.INK, UiPalette.OUTLINE_THIN, int(LABEL_HEIGHT * 0.5))
	UiDraw.text_centered(
		self, chip, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK, UiPalette.INK
	)
	if not title.is_empty():
		var title_pos := Vector2(
			chip.end.x + BODY_GAP, UiDraw.baseline_in(chip, UiPalette.FONT_LARGE)
		)
		UiDraw.text(self, title_pos, title, UiPalette.FONT_LARGE, UiPalette.INK)
	var font := UiDraw.font()
	var left := HORIZONTAL_ALIGNMENT_LEFT
	var body_top := chip.end.y + BODY_GAP + font.get_ascent(font_size)
	draw_multiline_string(
		font, Vector2(x, body_top), body, left, width, font_size, max_lines, UiPalette.INK
	)
	var lines := font.get_multiline_string_size(body, left, width, font_size, max_lines).y
	return chip.end.y + BODY_GAP + lines


func _on_start() -> void:
	if _selected < 0:
		return
	GameSession.prepare_match(_managers()[_selected].id)
	get_tree().change_scene_to_file(MATCH_SCENE)
