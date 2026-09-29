class_name UiDraw
extends RefCounted
## コードで描く部品(パネル・文字・商品と客層の仮アイコン・ボタン)と、数の書式。

const FONT_PATH := "res://assets/fonts/ZenKakuGothicNew-Bold.ttf"
const HOVER_LIGHTEN := 0.12
const PRESS_DARKEN := 0.15
const DISABLED_ALPHA := 0.4
const ICON_TEXT_RATIO := 0.9
const SHADOW := Color(0, 0, 0, 0.12)
const SHADOW_SIZE := 3

static var _font: Font
static var _boxes: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH)
	return _font


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
	panel(item, rect, fill, UiPalette.PANEL_EDGE, 1, radius)


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


static func text_width(value: String, size: int) -> float:
	return font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 商品の絵。イラストが無いうちはカテゴリの色の丸に短い名前の1文字目
static func product_icon(
	item: CanvasItem, center: Vector2, radius: float, product: ProductData
) -> void:
	if product.icon != null:
		var side := radius * 2.0
		item.draw_texture_rect(
			product.icon, Rect2(center - Vector2(radius, radius), Vector2(side, side)), false
		)
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
		var side := radius * 2.0
		var rect := Rect2(center - Vector2(radius, radius), Vector2(side, side))
		item.draw_texture_rect(customer.icon, rect, false, Color(1, 1, 1, alpha))
		return
	item.draw_circle(center, radius, color)
	var ink := UiPalette.INK_ON_DARK
	ink.a = alpha
	_initial(item, center, radius, customer.display_name.left(1), ink)


static func make_button(label: String, fill: Color, size := UiPalette.FONT_LARGE) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UiPalette.INK_ON_DARK)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, DISABLED_ALPHA * 2.0))
	button.add_theme_stylebox_override("normal", box(fill))
	button.add_theme_stylebox_override("hover", box(fill.lightened(HOVER_LIGHTEN)))
	button.add_theme_stylebox_override("pressed", box(fill.darkened(PRESS_DARKEN)))
	button.add_theme_stylebox_override("focus", box(fill))
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
