class_name ForecastPanel
extends MatchPart
## 客層予報と突発イベントの予告(GameDesign.md 1.2節・9.2節・9.5節・11章)。天気予報の形で並べる:
## 時間帯ごとに空の小窓・名前・人数、客層アイコンの大きさで量、その下の丸で欲しいカテゴリ(大きいほど強い)。
## 突発イベントは下端に固定し、予告中は黄色と紺の縞の枠で点滅させる。

const PAD := 8.0
const TAB_POS := Vector2(8, 8)
const BLOCK_TOP := 42.0
const BLOCK_HEIGHT := 98.0
const BLOCK_GAP := 4.0
const SKY_ICON_SIZE := 34.0
const TITLE_X := 50.0
const TITLE_Y := 25.0
const LABEL_HEIGHT := 20.0
const ICON_Y := 54.0
const MIN_ICON_RADIUS := 10.0
const MAX_ICON_RADIUS := 18.0
const NAME_Y := 83.0
const WANT_Y := 91.0
const WANT_RADIUS := 5.5
const WANT_GAP := 2.0
const DIM_INK := Color(0.36, 0.4, 0.51, 0.75)
const BLOCK_LABELS: Array[String] = ["いま", "次", "その次"]

const EVENT_HEIGHT := 104.0
const HAZARD_WIDTH := 7.0
const HAZARD_STRIPE := 9.0
const EVENT_ICON_RADIUS := 17.0
const EVENT_TITLE_Y := 26.0
const EVENT_ROW_Y := 54.0
const EVENT_ICON_Y := 56.0
const WARNING_Y := 18.0
const CHIP_Y := 66.0
const CHIP_HEIGHT := 20.0
const CHIP_PAD := 6.0
const WARNING_SIZE := 22.0
const EVENT_FILL := Color("#fff4cc")
## 予告中の縞の点滅の最も薄いとき
const STRIPE_MIN_ALPHA := 0.35
const COUNT_SEPARATOR := "  :  "


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.card(self, Rect2(Vector2.ZERO, size), UiPalette.PAPER)
	UiDraw.tab(self, TAB_POS, "客層予報")
	var bands: Array[TimeBandData] = []
	var first_label := 1
	if not match_state.is_preparing():
		bands.append(match_state.current_band())
		first_label = 0
	bands.append_array(match_state.forecast_bands(store_index))
	var y := BLOCK_TOP
	for i in bands.size():
		var label := BLOCK_LABELS[mini(i + first_label, BLOCK_LABELS.size() - 1)]
		var block := Rect2(PAD, y, size.x - PAD * 2.0, BLOCK_HEIGHT)
		_draw_band(block, label, bands[i], label == BLOCK_LABELS[0])
		y += BLOCK_HEIGHT + BLOCK_GAP
	var event_rect := Rect2(PAD, size.y - PAD - EVENT_HEIGHT, size.x - PAD * 2.0, EVENT_HEIGHT)
	_draw_event(event_rect)


func _draw_band(rect: Rect2, label: String, band: TimeBandData, current: bool) -> void:
	var radius := UiPalette.RADIUS_SMALL
	if current:
		UiDraw.panel(
			self, rect, UiPalette.INK_ON_DARK, UiPalette.INK, UiPalette.OUTLINE_THIN, radius
		)
	else:
		UiDraw.panel(self, rect, UiPalette.PAPER_DIM, Color.TRANSPARENT, 0, radius)
	var icon := Rect2(rect.position + Vector2(PAD, PAD), Vector2.ONE * SKY_ICON_SIZE)
	UiDraw.sky_icon(self, icon, band)
	var ink := UiPalette.INK if current else DIM_INK
	var title_x := rect.position.x + TITLE_X
	var label_width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + PAD * 1.5
	var label_rect := Rect2(title_x, rect.position.y + PAD, label_width, LABEL_HEIGHT)
	UiDraw.panel(self, label_rect, ink, Color.TRANSPARENT, 0, int(LABEL_HEIGHT * 0.5))
	UiDraw.text_centered(self, label_rect, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK)
	var name_pos := Vector2(label_rect.end.x + PAD * 0.75, rect.position.y + TITLE_Y)
	UiDraw.text(self, name_pos, band.display_name, UiPalette.FONT_LARGE, ink)
	var info := "%d〜%d時 %d人" % [band.clock_start, band.clock_end, band.customer_count]
	var info_pos := Vector2(rect.position.x, rect.position.y + TITLE_Y)
	UiDraw.text(
		self,
		info_pos,
		info,
		UiPalette.FONT_SMALL,
		ink,
		HORIZONTAL_ALIGNMENT_RIGHT,
		rect.size.x - PAD
	)
	var types: Array = band.mix.keys()
	types.sort_custom(func(a: StringName, b: StringName) -> bool: return band.mix[a] > band.mix[b])
	if types.is_empty():
		return
	var slot_width := (rect.size.x - PAD * 2.0) / types.size()
	var top := float(band.mix[types[0]])
	var alpha := 1.0 if current else DIM_INK.a
	for i in types.size():
		var customer := db().customer_type(types[i])
		var x := rect.position.x + PAD + slot_width * (i + 0.5)
		var share := float(band.mix[types[i]]) / top
		var radius_px := lerpf(MIN_ICON_RADIUS, MAX_ICON_RADIUS, share)
		UiDraw.customer_icon(self, Vector2(x, rect.position.y + ICON_Y), radius_px, customer, alpha)
		var name_rect_pos := Vector2(x - slot_width / 2.0, rect.position.y + NAME_Y)
		var name := customer.display_name
		UiDraw.text(
			self,
			name_rect_pos,
			name,
			UiPalette.FONT_TINY,
			ink,
			HORIZONTAL_ALIGNMENT_CENTER,
			slot_width
		)
		_draw_wants(Vector2(x, rect.position.y + WANT_Y), customer, alpha)


