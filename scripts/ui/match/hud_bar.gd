class_name HudBar
extends MatchPart
## 上端(GameDesign.md 9.2節・9.5節)。空に浮かぶ3枚の札:
## 左=店の時計・時間帯と1日の進み、中央=両店の売上と綱引きのバー、右=残り時間。
## 売上は数字が回って追いつき、増えた瞬間に少し大きくなる。

const ROLL_SPEED := 6.0
const BUMP_SECONDS := 0.25
const BUMP_SCALE := 1.2
const HURRY_SECONDS := 30.0
const HURRY_PULSE := 0.25
const PAD := 12.0

const CLOCK_RECT := Rect2(12, 8, 300, 50)
const SKY_ICON_SIZE := 36.0
const CLOCK_TEXT_X := 58.0
const CLOCK_FONT := 30
const DAY_BAR_X := 150.0
const DAY_BAR_Y := 32.0
const DAY_BAR_HEIGHT := 10.0
const DAY_LABEL_Y := 24.0
const DAY_MARKER := Vector2(5, 6)
const FUTURE_FADE := 0.55

const SCORE_RECT := Rect2(392, 6, 496, 42)
const VS_RADIUS := 19.0
const SALES_FONT := 26
const TUG_Y := 52.0
const TUG_HEIGHT := 10.0

const REMAIN_RECT := Rect2(1000, 8, 268, 50)
const REMAIN_FONT := 30

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
	_draw_clock()
	_draw_scoreboard()
	_draw_remaining()


func _draw_clock() -> void:
	UiDraw.card(self, CLOCK_RECT, UiPalette.PAPER)
	var band := match_state.current_band()
	var icon_y := CLOCK_RECT.position.y + (CLOCK_RECT.size.y - SKY_ICON_SIZE) / 2.0
	var icon := Rect2(CLOCK_RECT.position.x + PAD * 0.75, icon_y, SKY_ICON_SIZE, SKY_ICON_SIZE)
	UiDraw.sky_icon(self, icon, band)
	var clock := UiDraw.clock(match_state.clock_minutes())
	var baseline := UiDraw.baseline_in(CLOCK_RECT, CLOCK_FONT)
	var clock_pos := Vector2(CLOCK_RECT.position.x + CLOCK_TEXT_X, baseline)
	UiDraw.text(self, clock_pos, clock, CLOCK_FONT, UiPalette.INK)
	var label := "開店準備" if match_state.is_preparing() else band.display_name
	var label_pos := Vector2(CLOCK_RECT.position.x + DAY_BAR_X, CLOCK_RECT.position.y + DAY_LABEL_Y)
	UiDraw.text(self, label_pos, label, UiPalette.FONT_BODY, UiPalette.INK)
	_draw_day_bar()


## 1日の帯。時間帯ごとに空の色で塗り分け、まだ来ていない時間帯は薄くし、いまの位置に印を置く
func _draw_day_bar() -> void:
	var width := CLOCK_RECT.size.x - DAY_BAR_X - PAD
	var bar := Rect2(
		CLOCK_RECT.position + Vector2(DAY_BAR_X, DAY_BAR_Y), Vector2(width, DAY_BAR_HEIGHT)
	)
	var bands := db().sorted_bands()
	var total := match_state.duration()
	var now := 0.0 if match_state.is_preparing() else match_state.elapsed / total
	var x := bar.position.x
	for band in bands:
		var part := bar.size.x * band.duration / total
		var color := band.sky_top
		if (x - bar.position.x) / bar.size.x >= now:
			color = color.lerp(UiPalette.PAPER, FUTURE_FADE)
		draw_rect(Rect2(x, bar.position.y, part, bar.size.y), color)
		x += part
	UiDraw.panel(self, bar, Color.TRANSPARENT, UiPalette.INK, UiPalette.OUTLINE_THIN, 0)
	var marker_x := bar.position.x + bar.size.x * clampf(now, 0.0, 1.0)
	var tip := Vector2(marker_x, bar.position.y + DAY_MARKER.y * 0.5)
	var marker := PackedVector2Array(
		[
			tip,
			tip + Vector2(-DAY_MARKER.x, -DAY_MARKER.y * 1.5),
			tip + Vector2(DAY_MARKER.x, -DAY_MARKER.y * 1.5),
		]
	)
	draw_colored_polygon(marker, UiPalette.INK)
	draw_line(
		Vector2(marker_x, bar.position.y),
		Vector2(marker_x, bar.end.y),
		UiPalette.INK,
		UiPalette.OUTLINE_THIN
	)


