# 7章 オンライン対戦

GameDesign.md 13章の実装。両方の端末で同じ `MatchState` を回し、操作だけを中継サーバー越しに送り合う(ロックステップ)。

## 7.1 中継サーバーと接続

| 部品 | 内容 |
|---|---|
| `server/`(Cloudflare Worker + Durable Object) | `wss://<host>/room/<合言葉>?op=create\|join`。ランダムマッチは `wss://<host>/match` で、1つの `Matchmaker` が待っている1人と次に来た1人を組み、組んだ2人の文を流す(組の番号と役割は接続の attachment に持つ)。合言葉ごとの `Room` が2本の WebSocket を持ち、文を相手へそのまま流す。2人目が入ったら両方へ `paired`(役割つき)、片方が閉じたら残りへ `peer_left`。入れないときは `error`(`taken` / `missing` / `full`)を1つ送って閉じる(ブラウザは101以外の応答を読めないため) |
| `NetSession`(autoload、`scripts/net/net_session.gd`) | WebSocket を1本持ち、`_process` で受けた文(JSON の辞書)を溜める。画面は `next_message()` で1つずつ取り出し、次の画面へ移る文を受けたらそこでやめる(残りは次の画面が読む)。閉じたら `closed` を溜める。自分の店は部屋を作った側が0 |
| `NetProtocol`(`scripts/net/net_protocol.gd`) | 文の種類とキーの名前 |
| `NetConfig`(`data/net.tres`) | サーバーのURL・操作の遅れ(tick)・送る間隔・待つ表示と切断の秒数・合言葉の桁数・引き継ぐCPUの強さ |

- サーバーのURLは環境変数 `CONVENI_SERVER` で差し替えられる(ローカルの `npx wrangler dev` で試すため)
- 文の流れ:部屋で `paired` → 互いに `hello`(版とWeb版か。違えば対戦しない)→ 店長選択で `pick` → 部屋を作った側が `start`(種と両店の店長)→ 試合で `in` / `hash` / `end` → `resign` / `drop`

## 7.2 試合の進め方

| 部品 | 内容 |
|---|---|
| `Lockstep`(`scripts/net/lockstep.gd`、RefCounted) | 自分の操作を `tick + input_delay_ticks` に予約し、`send_interval_ticks` ごとに「どの tick まで出し終えたか」と操作をまとめて送る。相手が出し終えた tick までしか進めない。予約した操作は、その tick の `advance` の前に店の番号の順・出した順に `MatchRecord.apply` で流す。時間帯の変わり目と試合の終わりに `MatchState.checksum()` を送り合い、違えば `desynced`。試合が終わったら残りを送ってから `end` を送る(相手はもう待たない) |
| `PlayerCommands`(`scripts/ui/match/player_commands.gd`) | 画面の操作の窓口。CPU戦は `MatchState` のコマンドをそのまま呼び、オンラインは `Lockstep.submit` へ予約して、いまの状態で通るかどうかを返す(押した直後の光り用)。`MatchPart.commands` に入れて部品で共有する |
| `OnlineMatchLink`(`scripts/ui/match/online_match_link.gd`) | 試合画面に重ねる Control。届いた文を `Lockstep` へ渡して1物理フレームに1tick進め、待つ表示・降参のメニュー・打ち切りの幕を持つ。`waiting_seconds` が `drop_seconds` を超えたら `drop` を送り、相手の店を `CpuPlayer` に任せる(`Lockstep.take_over`)。`resign` / `peer_left` / `closed` でも同じく任せる。`drop` を受けた側は打ち切って抜ける |
| `ViewSide`(`scripts/ui/view_side.gd`) | 画面の自店の番号(`own`)と、店の番号から色・呼び名を引く関数。部屋に入った側は店1だが、自店を左・自店の色で出すため、画面は `UiPalette.STORE_COLORS[店の番号]` ではなく `ViewSide.color(店の番号)` を使う |

- `MatchController` はオンラインでは CPU を作らず、`MatchRunner` を `OnlineMatchLink` に渡して進めさせる。スナップショットとヒントは作らない
- 結果は `GameSession.finish_online_match`(相手が抜けたら勝ちに書き換える)でオンラインの戦績(`SaveData.online_*`)に残す
- ブラウザは裏に回したタブの描画を止めるため、タブを離れた側の試合は止まる。相手はそれを10秒の無通信として扱う

## 7.3 画面

| シーン | スクリプト | 責務 |
|---|---|---|
| `scenes/online_lobby.tscn` | `scripts/ui/online_lobby_screen.gd` | 部屋を作る(合言葉を乱数で作り、使われていたら作り直す)/ 数字のボタンで合言葉を入れて入る / ランダムマッチで待つ。`hello` を確かめ合ったら `GameSession.online` を立てて店長選択へ |
| `scenes/manager_select.tscn` | `scripts/ui/manager_select_screen.gd` | オンラインではCPUの強さを隠し、選んだら `pick` を送って待つ。部屋を作った側が両方の選択をそろえて `start` を送る |
