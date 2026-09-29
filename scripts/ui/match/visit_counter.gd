class_name VisitCounter
extends MatchPart
## 客層ごとの来店数(両店ぶん)と、この時間帯に取り逃した客の数(GameDesign.md 2.6節・9.2節・9.5節)。
## 多いほうの数を店の色で出す。入りきらないときは、いまの時間帯に来る客層を優先して並べる。

const PAD := 8.0
const TAB_POS := Vector2(8, 8)
const ROWS_TOP := 40.0
const ROW_HEIGHT := 19.0
const ICON_RADIUS := 6.5
const ICON_GAP := 5.0
const COLUMN_WIDTH := 44.0
const HEADER_Y := 26.0
const FOOTER_HEIGHT := 50.0
const TOTAL_FONT := 17
const DIVIDER := Color("#ddd5c4")


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.card(self, Rect2(Vector2.ZERO, size), UiPalette.PAPER)
	UiDraw.tab(self, TAB_POS, "来店数")
	var own := match_state.stores[0]
	var rival := match_state.stores[1]
	var colors := UiPalette.STORE_COLORS
	_draw_pair(
		HEADER_Y,
		UiPalette.STORE_NAMES[0],
		UiPalette.STORE_NAMES[1],
		colors[0],
		colors[1],
		UiPalette.FONT_SMALL
	)
	var footer_top := size.y - FOOTER_HEIGHT
	var max_rows := int((footer_top - ROWS_TOP) / ROW_HEIGHT)
	var y := ROWS_TOP
	for customer in _visible_types().slice(0, max_rows):
		var mid := y + ROW_HEIGHT / 2.0
		UiDraw.customer_icon(self, Vector2(PAD + ICON_RADIUS, mid), ICON_RADIUS, customer)
		var row := Rect2(0, y, size.x, ROW_HEIGHT)
		var base := UiDraw.baseline_in(row, UiPalette.FONT_TINY)
		var name_pos := Vector2(PAD + ICON_RADIUS * 2.0 + ICON_GAP, base)
		UiDraw.text(self, name_pos, customer.display_name, UiPalette.FONT_TINY, UiPalette.INK)
		var own_count := int(own.visitors.get(customer.id, 0))
		var rival_count := int(rival.visitors.get(customer.id, 0))
		_draw_counts(
			UiDraw.baseline_in(row, UiPalette.FONT_SMALL),
			own_count,
			rival_count,
			UiPalette.FONT_SMALL
		)
		y += ROW_HEIGHT
	draw_line(
		Vector2(PAD, footer_top), Vector2(size.x - PAD, footer_top), DIVIDER, UiPalette.OUTLINE_THIN
	)
	var total_row := Rect2(0, footer_top, size.x, FOOTER_HEIGHT * 0.5)
	var total_base := UiDraw.baseline_in(total_row, TOTAL_FONT)
	UiDraw.text(self, Vector2(PAD, total_base), "合計", UiPalette.FONT_SMALL, UiPalette.INK)
	_draw_counts(total_base, own.visitor_total, rival.visitor_total, TOTAL_FONT)
	var band := match_state.current_band()
	var lost_row := Rect2(0, total_row.end.y, size.x, FOOTER_HEIGHT * 0.5)
	var lost_base := UiDraw.baseline_in(lost_row, UiPalette.FONT_SMALL)
	var label := "取り逃し(%s)" % band.display_name
	UiDraw.text(self, Vector2(PAD, lost_base), label, UiPalette.FONT_TINY, UiPalette.BAD)
	var own_lost := str(own.lost_in_band(band.id))
	var rival_lost := str(rival.lost_in_band(band.id))
	_draw_pair(lost_base, own_lost, rival_lost, UiPalette.BAD, UiPalette.BAD, UiPalette.FONT_SMALL)


## いまの時間帯に来る客層(多い順)のあとに、それ以外で来たことのある客層
func _visible_types() -> Array[CustomerTypeData]:
	var mix := match_state.current_band().mix
	var current: Array[CustomerTypeData] = []
	var others: Array[CustomerTypeData] = []
	for customer in db().sorted_customer_types():
		if mix.has(customer.id):
			current.append(customer)
			continue
		for store in match_state.stores:
			if store.visitors.has(customer.id):
				others.append(customer)
				break
	current.sort_custom(
		func(a: CustomerTypeData, b: CustomerTypeData) -> bool: return mix[a.id] > mix[b.id]
	)
	current.append_array(others)
	return current


## 多いほうを店の色で出す
func _draw_counts(baseline: float, own_count: int, rival_count: int, font_size: int) -> void:
	var colors := UiPalette.STORE_COLORS
	var own_color := colors[0] if own_count > rival_count else UiPalette.INK_SOFT
	var rival_color := colors[1] if rival_count > own_count else UiPalette.INK_SOFT
	_draw_pair(baseline, str(own_count), str(rival_count), own_color, rival_color, font_size)


func _draw_pair(
	baseline: float,
	left: String,
	right: String,
	left_color: Color,
	right_color: Color,
	font_size: int
) -> void:
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	var own_pos := Vector2(size.x - PAD - COLUMN_WIDTH * 2.0, baseline)
	UiDraw.text(self, own_pos, left, font_size, left_color, align, COLUMN_WIDTH)
	var rival_pos := Vector2(size.x - PAD - COLUMN_WIDTH, baseline)
	UiDraw.text(self, rival_pos, right, font_size, right_color, align, COLUMN_WIDTH)
