class_name HudBar
extends MatchPart
## 上端:店の時計・時間帯・残り時間・両店の売上(GameDesign.md 9.2節)。売上は数字が回って追いつく。

const ROLL_SPEED := 6.0
const BUMP_SECONDS := 0.25
const BUMP_SCALE := 1.25
const HURRY_SECONDS := 30.0
const PAD := 16.0
const CLOCK_WIDTH := 80.0
const CHIP_SIZE := Vector2(64, 28)
const BAND_BAR_SIZE := Vector2(120, 6)
const GAP := 10.0
const TUG_SIZE := Vector2(300, 10)
const TUG_OFFSET := 8.0
const SALES_OFFSET := -4.0
const RIGHT_WIDTH := 280.0
const LIGHTEN := 0.35
const TRACK := Color(1, 1, 1, 0.25)

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
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.BAR)
	var mid := size.y / 2.0
	_draw_clock(mid)
	_draw_sales(mid)
	_draw_remaining(mid)


func _draw_clock(mid: float) -> void:
	var ink := UiPalette.INK_ON_DARK
	var baseline := _baseline(mid, UiPalette.FONT_HEAD)
	var clock := UiDraw.clock(match_state.clock_minutes())
	UiDraw.text(self, Vector2(PAD, baseline), clock, UiPalette.FONT_HEAD, ink)
	var chip := Rect2(Vector2(PAD + CLOCK_WIDTH, mid - CHIP_SIZE.y / 2.0), CHIP_SIZE)
	UiDraw.panel(self, chip, ink)
	var band := match_state.current_band()
	UiDraw.text_centered(self, chip, band.display_name, UiPalette.FONT_LARGE, UiPalette.BAR)
	var bar := Rect2(Vector2(chip.end.x + GAP, mid - BAND_BAR_SIZE.y / 2.0), BAND_BAR_SIZE)
	var radius := int(BAND_BAR_SIZE.y / 2.0)
	UiDraw.panel(self, bar, TRACK, Color.TRANSPARENT, 0, radius)
	var progress := 0.0 if match_state.is_preparing() else match_state.band_progress()
	var filled := Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y))
	UiDraw.panel(self, filled, ink, Color.TRANSPARENT, 0, radius)


func _draw_remaining(mid: float) -> void:
	var baseline := _baseline(mid, UiPalette.FONT_HEAD)
	var pos := Vector2(size.x - PAD - RIGHT_WIDTH, baseline)
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	if match_state.is_preparing():
		var prep := "開店準備 あと%d秒" % int(ceil(match_state.prep_remaining()))
		UiDraw.text(self, pos, prep, UiPalette.FONT_HEAD, UiPalette.WARN, align, RIGHT_WIDTH)
		return
	var remaining := match_state.remaining_time()
	var color := UiPalette.INK_ON_DARK
	if remaining <= HURRY_SECONDS:
		color = UiPalette.BAD.lightened(LIGHTEN)
	var label := "残り " + UiDraw.mm_ss(remaining)
	UiDraw.text(self, pos, label, UiPalette.FONT_HEAD, color, align, RIGHT_WIDTH)


func _draw_sales(mid: float) -> void:
	var center := size.x / 2.0
	var tug := Rect2(Vector2(center - TUG_SIZE.x / 2.0, mid + TUG_OFFSET), TUG_SIZE)
	var total := _shown_sales[0] + _shown_sales[1]
	var share := 0.5 if total <= 0.0 else _shown_sales[0] / total
	var radius := int(TUG_SIZE.y / 2.0)
	UiDraw.panel(self, tug, UiPalette.STORE_COLORS[1], Color.TRANSPARENT, 0, radius)
	var own := Rect2(tug.position, Vector2(tug.size.x * share, tug.size.y))
	UiDraw.panel(self, own, UiPalette.STORE_COLORS[0], Color.TRANSPARENT, 0, radius)
	var tick := Vector2(center, tug.position.y - radius)
	draw_line(tick, Vector2(center, tug.end.y + radius), UiPalette.INK_ON_DARK, 2.0)
	for i in MatchState.STORE_COUNT:
		var font_size := UiPalette.FONT_LARGE
		if _bump[i] > 0.0:
			font_size = int(font_size * lerpf(1.0, BUMP_SCALE, _bump[i] / BUMP_SECONDS))
		var sales := UiDraw.yen(int(round(_shown_sales[i])))
		var label := "%s %s" % [UiPalette.STORE_NAMES[i], sales]
		var color := UiPalette.STORE_COLORS[i].lightened(LIGHTEN)
		var y := mid + SALES_OFFSET
		if i == 0:
			var pos := Vector2(center - GAP - TUG_SIZE.x, y)
			UiDraw.text(self, pos, label, font_size, color, HORIZONTAL_ALIGNMENT_RIGHT, TUG_SIZE.x)
		else:
			UiDraw.text(self, Vector2(center + GAP, y), label, font_size, color)


static func _baseline(mid: float, font_size: int) -> float:
	var f := UiDraw.font()
	return mid + (f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
