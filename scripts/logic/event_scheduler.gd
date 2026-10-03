class_name EventScheduler
extends RefCounted
## 突発イベントの抽選・予告・客の到着(GameDesign.md 11章)。MatchState が持ち、順に問い合わせる。
## 時刻はすべて開店からの経過秒。

## 次に起きるイベント。もう起きなければ null
var next_event: EventData
var next_start := INF
## いま客が来ているイベント。無ければ null
var active_event: EventData
var active_start := 0.0
var active_spawned := 0
## 店ごとの、このイベントの客が入った数
var active_counts: Array[int] = []

var _db: GameDatabase
var _rng: RandomNumberGenerator
var _duration: float
var _weather: WeatherData
var _announced: Array[bool] = []


func _init(
	database: GameDatabase, rng: RandomNumberGenerator, store_count: int, weather: WeatherData
) -> void:
	_db = database
	_rng = rng
	_weather = weather
	_duration = database.match_duration()
	_announced.resize(store_count)
	active_counts.resize(store_count)
	_schedule_after(0.0)


## 予告が見える時刻になった店へ一度だけ true を返す
func take_announcement(store_index: int, lead: float, now: float) -> bool:
	if next_event == null or _announced[store_index] or now < next_start - lead:
		return false
	_announced[store_index] = true
	return true


## その店に見えている予告。無ければ null
func announced_event(lead: float, now: float) -> EventData:
	if next_event != null and now >= next_start - lead:
		return next_event
	return null


## 開始時刻になったら次のイベントを始め、その次を抽選する
func try_start(now: float) -> bool:
	if next_event == null or now < next_start:
		return false
	active_event = next_event
	active_start = next_start
	active_spawned = 0
	active_counts.fill(0)
	_schedule_after(next_start)
	return true


## いま生成すべきイベントの客の数
func customers_due(now: float) -> int:
	if active_event == null:
		return 0
	var balance := _db.balance
	var progress := clampf((now - active_start) / balance.event_arrival_seconds, 0.0, 1.0)
	var target := int(floor(progress * balance.event_customer_count))
	return maxi(target - active_spawned, 0)


## store_index はイベントの客が入った店(どちらにも入らなければ -1)
func record_customer(store_index: int) -> void:
	active_spawned += 1
	if store_index >= 0:
		active_counts[store_index] += 1


func is_active_done() -> bool:
	return active_event != null and active_spawned >= _db.balance.event_customer_count


func finish_active() -> void:
	active_event = null


## other と同じ状態にする(スナップショット用。乱数は自分のものを使い続ける)
func copy_from(other: EventScheduler) -> void:
	next_event = other.next_event
	next_start = other.next_start
	active_event = other.active_event
	active_start = other.active_start
	active_spawned = other.active_spawned
	active_counts = other.active_counts.duplicate()
	_announced = other._announced.duplicate()


func _schedule_after(from_time: float) -> void:
	var balance := _db.balance
	next_event = null
	next_start = INF
	_announced.fill(false)
	var start := from_time
	while true:
		start += _rng.randf_range(balance.event_interval_min, balance.event_interval_max)
		# 試合終了までに客が来終わらないイベントは起こさない
		if start + balance.event_arrival_seconds > _duration:
			return
		var candidates := _events_in_band(_db.band_at(start).id)
		if not candidates.is_empty():
			next_event = _pick(candidates)
			next_start = start
			return


## 天気の重みに比例して選ぶ(GameDesign.md 12.2節)
func _pick(candidates: Array[EventData]) -> EventData:
	var total := 0
	for data in candidates:
		total += _weather.event_weight(data.id)
	var roll := _rng.randi_range(1, total)
	for data in candidates:
		roll -= _weather.event_weight(data.id)
		if roll <= 0:
			return data
	return candidates.back()


func _events_in_band(band_id: StringName) -> Array[EventData]:
	var result: Array[EventData] = []
	for data in _db.sorted_events():
		if data.band_ids.has(band_id):
			result.append(data)
	return result
