extends Node
## BGMと効果音の再生(GameDesign.md 9.8節、Architecture.md 4.3節)。autoload。
## 素材は assets/audio/{bgm,se}/<id>.ogg。同じ効果音は MIN_INTERVAL に1回までに間引く。

const BGM_PATH := "res://assets/audio/bgm/%s.ogg"
const SE_PATH := "res://assets/audio/se/%s.ogg"
const SE_IDS: Array[StringName] = [
	&"sale",
	&"order",
	&"delivery",
	&"stockout",
	&"click",
	&"notice",
	&"cutin",
	&"big_catch",
	&"reversal",
	&"win",
	&"lose",
]
const BGM_BUS := &"BGM"
const SE_BUS := &"SE"
const SE_VOICES := 8
## 同じ効果音を鳴らす最短の間隔(ミリ秒)
const MIN_INTERVAL_MSEC := 100

var _bgm := AudioStreamPlayer.new()
var _bgm_id: StringName = &""
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [BGM_BUS, SE_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_bgm.bus = BGM_BUS
	add_child(_bgm)
	for i in SE_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SE_BUS
		add_child(voice)
		_voices.append(voice)
	for id in SE_IDS:
		_streams[id] = load(SE_PATH % id)
	var save: SaveData = get_node("/root/GameSession").save
	apply_volumes(save.bgm_volume, save.se_volume)


func apply_volumes(bgm: float, se: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BGM_BUS), linear_to_db(bgm))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SE_BUS), linear_to_db(se))


## 同じ曲が流れていれば何もしない
func play_bgm(id: StringName) -> void:
	set_bgm_speed(1.0)
	if id == _bgm_id and _bgm.playing:
		return
	var stream := load(BGM_PATH % id) as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	_bgm_id = id
	_bgm.stream = stream
	_bgm.play()


func stop_bgm() -> void:
	_bgm_id = &""
	_bgm.stop()


func set_bgm_speed(scale: float) -> void:
	_bgm.pitch_scale = scale


func play_se(id: StringName, pitch := 1.0) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -MIN_INTERVAL_MSEC)) < MIN_INTERVAL_MSEC:
		return
	_last_played[id] = now
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.play()
