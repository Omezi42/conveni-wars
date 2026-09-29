class_name VisitCounter
extends MatchPart
## 客層ごとの来店数(両店ぶん)と、この時間帯に取り逃した客の数(GameDesign.md 2.6節・9.2節)。

const PAD := 10.0
const HEADER_HEIGHT := 26.0
const ROW_HEIGHT := 19.0
const ICON_RADIUS := 7.0
const ICON_GAP := 4.0
const DIVIDER_GAP := 4.0
const COLUMN_WIDTH := 52.0
const TEXT_BASELINE := 0.72
## 紺のパネルの上で店の色を読みやすくする
const LIGHTEN := 0.3
const DIVIDER := Color(1, 1, 1, 0.2)


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.glass_panel(self, Rect2(Vector2.ZERO, size))
	var own := match_state.stores[0]
	var rival := match_state.stores[1]
	var colors := UiPalette.STORE_COLORS
	var baseline := HEADER_HEIGHT * TEXT_BASELINE
	UiDraw.panel_title(self, Vector2(PAD, baseline), "来店数")
	var own_color := colors[0].lightened(LIGHTEN)
	var rival_color := colors[1].lightened(LIGHTEN)
	_draw_pair(baseline, UiPalette.STORE_NAMES[0], UiPalette.STORE_NAMES[1], own_color, rival_color)
	var y := HEADER_HEIGHT
	for customer in _visible_types():
		var mid := y + ROW_HEIGHT / 2.0
		UiDraw.customer_icon(self, Vector2(PAD + ICON_RADIUS, mid), ICON_RADIUS, customer)
		var row_base := y + ROW_HEIGHT * TEXT_BASELINE
		var name_pos := Vector2(PAD + ICON_RADIUS * 2.0 + ICON_GAP, row_base)
		UiDraw.text(self, name_pos, customer.display_name, UiPalette.FONT_SMALL, UiPalette.INK)
		var own_count := int(own.visitors.get(customer.id, 0))
		_draw_counts(row_base, own_count, int(rival.visitors.get(customer.id, 0)))
		y += ROW_HEIGHT
	y += DIVIDER_GAP
	draw_line(Vector2(PAD, y), Vector2(size.x - PAD, y), DIVIDER, 1.0)
	var total_base := y + ROW_HEIGHT * TEXT_BASELINE
	UiDraw.text(self, Vector2(PAD, total_base), "合計", UiPalette.FONT_SMALL, UiPalette.INK)
	_draw_counts(total_base, own.visitor_total, rival.visitor_total)
	y += ROW_HEIGHT
	var band := match_state.current_band()
	var lost_base := y + ROW_HEIGHT * TEXT_BASELINE
	var label := "取り逃し(%s)" % band.display_name
	UiDraw.text(self, Vector2(PAD, lost_base), label, UiPalette.FONT_SMALL, UiPalette.BAD_BRIGHT)
	var own_lost := str(own.lost_in_band(band.id))
	var rival_lost := str(rival.lost_in_band(band.id))
	_draw_pair(lost_base, own_lost, rival_lost, UiPalette.BAD_BRIGHT, UiPalette.BAD_BRIGHT)


## 来た客層と、いまの時間帯に来る客層
func _visible_types() -> Array[CustomerTypeData]:
	var mix := match_state.current_band().mix
	var result: Array[CustomerTypeData] = []
	for customer in db().sorted_customer_types():
		var seen := mix.has(customer.id)
		for store in match_state.stores:
			seen = seen or store.visitors.has(customer.id)
		if seen:
			result.append(customer)
	return result


## 多いほうを店の色で出す
func _draw_counts(baseline: float, own_count: int, rival_count: int) -> void:
	var colors := UiPalette.STORE_COLORS
	var own_color := colors[0].lightened(LIGHTEN) if own_count > rival_count else UiPalette.INK_SOFT
	var rival_color := (
		colors[1].lightened(LIGHTEN) if rival_count > own_count else UiPalette.INK_SOFT
	)
	_draw_pair(baseline, str(own_count), str(rival_count), own_color, rival_color)


func _draw_pair(
	baseline: float, left: String, right: String, left_color: Color, right_color: Color
) -> void:
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	var font_size := UiPalette.FONT_SMALL
	var own_pos := Vector2(size.x - PAD - COLUMN_WIDTH * 2.0, baseline)
	UiDraw.text(self, own_pos, left, font_size, left_color, align, COLUMN_WIDTH)
	var rival_pos := Vector2(size.x - PAD - COLUMN_WIDTH, baseline)
	UiDraw.text(self, rival_pos, right, font_size, right_color, align, COLUMN_WIDTH)
