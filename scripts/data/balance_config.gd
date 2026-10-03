class_name BalanceConfig
extends Resource
## 試合の数値の設定(`data/balance.tres` の1つだけ)。仕様の数値は GameDesign.md が正。

@export_group("試合(1章)")
## 開店時の棚(マス9つぶんの商品id。空きは &"")。両店ともこの棚で開店する(1.6節)
@export var opening_shelf: Array[StringName]
## 開店時の棚の商品ごとの在庫のロット数(無料)
@export var opening_lots: int
@export var starting_funds: int

@export_group("来店(2章)")
## 店を選ぶ確率を魅力度の何乗に比例させるか
@export var choice_exponent: float

@export_group("棚(4章)")
@export var center_slot: int
@export var center_multiplier: float
@export var corner_multiplier: float
@export var combo_multiplier: float

@export_group("値段(5章)")
## 段階ごとの変化率(安売り・定価・強気の順)
@export var price_step_rates: Array[float]
@export var price_step_names: Array[String]
@export var default_price_step: int
## 「安売り」の段階(タイムセールはこの段階として値段補正を計算する)
@export var sale_price_step: int
## 売値を丸める単位(円)
@export var price_round_unit: int
@export var price_cooldown: float
## 値段補正 = 1 − 敏感さ × 変化率 × この係数
@export var price_effect_factor: float

@export_group("発注と在庫(6章)")
@export var lot_size: int
@export var delivery_seconds: float
@export var waste_seconds: float
@export var low_stock_threshold: int

@export_group("結果と演出(9章)")
## ふりかえりの利益を記録する間隔(秒)
@export var history_interval: float
## 時間帯の客のうち自店に入った割合がこれ以上なら「読み的中!」、これ以下なら外れ(9.3節)
@export var read_hit_share: float
@export var read_miss_share: float
## いまの時間帯の割合を上端に出し始める、両店に入った客の人数(9.2節)
@export var live_share_min_visitors: int

@export_group("突発イベント(11章)")
@export var event_interval_min: float
@export var event_interval_max: float
@export var event_announce_seconds: float
@export var event_customer_count: int
@export var event_arrival_seconds: float
@export var event_buy_multiplier: int
@export var event_per_product_limit: int
## 自店に入ったイベントの客がこの割合以上なら「大口獲得!」
@export var big_catch_ratio: float


func price_step_count() -> int:
	return price_step_rates.size()


## 時間帯の客の割合が「読み的中」なら 1、「外れ」なら -1、そのあいだか客がいなければ 0(9.3節)
func share_grade(share: float) -> int:
	if share >= read_hit_share:
		return 1
	if share >= 0.0 and share <= read_miss_share:
		return -1
	return 0
