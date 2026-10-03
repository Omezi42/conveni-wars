class_name UiDraw
extends RefCounted
## コードで描く部品(輪郭線と影のあるパネル・縁取りした文字・グラデーション・商品と客層の仮アイコン・
## 空の小窓・硬貨・吹き出し)と、数の書式。見た目の方針は GameDesign.md 9.5節。

const FONT_PATH := "res://assets/fonts/ZenKakuGothicNew-Bold.ttf"
## 縁取りした文字の縁の太さ(文字の大きさに対する割合と下限)
const OUTLINE_RATIO := 0.22
const OUTLINE_MIN := 4
## 商品アイコンの角の丸み・頭文字の大きさ(辺に対する割合)
const ICON_RADIUS_RATIO := 0.24
const ICON_LETTER_RATIO := 0.52
const ICON_SHINE := Color(1, 1, 1, 0.3)
const ICON_SHINE_HEIGHT := 0.34
const ICON_SHINE_INSET := 0.14
const ICON_BORDER_MIN := 1
const ICON_BORDER_RATIO := 0.05
## 絵の足もとの影の幅・高さ(辺に対する割合)と、絵の下端から影を上げる量
const ICON_SHADOW_WIDTH := 0.7
const ICON_SHADOW_HEIGHT := 0.16
const ICON_SHADOW_RISE := 0.06
const ELLIPSE_STEPS := 20
## 客層アイコンに頭文字を入れる最小の半径
const LETTER_MIN_RADIUS := 9.0
const CUSTOMER_LETTER_RATIO := 1.05
const CUSTOMER_BORDER_RATIO := 0.16
const CUSTOMER_BORDER_MIN := 1.5
## 角丸の弧の分割数
const ARC_STEPS := 6
## 空の小窓の角の丸み・太陽と月の大きさ(高さに対する割合)
const SKY_ICON_RADIUS := 0.28
const SKY_ICON_BODY := 0.24
const SUN_RAYS := 8
const SUN_RAY_LENGTH := 0.45
const SUN_RAY_WIDTH := 0.22
const SUN_RAY_MIN_WIDTH := 1.5
## 月の欠けを作る円のずれと大きさ(半径に対する割合)
const MOON_CUT := Vector2(0.45, -0.3)
const MOON_CUT_RADIUS := 0.85
const COIN_LETTER_RATIO := 1.2
## 注意の印の高さ(幅に対する割合)と「!」の大きさ・下げる量(高さに対する割合)
const WARNING_HEIGHT_RATIO := 0.88
const WARNING_MARK_RATIO := 0.62
const WARNING_MARK_DROP := 0.12
const BUBBLE_TAIL := Vector2(8, 7)
## 光の筋の根元の半径(外側の半径に対する割合)
const BURST_INNER := 0.2
const TAB_HEIGHT := 26.0
const TAB_PAD := 10.0
## 丸い札の左右の余白(高さに対する割合)
const PILL_PAD_RATIO := 0.7
const HALF := 0.5
const STAR_POINTS := 5
const STAR_INNER := 0.45
## 緑の丸い札のチェック(フォントに ✓ が無いため線で描く)。折れ線と線の太さは半径に対する割合
const CHECK_POINTS: Array[Vector2] = [Vector2(-0.5, 0.0), Vector2(-0.12, 0.38), Vector2(0.5, -0.35)]
const CHECK_WIDTH_RATIO := 0.25

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
		cached.corner_detail = ARC_STEPS
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


## 輪郭線と、下へずらした影のあるパネル(ステッカー風)
static func card(
	item: CanvasItem, rect: Rect2, fill: Color, radius := -1, border := UiPalette.OUTLINE
) -> void:
	var shadow := Rect2(rect.position + Vector2(0, UiPalette.SHADOW_DROP), rect.size)
	panel(item, shadow, UiPalette.SHADOW, Color.TRANSPARENT, 0, radius)
	panel(item, rect, fill, UiPalette.INK, border, radius)


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


## 縁取りした文字(色の付いた地や空の上に置く数字・見出し)
static func text_outlined(
	item: CanvasItem,
	pos: Vector2,
	value: String,
	size: int,
	color: Color,
	edge := UiPalette.INK,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	width := -1.0
) -> void:
	var outline := maxi(OUTLINE_MIN, int(size * OUTLINE_RATIO))
	item.draw_string_outline(font(), pos, value, align, width, size, outline, edge)
	item.draw_string(font(), pos, value, align, width, size, color)