func _draw_scoreboard() -> void:
	var half := (SCORE_RECT.size.x - VS_RADIUS * 2.0) / 2.0
	for i in MatchState.STORE_COUNT:
		var x := SCORE_RECT.position.x + (half + VS_RADIUS * 2.0) * i
		var plate := Rect2(x, SCORE_RECT.position.y, half, SCORE_RECT.size.y)
		UiDraw.card(self, plate, UiPalette.STORE_COLORS[i])
		_draw_sales(plate, i)
	var center := Vector2(
		SCORE_RECT.position.x + SCORE_RECT.size.x / 2.0,
		SCORE_RECT.position.y + SCORE_RECT.size.y / 2.0
	)
	draw_circle(
		center + Vector2(0, UiPalette.SHADOW_DROP), VS_RADIUS + UiPalette.OUTLINE, UiPalette.SHADOW
	)
	draw_circle(center, VS_RADIUS + UiPalette.OUTLINE, UiPalette.INK)
	draw_circle(center, VS_RADIUS, UiPalette.MONEY)
	var cell := Rect2(center - Vector2.ONE * VS_RADIUS, Vector2.ONE * VS_RADIUS * 2.0)
	UiDraw.text_centered(self, cell, "VS", UiPalette.FONT_BODY, UiPalette.INK)
	_draw_tug()


## 店名は札の端に小さく、売上は大きく縁取りして出す(自店は右寄せ・相手は左寄せで中央の VS に寄せる)
func _draw_sales(plate: Rect2, index: int) -> void:
	var white := UiPalette.INK_ON_DARK
	var name := UiPalette.STORE_NAMES[index]
	var name_base := UiDraw.baseline_in(plate, UiPalette.FONT_SMALL)
	var inner := plate.grow(-PAD)
	var name_align := HORIZONTAL_ALIGNMENT_LEFT if index == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	UiDraw.text(
		self,
		Vector2(inner.position.x, name_base),
		name,
		UiPalette.FONT_SMALL,
		white,
		name_align,
		inner.size.x
	)
	var font_size := SALES_FONT
	if _bump[index] > 0.0:
		font_size = int(font_size * lerpf(1.0, BUMP_SCALE, _bump[index] / BUMP_SECONDS))
	var sales := UiDraw.yen(int(round(_shown_sales[index])))
	var sales_align := HORIZONTAL_ALIGNMENT_RIGHT if index == 0 else HORIZONTAL_ALIGNMENT_LEFT
	var sales_base := UiDraw.baseline_in(plate, SALES_FONT)
	UiDraw.text_outlined(
		self,
		Vector2(inner.position.x, sales_base),
		sales,
		font_size,
		white,
		UiPalette.INK,
		sales_align,
		inner.size.x
	)


## 売上の綱引き(自店の割合ぶん青、残りを赤)
func _draw_tug() -> void:
	var tug := Rect2(SCORE_RECT.position.x, TUG_Y, SCORE_RECT.size.x, TUG_HEIGHT)
	var total := _shown_sales[0] + _shown_sales[1]
	var share := 0.5 if total <= 0.0 else _shown_sales[0] / total
	var radius := int(TUG_HEIGHT / 2.0)
	UiDraw.panel(self, tug, UiPalette.STORE_COLORS[1], Color.TRANSPARENT, 0, radius)
	var own := Rect2(tug.position, Vector2(tug.size.x * share, tug.size.y))
	UiDraw.panel(self, own, UiPalette.STORE_COLORS[0], Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, tug, Color.TRANSPARENT, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	var split := own.end.x
	draw_line(
		Vector2(split, tug.position.y),
		Vector2(split, tug.end.y),
		UiPalette.INK_ON_DARK,
		UiPalette.OUTLINE
	)


func _draw_remaining() -> void:
	var fill := UiPalette.PAPER
	var ink := UiPalette.INK
	var label := "残り"
	var value := ""
	if match_state.is_preparing():
		fill = UiPalette.WARN
		label = "開店まで"
		value = "%d秒" % int(ceil(match_state.prep_remaining()))
	else:
		var remaining := match_state.remaining_time()
		value = UiDraw.mm_ss(remaining)
		if remaining <= HURRY_SECONDS:
			fill = UiPalette.BAD.lightened(HURRY_PULSE * blink())
			ink = UiPalette.INK_ON_DARK
	UiDraw.card(self, REMAIN_RECT, fill)
	var inner := REMAIN_RECT.grow(-PAD)
	var label_base := UiDraw.baseline_in(REMAIN_RECT, UiPalette.FONT_BODY)
	UiDraw.text(self, Vector2(inner.position.x, label_base), label, UiPalette.FONT_BODY, ink)
	var value_base := UiDraw.baseline_in(REMAIN_RECT, REMAIN_FONT)
	var pos := Vector2(inner.position.x, value_base)
	UiDraw.text(self, pos, value, REMAIN_FONT, ink, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
