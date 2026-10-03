class_name ProfitChart
extends Control
## 結果のふりかえり(GameDesign.md 9.4節)。両店の利益の折れ線に、時間帯の境目・時間帯ごとに自店へ入った客の割合・
## いちばん多い負けた理由・突発イベントの印(自店が大口獲得したものは★)を重ねる。

const PAD := 18.0
const TITLE_Y := 36.0
const LEGEND_LINE := 22.0
const LEGEND_GAP := 6.0
const LEGEND_SPACING := 16.0
const PLOT_TOP := 78.0
const PLOT_LEFT := 74.0
const PLOT_BOTTOM_SPACE := 142.0
const LINE_WIDTH := 3.0
const GRID_WIDTH := 1.5
const DASH := Vector2(6, 5)
const VALUE_GAP := 8.0
const MARK_Y := 12.0
const MARK_RADIUS := 7.0
const STAR_RADIUS := 10.0
const MARK_LINE := Color(1.0, 0.69, 0.13, 0.4)
const STRIP_GAP := 8.0
const STRIP_HEIGHT := 28.0
const SHARE_Y := 30.0
## 割合の下の、その時間帯でいちばん多い負けた理由(GameDesign.md 9.4節)
const REASON_Y := 54.0
const NOTE_Y := 80.0
## ベースラインから文字の見た目の中央までの高さ(文字の大きさに対する割合)
const TEXT_MID := 0.35
## 下向きの三角の上辺の高さ(半径に対する割合)
const TRIANGLE_TOP := 0.6
const GRID_DARKEN := 0.1
const MARK_OUTLINE := 1.0

var _result: MatchResult


func setup(result: MatchResult) -> void:
	_result = result
	queue_redraw()


func _draw() -> void:
	UiDraw.card(self, Rect2(Vector2.ZERO, size), UiPalette.PAPER, UiPalette.RADIUS)
	var title := "利益の動き"
	if _result != null and _result.weather != null:
		title += "(%s)" % _result.weather.display_name
	UiDraw.text(self, Vector2(PAD, TITLE_Y), title, UiPalette.FONT_LARGE, UiPalette.INK)
	_draw_legend()
	if _result == null or _result.history == null or _result.history.times.is_empty():
		return
	var plot := Rect2(
		PLOT_LEFT, PLOT_TOP, size.x - PLOT_LEFT - PAD, size.y - PLOT_TOP - PLOT_BOTTOM_SPACE
	)
	var span := _profit_span()
	_draw_grid(plot, span)
	_draw_band_lines(plot)
	_draw_event_marks(plot)
	for i in range(MatchState.STORE_COUNT - 1, -1, -1):
		_draw_line(plot, span, i)
	_draw_bands(plot)


## 右上の「― 自店 ― 相手」
func _draw_legend() -> void:
	var x := size.x - PAD
	for i in range(MatchState.STORE_COUNT - 1, -1, -1):
		var name := UiPalette.STORE_NAMES[i]
		x -= UiDraw.text_width(name, UiPalette.FONT_BODY)
		UiDraw.text(self, Vector2(x, TITLE_Y), name, UiPalette.FONT_BODY, UiPalette.INK)
		x -= LEGEND_GAP + LEGEND_LINE
		var y := TITLE_Y - UiPalette.FONT_BODY * TEXT_MID
		draw_line(
			Vector2(x, y), Vector2(x + LEGEND_LINE, y), UiPalette.STORE_COLORS[i], LINE_WIDTH, true
		)
		x -= LEGEND_SPACING


## 縦軸の下端と上端の利益(0は必ず含める)
func _profit_span() -> Vector2:
	var low := 0
	var high := 1
	for profits in _result.history.profits:
		for value in profits:
			low = mini(low, value)
			high = maxi(high, value)
	return Vector2(low, high)


func _y_of(plot: Rect2, span: Vector2, value: float) -> float:
	return plot.end.y - plot.size.y * (value - span.x) / (span.y - span.x)


func _x_of(plot: Rect2, time: float) -> float:
	var duration := GameDatabase.get_default().match_duration()
	return plot.position.x + plot.size.x * clampf(time / duration, 0.0, 1.0)


func _draw_grid(plot: Rect2, span: Vector2) -> void:
	var zero := _y_of(plot, span, 0.0)
	draw_line(
		Vector2(plot.position.x, zero), Vector2(plot.end.x, zero), UiPalette.INK_SOFT, GRID_WIDTH
	)
	_dashed(plot.position.x, plot.end.x, plot.position.y)
	var label_width := plot.position.x - VALUE_GAP
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	var font_size := UiPalette.FONT_SMALL
	var top_label := UiDraw.yen(int(span.y))
	var half := font_size * TEXT_MID
	UiDraw.text(
		self,
		Vector2(0, plot.position.y + half),
		top_label,
		font_size,
		UiPalette.INK_SOFT,
		right,
		label_width
	)
	UiDraw.text(
		self, Vector2(0, zero + half), "¥0", font_size, UiPalette.INK_SOFT, right, label_width
	)


