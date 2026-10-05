class_name OnlineLobbyScreen
extends Control
## オンライン対戦の部屋(GameDesign.md 13.2節、Architecture.md 7.3節)。部屋を作って合言葉を出すか、合言葉を入れて入るか、ランダムマッチで待つ。
## 合言葉は画面の数字のボタン(とキーボードの数字)で入れる。2人がそろったら版を確かめ合い、店長選択へ進む。

enum Mode { MENU, HOSTING, ENTRY, JOINING, SEARCHING }

const SELECT_SCENE := "res://scenes/manager_select.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const HEADER_RECT := Rect2(440, 22, 400, 52)
const RECORD_Y := 112.0
const PANEL_RECT := Rect2(340, 136, 600, 440)
const MENU_BUTTON_SIZE := Vector2(400, 84)
const MENU_FIRST_Y := 168.0
const MENU_GAP := 22.0
const BACK_RECT := Rect2(540, 610, 200, 60)
const CODE_LABEL_Y := 196.0
const CODE_BOX := Vector2(64, 84)
const CODE_BOX_GAP := 14.0
const CODE_BOX_Y := 200.0
const KEY_SIZE := Vector2(110, 50)
const KEY_GAP := Vector2(12, 8)
const KEY_TOP := 298.0
const KEY_COLUMNS := 3
const LABEL_DELETE := "消す"
const LABEL_ENTER := "入る"
const NOTE_Y := 360.0
const STATUS_Y := 548.0
const DOTS_PER_SECOND := 2.0
const MAX_DOTS := 3

var _mode := Mode.MENU
var _config: NetConfig
var _code := ""
var _status := ""
var _error := ""
var _create_tries := 0
var _menu_buttons: Array[PopButton] = []
var _keys: Array[PopButton] = []
var _enter_key: PopButton
var _back: PopButton
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_config = NetSession.config
	GameSession.online = false
	NetSession.close()
	AudioDirector.play_bgm(&"menu")
	var create := _add_button("部屋を作る", UiPalette.MONEY, _menu_rect(0), UiPalette.FONT_HEAD)
	create.pressed.connect(_on_create)
	var join := _add_button("合言葉で入る", UiPalette.PAPER, _menu_rect(1), UiPalette.FONT_HEAD)
	join.pressed.connect(_on_join_pressed)
	var random := _add_button("ランダムマッチ", UiPalette.PAPER, _menu_rect(2), UiPalette.FONT_HEAD)
	random.pressed.connect(_on_random)
	_menu_buttons = [create, join, random]
	var labels: Array[String] = []
	for digit in range(1, 10):
		labels.append(str(digit))
	labels.append_array([LABEL_DELETE, "0", LABEL_ENTER])
	for i in labels.size():
		var fill := UiPalette.MONEY if labels[i] == LABEL_ENTER else UiPalette.PAPER
		var key := _add_button(labels[i], fill, _key_rect(i), UiPalette.FONT_HEAD)
		key.pressed.connect(_on_key.bind(labels[i]))
		_keys.append(key)
		if labels[i] == LABEL_ENTER:
			_enter_key = key
	_back = _add_button("タイトルへ", UiPalette.PAPER, BACK_RECT, UiPalette.FONT_LARGE)
	_back.pressed.connect(_on_back)
	if not NetSession.is_available():
		_error = "オンライン対戦のサーバーが用意されていません"
	_set_mode(Mode.MENU)


func _add_button(label: String, fill: Color, rect: Rect2, font_size: int) -> PopButton:
	var button := PopButton.create(label, fill, UiPalette.INK, font_size)
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button


func _menu_rect(index: int) -> Rect2:
	var x := PANEL_RECT.get_center().x - MENU_BUTTON_SIZE.x * 0.5
	return Rect2(
		Vector2(x, MENU_FIRST_Y + index * (MENU_BUTTON_SIZE.y + MENU_GAP)), MENU_BUTTON_SIZE
	)


