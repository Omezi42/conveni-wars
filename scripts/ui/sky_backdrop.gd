class_name SkyBackdrop
extends Control
## 画面の背景の空(GameDesign.md 9.5節)。上から下へのグラデーションで、夜は星がまたたく。
## 試合中は時間帯の色へゆっくり移り、空の色で1日のいまを見せる。入力は通す。

const BLEND_SECONDS := 2.5
const STAR_COUNT := 70
const STAR_SEED := 20260929
const STAR_MAX_Y := 0.8
const STAR_RADIUS_MIN := 0.8
const STAR_RADIUS_MAX := 1.9
const TWINKLE_HZ := 0.6
const TWINKLE_DEPTH := 0.5

static var _stars: Array[Vector3] = []

var _top := UiPalette.MENU_SKY_TOP
var _bottom := UiPalette.MENU_SKY_BOTTOM
var _night := 0.0
var _from: Array[Color] = []
var _to: Array[Color] = []
var _night_from := 0.0
var _night_to := 0.0
var _blend := 1.0


## 空を rect へ描く(night は星の濃さ 0〜1)。背景の部品を置かずに空を描く画面からも使う
static func paint(item: CanvasItem, rect: Rect2, top: Color, bottom: Color, night: float) -> void:
	UiDraw.gradient_rect(item, rect, top, bottom)
	if night <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var stars := _star_field()
	for i in stars.size():
		var star := stars[i]
		var twinkle := 1.0 - TWINKLE_DEPTH * (0.5 + 0.5 * sin(now * TAU * TWINKLE_HZ + i))
		var color := UiPalette.STAR
		color.a *= night * twinkle
		var pos := rect.position + Vector2(star.x * rect.size.x, star.y * rect.size.y)
		item.draw_circle(pos, star.z, color)


## x・y(画面に対する割合)・半径。並びは毎回同じにする(試合の乱数は使わない)
static func _star_field() -> Array[Vector3]:
	if _stars.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = STAR_SEED
		for i in STAR_COUNT:
			var radius := rng.randf_range(STAR_RADIUS_MIN, STAR_RADIUS_MAX)
			_stars.append(Vector3(rng.randf(), rng.randf() * STAR_MAX_Y, radius))
	return _stars


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_sky(top: Color, bottom: Color, night: bool, instant := false) -> void:
	var night_value := 1.0 if night else 0.0
	if instant:
		_top = top
		_bottom = bottom
		_night = night_value
		_blend = 1.0
		queue_redraw()
		return
	_from = [_top, _bottom]
	_to = [top, bottom]
	_night_from = _night
	_night_to = night_value
	_blend = 0.0


## weather があれば、その天気の色を混ぜる(GameDesign.md 12.3節)
func set_band(band: TimeBandData, instant := false, weather: WeatherData = null) -> void:
	var top := band.sky_top
	var bottom := band.sky_bottom
	if weather != null:
		top = weather.tinted(top)
		bottom = weather.tinted(bottom)
	set_sky(top, bottom, band.night, instant)


func _process(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(_blend + delta / BLEND_SECONDS, 1.0)
		var t := smoothstep(0.0, 1.0, _blend)
		_top = _from[0].lerp(_to[0], t)
		_bottom = _from[1].lerp(_to[1], t)
		_night = lerpf(_night_from, _night_to, t)
		queue_redraw()
	elif _night > 0.0:
		queue_redraw()


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), _top, _bottom, _night)