## rect の中央(縦も中央)に1行で描く。幅に収まらなければ文字を小さくする
static func text_centered(
	item: CanvasItem, rect: Rect2, value: String, size: int, color: Color, edge := Color.TRANSPARENT
) -> void:
	var fitted := fit_size(value, size, rect.size.x)
	var pos := Vector2(rect.position.x, baseline_in(rect, fitted))
	if edge.a > 0.0:
		text_outlined(
			item, pos, value, fitted, color, edge, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x
		)
	else:
		text(item, pos, value, fitted, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## rect の縦の中央に文字を置くときのベースライン
static func baseline_in(rect: Rect2, size: int) -> float:
	var f := font()
	return rect.position.y + (rect.size.y + f.get_ascent(size) - f.get_descent(size)) * HALF


static func text_width(value: String, size: int) -> float:
	return font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 幅に収まる文字の大きさ(size から小さくしていく。FONT_SMALL より小さくはしない)
static func fit_size(value: String, size: int, width: float) -> int:
	var fitted := size
	while fitted > UiPalette.FONT_SMALL and text_width(value, fitted) > width:
		fitted -= 1
	return fitted


## パネルの見出しの札(紺の地に白い文字)。pos は左上。描いた札の矩形を返す
static func tab(item: CanvasItem, pos: Vector2, title: String, fill := UiPalette.INK) -> Rect2:
	var rect := Rect2(
		pos, Vector2(text_width(title, UiPalette.FONT_BODY) + TAB_PAD * 2.0, TAB_HEIGHT)
	)
	panel(item, rect, fill, Color.TRANSPARENT, 0, UiPalette.RADIUS_SMALL)
	text_centered(item, rect, title, UiPalette.FONT_BODY, UiPalette.INK_ON_DARK)
	return rect


## 輪郭線のある丸い札(在庫数・倍率などの小さな数字)。center を中心に、文字に合わせた幅で描く
static func pill(
	item: CanvasItem,
	center: Vector2,
	label: String,
	size: int,
	fill: Color,
	ink: Color,
	height: float
) -> Rect2:
	var width := maxf(height, text_width(label, size) + height * PILL_PAD_RATIO)
	var rect := Rect2(center - Vector2(width, height) * HALF, Vector2(width, height))
	panel(item, rect, fill, UiPalette.INK, UiPalette.OUTLINE_THIN, int(height * HALF))
	text_centered(item, rect, label, size, ink)
	return rect


## 上から下へのグラデーションの矩形
static func gradient_rect(item: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	item.draw_polygon(corners(rect), PackedColorArray([top, top, bottom, bottom]))


## 上から下へのグラデーションの角丸矩形(輪郭線つき)
static func gradient_round_rect(
	item: CanvasItem, rect: Rect2, top: Color, bottom: Color, radius: float, border := 0.0
) -> void:
	var points := round_rect_points(rect, radius)
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, (point.y - rect.position.y) / rect.size.y))
	item.draw_polygon(points, colors)
	if border > 0.0:
		var ring := points.duplicate()
		ring.append(points[0])
		item.draw_polyline(ring, UiPalette.INK, border, true)


## 矩形の4隅(左上から時計回り)
static func corners(rect: Rect2) -> PackedVector2Array:
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return PackedVector2Array([rect.position, top_right, rect.end, bottom_left])


## 角丸矩形の外周の点(時計回り)。半径は辺の半分より少し小さく抑え、重なった頂点を作らない(Pitfalls.md)
static func round_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * HALF - 0.5)
	var centers := [
		rect.position + Vector2(r, r),
		Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r),
		Vector2(rect.position.x + r, rect.end.y - r),
	]
	var points := PackedVector2Array()
	for corner in centers.size():
		var start := PI + corner * PI * HALF
		for step in ARC_STEPS + 1:
			var angle := start + PI * HALF * step / ARC_STEPS
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * r)
	return points


