extends Node
## オンライン対戦の中継サーバーとの接続(GameDesign.md 13章、Architecture.md 7.1節)。autoload。
## 部屋・店長選択・試合の画面をまたいで1本の WebSocket を持ち、届いた文を順に溜める。
## 画面は next_message() で1つずつ取り出し、次の画面へ移る文を受けたらそこで取り出すのをやめる(残りは次の画面が読む)。

enum State { IDLE, CONNECTING, WAITING, PAIRED, CLOSED }

const ROOM_PATH := "/room/"
const MATCH_PATH := "/match"
const OP_CREATE := "create"
const OP_JOIN := "join"
## 試合の計算の作りを変えて、古い版と対戦すると食い違うようになったら上げる
const PROTOCOL_VERSION := 1
## テストで中継サーバーのURLを差し替える環境変数
const SERVER_ENV := "CONVENI_SERVER"

var state := State.IDLE
var role := ""
var code := ""
var config: NetConfig

var _peer: WebSocketPeer
var _inbox: Array[Dictionary] = []


func _ready() -> void:
	config = NetConfig.load_default()


func _process(_delta: float) -> void:
	poll()


func server_url() -> String:
	var override := OS.get_environment(SERVER_ENV)
	return override if override != "" else config.server_url


func is_available() -> bool:
	return server_url() != ""


func is_host() -> bool:
	return role == NetProtocol.HOST


## 自分の店の番号(部屋を作った側が店0。GameDesign.md 13.2節)
func own_store() -> int:
	return 0 if is_host() else 1


func version() -> String:
	return "%s/%d" % [Engine.get_version_info().string, PROTOCOL_VERSION]


func open_room(room_code: String, create: bool) -> bool:
	code = room_code
	var op := OP_CREATE if create else OP_JOIN
	return _open("%s%s%s?op=%s" % [server_url(), ROOM_PATH, code, op])


## ランダムマッチで待っている人と組む(いなければ来るまで待つ。GameDesign.md 13.2節)
func open_random() -> bool:
	code = ""
	return _open(server_url() + MATCH_PATH)


func _open(url: String) -> bool:
	var keep_code := code
	close()
	code = keep_code
	_peer = WebSocketPeer.new()
	if _peer.connect_to_url(url) != OK:
		_peer = null
		state = State.CLOSED
		return false
	state = State.CONNECTING
	return true


func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	var ready_state := _peer.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN and state == State.CONNECTING:
		state = State.WAITING
	while _peer.get_available_packet_count() > 0:
		_receive(_peer.get_packet().get_string_from_utf8())
	if ready_state == WebSocketPeer.STATE_CLOSED:
		_peer = null
		state = State.CLOSED
		_inbox.append({NetProtocol.KIND: NetProtocol.CLOSED})


func send(message: Dictionary) -> void:
	if _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send_text(JSON.stringify(message))


## 溜まった文を1つ取り出す。無ければ空の辞書
func next_message() -> Dictionary:
	if _inbox.is_empty():
		return {}
	return _inbox.pop_front()


## 接続を閉じ、溜まった文も捨てる(閉じたことは文にしない)
func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_inbox.clear()
	state = State.IDLE
	role = ""


func _receive(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return
	var message: Dictionary = data
	if message.get(NetProtocol.KIND, "") == NetProtocol.PAIRED:
		state = State.PAIRED
		role = message.get(NetProtocol.ROLE, "")
	_inbox.append(message)