func _dashed(from_x: float, to_x: float, y: float) -> void:
	var at := from_x
	while at < to_x:
		var end := minf(at + DASH.x, to_x)
		draw_line(
			Vector2(at, y), Vector2(end, y), UiPalette.PAPER_DIM.darkened(GRID_DARKEN), GRID_WIDTH
		)
		at += DASH.x + DASH.y


func _draw_band_lines(plot: Rect2) -> void:
	var db := GameDatabase.get_default()
	for i in range(1, db.sorted_bands().size()):
		var x := _x_of(plot, db.band_start_time(i))
		draw_line(
			Vector2(x, plot.position.y), Vector2(x, plot.end.y), UiPalette.INK_SOFT, GRID_WIDTH
		)


func _draw_event_marks(plot: Rect2) -> void:
	var balance := GameDatabase.get_default().balance
	var big_catch := ceili(balance.event_customer_count * balance.big_catch_ratio)
	for mark in _result.history.event_marks:
		var x := _x_of(plot, mark.time)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), MARK_LINE, GRID_WIDTH)
		var center := Vector2(x, plot.position.y - MARK_Y)
		var own := (
			mark.store_counts[MatchController.PLAYER] if not mark.store_counts.is_empty() else 0
		)
		if own >= big_catch:
			UiDraw.star(self, center, STAR_RADIUS, UiPalette.MONEY, UiPalette.INK)
			continue
		var triangle := PackedVector2Array(
			[
				center + Vector2(-MARK_RADIUS, -MARK_RADIUS * TRIANGLE_TOP),
				center + Vector2(MARK_RADIUS, -MARK_RADIUS * TRIANGLE_TOP),
				center + Vector2(0, MARK_RADIUS),
			]
		)
		draw_colored_polygon(triangle, UiPalette.WARN)
		triangle.append(triangle[0])
		draw_polyline(triangle, UiPalette.INK, MARK_OUTLINE, true)


func _draw_line(plot: Rect2, span: Vector2, store_index: int) -> void:
	var history := _result.history
	var points := PackedVector2Array([Vector2(plot.position.x, _y_of(plot, span, 0.0))])
	var profits := history.profits[store_index]
	for i in history.times.size():
		points.append(Vector2(_x_of(plot, history.times[i]), _y_of(plot, span, profits[i])))
	draw_polyline(points, UiPalette.STORE_COLORS[store_index], LINE_WIDTH, true)


## 横軸の下の時間帯の帯(名前)と、時間帯ごとに自店へ入った客の割合
func _draw_bands(plot: Rect2) -> void:
	var db := GameDatabase.get_default()
	var bands := db.sorted_bands()
	var strip_y := plot.end.y + STRIP_GAP
	for i in bands.size():
		var x := _x_of(plot, db.band_start_time(i))
		var end_x := _x_of(plot, db.band_start_time(i) + bands[i].duration)
		var strip := Rect2(x, strip_y, end_x - x, STRIP_HEIGHT)
		draw_rect(strip, bands[i].sky_top)
		UiDraw.text_centered(
			self,
			strip,
			bands[i].display_name,
			UiPalette.FONT_BODY,
			UiPalette.INK_ON_DARK,
			UiPalette.INK
		)
		var share_pos := Vector2(x, strip.end.y + SHARE_Y)
		var share := _share(bands[i].id)
		UiDraw.text(
			self,
			share_pos,
			"-" if share < 0.0 else "%d%%" % roundi(share * 100.0),
			UiPalette.FONT_HEAD,
			_share_color(share),
			HORIZONTAL_ALIGNMENT_CENTER,
			strip.size.x
		)
		var store := _result.stores[MatchController.PLAYER]
		UiDraw.text(
			self,
			Vector2(x, strip.end.y + REASON_Y),
			LossText.short_label(store.losses_in_band(bands[i].id)),
			UiPalette.FONT_BODY,
			UiPalette.INK_SOFT,
			HORIZONTAL_ALIGNMENT_CENTER,
			strip.size.x
		)
	var outline := Rect2(plot.position.x, strip_y, plot.size.x, STRIP_HEIGHT)
	draw_rect(outline, UiPalette.INK, false, UiPalette.OUTLINE_THIN)
	UiDraw.text(
		self,
		Vector2(0, strip_y + STRIP_HEIGHT + NOTE_Y),
		"時間帯の客のうち自店に入った割合   ▼ 突発イベント   ★ 大口獲得",
		UiPalette.FONT_SMALL,
		UiPalette.INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x
	)


func _share(band_id: StringName) -> float:
	return _result.stores[MatchController.PLAYER].band_share(band_id)


func _share_color(share: float) -> Color:
	match GameDatabase.get_default().balance.share_grade(share):
		1:
			return UiPalette.GOOD
		-1:
			return UiPalette.BAD
	return UiPalette.INK
