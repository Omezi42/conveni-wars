class_name TitleStreet
extends Control
## タイトルの背景の試合(GameDesign.md 9.5節)。裏でCPUどうしの MatchState を回し、見える客を歩道の端から
## 2軒の店の入口へ歩かせる。押す前から何をするゲームかを見せるため。音は鳴らさない(MatchSounds を置かない)。
## 試合が終わったら店長を選び直して次の試合を始める。

const CPU_PROFILE := &"standard"
const WALK_SPEED := 170.0
## 画面の外のどこから歩き始めるか(端からの距離)
const OFFSCREEN := 40.0
## 入口の前から店の中へ入るときに上がる量
const ENTER_RISE := 30.0
const HALF := 0.5

## 見える客が歩く高さ(絵の中心)と、店ごとの入口の中心の横の位置
var walk_y := 0.0
var door_x: Array[float] = [0.0, 0.0]

var _match: MatchState
var _cpus: Array[CpuPlayer] = []
var _visible := VisibleCustomers.new()
## 見た目と試合の種の乱数(タイトルを開くたびに違う試合にする)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_start_match()


func _physics_process(delta: float) -> void:
	if _match.finished:
		_start_match()
		return
	_match.advance(delta)
	for cpu in _cpus:
		cpu.update(delta)


func _process(delta: float) -> void:
	_visible.update(delta)
	queue_redraw()


func _draw() -> void:
	_visible.draw(self, _match.db)


func _start_match() -> void:
	var db := GameDatabase.get_default()
	var managers := db.sorted_managers()
	var first := _rng.randi_range(0, managers.size() - 1)
	var second := (first + _rng.randi_range(1, managers.size() - 1)) % managers.size()
	var ids: Array[StringName] = [managers[first].id, managers[second].id]
	_match = MatchState.new(db, ids, _rng.randi())
	_cpus.clear()
	for store in _match.stores:
		_cpus.append(CpuPlayer.new(_match, store.index, db.cpu_profile(CPU_PROFILE)))
	_match.customer_lost.connect(_visible.note_lost)
	_match.customer_arrived.connect(_on_customer_arrived)


## 左右どちらかの画面の外から歩道を歩き、入った店の入口で中へ入る(どちらにも入らなければ反対の外へ抜ける)
func _on_customer_arrived(
	type_id: StringName, store_index: int, is_event: bool, product_id: StringName
) -> void:
	var walker := _visible.accept(type_id, store_index, is_event, product_id)
	if walker.is_empty():
		return
	var from_left := _rng.randf() < HALF
	var start := Vector2(-OFFSCREEN if from_left else size.x + OFFSCREEN, walk_y)
	var end := Vector2(size.x + OFFSCREEN if from_left else -OFFSCREEN, walk_y)
	var control := start.lerp(end, HALF)
	if store_index >= 0:
		control = Vector2(door_x[store_index], walk_y)
		end = control - Vector2(0, ENTER_RISE)
	var distance := start.distance_to(control) + control.distance_to(end)
	_visible.spawn(walker, start, control, end, distance / WALK_SPEED)