func _key_rect(index: int) -> Rect2:
	var width := KEY_SIZE.x * KEY_COLUMNS + KEY_GAP.x * (KEY_COLUMNS - 1)
	var left := PANEL_RECT.get_center().x - width * 0.5
	var column := index % KEY_COLUMNS
	var row := index / KEY_COLUMNS
	var pos := Vector2(
		left + column * (KEY_SIZE.x + KEY_GAP.x), KEY_TOP + row * (KEY_SIZE.y + KEY_GAP.y)
	)
	return Rect2(pos, KEY_SIZE)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	for button in _menu_buttons:
		button.visible = mode == Mode.MENU
		button.disabled = not NetSession.is_available()
	for key in _keys:
		key.visible = mode == Mode.ENTRY
	_enter_key.disabled = _code.length() < _config.code_digits
	_back.text = "タイトルへ" if mode == Mode.MENU else "やめる"
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()
	if _mode == Mode.MENU or _mode == Mode.ENTRY:
		return
	while true:
		var message := NetSession.next_message()
		if message.is_empty():
			return
		if _handle(message):
			return


## 店長選択へ進んだら true(残りの文は次の画面が読む)
func _handle(message: Dictionary) -> bool:
	match message.get(NetProtocol.KIND, ""):
		NetProtocol.PAIRED:
			_status = "相手が見つかりました"
			(
				NetSession
				. send(
					{
						NetProtocol.KIND: NetProtocol.HELLO,
						NetProtocol.VERSION: NetSession.version(),
						NetProtocol.WEB: OS.has_feature("web"),
					}
				)
			)
		NetProtocol.HELLO:
			return _on_hello(message)
		NetProtocol.ERROR:
			_on_refused(String(message.get(NetProtocol.REASON, "")))
		NetProtocol.PEER_LEFT:
			_fail("相手が部屋を出ました")
		NetProtocol.CLOSED:
			if _error == "":
				_fail("サーバーにつながりませんでした")
	return false


func _on_hello(message: Dictionary) -> bool:
	var same_version: bool = message.get(NetProtocol.VERSION, "") == NetSession.version()
	var same_platform: bool = message.get(NetProtocol.WEB, false) == OS.has_feature("web")
	if not same_version or not same_platform:
		_fail("相手と遊んでいる版が違うため対戦できません")
		return false
	GameSession.online = true
	GameSession.online_own = NetSession.own_store()
	get_tree().change_scene_to_file(SELECT_SCENE)
	return true


func _on_refused(reason: String) -> void:
	match reason:
		NetProtocol.TAKEN:
			if _create_tries < _config.create_retries:
				_open_new_room()
				return
			_fail("部屋を作れませんでした。もう一度試してください")
		NetProtocol.MISSING:
			_fail("その合言葉の部屋はありません")
		NetProtocol.FULL:
			_fail("その部屋は満員です")
		_:
			_fail("部屋に入れませんでした")


func _fail(text: String) -> void:
	NetSession.close()
	_error = text
	_code = ""
	_set_mode(Mode.MENU)


func _on_create() -> void:
	_create_tries = 0
	_error = ""
	_open_new_room()


func _open_new_room() -> void:
	_create_tries += 1
	_code = ""
	for i in _config.code_digits:
		_code += str(_rng.randi_range(0, 9))
	_status = "相手が入るのを待っています"
	if not NetSession.open_room(_code, true):
		_fail("サーバーにつながりませんでした")
		return
	_set_mode(Mode.HOSTING)


func _on_random() -> void:
	_error = ""
	_code = ""
	_status = "相手を探しています"
	if not NetSession.open_random():
		_fail("サーバーにつながりませんでした")
		return
	_set_mode(Mode.SEARCHING)


func _on_join_pressed() -> void:
	_error = ""
	_code = ""
	_set_mode(Mode.ENTRY)


func _on_key(label: String) -> void:
	match label:
		LABEL_DELETE:
			_code = _code.left(-1)
		LABEL_ENTER:
			_join()
			return
		_:
			if _code.length() < _config.code_digits:
				_code += label
	_set_mode(Mode.ENTRY)


