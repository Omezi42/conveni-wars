class_name NetConfig
extends Resource
## オンライン対戦の設定(GameDesign.md 13章、Architecture.md 7章)。

const PATH := "res://data/net.tres"

## 中継サーバーの WebSocket のURL(末尾の / は付けない)。空ならオンライン対戦を出さない
@export var server_url: String
## 操作を何tick後に実行するか(0.17秒ぶん。相手へ届くまでの時間を見込む)
@export var input_delay_ticks: int
## 自分の操作を何tickごとにまとめて送るか
@export var send_interval_ticks: int
## 相手を待つのがこの秒数を超えたら「相手を待っています…」を出す
@export var wait_notice_seconds: float
## 相手を待つのがこの秒数を超えたら、通信が切れたとみなす
@export var drop_seconds: float
## 合言葉の桁数
@export var code_digits: int
## 部屋を作るとき、合言葉が使われていたら別の合言葉で作り直す回数
@export var create_retries: int
## 相手の通信が切れたあと相手の店を任せるCPUの強さ
@export var takeover_profile_id: StringName


static func load_default() -> NetConfig:
	return load(PATH) as NetConfig
