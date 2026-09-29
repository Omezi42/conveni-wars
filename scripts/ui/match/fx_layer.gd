class_name FxLayer
extends Control
## 演出(GameDesign.md 9.3節):売上の「+¥」の飛び出し・カットイン・「大口獲得!」などの大きな文字。
## 画面全体を覆うが入力は通す。

const POP_SECONDS := 0.9
const POP_RISE := 44.0
const MAX_POPS := 40
const CUTIN_SECONDS := 1.5
const CUTIN_HEIGHT := 84.0
## カットインが滑り込む/抜ける時間の割合
const CUTIN_SLIDE := 0.18
const CUTIN_ALPHA := 0.92
const BIG_SECONDS := 1.8
const BIG_POP_SECONDS := 0.2
const BIG_START_SCALE := 1.8
const OUTLINE := 8
const POP_OUTLINE := 4
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


## 画面を横切る帯。重なったら順に出す
func cutin(label: String, color: Color) -> void:
	_cutins.append({"text": label, "color": color, "t": 0.0})


func big(label: String, color: Color) -> void:
	_bigs.append({"text": label, "color": color, "t": 0.0})


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
	color.a = 1.0 - t * t
	var font_size: int = item["size"]
	var pos: Vector2 = item["pos"] + Vector2(0, -POP_RISE * t)
	var label: String = item["text"]
	var width := UiDraw.text_width(label, font_size)
	var at := pos - Vector2(width * HALF, 0)
	var outline := Color(1, 1, 1, color.a)
	draw_string_outline(
		UiDraw.font(), at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, POP_OUTLINE, outline
	)
	UiDraw.text(self, at, label, font_size, color)


func _draw_cutin(item: Dictionary) -> void:
	var t: float = item["t"]
	var slide := 0.0
	if t < CUTIN_SLIDE:
		slide = 1.0 - t / CUTIN_SLIDE
	elif t > 1.0 - CUTIN_SLIDE:
		slide = -(t - (1.0 - CUTIN_SLIDE)) / CUTIN_SLIDE
	var offset := slide * size.x
	var band := Rect2(offset, size.y * TOP_THIRD - CUTIN_HEIGHT * HALF, size.x, CUTIN_HEIGHT)
	var color: Color = item["color"]
	color.a = CUTIN_ALPHA
	draw_rect(band, color)
	UiDraw.text_centered(self, band, item["text"], UiPalette.FONT_HUGE, UiPalette.INK_ON_DARK)


func _draw_big(item: Dictionary) -> void:
	var t: float = item["t"]
	var elapsed := t * BIG_SECONDS
	var scale := 1.0
	if elapsed < BIG_POP_SECONDS:
		scale = lerpf(BIG_START_SCALE, 1.0, elapsed / BIG_POP_SECONDS)
	var font_size := int(UiPalette.FONT_TITLE * scale)
	var label: String = item["text"]
	var width := UiDraw.text_width(label, font_size)
	var font := UiDraw.font()
	var baseline := (
		size.y * HALF + (font.get_ascent(font_size) - font.get_descent(font_size)) * HALF
	)
	var pos := Vector2((size.x - width) * HALF, baseline)
	var alpha := 1.0 if t < 1.0 - CUTIN_SLIDE else (1.0 - t) / CUTIN_SLIDE
	var color: Color = item["color"]
	color.a = alpha
	var outline := Color(1, 1, 1, alpha)
	draw_string_outline(
		font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE, outline
	)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
