class_name UiDraw
extends RefCounted
## コードで描く部品(パネル・文字・商品と客層のアイコン・ボタン)と、数の書式。

const FONT_PATH := "res://assets/fonts/ZenKakuGothicNew-Bold.ttf"
const BACKGROUND_PATH := "res://assets/backgrounds/street.svg"
const PANEL_BORDER := 2
const TITLE_MARK_SIZE := Vector2(4, 14)
const TITLE_MARK_GAP := 6.0
const BUTTON_BORDER := 2
const BUTTON_EDGE_DARKEN := 0.25
const PORTRAIT_LIGHTEN := 0.55
const PORTRAIT_RING := 3.0
const HOVER_LIGHTEN := 0.12
const PRESS_DARKEN := 0.15
const DISABLED_ALPHA := 0.4
const ICON_TEXT_RATIO := 0.9
const SHADOW := Color(0, 0, 0, 0.12)
const SHADOW_SIZE := 3

static var _font: Font
static var _background: Texture2D
static var _boxes: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH)
	return _font


static func background() -> Texture2D:
	if _background == null:
		_background = load(BACKGROUND_PATH)
	return _background


## 背景の絵を全面に描く。scrim を重ねると絵が沈んで文字が読みやすくなる
static func backdrop(item: CanvasItem, rect: Rect2, scrim := Color.TRANSPARENT) -> void:
	item.draw_texture_rect(background(), rect, false)
	if scrim.a > 0.0:
		item.draw_rect(rect, scrim)


static func box(fill: Color, edge := Color.TRANSPARENT, border := 0, radius := -1) -> StyleBoxFlat:
	var corner := UiPalette.RADIUS if radius < 0 else radius
	var key := "%s|%s|%d|%d" % [fill.to_html(), edge.to_html(), border, corner]
	var cached: StyleBoxFlat = _boxes.get(key)
	if cached == null:
		cached = StyleBoxFlat.new()
		cached.bg_color = fill
		cached.set_corner_radius_all(corner)
		cached.anti_aliasing = true
		if border > 0:
			cached.border_color = edge
			cached.set_border_width_all(border)
		_boxes[key] = cached
	return cached


static func panel(
	item: CanvasItem, rect: Rect2, fill: Color, edge := Color.TRANSPARENT, border := 0, radius := -1
) -> void:
	box(fill, edge, border, radius).draw(item.get_canvas_item(), rect)


static func shadowed_panel(item: CanvasItem, rect: Rect2, fill: Color, radius := -1) -> void:
	panel(
		item, Rect2(rect.position + Vector2(0, SHADOW_SIZE), rect.size), SHADOW, SHADOW, 0, radius
	)
	panel(item, rect, fill, UiPalette.CARD_EDGE, 1, radius)


## 濃い紺の半透明に明るい縁取りのパネル(GameDesign.md 9.6節)
static func glass_panel(item: CanvasItem, rect: Rect2, edge := UiPalette.PANEL_EDGE) -> void:
	panel(item, rect, UiPalette.PANEL, edge, PANEL_BORDER, UiPalette.PANEL_RADIUS)


## パネルの見出し(左に色の印)。pos は印の左端・文字のベースライン
static func panel_title(
	item: CanvasItem, pos: Vector2, value: String, mark := UiPalette.PANEL_EDGE
) -> void:
	var size := UiPalette.FONT_BODY
	var mark_rect := Rect2(pos + Vector2(0, -TITLE_MARK_SIZE.y + 2.0), TITLE_MARK_SIZE)
	panel(item, mark_rect, mark, Color.TRANSPARENT, 0, 2)
	text(item, pos + Vector2(TITLE_MARK_SIZE.x + TITLE_MARK_GAP, 0), value, size, UiPalette.INK)


## pos は左端・ベースライン
static func text(
	item: CanvasItem,
	pos: Vector2,
	value: String,
	size: int,
	color: Color,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	width := -1.0
) -> void:
	item.draw_string(font(), pos, value, align, width, size, color)


