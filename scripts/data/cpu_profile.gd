class_name CpuProfile
extends Resource
## CPUの強さと判断の数値(GameDesign.md 8.2節・8.3節、Architecture.md 5章)。

@export var id: StringName
@export var display_name: String
## 判断の間隔(秒)
@export var think_interval: float
## 突発イベントの予告を見てから、発注に反映するまでの秒数
@export var event_reaction_delay: float
## 予告の客層を読み違える確率
@export var event_misread_chance: float
## 何秒先までに売れる見込みの量を在庫として持つか
@export var stock_horizon: float
## 自店へ来ると見込む客の割合
@export var assumed_share: float
## アクティブスキルを使い始める残り秒数
@export var skill_after_remaining: float
## 試合終了のこの秒数前までにアクティブスキルを使う
@export var skill_end_margin: float
