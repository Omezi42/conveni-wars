class_name LossReason
extends RefCounted
## 相手の店へ入った客の、負けた理由の判定と集計(GameDesign.md 2.7節)。

## 並びは人数が同じときに選ぶ順(GameDesign.md 9.3節)
enum Kind { OUT_OF_STOCK, ASSORTMENT, PRICE, BONUS }


class Loss:
	extends RefCounted
	var kind: Kind
	## 理由に付けるカテゴリ。無ければ &""
	var category_id: StringName

	func _init(loss_kind: Kind, category: StringName) -> void:
		kind = loss_kind
		category_id = category


## 理由ごとの人数と、理由ごとのカテゴリの人数
class Tally:
	extends RefCounted
	var total := 0
	## Kind → 人数
	var counts: Dictionary = {}
	## Kind → { カテゴリid → 人数 }
	var categories: Dictionary = {}

	func add(loss: Loss) -> void:
		total += 1
		counts[loss.kind] = count(loss.kind) + 1
		if loss.category_id == &"":
			return
		var by_category: Dictionary = categories.get_or_add(loss.kind, {})
		by_category[loss.category_id] = int(by_category.get(loss.category_id, 0)) + 1

	func count(kind: Kind) -> int:
		return int(counts.get(kind, 0))

	## 人数がいちばん多い理由。1件も無ければ -1
	func top_kind() -> int:
		var best := -1
		for kind: int in Kind.values():
			if count(kind) > 0 and (best < 0 or count(kind) > count(best)):
				best = kind
		return best

	## その理由でいちばん多いカテゴリ。無ければ &""
	func top_category(kind: Kind) -> StringName:
		var by_category: Dictionary = categories.get(kind, {})
		var best: StringName = &""
		for category_id: StringName in by_category:
			if best == &"" or by_category[category_id] > by_category[best]:
				best = category_id
		return best


## 相手へ入った(またはどちらにも入らなかった)客の、自店の負けた理由。数えない客は null
static func classify(
	own: Attraction.Evaluation,
	rival: Attraction.Evaluation,
	customer_type: CustomerTypeData,
	db: GameDatabase
) -> Loss:
	if own.score <= 0.0:
		return Loss.new(Kind.OUT_OF_STOCK, customer_type.top_category())
	if own.score >= rival.score:
		return null
	var price_ratio := own.score_with(false, true) / rival.score_with(false, true)
	var bonus_ratio := own.score_with(true, false) / rival.score_with(true, false)
	if price_ratio >= 1.0 and price_ratio >= bonus_ratio:
		return Loss.new(Kind.PRICE, _price_category(own, rival, db))
	if bonus_ratio >= 1.0:
		return Loss.new(Kind.BONUS, &"")
	return Loss.new(Kind.ASSORTMENT, _assortment_category(own, rival, db))


## 値段補正で失った点が、相手と比べていちばん大きいカテゴリ
static func _price_category(
	own: Attraction.Evaluation, rival: Attraction.Evaluation, db: GameDatabase
) -> StringName:
	var diff := _price_loss_by_category(own, db)
	var rival_loss := _price_loss_by_category(rival, db)
	for category_id: StringName in rival_loss:
		diff[category_id] = float(diff.get(category_id, 0.0)) - rival_loss[category_id]
	return _top_positive(diff)


## 欲しいカテゴリの重みの合計で、相手が自店をいちばん上回るカテゴリ
static func _assortment_category(
	own: Attraction.Evaluation, rival: Attraction.Evaluation, db: GameDatabase
) -> StringName:
	var diff: Dictionary = {}
	for pick in rival.picks:
		var category_id := db.product(pick.product_id).category_id
		diff[category_id] = float(diff.get(category_id, 0.0)) + pick.weight
	for pick in own.picks:
		var category_id := db.product(pick.product_id).category_id
		diff[category_id] = float(diff.get(category_id, 0.0)) - pick.weight
	return _top_positive(diff)


static func _price_loss_by_category(
	evaluation: Attraction.Evaluation, db: GameDatabase
) -> Dictionary:
	var losses: Dictionary = {}
	for pick in evaluation.picks:
		var category_id := db.product(pick.product_id).category_id
		var loss := pick.weight * pick.bonus * (1.0 - pick.price_modifier) * evaluation.appeal
		losses[category_id] = float(losses.get(category_id, 0.0)) + loss
	return losses


static func _top_positive(values: Dictionary) -> StringName:
	var best: StringName = &""
	var best_value := 0.0
	for key: StringName in values:
		if values[key] > best_value:
			best = key
			best_value = values[key]
	return best
