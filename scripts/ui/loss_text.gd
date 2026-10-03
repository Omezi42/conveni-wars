class_name LossText
extends RefCounted
## 負けた理由(GameDesign.md 2.7節)の文言。カットインの1行(9.3節)と結果画面の短い名前(9.4節)。

const SHORT_LABELS := {
	LossReason.Kind.OUT_OF_STOCK: "品切れ",
	LossReason.Kind.ASSORTMENT: "品ぞろえ",
	LossReason.Kind.PRICE: "値段",
	LossReason.Kind.BONUS: "ボーナス",
}


## その時間帯でいちばん多い理由の短い名前。1件も無ければ ""
static func short_label(tally: LossReason.Tally) -> String:
	var kind := tally.top_kind()
	return "" if kind < 0 else SHORT_LABELS[kind]


## 「次は〇〇を並べよう」などの1行。1件も無ければ ""
static func advice(tally: LossReason.Tally, store: StoreState, db: GameDatabase) -> String:
	var kind := tally.top_kind()
	if kind < 0:
		return ""
	var category_id := tally.top_category(kind)
	var category := "" if category_id == &"" else db.category(category_id).display_name
	match kind:
		LossReason.Kind.OUT_OF_STOCK:
			return "次は%sを並べよう" % category
		LossReason.Kind.ASSORTMENT:
			if category_id == &"":
				return "次は品ぞろえを増やそう"
			if store.is_category_stocked(category_id):
				return "次は%sを増やそう" % category
			return "次は%sを並べよう" % category
		LossReason.Kind.PRICE:
			return "次は%sの値段を見直そう" % category
	return "次は棚のボーナスを組もう"
