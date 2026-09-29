class_name HudBar
extends MatchPart
## 上端(GameDesign.md 9.2節):左右に両店の名前と売上、中央に時間帯・店の時計・残り時間。
## 売上は数字が回って追いつき、店の札の下の帯で売上の取り分を見せる。

const STORE_ICON := preload("res://assets/icons/ui/store.svg")
const ROLL_SPEED := 6.0
const BUMP_SECONDS := 0.25
const BUMP_SCALE := 1.25
const HURRY_SECONDS := 30.0
const MARGIN := 8.0
const BADGE_SIZE := Vector2(400, 44)
const CENTER_SIZE := Vector2(380, 48)
const PAD := 12.0
const ICON_RADIUS := 15.0
const ICON_RING := 3.0
const SHARE_HEIGHT := 4.0
const PROGRESS_HEIGHT := 4.0
const BADGE_DARKEN := 0.35
const BADGE_EDGE_LIGHTEN := 0.3
const SHARE_TRACK := Color(1, 1, 1, 0.18)
const BAND_ICON_RADIUS := 16.0
const BAND_NAME_X := 44.0
const CLOCK_GAP := 10.0

var _shown_sales: Array[float] = [0.0, 0.0]
var _bump: Array[float] = [0.0, 0.0]


func _process(delta: float) -> void:
	if match_state == null:
		return
	for i in MatchState.STORE_COUNT:
		var target := float(match_state.stores[i].sales)
		if target > _shown_sales[i] + 0.5:
			_bump[i] = BUMP_SECONDS
		_shown_sales[i] = lerpf(_shown_sales[i], target, minf(1.0, delta * ROLL_SPEED))
		_bump[i] = maxf(_bump[i] - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if match_state == null:
		return
	var top := (size.y - BADGE_SIZE.y) / 2.0
	var total := _shown_sales[0] + _shown_sales[1]
	var share := 0.5 if total <= 0.0 else _shown_sales[0] / total
	_draw_badge(Rect2(Vector2(MARGIN, top), BADGE_SIZE), 0, share)
	var right := Rect2(Vector2(size.x - MARGIN - BADGE_SIZE.x, top), BADGE_SIZE)
	_draw_badge(right, 1, 1.0 - share)
	var center := Rect2(
		Vector2((size.x - CENTER_SIZE.x) / 2.0, (size.y - CENTER_SIZE.y) / 2.0), CENTER_SIZE
	)
	_draw_center(center)


func _draw_badge(rect: Rect2, index: int, share: float) -> void:
	var color := UiPalette.STORE_COLORS[index]
	var fill := color.darkened(BADGE_DARKEN)
	fill.a = UiPalette.PANEL.a
	UiDraw.panel(self, rect, fill, color.lightened(BADGE_EDGE_LIGHTEN), 2, UiPalette.PANEL_RADIUS)
	var mid := rect.get_center().y - SHARE_HEIGHT / 2.0
	var icon_x := rect.position.x + PAD + ICON_RADIUS
	if index == 1:
		icon_x = rect.end.x - PAD - ICON_RADIUS
	var icon := Vector2(icon_x, mid)
	draw_circle(icon, ICON_RADIUS + ICON_RING, UiPalette.INK_ON_DARK)
	UiDraw.texture_at(self, STORE_ICON, icon, ICON_RADIUS)
	var font_size := UiPalette.FONT_HEAD
	if _bump[index] > 0.0:
		font_size = int(font_size * lerpf(1.0, BUMP_SCALE, _bump[index] / BUMP_SECONDS))
	var sales := UiDraw.yen(int(round(_shown_sales[index])))
	var name := UiPalette.STORE_TITLES[index]
	var ink := UiPalette.INK_ON_DARK
	var name_base := _baseline(mid, UiPalette.FONT_LARGE)
	var sales_base := _baseline(mid, UiPalette.FONT_HEAD)
	var inner := rect.size.x - PAD * 3.0 - ICON_RADIUS * 2.0
	var text_x := icon.x + ICON_RADIUS + PAD if index == 0 else rect.position.x + PAD
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	var left := HORIZONTAL_ALIGNMENT_LEFT
	if index == 0:
		UiDraw.text(self, Vector2(text_x, name_base), name, UiPalette.FONT_LARGE, ink)
		UiDraw.text(self, Vector2(text_x, sales_base), sales, font_size, ink, right, inner)
	else:
		UiDraw.text(self, Vector2(text_x, name_base), name, UiPalette.FONT_LARGE, ink, right, inner)
		UiDraw.text(self, Vector2(text_x, sales_base), sales, font_size, ink, left, inner)
	var track := Rect2(
		rect.position.x + PAD,
		rect.end.y - SHARE_HEIGHT - 4.0,
		rect.size.x - PAD * 2.0,
		SHARE_HEIGHT
	)
	UiDraw.panel(self, track, SHARE_TRACK, Color.TRANSPARENT, 0, 2)
	var filled := Rect2(track.position, Vector2(track.size.x * share, track.size.y))
	if index == 1:
		filled.position.x = track.end.x - filled.size.x
	UiDraw.panel(self, filled, color.lightened(BADGE_EDGE_LIGHTEN), Color.TRANSPARENT, 0, 2)


func _draw_center(rect: Rect2) -> void:
	UiDraw.glass_panel(self, rect)
	var band := match_state.current_band()
	var mid := rect.get_center().y - PROGRESS_HEIGHT / 2.0
	var icon := Vector2(rect.position.x + PAD + BAND_ICON_RADIUS, mid)
	if band.icon != null:
		UiDraw.texture_at(self, band.icon, icon, BAND_ICON_RADIUS)
	var ink := UiPalette.INK
	var head := _baseline(mid, UiPalette.FONT_HEAD)
	UiDraw.text(
		self,
		Vector2(rect.position.x + PAD + BAND_NAME_X, head),
		band.display_name,
		UiPalette.FONT_HEAD,
		ink
	)
	var clock := UiDraw.clock(match_state.clock_minutes())
	var clock_x := (
		rect.position.x
		+ PAD
		+ BAND_NAME_X
		+ UiDraw.text_width(band.display_name, UiPalette.FONT_HEAD)
		+ CLOCK_GAP
	)
	var clock_pos := Vector2(clock_x, _baseline(mid, UiPalette.FONT_LARGE))
	UiDraw.text(self, clock_pos, clock, UiPalette.FONT_LARGE, UiPalette.INK_SOFT)
	var width := rect.size.x - PAD * 2.0
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	var remaining_pos := Vector2(rect.position.x + PAD, head)
	if match_state.is_preparing():
		var prep := "開店準備 あと%d秒" % int(ceil(match_state.prep_remaining()))
		UiDraw.text(self, remaining_pos, prep, UiPalette.FONT_LARGE, UiPalette.WARN, right, width)
	else:
		var remaining := match_state.remaining_time()
		var color := UiPalette.BAD_BRIGHT if remaining <= HURRY_SECONDS else ink
		var label := "残り " + UiDraw.mm_ss(remaining)
		UiDraw.text(self, remaining_pos, label, UiPalette.FONT_HEAD, color, right, width)
	var bar := Rect2(
		rect.position.x + PAD, rect.end.y - PROGRESS_HEIGHT - 4.0, width, PROGRESS_HEIGHT
	)
	UiDraw.panel(self, bar, SHARE_TRACK, Color.TRANSPARENT, 0, 2)
	var progress := 0.0 if match_state.is_preparing() else match_state.band_progress()
	var filled := Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y))
	UiDraw.panel(self, filled, UiPalette.ACCENT, Color.TRANSPARENT, 0, 2)


static func _baseline(mid: float, font_size: int) -> float:
	var f := UiDraw.font()
	return mid + (f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
