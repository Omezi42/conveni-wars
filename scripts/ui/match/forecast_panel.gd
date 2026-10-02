class_name ForecastPanel
extends MatchPart
## 次の時間帯の予報と、突発イベントの予告(GameDesign.md 1.2節・9.2節・9.5節・11章)。
## 時間帯ごとに、左に空の小窓・名前・始まるまでの秒数、右に欲しがられるカテゴリを商品の絵と名前で
## 大きい順に並べる(客層→欲しい物を覚えなくても発注を決められるように)。
## 突発イベントの予告が出ている間は、枠全体を黄色と紺の縞の予告に切り替える。

const PAD := 10.0
const TAB_POS := Vector2(10, 10)
const BLOCKS_TOP := 44.0
const BLOCK_GAP := 6.0
const INFO_WIDTH := 130.0
const SKY_ICON_SIZE := 48.0
const SKY_ICON_SIZE_ROW := 40.0
## 並べるカテゴリの数(名前を読める幅を保つため)と、絵の大きさ(ブロックの高さに対する割合。欲しがられる度合いで変える)
const MAX_CATEGORIES := 3
const MIN_ICON := 0.36
const MAX_ICON := 0.56
const ICON_Y := 0.42
const CATEGORY_NAME_Y := 0.9
const RANK_FADE := 0.25

const HAZARD_WIDTH := 8.0
const HAZARD_STRIPE := 10.0
const EVENT_FILL := Color("#fff4cc")
const STRIPE_MIN_ALPHA := 0.35
const WARNING_SIZE := 28.0
const EVENT_TITLE_Y := 34.0
const EVENT_CUSTOMER_RADIUS := 26.0
const EVENT_ROW_Y := 88.0
const EVENT_ICON_SIDE := 52.0
const EVENT_ICONS_Y := 150.0
const EVENT_ICON_GAP := 64.0
const EVENT_NAME_GAP := 18.0


func _draw() -> void:
	if match_state == null:
		return
	var event := match_state.events.active_event
	if event == null:
		event = match_state.announced_event(store_index)
	if event != null:
		_draw_event(event)
		return
	UiDraw.card(self, Rect2(Vector2.ZERO, size), UiPalette.PAPER)
	UiDraw.tab(self, TAB_POS, "次に来る客")
	var bands := match_state.forecast_bands(store_index)
	if bands.is_empty():
		var rect := Rect2(0, BLOCKS_TOP, size.x, size.y - BLOCKS_TOP)
		UiDraw.text_centered(self, rect, "まもなく閉店", UiPalette.FONT_LARGE, UiPalette.INK_SOFT)
		return
	var height := (size.y - BLOCKS_TOP - PAD - BLOCK_GAP * (bands.size() - 1)) / bands.size()
	for i in bands.size():
		var y := BLOCKS_TOP + (height + BLOCK_GAP) * i
		_draw_band(Rect2(PAD, y, size.x - PAD * 2.0, height), bands[i])


func _draw_band(rect: Rect2, band: TimeBandData) -> void:
	UiDraw.panel(self, rect, UiPalette.PAPER_DIM, Color.TRANSPARENT, 0, UiPalette.RADIUS_SMALL)
	var info := Rect2(rect.position, Vector2(INFO_WIDTH, rect.size.y))
	var when := "あと%d秒" % int(ceil(_seconds_until(band)))
	var stacked := SKY_ICON_SIZE + PAD + UiPalette.FONT_HEAD + PAD + UiPalette.FONT_BODY
	if stacked + PAD * 2.0 <= info.size.y:
		_draw_band_info_stacked(info, band, when, stacked)
	else:
		_draw_band_info_row(info, band, when)
	var shelf := Rect2(
		rect.position.x + INFO_WIDTH, rect.position.y, rect.size.x - INFO_WIDTH, rect.size.y
	)
	_draw_demand(shelf, _demand(band))


