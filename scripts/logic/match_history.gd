class_name MatchHistory
extends RefCounted
## 試合の記録(GameDesign.md 9.4節のふりかえり)。一定の間隔ごとの両店の利益と、突発イベントが起きた時刻を持つ。


class EventMark:
	extends RefCounted
	var event_id: StringName
	## 開店からの秒
	var time: float
	## 店ごとの入った客の数(イベントが終わってから入る)
	var store_counts: Array[int] = []

	func _init(id: StringName, at: float) -> void:
		event_id = id
		time = at


## 記録した時刻(開店からの秒)
var times: PackedFloat32Array = []
## 店ごとの、times と同じ順の利益
var profits: Array[PackedInt32Array] = []
var event_marks: Array[EventMark] = []

var _interval: float
var _next_time := 0.0


func _init(interval: float) -> void:
	_interval = interval


## 記録の時刻に達していれば両店の利益を1つ記録する
func record(now: float, stores: Array[StoreState]) -> void:
	if now < _next_time:
		return
	_append(now, stores)
	_next_time = (floorf(now / _interval) + 1.0) * _interval


## 試合の終わりの値を必ず1つ記録する
func record_final(end_time: float, stores: Array[StoreState]) -> void:
	if not times.is_empty() and is_equal_approx(times[times.size() - 1], end_time):
		return
	_append(end_time, stores)


func add_event(event_id: StringName, time: float) -> void:
	event_marks.append(EventMark.new(event_id, time))


func finish_event(store_counts: Array[int]) -> void:
	if not event_marks.is_empty():
		event_marks.back().store_counts = store_counts.duplicate()


func _append(now: float, stores: Array[StoreState]) -> void:
	if profits.is_empty():
		for i in stores.size():
			profits.append(PackedInt32Array())
	times.append(now)
	for store in stores:
		profits[store.index].append(store.profit())
