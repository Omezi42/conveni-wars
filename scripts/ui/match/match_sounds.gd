class_name MatchSounds
extends Node
## 試合のシグナルを受けて効果音とBGMの速さを決める(GameDesign.md 9.8節、Architecture.md 4.3節)。
## 大口獲得・逆転は演出を出す MatchController が直接鳴らす。

## 続けて売れるたびに上げる音程と、その上限
const SALE_PITCH_STEP := 0.03
const SALE_PITCH_MAX := 1.5
## この秒数売れなければ音程を戻す
const SALE_PITCH_RESET := 1.0
## 残りこの秒数でBGMを速くする(9.3節)
const HURRY_SECONDS := 30.0
const HURRY_SPEED := 1.15

var _match: MatchState
var _sale_pitch := 1.0
var _since_sale := 0.0


func setup(match_state: MatchState) -> void:
	_match = match_state
	_match.purchased.connect(_on_purchased)
	_match.ordered.connect(_only_player.bind(&"order"))
	_match.delivery_arrived.connect(
		func(store: int, _id: StringName, _count: int) -> void:
			_only_player(store, &"", &"delivery")
	)
	_match.band_changed.connect(func(_id: StringName) -> void: AudioDirector.play_se(&"cutin"))
	_match.event_announced.connect(
		func(_id: StringName, store: int) -> void: _only_player(store, &"", &"notice")
	)
	_match.match_ended.connect(_on_match_ended)
	AudioDirector.play_bgm(&"match")


func _process(delta: float) -> void:
	if _match == null:
		return
	_since_sale += delta
	if _since_sale >= SALE_PITCH_RESET:
		_sale_pitch = 1.0
	if not _match.finished and _match.remaining_time() <= HURRY_SECONDS:
		AudioDirector.set_bgm_speed(HURRY_SPEED)


func _only_player(store: int, _id: StringName, se: StringName) -> void:
	if store == ViewSide.own:
		AudioDirector.play_se(se)


func _on_purchased(store: int, product_id: StringName, _count: int, _amount: int) -> void:
	if store != ViewSide.own:
		return
	AudioDirector.play_se(&"sale", _sale_pitch)
	_sale_pitch = minf(_sale_pitch + SALE_PITCH_STEP, SALE_PITCH_MAX)
	_since_sale = 0.0
	var own := _match.stores[ViewSide.own]
	if own.stock(product_id) <= 0 and own.is_on_shelf(product_id):
		AudioDirector.play_se(&"stockout")


## 勝ち負けの音は結果画面が鳴らす
func _on_match_ended(_result: MatchResult) -> void:
	AudioDirector.stop_bgm()