## rect の中央(縦も中央)に1行で描く
static func text_centered(
	item: CanvasItem, rect: Rect2, value: String, size: int, color: Color
) -> void:
	var f := font()
	var baseline := rect.position.y + (rect.size.y + f.get_ascent(size) - f.get_descent(size)) / 2.0
	var pos := Vector2(rect.position.x, baseline)
	item.draw_string(f, pos, value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


static func text_outlined(
	item: CanvasItem,
	pos: Vector2,
	value: String,
	size: int,
	color: Color,
	outline: int,
	outline_color := Color.WHITE
) -> void:
	var f := font()
	var left := HORIZONTAL_ALIGNMENT_LEFT
	item.draw_string_outline(f, pos, value, left, -1, size, outline, outline_color)
	item.draw_string(f, pos, value, left, -1, size, color)


static func text_width(value: String, size: int) -> float:
	return font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 商品の絵。イラストが無いうちはカテゴリの色の丸に短い名前の1文字目
static func product_icon(
	item: CanvasItem, center: Vector2, radius: float, product: ProductData
) -> void:
	if product.icon != null:
		texture_at(item, product.icon, center, radius)
		return
	var category := GameDatabase.get_default().category(product.category_id)
	item.draw_circle(center, radius, category.color)
	_initial(item, center, radius, product.short_name.left(1))


static func customer_icon(
	item: CanvasItem, center: Vector2, radius: float, customer: CustomerTypeData, alpha := 1.0
) -> void:
	var color := customer.color
	color.a = alpha
	if customer.icon != null:
		texture_at(item, customer.icon, center, radius, alpha)
		return
	item.draw_circle(center, radius, color)
	var ink := UiPalette.INK_ON_DARK
	ink.a = alpha
	_initial(item, center, radius, customer.display_name.left(1), ink)


## テクスチャを center を中心に一辺 radius×2 の正方形で描く
static func texture_at(
	item: CanvasItem, texture: Texture2D, center: Vector2, radius: float, alpha := 1.0
) -> void:
	var side := radius * 2.0
	var rect := Rect2(center - Vector2(radius, radius), Vector2(side, side))
	item.draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))


## 店長の顔。店長の色の丸の上に絵を載せる(絵が無ければ名前の1文字目)
static func portrait(
	item: CanvasItem, center: Vector2, radius: float, manager: ManagerData
) -> void:
	item.draw_circle(center, radius + PORTRAIT_RING, manager.color)
	item.draw_circle(center, radius, manager.color.lightened(PORTRAIT_LIGHTEN))
	if manager.portrait != null:
		texture_at(item, manager.portrait, center, radius * ICON_TEXT_RATIO)
		return
	_initial(item, center, radius, manager.display_name.left(1), manager.color)


static func make_button(
	label: String, fill: Color, size := UiPalette.FONT_LARGE, ink := UiPalette.INK_ON_DARK
) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	var faded_ink := ink
	faded_ink.a = DISABLED_ALPHA * 2.0
	button.add_theme_color_override("font_disabled_color", faded_ink)
	var edge := fill.darkened(BUTTON_EDGE_DARKEN)
	button.add_theme_stylebox_override("normal", box(fill, edge, BUTTON_BORDER))
	button.add_theme_stylebox_override(
		"hover", box(fill.lightened(HOVER_LIGHTEN), edge, BUTTON_BORDER)
	)
	button.add_theme_stylebox_override(
		"pressed", box(fill.darkened(PRESS_DARKEN), edge, BUTTON_BORDER)
	)
	button.add_theme_stylebox_override("focus", box(fill, edge, BUTTON_BORDER))
	var faded := fill
	faded.a = DISABLED_ALPHA
	button.add_theme_stylebox_override("disabled", box(faded))
	return button


static func yen(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + "¥" + digits + grouped


@warning_ignore("integer_division")
static func clock(minutes: int) -> String:
	return "%d:%02d" % [minutes / 60, minutes % 60]


## 残り時間の「分:秒」
static func mm_ss(seconds: float) -> String:
	var whole := int(ceil(seconds))
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]


static func _initial(
	item: CanvasItem, center: Vector2, radius: float, letter: String, ink := UiPalette.INK_ON_DARK
) -> void:
	var size := int(radius * ICON_TEXT_RATIO)
	var rect := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	text_centered(item, rect, letter, size, ink)