## 斜めの縞(突発イベントの予告の枠など)。rect の外へははみ出さない
static func stripes(item: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	stripes_in(item, corners(rect), color, width)


## 斜めの縞を、凸とは限らない多角形 area の中だけに描く
static func stripes_in(
	item: CanvasItem, area: PackedVector2Array, color: Color, width: float
) -> void:
	var bounds := Rect2(area[0], Vector2.ZERO)
	for point in area:
		bounds = bounds.expand(point)
	var x := bounds.position.x - bounds.size.y
	while x < bounds.end.x:
		var band := PackedVector2Array(
			[
				Vector2(x, bounds.end.y),
				Vector2(x + width, bounds.end.y),
				Vector2(x + width + bounds.size.y, bounds.position.y),
				Vector2(x + bounds.size.y, bounds.position.y),
			]
		)
		for piece in Geometry2D.intersect_polygons(band, area):
			item.draw_colored_polygon(piece, color)
		x += width * 2.0


## 商品の絵(足もとに楕円の影を落とす)。イラストが無いときは、カテゴリの色の角丸の箱に短い名前の1文字目
static func product_icon(
	item: CanvasItem, center: Vector2, side: float, product: ProductData, alpha := 1.0
) -> void:
	var rect := Rect2(center - Vector2(side, side) * HALF, Vector2(side, side))
	if product.icon != null:
		ground_shadow(item, Vector2(center.x, rect.end.y - side * ICON_SHADOW_RISE), side, alpha)
		item.draw_texture_rect(product.icon, rect, false, Color(1, 1, 1, alpha))
		return
	var category := GameDatabase.get_default().category(product.category_id)
	var fill := category.color
	fill.a = alpha
	var ink := UiPalette.INK
	ink.a = alpha
	var border := maxi(ICON_BORDER_MIN, int(side * ICON_BORDER_RATIO))
	var radius := int(side * ICON_RADIUS_RATIO)
	panel(item, rect, fill, ink, border, radius)
	var inset := side * ICON_SHINE_INSET
	var shine_rect := Rect2(
		rect.position + Vector2(inset, inset * HALF),
		Vector2(side - inset * 2.0, side * ICON_SHINE_HEIGHT)
	)
	var shine := ICON_SHINE
	shine.a *= alpha
	panel(item, shine_rect, shine, Color.TRANSPARENT, 0, int(radius * HALF))
	var white := UiPalette.INK_ON_DARK
	white.a = alpha
	text_centered(item, rect, product.short_name.left(1), int(side * ICON_LETTER_RATIO), white, ink)


## カテゴリの絵(そのカテゴリの最初の商品の絵を使う)
static func category_icon(
	item: CanvasItem, center: Vector2, side: float, category_id: StringName, alpha := 1.0
) -> void:
	for product in GameDatabase.get_default().sorted_products():
		if product.category_id == category_id:
			product_icon(item, center, side, product, alpha)
			return


## 絵の足もとの楕円の影。bottom は影の中心、width は絵の幅
static func ground_shadow(item: CanvasItem, bottom: Vector2, width: float, alpha := 1.0) -> void:
	var radius := Vector2(width * ICON_SHADOW_WIDTH, width * ICON_SHADOW_HEIGHT) * HALF
	var points := PackedVector2Array()
	for step in ELLIPSE_STEPS:
		var angle := TAU * step / ELLIPSE_STEPS
		points.append(bottom + Vector2(cos(angle), sin(angle)) * radius)
	var shadow := UiPalette.SHADOW
	shadow.a *= alpha
	item.draw_colored_polygon(points, shadow)


## 客層の絵。イラストが無いうちは、客層の色の丸(大きければ頭文字)
static func customer_icon(
	item: CanvasItem, center: Vector2, radius: float, customer: CustomerTypeData, alpha := 1.0
) -> void:
	if customer.icon != null:
		var side := radius * 2.0
		var rect := Rect2(center - Vector2(radius, radius), Vector2(side, side))
		item.draw_texture_rect(customer.icon, rect, false, Color(1, 1, 1, alpha))
		return
	var ink := UiPalette.INK
	ink.a = alpha
	var border := maxf(CUSTOMER_BORDER_MIN, radius * CUSTOMER_BORDER_RATIO)
	item.draw_circle(center, radius + border, ink)
	var fill := customer.color
	fill.a = alpha
	item.draw_circle(center, radius, fill)
	if radius >= LETTER_MIN_RADIUS:
		var white := UiPalette.INK_ON_DARK
		white.a = alpha
		var cell := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		var letter := customer.display_name.left(1)
		text_centered(item, cell, letter, int(radius * CUSTOMER_LETTER_RATIO), white, ink)


## 時間帯の空の小窓(空の色と、昼は太陽・夜は月)
static func sky_icon(item: CanvasItem, rect: Rect2, band: TimeBandData) -> void:
	var radius := rect.size.y * SKY_ICON_RADIUS
	gradient_round_rect(item, rect, band.sky_top, band.sky_bottom, radius, UiPalette.OUTLINE_THIN)
	var center := rect.get_center()
	var body := rect.size.y * SKY_ICON_BODY
	if band.night:
		moon(item, center, body, band.sky_top)
	else:
		sun(item, center, body)


## 天気の絵。イラストが無いうちは、紙色の丸に名前の1文字目
static func weather_icon(
	item: CanvasItem, center: Vector2, side: float, weather: WeatherData
) -> void:
	var rect := Rect2(center - Vector2(side, side) * HALF, Vector2(side, side))
	if weather.icon != null:
		item.draw_texture_rect(weather.icon, rect, false)
		return
	item.draw_circle(center, side * HALF, UiPalette.INK)
	item.draw_circle(center, side * HALF - UiPalette.OUTLINE_THIN, UiPalette.PAPER)
	text_centered(
		item, rect, weather.display_name.left(1), int(side * ICON_LETTER_RATIO), UiPalette.INK
	)


static func sun(item: CanvasItem, center: Vector2, radius: float) -> void:
	for i in SUN_RAYS:
		var direction := Vector2.from_angle(TAU * i / SUN_RAYS)
		var from := center + direction * radius * (1.0 + SUN_RAY_LENGTH * HALF)
		var to := center + direction * radius * (1.0 + SUN_RAY_LENGTH * 1.5)
		var width := maxf(SUN_RAY_MIN_WIDTH, radius * SUN_RAY_WIDTH)
		item.draw_line(from, to, UiPalette.SUN, width, true)
	item.draw_circle(center, radius, UiPalette.SUN)


static func moon(item: CanvasItem, center: Vector2, radius: float, sky: Color) -> void:
	item.draw_circle(center, radius, UiPalette.MOON)
	item.draw_circle(center + MOON_CUT * radius, radius * MOON_CUT_RADIUS, sky)


## 注意の印(黄色い三角に「!」。フォントに ⚠ が無いため形で描く)
static func warning_icon(item: CanvasItem, center: Vector2, side: float) -> void:
	var height := side * WARNING_HEIGHT_RATIO
	var points := PackedVector2Array(
		[
			center + Vector2(0, -height * HALF),
			center + Vector2(side * HALF, height * HALF),
			center + Vector2(-side * HALF, height * HALF),
		]
	)
	item.draw_colored_polygon(points, UiPalette.MONEY)
	var ring := points.duplicate()
	ring.append(points[0])
	item.draw_polyline(ring, UiPalette.INK, UiPalette.OUTLINE_THIN, true)
	var cell := Rect2(center - Vector2(side, height) * HALF, Vector2(side, height))
	cell.position.y += height * WARNING_MARK_DROP
	text_centered(item, cell, "!", int(height * WARNING_MARK_RATIO), UiPalette.INK)


## 中心から放射状に交互に伸びる光の筋(大きな文字の後ろ)。angle で回す
static func burst(
	item: CanvasItem, center: Vector2, radius: float, rays: int, angle: float, color: Color
) -> void:
	var step := TAU / rays
	for i in range(0, rays, 2):
		var a := angle + i * step
		var ray := PackedVector2Array(
			[
				center + Vector2.from_angle(a) * radius * BURST_INNER,
				center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step) * radius,
				center + Vector2.from_angle(a + step) * radius * BURST_INNER,
			]
		)
		item.draw_colored_polygon(ray, color)


