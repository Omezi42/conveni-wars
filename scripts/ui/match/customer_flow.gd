class_name CustomerFlow
extends MatchPart
## 2軒のあいだの通りと、両店の入口へ流れ込む人の流れ・見える客(GameDesign.md 2.6節・9.2節・9.5節)。
## 客は1人ずつ通りを歩かせず、入った店の入口へ吸い込まれる短い流れとして描き、
## 流れの太さでどちらの店へ多く入っているかを見せる(1秒に4〜9人来るため)。夜は入口から明かりがこぼれる。
## 流れとは別に、1秒に1人ほどを見える客として通りの端から入口まで歩かせる(自店が取り逃した客を優先する)。

## 見える客が自店へ入った(そのマスを光らせる)
signal visible_entered(product_id: StringName)

const WALK_SECONDS := 0.9
const ICON_RADIUS := 9.0
const EVENT_ICON_RADIUS := 11.0
const EVENT_RING := 2.5
const LANE_JITTER := 22.0
const DOOR_SPREAD := 18.0
const MAX_WALKERS := 60
const LEAVE_ALPHA := 0.45
## 流れの太さに使う、最近の来店の勢い(秒あたり)の減り方
const RATE_DECAY_SECONDS := 1.5
const RATE_FOR_FULL_STREAM := 9.0
const STREAM_MAX_WIDTH := 30.0
const STREAM_ALPHA := 0.35
const VISIBLE_SECONDS := 2.6
## 見える客が通りの端から現れる位置(端からの距離)
const VISIBLE_EDGE := 24.0
const SIDEWALK_WIDTH := 16.0
const CURB := 2.0
const DASH_LENGTH := 16.0
const DASH_WIDTH := 3.0
const DOOR_MAT := Vector2(8, 60)
const LIGHT_RADIUS := 56.0
const LIGHT_RINGS := 4
const HALF_DISC_STEPS := 16
const HALF := 0.5

## 入口の位置(この部品の中の座標。自店・相手の順)
var door_points: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

var _walkers: Array[Dictionary] = []
var _visible := VisibleCustomers.new()
var _rates: Array[float] = [0.0, 0.0]
## 夜の度合い(空と同じ速さで移る)
var _night := -1.0
## 見た目だけの乱数(試合の乱数は使わない。使うと同じ種で同じ試合にならなくなる)
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_visible.priority_store = MatchController.PLAYER
	_visible.entered.connect(_on_visible_entered)


func push_arrival(
	type_id: StringName, store_index_in: int, is_event: bool, product_id: StringName
) -> void:
	_push_visible(type_id, store_index_in, is_event, product_id)
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
	_visible.note_lost(lost_store, category_id)


## 通りの上か下の端から、入った店の入口へ歩かせる(両店とも入らなければ反対の端へ抜ける)
func _push_visible(
	type_id: StringName, store_index_in: int, is_event: bool, product_id: StringName
) -> void:
	var walker := _visible.accept(type_id, store_index_in, is_event, product_id)
	if walker.is_empty():
		return
	var from_top := _rng.randf() < HALF
	var x := size.x * HALF
	var start := Vector2(x, -VISIBLE_EDGE if from_top else size.y + VISIBLE_EDGE)
	var end := Vector2(x, size.y + VISIBLE_EDGE if from_top else -VISIBLE_EDGE)
	if store_index_in >= 0:
		end = door_points[store_index_in]
	_visible.spawn(walker, start, Vector2(x, end.y), end, VISIBLE_SECONDS)


func _on_visible_entered(entered_store: int, product_id: StringName) -> void:
	if entered_store == MatchController.PLAYER:
		visible_entered.emit(product_id)


func _process(delta: float) -> void:
	for walker in _walkers:
		walker["t"] += delta / WALK_SECONDS
	_walkers = _walkers.filter(func(w: Dictionary) -> bool: return w["t"] < 1.0)
	_visible.update(delta)
	for i in _rates.size():
		_rates[i] *= exp(-delta / RATE_DECAY_SECONDS)
	if match_state != null:
		var target := 1.0 if match_state.current_band().night else 0.0
		if _night < 0.0:
			_night = target
		_night = move_toward(_night, target, delta / SkyBackdrop.BLEND_SECONDS)
	super._process(delta)


func _draw() -> void:
	if match_state == null:
		return
	_draw_street()
	for i in door_points.size():
		_draw_stream(i)
	for walker in _walkers:
		_draw_walker(walker)
	_visible.draw(self, db())


## 上から見た通り:両側の歩道・車道・中央の破線。夜は暗くなり、入口の前に店の明かりがこぼれる
func _draw_street() -> void:
	var night := clampf(_night, 0.0, 1.0)
	var road := UiPalette.STREET.lerp(UiPalette.STREET_NIGHT, night)
	var walk := UiPalette.SIDEWALK.lerp(UiPalette.SIDEWALK_NIGHT, night)
	draw_rect(Rect2(Vector2.ZERO, size), road)
	draw_rect(Rect2(0, 0, SIDEWALK_WIDTH, size.y), walk)
	draw_rect(Rect2(size.x - SIDEWALK_WIDTH, 0, SIDEWALK_WIDTH, size.y), walk)
	for x in [SIDEWALK_WIDTH, size.x - SIDEWALK_WIDTH]:
		draw_line(Vector2(x, 0), Vector2(x, size.y), UiPalette.INK, CURB)
	var mid := size.x * HALF
	var y := 0.0
	while y < size.y:
		draw_line(
			Vector2(mid, y),
			Vector2(mid, minf(y + DASH_LENGTH, size.y)),
			UiPalette.STREET_LINE,
			DASH_WIDTH
		)
		y += DASH_LENGTH * 2.0
	for i in door_points.size():
		var door := door_points[i]
		if night > 0.0:
			var facing := 1.0 if i == 0 else -1.0
			for ring in LIGHT_RINGS:
				var light := UiPalette.DOOR_LIGHT
				light.a *= night / LIGHT_RINGS
				_half_disc(door, LIGHT_RADIUS * (ring + 1) / LIGHT_RINGS, facing, light)
		var mat_x := door.x if i == 0 else door.x - DOOR_MAT.x
		var mat := Rect2(mat_x, door.y - DOOR_MAT.y * HALF, DOOR_MAT.x, DOOR_MAT.y)
		draw_rect(mat, UiPalette.STORE_ACCENTS[i])


## 通りの側(facing が正なら右)だけの半円。店の壁へ明かりがはみ出さないようにする
func _half_disc(center: Vector2, radius: float, facing: float, color: Color) -> void:
	var points := PackedVector2Array()
	for step in HALF_DISC_STEPS + 1:
		var angle := -PI * HALF + PI * step / HALF_DISC_STEPS
		points.append(center + Vector2(cos(angle) * facing, sin(angle)) * radius)
	draw_colored_polygon(points, color)


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
		draw_circle(pos, radius + EVENT_RING * 2.0, UiPalette.MONEY)
	UiDraw.customer_icon(self, pos, radius, customer, alpha)