## 段が高いとき:空の小窓・名前・秒数を縦に積む
func _draw_band_info_stacked(info: Rect2, band: TimeBandData, when: String, lines: float) -> void:
	var top := info.position.y + (info.size.y - lines) * 0.5
	var icon := Rect2(
		Vector2(info.get_center().x - SKY_ICON_SIZE * 0.5, top), Vector2.ONE * SKY_ICON_SIZE
	)
	UiDraw.sky_icon(self, icon, band)
	var name_base := icon.end.y + PAD + UiPalette.FONT_HEAD
	var when_base := name_base + PAD + UiPalette.FONT_BODY
	_draw_band_texts(Rect2(info.position.x, 0, info.size.x, 0), band, when, name_base, when_base)


## 段が低いとき(予報が2つ先まで出るとき):左に空の小窓、右に名前と秒数
func _draw_band_info_row(info: Rect2, band: TimeBandData, when: String) -> void:
	var side := SKY_ICON_SIZE_ROW
	var icon := Rect2(
		Vector2(info.position.x + PAD, info.get_center().y - side * 0.5), Vector2.ONE * side
	)
	UiDraw.sky_icon(self, icon, band)
	var left := icon.end.x + PAD
	var column := Rect2(left, 0, info.end.x - left, 0)
	var lines := UiPalette.FONT_HEAD + PAD + UiPalette.FONT_BODY
	var name_base := info.get_center().y - lines * 0.5 + UiPalette.FONT_HEAD
	var when_base := name_base + PAD + UiPalette.FONT_BODY
	_draw_band_texts(column, band, when, name_base, when_base)


## column は横の位置と幅だけを使う
func _draw_band_texts(
	column: Rect2, band: TimeBandData, when: String, name_base: float, when_base: float
) -> void:
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var width := column.size.x
	var name_size := UiDraw.fit_size(band.display_name, UiPalette.FONT_HEAD, width)
	UiDraw.text(
		self,
		Vector2(column.position.x, name_base),
		band.display_name,
		name_size,
		UiPalette.INK,
		center,
		width
	)
	UiDraw.text(
		self,
		Vector2(column.position.x, when_base),
		when,
		UiDraw.fit_size(when, UiPalette.FONT_BODY, width),
		UiPalette.INK_SOFT,
		center,
		width
	)


## 欲しがられるカテゴリを大きい順に、商品の絵と名前で並べる
func _draw_demand(rect: Rect2, demand: Dictionary) -> void:
	var categories: Array = demand.keys()
	categories.sort_custom(func(a: StringName, b: StringName) -> bool: return demand[a] > demand[b])
	categories = categories.slice(0, MAX_CATEGORIES)
	if categories.is_empty():
		return
	var top := float(demand[categories[0]])
	var slot := rect.size.x / MAX_CATEGORIES
	for i in categories.size():
		var share := float(demand[categories[i]]) / top
		var side := rect.size.y * lerpf(MIN_ICON, MAX_ICON, share)
		var center := Vector2(
			rect.position.x + slot * (i + 0.5), rect.position.y + rect.size.y * ICON_Y
		)
		UiDraw.category_icon(self, center, side, categories[i])
		var ink := UiPalette.INK.lerp(UiPalette.INK_SOFT, RANK_FADE * i)
		var name_pos := Vector2(
			rect.position.x + slot * i, rect.position.y + rect.size.y * CATEGORY_NAME_Y
		)
		var name := db().category(categories[i]).display_name
		var name_size := UiDraw.fit_size(name, UiPalette.FONT_BODY, slot)
		UiDraw.text(self, name_pos, name, name_size, ink, HORIZONTAL_ALIGNMENT_CENTER, slot)


## カテゴリ → 欲しがられる度合い(客層の割合 × 欲しい重み の合計)
func _demand(band: TimeBandData) -> Dictionary:
	var demand := {}
	var total := float(band.mix_total())
	if total <= 0.0:
		return demand
	for type_id: StringName in band.mix:
		var customer := db().customer_type(type_id)
		var share: float = band.mix[type_id] / total
		for category_id: StringName in customer.wants:
			demand[category_id] = (
				demand.get(category_id, 0.0) + share * customer.weight_of(category_id)
			)
	return demand


func _seconds_until(band: TimeBandData) -> float:
	var index := db().sorted_bands().find(band)
	return maxf(db().band_start_time(index) - match_state.elapsed, 0.0)


