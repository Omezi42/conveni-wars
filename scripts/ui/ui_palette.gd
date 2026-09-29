class_name UiPalette
extends RefCounted
## 画面の色と文字の大きさ(UIクロームはコードで描く。GameDesign.md 9.6節)。
## パネルは濃い紺の半透明に明るい縁取り。棚のマスと商品タイルは明るい地(CARD)に濃い文字(CARD_INK)。

const BACKGROUND := Color("#18284a")
const PANEL := Color(0.06, 0.11, 0.23, 0.9)
const PANEL_EDGE := Color(0.45, 0.72, 1.0, 0.75)
## パネルの中の区切り(時間帯の塊など)
const PANEL_INNER := Color(1, 1, 1, 0.07)
const INK := Color("#f2f6ff")
const INK_SOFT := Color("#a9bad6")
const INK_ON_DARK := Color("#ffffff")
const CARD := Color("#f5f8fd")
const CARD_EDGE := Color("#c3cfdf")
const CARD_INK := Color("#1f2a3a")
const CARD_INK_SOFT := Color("#6b7785")
## カットインの帯などの濃い色
const BAR := Color("#0e1a33")
## 背景の絵の上に文字を載せる画面(タイトル・店長選択・結果)で絵を暗く沈める幕
const SCRIM := Color(0.04, 0.08, 0.18, 0.55)

## 主な操作のボタン(はじめる・決定・もう一度)
const ACCENT := Color("#f7c325")
const ACCENT_INK := Color("#4a3500")

## 店の色(自店・相手)
const STORE_COLORS: Array[Color] = [Color("#2f7de1"), Color("#e0484f")]
const STORE_NAMES: Array[String] = ["自店", "相手"]
const STORE_TITLES: Array[String] = ["わたしの店", "相手の店"]

const GOOD := Color("#2e9e5b")
const GOOD_BRIGHT := Color("#63d98f")
const WARN := Color("#f0a830")
const BAD := Color("#e04b4b")
const BAD_BRIGHT := Color("#ff8080")
const EMPTY_SLOT := Color(1, 1, 1, 0.1)
const SOLD_OUT := Color("#f8d3d3")

## 値段の段階の色(安売り・定価・強気)
const PRICE_COLORS: Array[Color] = [Color("#2e9e5b"), Color("#56657d"), Color("#e07a2b")]

## 棚のボーナスの枠の色(ShelfBonus.Kind の順)
const BONUS_COLORS: Array[Color] = [Color("#f0b400"), Color("#1fa2a8"), Color("#e2559b")]

const FONT_SMALL := 12
const FONT_BODY := 14
const FONT_LARGE := 18
const FONT_HEAD := 24
const FONT_HUGE := 40
const FONT_TITLE := 72

const RADIUS := 8
const PANEL_RADIUS := 12
