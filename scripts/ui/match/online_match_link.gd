class_name OnlineMatchLink
extends Control
## オンライン対戦の試合のつなぎ(GameDesign.md 13.1節・13.3節、Architecture.md 7.2節)。画面全体に重ねる。
## 届いた文を Lockstep へ渡して進め、相手を待つ表示・相手が抜けたときのCPUへの引き継ぎ・降参のメニュー・
## 通信のずれや自分が切られたときの打ち切りの幕を持つ。

const TITLE_SCENE := "res://scenes/title.tscn"
const WAIT_TEXT := "相手を待っています…"
const PEER_GONE_TEXT := "相手の通信が切れました。相手の店はCPUが続けます"
const DESYNC_TEXT := "通信のずれで試合を中止しました"
const DROPPED_TEXT := "通信が切れました"
const NOTICE_Y := 112.0
const NOTICE_HEIGHT := 44.0
const NOTICE_SECONDS := 4.0
const CURTAIN := Color(0.05, 0.07, 0.15, 0.82)
const CURTAIN_TEXT_Y := 320.0
const CURTAIN_BUTTON := Rect2(520, 380, 240, 70)
## 降参のメニュー(上端の右端のボタンの下に出す)
const MENU_RECT := Rect2(1000, 70, 268, 176)
const MENU_PAD := 14.0
const MENU_BUTTON_HEIGHT := 60.0

var lockstep: Lockstep

var _config: NetConfig
var _notice := ""
var _notice_timer := 0.0
var _aborted_text := ""
var _menu_open := false
var _resign: PopButton
var _keep: PopButton
var _to_title: PopButton


func setup(runner: MatchRunner, own: int) -> void:
	_config = NetSession.config
	lockstep = Lockstep.new(runner, own, _config, NetSession.send)
	lockstep.desynced.connect(func() -> void: _abort(DESYNC_TEXT))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := MENU_RECT.size.x - MENU_PAD * 2.0
	_resign = _add_button("降参する", UiPalette.BAD, UiPalette.INK_ON_DARK)
	_resign.position = MENU_RECT.position + Vector2(MENU_PAD, MENU_PAD)
	_resign.size = Vector2(width, MENU_BUTTON_HEIGHT)
	_resign.pressed.connect(_on_resign)
	_keep = _add_button("続ける", UiPalette.PAPER, UiPalette.INK)
	_keep.position = _resign.position + Vector2(0, MENU_BUTTON_HEIGHT + MENU_PAD)
	_keep.size = _resign.size
	_keep.pressed.connect(close_menu)
	_to_title = _add_button("タイトルへ", UiPalette.PAPER, UiPalette.INK)
	_to_title.position = CURTAIN_BUTTON.position
	_to_title.size = CURTAIN_BUTTON.size
	_to_title.pressed.connect(_go_title)
	_show_controls()


func _add_button(label: String, fill: Color, ink: Color) -> PopButton:
	var button := PopButton.create(label, fill, ink, UiPalette.FONT_LARGE)
	add_child(button)
	return button


## 相手が抜けて、相手の店をCPUに任せたか(結果は自分の勝ちにする)
func peer_left() -> bool:
	return lockstep.peer_dropped


func is_aborted() -> bool:
	return _aborted_text != ""


func step(delta: float) -> void:
	_read_messages()
	if is_aborted():
		return
	lockstep.step(delta)
	var silent := lockstep.waiting_seconds >= _config.drop_seconds
	if silent and not lockstep.peer_dropped:
		NetSession.send({NetProtocol.KIND: NetProtocol.DROP})
		_peer_gone()


func open_menu() -> void:
	if is_aborted() or lockstep.match_state().finished:
		return
	_menu_open = true
	_show_controls()


func close_menu() -> void:
	_menu_open = false
	_show_controls()


func _process(delta: float) -> void:
	_notice_timer = maxf(_notice_timer - delta, 0.0)
	queue_redraw()


func _read_messages() -> void:
	while not is_aborted():
		var message := NetSession.next_message()
		if message.is_empty():
			return
		match message.get(NetProtocol.KIND, ""):
			NetProtocol.INPUT, NetProtocol.HASH, NetProtocol.END:
				lockstep.receive(message)
			NetProtocol.RESIGN, NetProtocol.PEER_LEFT, NetProtocol.CLOSED:
				_peer_gone()
			NetProtocol.DROP:
				_abort(DROPPED_TEXT)


func _peer_gone() -> void:
	var state := lockstep.match_state()
	if lockstep.peer_dropped or lockstep.peer_ended or state.finished:
		return
	NetSession.close()
	var profile := state.db.cpu_profile(_config.takeover_profile_id)
	lockstep.take_over(CpuPlayer.new(state, lockstep.peer(), profile))
	_notice = PEER_GONE_TEXT
	_notice_timer = NOTICE_SECONDS


## 降参は負けとして残し、タイトルへ戻る(GameDesign.md 13.3節)
func _on_resign() -> void:
	NetSession.send({NetProtocol.KIND: NetProtocol.RESIGN})
	GameSession.resign_online_match()
	_go_title()


func _abort(text: String) -> void:
	NetSession.close()
	_aborted_text = text
	_menu_open = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_controls()


func _go_title() -> void:
	NetSession.close()
	GameSession.online = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _show_controls() -> void:
	_resign.visible = _menu_open
	_keep.visible = _menu_open
	_to_title.visible = is_aborted()


func _draw() -> void:
	if is_aborted():
		draw_rect(Rect2(Vector2.ZERO, size), CURTAIN)
		UiDraw.text_outlined(
			self,
			Vector2(0, CURTAIN_TEXT_Y),
			_aborted_text,
			UiPalette.FONT_HEAD,
			UiPalette.INK_ON_DARK,
			UiPalette.INK,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x
		)
		return
	if _menu_open:
		UiDraw.card(self, MENU_RECT, UiPalette.PAPER)
	var text := _notice if _notice_timer > 0.0 else ""
	if text == "" and lockstep.waiting_seconds >= _config.wait_notice_seconds:
		text = WAIT_TEXT
	if text != "":
		UiDraw.pill(
			self,
			Vector2(size.x * 0.5, NOTICE_Y),
			text,
			UiPalette.FONT_LARGE,
			UiPalette.INK,
			UiPalette.INK_ON_DARK,
			NOTICE_HEIGHT
		)