## 5つの角の星(内側の半径は外側に対する割合 STAR_INNER)。edge の輪郭線を付ける
static func star(
	item: CanvasItem, center: Vector2, radius: float, fill: Color, edge: Color
) -> void:
	var points := PackedVector2Array()
	for i in STAR_POINTS * 2:
		var length := radius if i % 2 == 0 else radius * STAR_INNER
		var angle := -PI / 2.0 + PI * i / STAR_POINTS
		points.append(center + Vector2.from_angle(angle) * length)
	item.draw_colored_polygon(points, fill)
	points.append(points[0])
	item.draw_polyline(points, edge, UiPalette.OUTLINE_THIN, true)


## 緑の丸い札に白いチェック(選ばれている・揃っている印)
static func check(item: CanvasItem, center: Vector2, radius: float) -> void:
	item.draw_circle(center, radius + UiPalette.OUTLINE_THIN, UiPalette.INK)
	item.draw_circle(center, radius, UiPalette.GOOD)
	var points := PackedVector2Array()
	for point in CHECK_POINTS:
		points.append(center + point * radius)
	item.draw_polyline(points, UiPalette.INK_ON_DARK, radius * CHECK_WIDTH_RATIO, true)


## ¥の硬貨
static func coin(item: CanvasItem, center: Vector2, radius: float) -> void:
	item.draw_circle(center, radius + UiPalette.OUTLINE_THIN, UiPalette.INK)
	item.draw_circle(center, radius, UiPalette.MONEY)
	var cell := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	text_centered(item, cell, "¥", int(radius * COIN_LETTER_RATIO), UiPalette.INK)


## 吹き出し(下にしっぽ)。tail_x はしっぽの横の位置
static func bubble(item: CanvasItem, rect: Rect2, fill: Color, edge: Color, tail_x: float) -> void:
	var tail := PackedVector2Array(
		[
			Vector2(tail_x - BUBBLE_TAIL.x * HALF, rect.end.y - 1.0),
			Vector2(tail_x + BUBBLE_TAIL.x * HALF, rect.end.y - 1.0),
			Vector2(tail_x, rect.end.y + BUBBLE_TAIL.y),
		]
	)
	item.draw_colored_polygon(tail, edge)
	panel(item, rect, fill, edge, UiPalette.OUTLINE_THIN, UiPalette.RADIUS_SMALL)


static func yen(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + "¥" + digits + grouped


## 残り時間の「分:秒」
static func mm_ss(seconds: float) -> String:
	var whole := int(ceil(seconds))
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]
