extends RefCounted
## 天気(GameDesign.md 12章)。

const T = preload("res://tools/tests/test_util.gd")
const STEP := 1.0 / 30.0
const DRAWS := 200
## 出やすさ 3:2:2:2 のとき、晴れが引かれる割合のおよその範囲
const SUNNY_SHARE_MIN := 0.2
const SUNNY_SHARE_MAX := 0.47

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_band_mix_adds_weather_customers()
	_test_same_seed_same_weather()
	_test_draw_follows_chance()
	_test_rain_brings_rain_customers_and_showers()


func _test_band_mix_adds_weather_customers() -> void:
	var sunny := T.new_match()
	var rain := T.new_match(&"veteran", &"veteran", 1, &"rain")
	var morning := T.db().band(&"morning")
	_assert.call(sunny.band_mix(morning) == morning.mix, "sunny keeps the band mix")
	var mix := rain.band_mix(morning)
	_assert.call(int(mix[&"rain_shelter"]) == 3, "rain adds rain shelter customers")
	_assert.call(int(mix[&"office"]) == int(morning.mix[&"office"]), "other weights stay")
	_assert.call(not morning.mix.has(&"rain_shelter"), "the band data itself is not changed")


func _test_same_seed_same_weather() -> void:
	var ids: Array[StringName] = [&"veteran", &"idol"]
	for seed_value in [1, 2, 3, 4, 5]:
		var a := MatchState.new(T.db(), ids, seed_value)
		var b := MatchState.new(T.db(), ids, seed_value)
		_assert.call(a.weather == b.weather, "seed %d draws the same weather" % seed_value)


func _test_draw_follows_chance() -> void:
	var ids: Array[StringName] = [&"veteran", &"idol"]
	var counts := {}
	for seed_value in DRAWS:
		var m := MatchState.new(T.db(), ids, seed_value)
		counts[m.weather.id] = int(counts.get(m.weather.id, 0)) + 1
	for weather in T.db().sorted_weathers():
		_assert.call(counts.has(weather.id), "%s is drawn sometimes" % weather.id)
	var sunny := float(counts.get(&"sunny", 0)) / DRAWS
	_assert.call(
		sunny >= SUNNY_SHARE_MIN and sunny <= SUNNY_SHARE_MAX, "sunny about 1/3 (%.2f)" % sunny
	)


func _test_rain_brings_rain_customers_and_showers() -> void:
	var showers := {&"sunny": 0, &"rain": 0}
	var shelter_band_customers := {&"sunny": 0, &"rain": 0}
	for weather_id: StringName in showers:
		for seed_value in [1, 2, 3, 4]:
			var m := T.new_match(&"veteran", &"veteran", seed_value, weather_id)
			m.event_started.connect(
				func(id: StringName) -> void:
					if id == &"shower":
						showers[weather_id] += 1
			)
			m.customer_arrived.connect(
				func(type_id: StringName, _store: int, is_event: bool, _p: StringName) -> void:
					if type_id == &"rain_shelter" and not is_event:
						shelter_band_customers[weather_id] += 1
			)
			while not m.finished:
				m.advance(STEP)
	_assert.call(shelter_band_customers[&"sunny"] == 0, "no rain shelter band customers if sunny")
	_assert.call(shelter_band_customers[&"rain"] > 0, "rain shelter customers come with rain")
	_assert.call(showers[&"rain"] > showers[&"sunny"], "showers happen more often in rain")
