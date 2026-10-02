class_name HudBar
extends MatchPart
## 上端(GameDesign.md 9.2節・9.5節)。左=時間帯・1日の進み・残り時間を1枚の札に、
## 右=両店の利益と綱引きのバー。
## 売上は数字が回って追いつき、増えた瞬間に少し大きくなる。

const ROLL_SPEED := 6.0
const BUMP_SECONDS := 0.25
const BUMP_SCALE := 1.2
const HURRY_SECONDS := 30.0
const HURRY_PULSE := 0.25
const PAD := 12.0

const CLOCK_RECT := Rect2(12, 6, 380, 66)
const SKY_ICON_SIZE := 50.0
## 時間帯の名前と、その下の1日の帯
const DAY_X := 74.0
const DAY_LABEL_Y := 30.0
const DAY_BAR_Y := 42.0
const DAY_BAR_HEIGHT := 12.0
const DAY_MARKER := Vector2(6, 7)
const FUTURE_FADE := 0.55
## 残り時間の札(時間帯の札の右端に入れる)
const REMAIN_WIDTH := 116.0
const REMAIN_INSET := 6.0
const REMAIN_FONT := 32
const REMAIN_LABEL_BASE := 18.0
const REMAIN_VALUE_TOP := 16.0

## 右端は一時停止のボタンのために空ける(MatchController.PAUSE_BUTTON_RECT)
const SCORE_RECT := Rect2(412, 6, 796, 52)
const VS_RADIUS := 22.0
const SALES_FONT := 36
const PROFIT_LABEL := "の利益"
const TUG_Y := 62.0
const TUG_HEIGHT := 12.0

var _shown_profit: Array[float] = [0.0, 0.0]
var _bump: Array[float] = [0.0, 0.0]


func _process(delta: float) -> void:
	if match_state == null:
		return
	for i in MatchState.STORE_COUNT:
		var target := float(match_state.stores[i].profit())
		if target > _shown_profit[i] + 0.5:
			_bump[i] = BUMP_SECONDS
		_shown_profit[i] = lerpf(_shown_profit[i], target, minf(1.0, delta * ROLL_SPEED))
		_bump[i] = maxf(_bump[i] - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if match_state == null:
		return
	_draw_clock()
	_draw_scoreboard()


func _draw_clock() -> void:
	UiDraw.card(self, CLOCK_RECT, UiPalette.PAPER)
	var band := match_state.current_band()
	var icon_y := CLOCK_RECT.position.y + (CLOCK_RECT.size.y - SKY_ICON_SIZE) / 2.0
	var icon := Rect2(CLOCK_RECT.position.x + PAD * 0.75, icon_y, SKY_ICON_SIZE, SKY_ICON_SIZE)
	UiDraw.sky_icon(self, icon, band)
	var label := band.display_name
	var label_pos := Vector2(CLOCK_RECT.position.x + DAY_X, CLOCK_RECT.position.y + DAY_LABEL_Y)
	UiDraw.text(self, label_pos, label, UiPalette.FONT_LARGE, UiPalette.INK)
	_draw_day_bar()
	_draw_remaining()


## 1日の帯。時間帯ごとに空の色で塗り分け、まだ来ていない時間帯は薄くし、いまの位置に印を置く
func _draw_day_bar() -> void:
	var width := CLOCK_RECT.size.x - DAY_X - REMAIN_WIDTH - REMAIN_INSET - PAD
	var bar := Rect2(
		CLOCK_RECT.position + Vector2(DAY_X, DAY_BAR_Y), Vector2(width, DAY_BAR_HEIGHT)
	)
	var bands := db().sorted_bands()
	var total := match_state.duration()
	var now := match_state.elapsed / total
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
		_draw_profit(plate, i)
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


## 店名は札の外側の端に、利益は大きく縁取りして出す(自店は右寄せ・相手は左寄せで中央の VS に寄せる)
func _draw_profit(plate: Rect2, index: int) -> void:
	var white := UiPalette.INK_ON_DARK
	var name := UiPalette.STORE_NAMES[index] + PROFIT_LABEL
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
	var sales := UiDraw.yen(int(round(_shown_profit[index])))
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


## 利益の綱引き(自店の割合ぶん青、残りを赤)。利益は負にもなるため、差を両店の絶対値の和で割って寄せる
func _draw_tug() -> void:
	var tug := Rect2(SCORE_RECT.position.x, TUG_Y, SCORE_RECT.size.x, TUG_HEIGHT)
	var scale := absf(_shown_profit[0]) + absf(_shown_profit[1])
	var share := 0.5
	if scale > 0.0:
		share = clampf(0.5 + (_shown_profit[0] - _shown_profit[1]) / (2.0 * scale), 0.0, 1.0)
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


## 時計の札の右端の、残り時間。残り30秒で赤く点滅する
func _draw_remaining() -> void:
	var fill := UiPalette.INK
	var label := "残り"
	var remaining := match_state.remaining_time()
	var value := UiDraw.mm_ss(remaining)
	if remaining <= HURRY_SECONDS:
		fill = UiPalette.BAD.lightened(HURRY_PULSE * blink())
	var rect := Rect2(
		CLOCK_RECT.end.x - REMAIN_WIDTH - REMAIN_INSET,
		CLOCK_RECT.position.y + REMAIN_INSET,
		REMAIN_WIDTH,
		CLOCK_RECT.size.y - REMAIN_INSET * 2.0
	)
	UiDraw.panel(self, rect, fill, Color.TRANSPARENT, 0, UiPalette.RADIUS_SMALL)
	var white := UiPalette.INK_ON_DARK
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var label_pos := Vector2(rect.position.x, rect.position.y + REMAIN_LABEL_BASE)
	UiDraw.text(self, label_pos, label, UiPalette.FONT_SMALL, white, center, rect.size.x)
	var value_rect := rect.grow_individual(0, -REMAIN_VALUE_TOP, 0, 0)
	UiDraw.text_centered(self, value_rect, value, REMAIN_FONT, white)
