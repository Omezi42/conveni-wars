class_name ManagerSkills
extends RefCounted
## 店長スキル(GameDesign.md 7章)。パッシブの補正値の問い合わせと、アクティブの発動。
## 効果の種類はここ、数値は ManagerData の params に持つ。


static func order_cost_multiplier(manager: ManagerData) -> float:
	if manager.passive_kind == SkillKinds.Passive.ORDER_DISCOUNT:
		return float(manager.passive_params["cost_multiplier"])
	return 1.0


static func appeal_multiplier(manager: ManagerData, customer_type_id: StringName) -> float:
	if manager.passive_kind == SkillKinds.Passive.CUSTOMER_APPEAL:
		var targets: Array = manager.passive_params["customer_types"]
		if targets.has(customer_type_id):
			return float(manager.passive_params["multiplier"])
	return 1.0


## 値段補正の係数。安売り(変化率が負)の効きだけを強める
static func price_effect_factor(manager: ManagerData, rate: float, balance: BalanceConfig) -> float:
	var factor := balance.price_effect_factor
	if rate < 0.0 and manager.passive_kind == SkillKinds.Passive.SALE_BOOST:
		factor *= float(manager.passive_params["sale_effect_multiplier"])
	return factor


## 客層予報で「次の時間帯」に加えて出す時間帯の数
static func extra_forecast_bands(manager: ManagerData) -> int:
	if manager.passive_kind == SkillKinds.Passive.FORECAST:
		return int(manager.passive_params["extra_forecast_bands"])
	return 0


## 突発イベントの予告を早める秒数
static func announce_lead_bonus(manager: ManagerData) -> float:
	if manager.passive_kind == SkillKinds.Passive.FORECAST:
		return float(manager.passive_params["announce_lead_bonus"])
	return 0.0


## 発注が届くまでの秒数
static func delivery_seconds(manager: ManagerData, balance: BalanceConfig) -> float:
	if manager.passive_kind == SkillKinds.Passive.FORECAST:
		return float(manager.passive_params["delivery_seconds"])
	return balance.delivery_seconds


## 売値に使う値段の段階。値札ロック中は自店の全商品を決まった段階で売る(値段補正は変わらない)
static func sell_price_step(store: StoreState, step: int) -> int:
	if store.is_active_running(SkillKinds.Active.PRICE_LOCK):
		return int(store.manager.active_params["sell_price_step"])
	return step


## 効果の続く秒数。すぐに終わる効果は 0
static func active_duration(manager: ManagerData) -> float:
	return float(manager.active_params.get("duration", 0.0))


static func activate(match_state: MatchState, store_index: int) -> void:
	var store := match_state.stores[store_index]
	store.active_remaining = active_duration(store.manager)
	match store.manager.active_kind:
		SkillKinds.Active.BULK_ORDER:
			var count := int(store.manager.active_params["count"])
			for product_id in store.shelf_product_ids():
				match_state.deliver(store_index, product_id, count)
		SkillKinds.Active.TIME_SALE:
			store.mark_dirty()
