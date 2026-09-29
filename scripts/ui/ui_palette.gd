class_name UiPalette
extends RefCounted
## 画面の色・文字の大きさ・線の太さ(UIクロームはコードで描く。CLAUDE.md「アセット」)。
## 見た目の方針は GameDesign.md 9.5節:太い輪郭線とずらした影の「ステッカー」風。

## 輪郭線と本文の色(濃い紺)
const INK := Color("#1d2342")
const INK_SOFT := Color("#5d6582")
const INK_ON_DARK := Color("#ffffff")
## パネルの地(温かい白)と、その一段暗い色
const PAPER := Color("#fffaf0")
const PAPER_DIM := Color("#ece5d6")
const SHADOW := Color(0.07, 0.08, 0.2, 0.38)
const SCRIM := Color(0.07, 0.08, 0.2, 0.35)

## 店内の床・棚のマスの地・棚板
const FLOOR := Color("#fdf1d8")
const SLOT := Color("#f3ead6")
const SHELF_BOARD := Color("#b9c2d0")
## 通り(昼・夜)と歩道・中央線
const STREET := Color("#6d7389")
const STREET_NIGHT := Color("#33374d")
const SIDEWALK := Color("#c9c3b4")
const SIDEWALK_NIGHT := Color("#5b5a66")
const STREET_LINE := Color("#f6f1e2")
## 夜に入口からこぼれる店の明かり
const DOOR_LIGHT := Color(1.0, 0.9, 0.55, 0.45)
const DOOR_GLASS := Color("#bfe9f5")
const STAR := Color(1, 1, 0.9, 0.85)
const MOON := Color("#fff3b0")
const SUN := Color("#ffd23f")

## 店の色(自店・相手)と、看板の帯の差し色
const STORE_COLORS: Array[Color] = [Color("#2f6fe8"), Color("#ef4b3f")]
const STORE_ACCENTS: Array[Color] = [Color("#2ec5e3"), Color("#ffa630")]
const STORE_NAMES: Array[String] = ["自店", "相手"]

const GOOD := Color("#1fa45c")
const WARN := Color("#ffb020")
const BAD := Color("#e5383b")
## お金(売上の飛び出し・資金の硬貨)
const MONEY := Color("#ffd23f")
## 入荷待ち
const DELIVERY := Color("#3b82f6")

## 値札の地と文字の色(安売り・定価・強気)。安売りは黄色い特価札、強気は紺の札
const PRICE_FILLS: Array[Color] = [Color("#ffd23f"), Color("#ffffff"), Color("#2b3358")]
const PRICE_INKS: Array[Color] = [Color("#d62b2b"), Color("#1d2342"), Color("#ffd23f")]

## 棚のボーナスの枠の色(ShelfBonus.Kind の順:目玉・コーナー・セット)
const BONUS_COLORS: Array[Color] = [Color("#ffb400"), Color("#14b8a6"), Color("#ec4899")]

## タイトル・店長選択・結果の空(試合中は時間帯のデータの色を使う)
const MENU_SKY_TOP := Color("#f08a6c")
const MENU_SKY_BOTTOM := Color("#ffd08f")
const RESULT_SKY_TOP := Color("#121a40")
const RESULT_SKY_BOTTOM := Color("#343a74")

const FONT_TINY := 12
const FONT_SMALL := 13
const FONT_BODY := 15
const FONT_LARGE := 19
const FONT_HEAD := 26
const FONT_HUGE := 44
const FONT_TITLE := 80

const RADIUS := 12
const RADIUS_SMALL := 7
const OUTLINE := 3
const OUTLINE_THIN := 2
## 影をずらす量(下へ)
const SHADOW_DROP := 4.0
