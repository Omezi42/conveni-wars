# 中継サーバー

オンライン対戦(GameDesign.md 13章)の2人の文を流すだけの Cloudflare Worker。設計は Architecture.md 7.1節。

```bash
cd server
npx wrangler dev          # ローカル: ws://127.0.0.1:8787
npx wrangler deploy       # 本番: 出たURLの https を wss に替えて data/net.tres の server_url へ
node test_relay.mjs ws://127.0.0.1:8787   # 部屋の作成・参加・中継・切断の確かめ
```
