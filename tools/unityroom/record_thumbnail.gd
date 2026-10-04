extends SceneTree
## unityroom のサムネイルGIFの素材コマを書き出す(タイトル → 試合の数場面 → 結果)。
## 自店も CPU(つよい)に遊ばせ、相手は CPU(やさしい)にして、売れていく試合を撮る。
## GIFへの変換は tools/unityroom/make_thumbnails.sh が行う(コマの選び方と切り抜きもそちら)。
## ウィンドウを開いて描くため --headless では撮れない。コマの間隔を固定するため --fixed-fps を付ける:
##   godot --path . --fixed-fps 30 --script res://tools/unityroom/record_thumbnail.gd -- <出力フォルダ>
## 画面のクラスは autoload を参照するため名前で参照しない(capture_screens.gd と同じ理由)。

const PLAYER := 0
const FPS := 30
## 何コマに1枚書き出すか(30fps ÷ 3 = 10fps)
const FRAME_EVERY := 3
const SEED := 20260929
const MANAGER_ID := &"idol"
const WEATHER_ID := &"sunny"
const PLAYER_CPU_ID := &"hard"
const RIVAL_CPU_ID := &"easy"
## 本物の戦績を書き換えないよう、撮る間はこのファイルへ保存する
const TEST_SAVE_PATH := "user://thumbnail_save.cfg"
## タイトルの通りに見える客が歩き出すまで待つ秒数と、撮る秒数
const TITLE_WARMUP := 5.0
const TITLE_SECONDS := 2.0
## 撮る場面(開店からの秒)。開店直後の売れ始め・昼の時間帯へ変わる所(75秒)・閉店
const SEGMENTS := [
	["2_open", 6.0, 11.0],
	["3_rush", 74.5, 79.5],
	["4_close", 295.5, 300.0],
]
const RESULT_SECONDS := 3.0
const RESULT_SEGMENT := "5_result"

var _out_dir := ""
var _session: Node
var _frame := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = (
		args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://logs/thumbnail")
	)
	_session = root.get_node("GameSession")
	_session.save = _test_save()

	var title := _show("res://scenes/title.tscn")
	await _skip(TITLE_WARMUP)
	await _record("1_title", TITLE_SECONDS)
	title.queue_free()

	_session.prepare_match(MANAGER_ID)
	_session.match_seed = SEED
	_session.weather_id = WEATHER_ID
	var controller := _show("res://scenes/match.tscn")
	var state: MatchState = controller.match_state
	var player_cpu := CpuPlayer.new(state, PLAYER, state.db.cpu_profile(PLAYER_CPU_ID))
	for segment in SEGMENTS:
		while state.elapsed < segment[1]:
			await _tick(controller, player_cpu, "")
		while state.elapsed < segment[2] and not state.finished:
			await _tick(controller, player_cpu, segment[0])
	while _find(&"ResultScreen") == null:
		await _tick(controller, player_cpu, "")
	controller.queue_free()
	await _record(RESULT_SEGMENT, RESULT_SECONDS)

	print("recorded to ", _out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	quit()


## 試合を1コマ進める。撮影の窓が後ろへ回ると試合が一時停止するため(GameDesign.md 9.9節)、撮る間は閉じておく
func _tick(controller: Control, player_cpu: CpuPlayer, segment: String) -> void:
	controller._pause.close()
	player_cpu.update(1.0 / FPS)
	await _next_frame(segment)


func _skip(seconds: float) -> void:
	for i in int(seconds * FPS):
		await _next_frame("")


func _record(segment: String, seconds: float) -> void:
	for i in int(seconds * FPS):
		await _next_frame(segment)


## 1コマ描いて、場面の中なら FRAME_EVERY コマに1枚を <出力>/<場面>/f0001.png の形で書き出す
func _next_frame(segment: String) -> void:
	await process_frame
	if segment == "":
		return
	var dir := _out_dir.path_join(segment)
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		_frame = 0
	_frame += 1
	if _frame % FRAME_EVERY != 0:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(dir.path_join("f%04d.png" % (_frame / FRAME_EVERY)))


func _show(path: String) -> Control:
	var scene: Control = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	return scene


func _find(class_id: StringName) -> Node:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script != null and script.get_global_name() == class_id:
			return child
	return null


## 1試合遊んだことのある戦績にし(はじめるで店長選択を出す)、ヒントは出し終えたことにする
func _test_save() -> SaveData:
	var save := SaveData.new(TEST_SAVE_PATH)
	save.wins = 1
	save.cpu_profile_id = RIVAL_CPU_ID
	for hint in [
		HintLayer.OPENING,
		HintLayer.LOST,
		HintLayer.LOW_STOCK,
		HintLayer.EVENT,
		HintLayer.UNDERCUT,
		HintLayer.SKILL,
		HintLayer.AUTO_ORDER
	]:
		save.mark_hint(hint)
	return save
