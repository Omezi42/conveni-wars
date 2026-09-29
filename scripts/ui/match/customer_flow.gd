class_name CustomerFlow
extends MatchPart
## 両店の入口へ流れ込む人の流れと、取り逃した客の吹き出し(GameDesign.md 2.6節・9.2節)。
## 客は1人ずつ通りを歩かせず、入った店の入口へ吸い込まれる短い流れとして描き、
## 流れの太さでどちらの店へ多く入っているかを見せる(1秒に4〜9人来るため)。

const WALK_SECONDS := 0.9
const ICON_RADIUS := 7.0
const EVENT_ICON_RADIUS := 9.0
const EVENT_RING := 2.0
const LANE_JITTER := 22.0
const DOOR_SPREAD := 18.0
const MAX_WALKERS := 60
const LEAVE_ALPHA := 0.45
## 流れの太さに使う、最近の来店の勢い(秒あたり)の減り方
const RATE_DECAY_SECONDS := 1.5
const RATE_FOR_FULL_STREAM := 9.0
const STREAM_MAX_WIDTH := 30.0
const STREAM_ALPHA := 0.28
const BUBBLE_SECONDS := 1.6
## 吹き出しは店ごとにこの秒数に1つまで(画面が埋まらないように間引く。数はすべて数える)
const BUBBLE_INTERVAL := 1.2
const BUBBLE_RISE := 26.0
const BUBBLE_PAD := 6.0
const BUBBLE_HEIGHT := 22.0
const BUBBLE_OFFSET := Vector2(0, -34)
const DASH_LENGTH := 14.0
const DASH_WIDTH := 3.0
const HALF := 0.5

## 入口の位置(この部品の中の座標。自店・相手の順)
var door_points: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

var _walkers: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _bubble_cooldown: Array[float] = [0.0, 0.0]
var _rates: Array[float] = [0.0, 0.0]
## 見た目だけの乱数(試合の乱数は使わない。使うと同じ種で同じ試合にならなくなる)
var _rng := RandomNumberGenerator.new()


func push_arrival(type_id: StringName, store_index_in: int, is_event: bool) -> void:
	if _walkers.size() >= MAX_WALKERS:
		_walkers.pop_front()
	var from_top := _rng.randf() < HALF
	var start_x := size.x * HALF + _rng.randf_range(-LANE_JITTER, LANE_JITTER)
	var start := Vector2(start_x, 0.0 if from_top else size.y)
	var end := Vector2(start_x, size.y if from_top else 0.0)
	if store_index_in >= 0:
		end = door_points[store_index_in] + Vector2(0, _rng.randf_range(-DOOR_SPREAD, DOOR_SPREAD))
		_rates[store_index_in] += 1.0 / RATE_DECAY_SECONDS
	var control := Vector2(size.x * HALF, end.y)
	(
		_walkers
		. append(
			{
				"type": type_id,
				"store": store_index_in,
				"start": start,
				"control": control,
				"end": end,
				"t": 0.0,
				"event": is_event,
			}
		)
	)


func push_lost(lost_store: int, category_id: StringName) -> void:
	if _bubble_cooldown[lost_store] > 0.0:
		return
	_bubble_cooldown[lost_store] = BUBBLE_INTERVAL
	var label := "%sが無い…" % db().category(category_id).display_name
	var anchor := door_points[lost_store] + BUBBLE_OFFSET
	_bubbles.append({"text": label, "anchor": anchor, "t": 0.0, "store": lost_store})


func _process(delta: float) -> void:
	for walker in _walkers:
		walker["t"] += delta / WALK_SECONDS
	_walkers = _walkers.filter(func(w: Dictionary) -> bool: return w["t"] < 1.0)
	for bubble in _bubbles:
		bubble["t"] += delta / BUBBLE_SECONDS
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["t"] < 1.0)
	for i in _rates.size():
		_rates[i] *= exp(-delta / RATE_DECAY_SECONDS)
		_bubble_cooldown[i] = maxf(_bubble_cooldown[i] - delta, 0.0)
	super._process(delta)


func _draw() -> void:
	if match_state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.STREET)
	var x := size.x * HALF
	var y := 0.0
	while y < size.y:
		draw_line(
			Vector2(x, y),
			Vector2(x, minf(y + DASH_LENGTH, size.y)),
			UiPalette.STREET_LINE,
			DASH_WIDTH
		)
		y += DASH_LENGTH * 2.0
	for i in door_points.size():
		_draw_stream(i)
	for walker in _walkers:
		_draw_walker(walker)
	for bubble in _bubbles:
		_draw_bubble(bubble)


func _draw_stream(index: int) -> void:
	var width := clampf(_rates[index] / RATE_FOR_FULL_STREAM, 0.0, 1.0) * STREAM_MAX_WIDTH
	if width < 1.0:
		return
	var color := UiPalette.STORE_COLORS[index]
	color.a = STREAM_ALPHA
	var door := door_points[index]
	draw_line(Vector2(size.x * HALF, door.y), door, color, width)
	draw_circle(Vector2(size.x * HALF, door.y), width * HALF, color)


func _draw_walker(walker: Dictionary) -> void:
	var t: float = walker["t"]
	var start: Vector2 = walker["start"]
	var control: Vector2 = walker["control"]
	var end: Vector2 = walker["end"]
	var pos := start.lerp(control, t).lerp(control.lerp(end, t), t)
	var customer := db().customer_type(walker["type"])
	var alpha := 1.0 if int(walker["store"]) >= 0 else LEAVE_ALPHA
	var radius := EVENT_ICON_RADIUS if walker["event"] else ICON_RADIUS
	if walker["event"]:
		draw_circle(pos, radius + EVENT_RING, UiPalette.WARN)
	UiDraw.customer_icon(self, pos, radius, customer, alpha)


func _draw_bubble(bubble: Dictionary) -> void:
	var t: float = bubble["t"]
	var label: String = bubble["text"]
	var width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + BUBBLE_PAD * 2.0
	var anchor: Vector2 = bubble["anchor"] + Vector2(0, -BUBBLE_RISE * t)
	var left := anchor.x if int(bubble["store"]) == 0 else anchor.x - width
	var rect := Rect2(left, anchor.y - BUBBLE_HEIGHT * HALF, width, BUBBLE_HEIGHT)
	var alpha := 1.0 - t * t
	var fill := UiPalette.PANEL
	fill.a = alpha
	var edge := UiPalette.BAD
	edge.a = alpha
	UiDraw.panel(self, rect, fill, edge, 1)
	var ink := UiPalette.BAD
	ink.a = alpha
	UiDraw.text_centered(self, rect, label, UiPalette.FONT_SMALL, ink)
