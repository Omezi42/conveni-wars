class_name TitleScreen
extends Control
## タイトル(GameDesign.md 9.1節・9.5節)。夕暮れの通りに、看板を掲げた2軒のコンビニが向かい合う。

const NEXT_SCENE := "res://scenes/manager_select.tscn"
const LOGO_Y := 150.0
const LOGO_SHADOW := Vector2(0, 7)
const LOGO_OUTLINE := 16
const LOGO_HEAD := "コンビニ"
const LOGO_TAIL := "ウォーズ"
const TAGLINE := "CPUの店長と、1日の売上で勝負!"
const TAGLINE_Y := 184.0
const TAGLINE_HEIGHT := 38.0
const TAGLINE_PAD := 22.0
const RULES_RECT := Rect2(420, 250, 440, 172)
const RULE_LINE := 34.0
const RULE_FONT := 17
const RULES: Array[String] = [
	"向かい合った2軒のコンビニで、同じ客を取り合う。",
	"次に来る客層を読んで、先に発注する。",
	"棚に並べて、値段で相手を出し抜く。",
	"1試合5分。売上の多いほうが勝ち。",
]
const BUTTON_RECT := Rect2(490, 452, 300, 80)
const GROUND_Y := 560.0
const CURB_HEIGHT := 40.0
const ROAD_LINE_Y := 650.0
const DASH := Vector2(60, 8)
const STORE_RECTS: Array[Rect2] = [Rect2(40, 250, 360, 310), Rect2(880, 250, 360, 310)]
const SIGN_HEIGHT := 64.0
const STRIPE := Vector2(4, 8)
const SIGN_TEXT := "24H"
const WALL := Color("#f4eee2")
const WINDOW_LIGHT := Color("#fff1c9")
const WINDOW_INSET := 22.0
const WINDOW_TOP := 96.0
const DOOR_WIDTH := 84.0
const DOOR_GAP := 14.0
const SHELF_ROWS := 3
const SHELF_LINE := 3.0
const ITEM_SIDE := 36.0
const ITEM_GAP := 6.0
const HANDLE := Vector2(4, 22)


func _ready() -> void:
	var start := PopButton.create("はじめる", UiPalette.MONEY, UiPalette.INK, UiPalette.FONT_HEAD + 6)
	add_child(start)
	start.position = BUTTON_RECT.position
	start.size = BUTTON_RECT.size
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	SkyBackdrop.paint(self, screen, UiPalette.MENU_SKY_TOP, UiPalette.MENU_SKY_BOTTOM, 0.0)
	_draw_ground()
	for i in STORE_RECTS.size():
		_draw_store(STORE_RECTS[i], i)
	_draw_logo()
	_draw_tagline()
	_draw_rules()


func _draw_ground() -> void:
	draw_rect(Rect2(0, GROUND_Y, size.x, CURB_HEIGHT), UiPalette.SIDEWALK)
	var road_top := GROUND_Y + CURB_HEIGHT
	draw_rect(Rect2(0, road_top, size.x, size.y - road_top), UiPalette.STREET)
	for y in [GROUND_Y, road_top]:
		draw_line(Vector2(0, y), Vector2(size.x, y), UiPalette.INK, UiPalette.OUTLINE)
	var x := DASH.x * 0.5
	while x < size.x:
		draw_rect(Rect2(x, ROAD_LINE_Y - DASH.y * 0.5, DASH.x, DASH.y), UiPalette.STREET_LINE)
		x += DASH.x * 2.0