func _draw_event(event: EventData) -> void:
	var active := match_state.events.active_event != null
	var rect := Rect2(Vector2.ZERO, size)
	UiDraw.card(self, rect, UiPalette.MONEY)
	var stripe := UiPalette.INK
	stripe.a = 1.0 if active else lerpf(STRIPE_MIN_ALPHA, 1.0, blink())
	UiDraw.stripes(self, rect.grow(-UiPalette.OUTLINE), stripe, HAZARD_STRIPE)
	var inner := rect.grow(-HAZARD_WIDTH - UiPalette.OUTLINE)
	UiDraw.panel(self, inner, EVENT_FILL, UiPalette.INK, UiPalette.OUTLINE_THIN)
	var title := "%s 発生中!" % event.display_name
	if not active:
		title = "%s あと%d秒" % [event.display_name, int(ceil(match_state.seconds_until_event()))]
	var warning := (
		inner.position + Vector2(PAD + WARNING_SIZE * 0.5, EVENT_TITLE_Y - WARNING_SIZE * 0.4)
	)
	UiDraw.warning_icon(self, warning, WARNING_SIZE)
	var title_x := warning.x + WARNING_SIZE * 0.5 + PAD
	var title_size := UiDraw.fit_size(title, UiPalette.FONT_HEAD, inner.end.x - PAD - title_x)
	UiDraw.text(
		self, Vector2(title_x, inner.position.y + EVENT_TITLE_Y), title, title_size, UiPalette.BAD
	)
	var customer := db().customer_type(event.customer_type_id)
	var icon := Vector2(
		inner.position.x + PAD + EVENT_CUSTOMER_RADIUS, inner.position.y + EVENT_ROW_Y - PAD
	)
	UiDraw.customer_icon(self, icon, EVENT_CUSTOMER_RADIUS, customer)
	var info_pos := Vector2(icon.x + EVENT_CUSTOMER_RADIUS + PAD, inner.position.y + EVENT_ROW_Y)
	if active:
		_draw_event_counts(info_pos)
	else:
		var balance := match_state.balance
		var info := (
			"%s %d人がまとめ買い(%d倍)"
			% [customer.display_name, balance.event_customer_count, balance.event_buy_multiplier]
		)
		var info_size := UiDraw.fit_size(info, UiPalette.FONT_LARGE, inner.end.x - PAD - info_pos.x)
		UiDraw.text(self, info_pos, info, info_size, UiPalette.INK)
	_draw_event_wants(inner, customer)


## イベントの客が欲しがるカテゴリを商品の絵で並べる
func _draw_event_wants(inner: Rect2, customer: CustomerTypeData) -> void:
	var wants: Array = customer.wants.keys()
	wants.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return customer.weight_of(a) > customer.weight_of(b)
	)
	var slot := EVENT_ICON_SIDE + EVENT_ICON_GAP
	var x := inner.position.x + PAD + slot * 0.5
	var y := inner.position.y + EVENT_ICONS_Y - EVENT_NAME_GAP
	for category_id: StringName in wants:
		UiDraw.category_icon(self, Vector2(x, y), EVENT_ICON_SIDE, category_id)
		var name := db().category(category_id).display_name
		var name_x := x - slot * 0.5
		UiDraw.text(
			self,
			Vector2(name_x, y + EVENT_ICON_SIDE * 0.5 + EVENT_NAME_GAP),
			name,
			UiDraw.fit_size(name, UiPalette.FONT_BODY, slot),
			UiPalette.INK,
			HORIZONTAL_ALIGNMENT_CENTER,
			slot
		)
		x += slot


## 発生中のイベントの客が両店へ入った数(店の色で並べる)
func _draw_event_counts(pos: Vector2) -> void:
	var counts := match_state.events.active_counts
	var x := pos.x
	for i in counts.size():
		var label := "%s %d人" % [UiPalette.STORE_NAMES[i], counts[i]]
		UiDraw.text(self, Vector2(x, pos.y), label, UiPalette.FONT_LARGE, UiPalette.STORE_COLORS[i])
		x += UiDraw.text_width(label, UiPalette.FONT_LARGE) + PAD * 2.0