func _join() -> void:
	if _code.length() < _config.code_digits:
		return
	_error = ""
	_status = "つないでいます"
	if not NetSession.open_room(_code, false):
		_fail("サーバーにつながりませんでした")
		return
	_set_mode(Mode.JOINING)


func _on_back() -> void:
	if _mode == Mode.MENU:
		get_tree().change_scene_to_file(TITLE_SCENE)
		return
	NetSession.close()
	_code = ""
	_set_mode(Mode.MENU)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or _mode != Mode.ENTRY:
		return
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		_on_key(str(key.keycode - KEY_0))
	elif key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		_on_key(str(key.keycode - KEY_KP_0))
	elif key.keycode == KEY_BACKSPACE:
		_on_key(LABEL_DELETE)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_on_key(LABEL_ENTER)


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	SkyBackdrop.paint(self, screen, UiPalette.MENU_SKY_TOP, UiPalette.MENU_SKY_BOTTOM, 0.0)
	UiDraw.panel(
		self, HEADER_RECT, UiPalette.INK, Color.TRANSPARENT, 0, int(HEADER_RECT.size.y * 0.5)
	)
	UiDraw.text_centered(self, HEADER_RECT, "オンライン対戦", UiPalette.FONT_HEAD, UiPalette.INK_ON_DARK)
	var save := GameSession.save
	var record := "オンライン戦績  %d勝 %d敗 %d分" % [save.online_wins, save.online_losses, save.online_draws]
	UiDraw.text_outlined(
		self,
		Vector2(0, RECORD_Y),
		record,
		UiPalette.FONT_LARGE,
		UiPalette.INK_ON_DARK,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x
	)
	UiDraw.card(self, PANEL_RECT, UiPalette.PAPER)
	match _mode:
		Mode.HOSTING:
			_draw_code("合言葉", "相手にこの合言葉を伝えてください")
			_draw_status(_status + _dots())
		Mode.ENTRY:
			_draw_code("合言葉を入れる", "")
		Mode.JOINING:
			_draw_code("合言葉", "")
			_draw_status(_status + _dots())
		Mode.SEARCHING:
			_draw_line_at(CODE_BOX_Y + CODE_BOX.y * 0.5, "ランダムマッチ", UiPalette.INK_SOFT)
			_draw_status(_status + _dots())
	if _error != "":
		_draw_line_at(STATUS_Y, _error, UiPalette.BAD)


func _draw_code(label: String, note: String) -> void:
	_draw_line_at(CODE_LABEL_Y - UiPalette.FONT_LARGE, label, UiPalette.INK_SOFT)
	var digits := _config.code_digits
	var width := CODE_BOX.x * digits + CODE_BOX_GAP * (digits - 1)
	var left := PANEL_RECT.get_center().x - width * 0.5
	for i in digits:
		var box := Rect2(Vector2(left + i * (CODE_BOX.x + CODE_BOX_GAP), CODE_BOX_Y), CODE_BOX)
		var filled := i < _code.length()
		var fill := UiPalette.INK_ON_DARK if filled else UiPalette.PAPER_DIM
		UiDraw.panel(self, box, fill, UiPalette.INK, UiPalette.OUTLINE, UiPalette.RADIUS_SMALL)
		if filled:
			UiDraw.text_centered(self, box, _code[i], UiPalette.FONT_HUGE, UiPalette.INK)
	if note != "":
		_draw_line_at(NOTE_Y, note, UiPalette.INK)


func _draw_status(text: String) -> void:
	_draw_line_at(STATUS_Y - UiPalette.FONT_HEAD * 2.0, text, UiPalette.INK)


func _draw_line_at(y: float, text: String, color: Color) -> void:
	UiDraw.text(
		self,
		Vector2(PANEL_RECT.position.x, y),
		text,
		UiPalette.FONT_LARGE,
		color,
		HORIZONTAL_ALIGNMENT_CENTER,
		PANEL_RECT.size.x
	)


func _dots() -> String:
	var count := int(Time.get_ticks_msec() / 1000.0 * DOTS_PER_SECOND) % (MAX_DOTS + 1)
	return ".".repeat(count)