## 店の建物:店の色の看板と帯・明かりのついた窓と棚の商品・通りの中央を向いた入口
func _draw_store(rect: Rect2, index: int) -> void:
	UiDraw.card(self, rect, WALL)
	var color := UiPalette.STORE_COLORS[index]
	var border := float(UiPalette.OUTLINE)
	var sign_rect := Rect2(
		rect.position + Vector2(border, border), Vector2(rect.size.x - border * 2.0, SIGN_HEIGHT)
	)
	draw_rect(sign_rect, color)
	var y := sign_rect.end.y
	draw_rect(Rect2(sign_rect.position.x, y, sign_rect.size.x, STRIPE.x), UiPalette.INK_ON_DARK)
	draw_rect(
		Rect2(sign_rect.position.x, y + STRIPE.x, sign_rect.size.x, STRIPE.y),
		UiPalette.STORE_ACCENTS[index]
	)
	draw_rect(
		Rect2(sign_rect.position.x, y + STRIPE.x + STRIPE.y, sign_rect.size.x, STRIPE.x),
		UiPalette.INK_ON_DARK
	)
	UiDraw.panel(self, rect, Color.TRANSPARENT, UiPalette.INK, UiPalette.OUTLINE)
	UiDraw.text_centered(
		self, sign_rect, SIGN_TEXT, UiPalette.FONT_HUGE, UiPalette.INK_ON_DARK, UiPalette.INK
	)
	var body := Rect2(
		rect.position.x + WINDOW_INSET,
		rect.position.y + WINDOW_TOP,
		rect.size.x - WINDOW_INSET * 2.0,
		rect.size.y - WINDOW_TOP
	)
	var door_on_right := index == 0
	var door_x := body.end.x - DOOR_WIDTH if door_on_right else body.position.x
	var door := Rect2(door_x, body.position.y, DOOR_WIDTH, body.size.y)
	var window_x := body.position.x if door_on_right else door.end.x + DOOR_GAP
	var window := Rect2(
		window_x, body.position.y, body.size.x - DOOR_WIDTH - DOOR_GAP, body.size.y - WINDOW_INSET
	)
	UiDraw.panel(
		self, window, WINDOW_LIGHT, UiPalette.INK, UiPalette.OUTLINE, UiPalette.RADIUS_SMALL
	)
	_draw_window_goods(window)
	UiDraw.panel(
		self, door, UiPalette.DOOR_GLASS, UiPalette.INK, UiPalette.OUTLINE, UiPalette.RADIUS_SMALL
	)
	var handle_x := (
		door.position.x + DOOR_GAP if door_on_right else door.end.x - DOOR_GAP - HANDLE.x
	)
	var handle := Rect2(handle_x, door.get_center().y - HANDLE.y * 0.5, HANDLE.x, HANDLE.y)
	draw_rect(handle, UiPalette.INK)


## 窓の中の棚と、並んだ商品の絵
func _draw_window_goods(window: Rect2) -> void:
	var products := GameDatabase.get_default().sorted_products()
	var row_height := window.size.y / SHELF_ROWS
	var count := 0
	for row in SHELF_ROWS:
		var shelf_y := window.position.y + row_height * (row + 1) - ITEM_GAP
		var x := window.position.x + ITEM_GAP * 2.0
		while x + ITEM_SIDE < window.end.x - ITEM_GAP:
			var center := Vector2(x + ITEM_SIDE * 0.5, shelf_y - ITEM_SIDE * 0.5)
			UiDraw.product_icon(self, center, ITEM_SIDE, products[count % products.size()])
			x += ITEM_SIDE + ITEM_GAP
			count += 1
		var line_from := Vector2(window.position.x + UiPalette.OUTLINE, shelf_y)
		var line_to := Vector2(window.end.x - UiPalette.OUTLINE, shelf_y)
		draw_line(line_from, line_to, UiPalette.INK, SHELF_LINE)


## 「コンビニ」は白、「ウォーズ」は黄色。太い縁取りと下へずらした影
func _draw_logo() -> void:
	var font := UiDraw.font()
	var font_size := UiPalette.FONT_TITLE
	var head_width := UiDraw.text_width(LOGO_HEAD, font_size)
	var total := head_width + UiDraw.text_width(LOGO_TAIL, font_size)
	var x := (size.x - total) * 0.5
	var parts := [
		[LOGO_HEAD, UiPalette.INK_ON_DARK, x], [LOGO_TAIL, UiPalette.MONEY, x + head_width]
	]
	for part: Array in parts:
		var pos := Vector2(part[2], LOGO_Y) + LOGO_SHADOW
		draw_string_outline(
			font,
			pos,
			part[0],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			LOGO_OUTLINE,
			UiPalette.INK
		)
	for part: Array in parts:
		var pos := Vector2(part[2], LOGO_Y)
		draw_string_outline(
			font,
			pos,
			part[0],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			LOGO_OUTLINE,
			UiPalette.INK
		)
		draw_string(font, pos, part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, part[1])


func _draw_tagline() -> void:
	var width := UiDraw.text_width(TAGLINE, UiPalette.FONT_LARGE) + TAGLINE_PAD * 2.0
	var rect := Rect2((size.x - width) * 0.5, TAGLINE_Y, width, TAGLINE_HEIGHT)
	UiDraw.panel(self, rect, UiPalette.INK, Color.TRANSPARENT, 0, int(TAGLINE_HEIGHT * 0.5))
	UiDraw.text_centered(self, rect, TAGLINE, UiPalette.FONT_LARGE, UiPalette.INK_ON_DARK)


func _draw_rules() -> void:
	UiDraw.card(self, RULES_RECT, UiPalette.PAPER)
	var top := RULES_RECT.position.y + (RULES_RECT.size.y - RULE_LINE * RULES.size()) * 0.5
	for i in RULES.size():
		var line := Rect2(RULES_RECT.position.x, top + RULE_LINE * i, RULES_RECT.size.x, RULE_LINE)
		UiDraw.text_centered(self, line, RULES[i], RULE_FONT, UiPalette.INK)
