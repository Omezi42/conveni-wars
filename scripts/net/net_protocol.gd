class_name NetProtocol
extends RefCounted
## 中継サーバーと相手へ送る文の形(Architecture.md 7.1節)。文は JSON の辞書で、種類を KIND に入れる。
## サーバーが出すのは PAIRED・PEER_LEFT・ERROR だけで、ほかは相手の文をそのまま流したもの。

const KIND := "k"

## サーバー → 2人がそろった。ROLE は HOST(部屋を作った側)か GUEST
const PAIRED := "paired"
const ROLE := "role"
const HOST := "host"
const GUEST := "guest"
## サーバー → 相手の接続が閉じた
const PEER_LEFT := "peer_left"
## サーバー → 部屋に入れなかった。REASON は TAKEN・MISSING・FULL
const ERROR := "error"
const REASON := "r"
const TAKEN := "taken"
const MISSING := "missing"
const FULL := "full"
## 端末の中で作る:サーバーとの接続が閉じた
const CLOSED := "closed"

## 2人がそろったら送り合う。版(VERSION)とWeb版か(WEB)が同じでなければ対戦しない
const HELLO := "hello"
const VERSION := "v"
const WEB := "web"
## 選んだ店長(MANAGER)
const PICK := "pick"
const MANAGER := "m"
## 部屋を作った側 → 試合を始める。種(SEED)と両店の店長(MANAGERS。店0・店1の順)
const START := "start"
const SEED := "seed"
const MANAGERS := "ms"
## 試合中の操作。UPTO の tick までの自分の操作を出し終えた。COMMANDS は [tick, 種類, 商品id, 値] の列
const INPUT := "in"
const UPTO := "u"
const COMMANDS := "c"
## 時間帯の変わり目と試合の終わりの状態のハッシュ
const HASH := "hash"
const TICK := "t"
const VALUE := "h"
## 試合が終わった(この文の前に、最後の tick までの操作を送り終えている)
const END := "end"
## 降参した
const RESIGN := "resign"
## 相手が10秒以上止まっていたので、相手の店をCPUに任せた(受けた側は通信が切れた扱いで抜ける)
const DROP := "drop"
