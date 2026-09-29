class_name ForecastPanel
extends MatchPart
## 客層予報と突発イベントの予告(GameDesign.md 1.2節・9.2節・11章)。
## 客層アイコンの大きさで量を、下の丸で欲しいカテゴリ(大きいほど強い)を見せる。

const PAD := 10.0
const HEADER_HEIGHT := 24.0
const BLOCK_HEIGHT := 104.0
const TITLE_BASELINE := 16.0
const ICON_Y := 46.0
const MIN_ICON_RADIUS := 9.0
const MAX_ICON_RADIUS := 19.0
const NAME_Y := 80.0
const WANT_Y := 94.0
const WANT_RADIUS := 7.0
const WANT_GAP := 2.0
const WANT_TEXT_RATIO := 1.3
const EVENT_TOP_GAP := 6.0
const EVENT_ICON_RADIUS := 20.0
const EVENT_LINE := 22.0
const EVENT_INFO_Y := 0.9
const EVENT_CHIP_Y := 1.3
const EVENT_CHIP_HEIGHT := 22.0
const CHIP_PAD := 6.0
const BLINK_EDGE := 3
const BLINK_MIN_ALPHA := 0.3
const TEXT_BASELINE := 0.72
const BLOCK_LABELS: Array[String] = ["いま", "次", "その次"]
const DIM := Color("#f3f5f7")
const EVENT_FILL := Color("#fff6e6")


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.shadowed_panel(self, Rect2(Vector2.ZERO, size), UiPalette.PANEL)
	var header := Vector2(PAD, HEADER_HEIGHT * TEXT_BASELINE)
	UiDraw.text(self, header, "客層予報", UiPalette.FONT_BODY, UiPalette.INK)
	var bands: Array[TimeBandData] = []
	var first_label := 1
	if not match_state.is_preparing():
		bands.append(match_state.current_band())
		first_label = 0
	bands.append_array(match_state.forecast_bands(store_index))
	var y := HEADER_HEIGHT
	for i in bands.size():
		var label := BLOCK_LABELS[mini(i + first_label, BLOCK_LABELS.size() - 1)]
		_draw_band(Rect2(0.0, y, size.x, BLOCK_HEIGHT), label, bands[i], label == BLOCK_LABELS[0])
		y += BLOCK_HEIGHT
	var event_top := y + EVENT_TOP_GAP
	_draw_event(Rect2(PAD, event_top, size.x - PAD * 2.0, size.y - event_top - PAD))


func _draw_band(rect: Rect2, label: String, band: TimeBandData, current: bool) -> void:
	if not current:
		UiDraw.panel(self, rect.grow_individual(-PAD / 2.0, 0, -PAD / 2.0, 0), DIM)
	var hours := "%d:00〜%d:00" % [band.clock_start, band.clock_end]
	var title := "%s %s %s %d人" % [label, band.display_name, hours, band.customer_count]
	var title_pos := rect.position + Vector2(PAD, TITLE_BASELINE)
	var title_color := UiPalette.INK if current else UiPalette.INK_SOFT
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
		_draw_wants(Vector2(x, rect.position.y + WANT_Y), customer)


## 欲しいカテゴリを重みの大きい順に丸で並べる(重みが小さいほど小さく)
func _draw_wants(center: Vector2, customer: CustomerTypeData) -> void:
	var wants := _sorted_wants(customer)
	if wants.is_empty():
		return
	var top := float(customer.weight_of(wants[0]))
	var width := wants.size() * (WANT_RADIUS * 2.0 + WANT_GAP) - WANT_GAP
	var x := center.x - width / 2.0 + WANT_RADIUS
	for category_id in wants:
		var category := db().category(category_id)
		var radius := WANT_RADIUS * sqrt(customer.weight_of(category_id) / top)
		draw_circle(Vector2(x, center.y), radius, category.color)
		var cell := Rect2(
			Vector2(x, center.y) - Vector2.ONE * WANT_RADIUS, Vector2.ONE * WANT_RADIUS * 2.0
		)
		var letter := category.display_name.left(1)
		var font_size := int(radius * WANT_TEXT_RATIO)
		UiDraw.text_centered(self, cell, letter, font_size, UiPalette.INK_ON_DARK)
		x += WANT_RADIUS * 2.0 + WANT_GAP


func _sorted_wants(customer: CustomerTypeData) -> Array[StringName]:
	var wants: Array[StringName] = []
	wants.assign(customer.wants.keys())
	wants.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return customer.weight_of(a) > customer.weight_of(b)
	)
	return wants


func _draw_event(rect: Rect2) -> void:
	var active := match_state.events.active_event
	var announced := match_state.announced_event(store_index)
	if active == null and announced == null:
		UiDraw.panel(self, rect, DIM)
		var hint := "突発イベントの予告はここに出る"
		UiDraw.text_centered(self, rect, hint, UiPalette.FONT_SMALL, UiPalette.INK_SOFT)
		return
	var event := active if active != null else announced
	var edge := UiPalette.WARN
	edge.a = lerpf(BLINK_MIN_ALPHA, 1.0, blink())
	UiDraw.panel(self, rect, EVENT_FILL, edge, BLINK_EDGE)
	var title: String
	if active != null:
		var counts := match_state.events.active_counts
		title = "%s 発生中! 自店%d 相手%d" % [event.display_name, counts[0], counts[1]]
	else:
		var seconds := int(ceil(match_state.seconds_until_event()))
		title = "⚠ %s あと%d秒" % [event.display_name, seconds]
	var y := rect.position.y + EVENT_LINE
	UiDraw.text(self, Vector2(rect.position.x + PAD, y), title, UiPalette.FONT_LARGE, UiPalette.BAD)
	var customer := db().customer_type(event.customer_type_id)
	var icon := Vector2(rect.position.x + PAD + EVENT_ICON_RADIUS, y + EVENT_LINE)
	UiDraw.customer_icon(self, icon, EVENT_ICON_RADIUS, customer)
	var balance := match_state.balance
	var info := (
		"%s ×%d(買う数%d倍)"
		% [customer.display_name, balance.event_customer_count, balance.event_buy_multiplier]
	)
	var info_x := icon.x + EVENT_ICON_RADIUS + PAD
	var info_pos := Vector2(info_x, y + EVENT_LINE * EVENT_INFO_Y)
	UiDraw.text(self, info_pos, info, UiPalette.FONT_SMALL, UiPalette.INK)
	var chip_x := info_x
	var chip_y := y + EVENT_LINE * EVENT_CHIP_Y
	for category_id in _sorted_wants(customer):
		var category := db().category(category_id)
		var label := category.display_name
		var width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + CHIP_PAD * 2.0
		var chip := Rect2(chip_x, chip_y, width, EVENT_CHIP_HEIGHT)
		UiDraw.panel(self, chip, category.color)
		UiDraw.text_centered(self, chip, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK)
		chip_x += width + CHIP_PAD
