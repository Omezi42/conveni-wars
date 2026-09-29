class_name FxLayer
extends Control
## 演出(GameDesign.md 9.3節・9.5節):売上の「+¥」の飛び出し・カットイン・「大口獲得!」などの大きな文字。
## 文字はすべて太く縁取りする。画面全体を覆うが入力は通す。

const POP_SECONDS := 0.9
const POP_RISE := 48.0
## 飛び出した直後に大きく出て戻る時間の割合と大きさ
const POP_GROW := 0.15
const POP_START_SCALE := 1.35
const MAX_POPS := 40
const CUTIN_SECONDS := 1.5
const CUTIN_HEIGHT := 92.0
## 帯の斜めの切り口の水平のずれ
const CUTIN_SLANT := 40.0
## カットインが滑り込む/抜ける時間の割合
const CUTIN_SLIDE := 0.18
## 滑り込みは速く入って減速、抜けはゆっくり出て加速(ease() の曲線)
const SLIDE_IN_EASE := 0.4
const SLIDE_OUT_EASE := 2.5
const BIG_EASE := 0.5
const CUTIN_STRIPE := 18.0
const CUTIN_STRIPE_COLOR := Color(1, 1, 1, 0.12)
const CUTIN_EDGE := 4.0
const BIG_SECONDS := 1.8
const BIG_POP_SECONDS := 0.2
const BIG_START_SCALE := 1.8
const BURST_RAYS := 16
const BURST_RADIUS := 300.0
const BURST_SPIN := 0.35
const BURST_ALPHA := 0.35
const HALF := 0.5
const TOP_THIRD := 0.38

var _pops: Array[Dictionary] = []
var _cutins: Array[Dictionary] = []
var _bigs: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pop(pos: Vector2, label: String, color: Color, font_size: int) -> void:
	if _pops.size() >= MAX_POPS:
		_pops.pop_front()
	_pops.append({"pos": pos, "text": label, "color": color, "size": font_size, "t": 0.0})


## 画面を横切る斜めの帯。重なったら順に出す。striped は注意を引く縞を重ねる
func cutin(label: String, color: Color, striped := false) -> void:
	_cutins.append({"text": label, "color": color, "striped": striped, "t": 0.0})


## 画面中央の大きな文字。burst は後ろに回る光の筋を出す
func big(label: String, color: Color, burst := false) -> void:
	_bigs.append({"text": label, "color": color, "burst": burst, "t": 0.0})


func is_idle() -> bool:
	return _pops.is_empty() and _cutins.is_empty() and _bigs.is_empty()


func _process(delta: float) -> void:
	for item in _pops:
		item["t"] += delta / POP_SECONDS
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p["t"] < 1.0)
	if not _cutins.is_empty():
		_cutins[0]["t"] += delta / CUTIN_SECONDS
		if _cutins[0]["t"] >= 1.0:
			_cutins.pop_front()
	if not _bigs.is_empty():
		_bigs[0]["t"] += delta / BIG_SECONDS
		if _bigs[0]["t"] >= 1.0:
			_bigs.pop_front()
	queue_redraw()


func _draw() -> void:
	for item in _pops:
		_draw_pop(item)
	if not _cutins.is_empty():
		_draw_cutin(_cutins[0])
	if not _bigs.is_empty():
		_draw_big(_bigs[0])


func _draw_pop(item: Dictionary) -> void:
	var t: float = item["t"]
	var color: Color = item["color"]
	var alpha := 1.0 - t * t
	color.a = alpha
	var scale := 1.0
	if t < POP_GROW:
		scale = lerpf(POP_START_SCALE, 1.0, t / POP_GROW)
	var font_size := int(float(item["size"]) * scale)
	var rise := POP_RISE * (1.0 - pow(1.0 - t, 2.0))
	var pos: Vector2 = item["pos"] + Vector2(0, -rise)
	var label: String = item["text"]
	var width := UiDraw.text_width(label, font_size)
	var edge := UiPalette.INK
	edge.a = alpha
	UiDraw.text_outlined(self, pos - Vector2(width * HALF, 0), label, font_size, color, edge)


func _draw_cutin(item: Dictionary) -> void:
	var t: float = item["t"]
	var slide := 0.0
	if t < CUTIN_SLIDE:
		slide = 1.0 - ease(t / CUTIN_SLIDE, SLIDE_IN_EASE)
	elif t > 1.0 - CUTIN_SLIDE:
		slide = -ease((t - (1.0 - CUTIN_SLIDE)) / CUTIN_SLIDE, SLIDE_OUT_EASE)
	var offset := slide * (size.x + CUTIN_SLANT * 2.0)
	var top := size.y * TOP_THIRD - CUTIN_HEIGHT * HALF
	var bottom := top + CUTIN_HEIGHT
	var left := offset - CUTIN_SLANT
	var right := offset + size.x + CUTIN_SLANT
	var band := PackedVector2Array(
		[
			Vector2(left + CUTIN_SLANT, top),
			Vector2(right + CUTIN_SLANT, top),
			Vector2(right - CUTIN_SLANT, bottom),
			Vector2(left - CUTIN_SLANT, bottom),
		]
	)
	var edge_band := PackedVector2Array()
	for point in band:
		edge_band.append(point + Vector2(0, CUTIN_EDGE * (-1.0 if point.y == top else 1.0)))
	draw_colored_polygon(edge_band, UiPalette.INK)
	draw_colored_polygon(band, item["color"])
	if item["striped"]:
		UiDraw.stripes_in(self, band, CUTIN_STRIPE_COLOR, CUTIN_STRIPE)
	var text_rect := Rect2(offset, top, size.x, CUTIN_HEIGHT)
	UiDraw.text_centered(
		self, text_rect, item["text"], UiPalette.FONT_HUGE, UiPalette.INK_ON_DARK, UiPalette.INK
	)


func _draw_big(item: Dictionary) -> void:
	var t: float = item["t"]
	var elapsed := t * BIG_SECONDS
	var scale := 1.0
	if elapsed < BIG_POP_SECONDS:
		scale = lerpf(BIG_START_SCALE, 1.0, ease(elapsed / BIG_POP_SECONDS, BIG_EASE))
	var alpha := 1.0 if t < 1.0 - CUTIN_SLIDE else (1.0 - t) / CUTIN_SLIDE
	var center := size * HALF
	if item["burst"]:
		_draw_burst(center, t, alpha, item["color"])
	var font_size := int(UiPalette.FONT_TITLE * scale)
	var label: String = item["text"]
	var font := UiDraw.font()
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * HALF
	var color: Color = item["color"]
	color.a = alpha
	var edge := UiPalette.INK
	edge.a = alpha
	var pos := Vector2(0, baseline)
	UiDraw.text_outlined(
		self, pos, label, font_size, color, edge, HORIZONTAL_ALIGNMENT_CENTER, size.x
	)


## 回る光の筋(大きな文字の後ろ)
func _draw_burst(center: Vector2, t: float, alpha: float, color: Color) -> void:
	var tint := color
	tint.a = BURST_ALPHA * alpha
	UiDraw.burst(self, center, BURST_RADIUS, BURST_RAYS, t * TAU * BURST_SPIN, tint)
