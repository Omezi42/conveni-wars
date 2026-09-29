class_name ForecastPanel
extends MatchPart
## 客層予報(GameDesign.md 1.2節・9.2節)。いまの時間帯と次(データ分析はその次も)を横に並べる。
## 客層アイコンの大きさで量を、下の丸で欲しいカテゴリ(大きいほど強い)を見せる。

const PAD := 8.0
const BLOCK_GAP := 6.0
const TITLE_BASELINE := 17.0
const ICON_Y := 42.0
const MIN_ICON_RADIUS := 10.0
const MAX_ICON_RADIUS := 17.0
const NAME_Y := 72.0
const WANT_Y := 84.0
const WANT_RADIUS := 6.0
const WANT_GAP := 2.0
const WANT_TEXT_RATIO := 1.3
const BLOCK_LABELS: Array[String] = ["いま", "次", "その次"]
const CURRENT_EDGE := Color(1, 1, 1, 0.35)


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.glass_panel(self, Rect2(Vector2.ZERO, size))
	var bands: Array[TimeBandData] = []
	var first_label := 1
	if not match_state.is_preparing():
		bands.append(match_state.current_band())
		first_label = 0
	bands.append_array(match_state.forecast_bands(store_index))
	if bands.is_empty():
		return
	var width := (size.x - PAD * 2.0 - BLOCK_GAP * (bands.size() - 1)) / bands.size()
	for i in bands.size():
		var rect := Rect2(PAD + i * (width + BLOCK_GAP), PAD / 2.0, width, size.y - PAD)
		var label := BLOCK_LABELS[mini(i + first_label, BLOCK_LABELS.size() - 1)]
		_draw_band(rect, label, bands[i], label == BLOCK_LABELS[0])


func _draw_band(rect: Rect2, label: String, band: TimeBandData, current: bool) -> void:
	UiDraw.panel(
		self, rect, UiPalette.PANEL_INNER, CURRENT_EDGE if current else Color.TRANSPARENT, 1
	)
	var hours := "%d:00〜%d:00" % [band.clock_start, band.clock_end]
	var title := "%s %s %s %d人" % [label, band.display_name, hours, band.customer_count]
	var title_pos := rect.position + Vector2(PAD, TITLE_BASELINE)
	var title_color := UiPalette.ACCENT if current else UiPalette.INK_SOFT
	UiDraw.text(self, title_pos, title, UiPalette.FONT_SMALL, title_color)
	var types: Array = band.mix.keys()
	types.sort_custom(func(a: StringName, b: StringName) -> bool: return band.mix[a] > band.mix[b])
	if types.is_empty():
		return
	var slot_width := (rect.size.x - PAD * 2.0) / types.size()
	var top := float(band.mix[types[0]])
	for i in types.size():
		var customer := db().customer_type(types[i])
		var x := rect.position.x + PAD + slot_width * (i + 0.5)
		var radius := lerpf(MIN_ICON_RADIUS, MAX_ICON_RADIUS, float(band.mix[types[i]]) / top)
		UiDraw.customer_icon(self, Vector2(x, rect.position.y + ICON_Y), radius, customer)
		var name_pos := Vector2(x - slot_width / 2.0, rect.position.y + NAME_Y)
		var center := HORIZONTAL_ALIGNMENT_CENTER
		var name := customer.display_name
		UiDraw.text(self, name_pos, name, UiPalette.FONT_SMALL, UiPalette.INK, center, slot_width)
		draw_wants(self, Vector2(x, rect.position.y + WANT_Y), customer, WANT_RADIUS)


## 欲しいカテゴリを重みの大きい順に丸で並べる(重みが小さいほど小さく)
static func draw_wants(
	item: CanvasItem, center: Vector2, customer: CustomerTypeData, max_radius: float
) -> void:
	var wants := customer.sorted_wants()
	if wants.is_empty():
		return
	var db := GameDatabase.get_default()
	var top := float(customer.weight_of(wants[0]))
	var width := wants.size() * (max_radius * 2.0 + WANT_GAP) - WANT_GAP
	var x := center.x - width / 2.0 + max_radius
	for category_id in wants:
		var category := db.category(category_id)
		var radius := max_radius * sqrt(customer.weight_of(category_id) / top)
		item.draw_circle(Vector2(x, center.y), radius, category.color)
		var cell := Rect2(
			Vector2(x, center.y) - Vector2.ONE * max_radius, Vector2.ONE * max_radius * 2.0
		)
		var letter := category.display_name.left(1)
		var font_size := int(radius * WANT_TEXT_RATIO)
		UiDraw.text_centered(item, cell, letter, font_size, UiPalette.INK_ON_DARK)
		x += max_radius * 2.0 + WANT_GAP
