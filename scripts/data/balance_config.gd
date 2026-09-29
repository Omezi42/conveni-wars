class_name BalanceConfig
extends Resource
## 試合の数値の設定(`data/balance.tres` の1つだけ)。仕様の数値は GameDesign.md が正。

@export_group("試合(1章)")
@export var prep_seconds: float
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
