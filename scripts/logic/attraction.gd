class_name Attraction
extends RefCounted
## 魅力度と、客が買う順番の計算(GameDesign.md 2.4節・2.5節・5.2節)。


## 客から見た1商品の点
class Pick:
	extends RefCounted
	var product_id: StringName
	var weight: int
	var score: float


class Evaluation:
	extends RefCounted
	## 店の魅力度(パッシブの倍率まで掛けたもの)
	var score := 0.0
	## 買う順番(カテゴリの重みが大きい順 → 点が高い順)
	var picks: Array[Pick] = []


static func evaluate(
	store: StoreState, customer_type: CustomerTypeData, db: GameDatabase
) -> Evaluation:
	var shelf_result := store.shelf_bonus()
	var best: Dictionary = {}
	for slot in store.shelf.size():
		if not store.is_slot_stocked(slot):
			continue
		var product_id := store.shelf[slot]
		var weight := customer_type.weight_of(db.product(product_id).category_id)
		if weight <= 0:
			continue
		var score := (
			weight
			* price_modifier_in_store(store, product_id, customer_type, db.balance)
			* shelf_result.multipliers[slot]
		)
		# 同じ商品を複数のマスに置いても、数えるのは点が最も高い1マスだけ
		var pick: Pick = best.get(product_id)
		if pick == null:
			pick = Pick.new()
			pick.product_id = product_id
			pick.weight = weight
			best[product_id] = pick
		pick.score = maxf(pick.score, score)

	var evaluation := Evaluation.new()
	var has_top := false
	var top_weight := customer_type.top_weight()
	for pick: Pick in best.values():
		evaluation.picks.append(pick)
		evaluation.score += pick.score
		has_top = has_top or pick.weight == top_weight
	evaluation.picks.sort_custom(_pick_before)
	if not has_top:
		evaluation.score *= db.balance.missing_top_multiplier
	evaluation.score *= ManagerSkills.appeal_multiplier(store.manager, customer_type.id)
	return evaluation


static func price_modifier_in_store(
	store: StoreState,
	product_id: StringName,
	customer_type: CustomerTypeData,
	balance: BalanceConfig
) -> float:
	var step := store.price_step(product_id)
	if store.is_active_running(SkillKinds.Active.TIME_SALE):
		step = balance.sale_price_step
	var rate := balance.price_step_rates[step] - compare_rate(store, product_id, balance)
	var factor := ManagerSkills.price_effect_factor(store.manager, rate, balance)
	return maxf(price_modifier(customer_type.price_sensitivity, rate, factor), 0.0)


## 値段を比べる相手の率(GameDesign.md 5.2節)。相手が同じカテゴリを置いていなければ定価と比べる
static func compare_rate(
	store: StoreState, product_id: StringName, balance: BalanceConfig
) -> float:
	var category_id := store.category_of(product_id)
	var rival_rate: Variant = (
		null if store.rival == null else store.rival.cheapest_rate_in(category_id)
	)
	if rival_rate == null:
		return balance.price_step_rates[balance.default_price_step]
	return rival_rate


## 値段補正 = 1 − 値段への敏感さ × 相手との率の差 × 係数
static func price_modifier(sensitivity: float, rate: float, factor: float) -> float:
	return 1.0 - sensitivity * rate * factor


## 魅力度の exponent 乗に比例した確率で店を選ぶ。どの店も0なら -1
static func choose_store(scores: Array[float], exponent: float, rng: RandomNumberGenerator) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for score in scores:
		var weight := pow(score, exponent) if score > 0.0 else 0.0
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0 and weights[i] > 0.0:
			return i
	# 丸め誤差で最後まで届いたときは、重みのある最後の店
	for i in range(weights.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return i
	return -1


static func _pick_before(a: Pick, b: Pick) -> bool:
	if a.weight != b.weight:
		return a.weight > b.weight
	if not is_equal_approx(a.score, b.score):
		return a.score > b.score
	return String(a.product_id) < String(b.product_id)