## 欲しいカテゴリを重みの大きい順に丸で並べる(重みが小さいほど小さく)
func _draw_wants(center: Vector2, customer: CustomerTypeData, alpha: float) -> void:
	var wants := _sorted_wants(customer)
	if wants.is_empty():
		return
	var top := float(customer.weight_of(wants[0]))
	var width := wants.size() * (WANT_RADIUS * 2.0 + WANT_GAP) - WANT_GAP
	var x := center.x - width / 2.0 + WANT_RADIUS
	var ink := UiPalette.INK
	ink.a = alpha
	for category_id in wants:
		var category := db().category(category_id)
		var radius := WANT_RADIUS * sqrt(customer.weight_of(category_id) / top)
		var fill := category.color
		fill.a = alpha
		draw_circle(Vector2(x, center.y), radius + 1.0, ink)
		draw_circle(Vector2(x, center.y), radius, fill)
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
	var radius := UiPalette.RADIUS_SMALL
	if active == null and announced == null:
		UiDraw.panel(self, rect, UiPalette.PAPER_DIM, Color.TRANSPARENT, 0, radius)
		var hint := "突発イベントの予告はここに出る"
		UiDraw.text_centered(self, rect, hint, UiPalette.FONT_SMALL, UiPalette.INK_SOFT)
		return
	var event := active if active != null else announced
	UiDraw.panel(self, rect, UiPalette.MONEY, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	var stripe := UiPalette.INK
	stripe.a = lerpf(STRIPE_MIN_ALPHA, 1.0, blink()) if active == null else 1.0
	UiDraw.stripes(self, rect.grow(-UiPalette.OUTLINE_THIN), stripe, HAZARD_STRIPE)
	var inner := rect.grow(-HAZARD_WIDTH)
	UiDraw.panel(self, inner, EVENT_FILL, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	var title := "%s 発生中!" % event.display_name
	if active == null:
		var seconds := int(ceil(match_state.seconds_until_event()))
		title = "%s あと%d秒" % [event.display_name, seconds]
	var warning := inner.position + Vector2(PAD + WARNING_SIZE * 0.5, WARNING_Y)
	UiDraw.warning_icon(self, warning, WARNING_SIZE)
	var title_x := warning.x + WARNING_SIZE * 0.5 + PAD * 0.75
	var title_width := inner.end.x - PAD - title_x
	var title_size := UiDraw.fit_size(title, UiPalette.FONT_LARGE, title_width)
	UiDraw.text(
		self, Vector2(title_x, inner.position.y + EVENT_TITLE_Y), title, title_size, UiPalette.BAD
	)
	var customer := db().customer_type(event.customer_type_id)
	var icon := Vector2(inner.position.x + PAD + EVENT_ICON_RADIUS, inner.position.y + EVENT_ICON_Y)
	UiDraw.customer_icon(self, icon, EVENT_ICON_RADIUS, customer)
	var info_x := icon.x + EVENT_ICON_RADIUS + PAD
	var info_pos := Vector2(info_x, inner.position.y + EVENT_ROW_Y)
	if active != null:
		_draw_event_counts(info_pos)
	else:
		var balance := match_state.balance
		var info := (
			"%s ×%d人(買う数%d倍)"
			% [customer.display_name, balance.event_customer_count, balance.event_buy_multiplier]
		)
		var info_size := UiDraw.fit_size(info, UiPalette.FONT_SMALL, inner.end.x - PAD - info_x)
		UiDraw.text(self, info_pos, info, info_size, UiPalette.INK)
	var chip_x := info_x
	var chip_y := inner.position.y + CHIP_Y
	for category_id in _sorted_wants(customer):
		var category := db().category(category_id)
		var label := category.display_name
		var width := UiDraw.text_width(label, UiPalette.FONT_TINY) + CHIP_PAD * 2.0
		var chip := Rect2(chip_x, chip_y, width, CHIP_HEIGHT)
		UiDraw.panel(
			self,
			chip,
			category.color,
			UiPalette.INK,
			UiPalette.OUTLINE_THIN,
			int(CHIP_HEIGHT * 0.5)
		)
		UiDraw.text_centered(
			self, chip, label, UiPalette.FONT_TINY, UiPalette.INK_ON_DARK, UiPalette.INK
		)
		chip_x += width + CHIP_PAD * 0.5


## 発生中のイベントの客が両店へ入った数(店の色で並べる)
func _draw_event_counts(pos: Vector2) -> void:
	var counts := match_state.events.active_counts
	var x := pos.x
	for i in counts.size():
		if i > 0:
			UiDraw.text(
				self, Vector2(x, pos.y), COUNT_SEPARATOR, UiPalette.FONT_BODY, UiPalette.INK
			)
			x += UiDraw.text_width(COUNT_SEPARATOR, UiPalette.FONT_BODY)
		var label := "%s %d人" % [UiPalette.STORE_NAMES[i], counts[i]]
		UiDraw.text(self, Vector2(x, pos.y), label, UiPalette.FONT_BODY, UiPalette.STORE_COLORS[i])
		x += UiDraw.text_width(label, UiPalette.FONT_BODY)
