// コンビニウォーズのオンライン対戦の中継サーバー(GameDesign.md 13章、Architecture.md 7.1節)。
// 合言葉ごとの部屋(Durable Object)が、2人の WebSocket の文を相手へそのまま流すだけ。試合の判定はしない。
// 接続: wss://<host>/room/<合言葉>?op=create|join

const CODE_PATTERN = /^\/room\/(\d{4})$/;
const HOST = "host";
const GUEST = "guest";

function send(ws, message) {
  try {
    ws.send(JSON.stringify(message));
  } catch {
    // 閉じかけの接続へは送れなくてよい
  }
}

// 部屋に入れない理由を1つ送ってから閉じる(ブラウザの WebSocket は 101 以外の応答の中身を読めないため)
function refuse(reason) {
  const pair = new WebSocketPair();
  pair[1].accept();
  send(pair[1], { k: "error", r: reason });
  pair[1].close(1000, reason);
  return new Response(null, { status: 101, webSocket: pair[0] });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = url.pathname.match(CODE_PATTERN);
    if (!match) {
      return new Response("conveni-wars relay", { status: 404 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }
    const room = env.ROOMS.get(env.ROOMS.idFromName(match[1]));
    return room.fetch(request);
  },
};

export class Room {
  constructor(ctx) {
    this.ctx = ctx;
  }

  async fetch(request) {
    const op = new URL(request.url).searchParams.get("op");
    const host = this.ctx.getWebSockets(HOST);
    const guest = this.ctx.getWebSockets(GUEST);
    let role;
    if (op === "create") {
      if (host.length > 0 || guest.length > 0) return refuse("taken");
      role = HOST;
    } else {
      if (host.length === 0) return refuse("missing");
      if (guest.length > 0) return refuse("full");
      role = GUEST;
    }
    const pair = new WebSocketPair();
    this.ctx.acceptWebSocket(pair[1], [role]);
    if (role === GUEST) {
      send(host[0], { k: "paired", role: HOST });
      send(pair[1], { k: "paired", role: GUEST });
    }
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  webSocketMessage(ws, message) {
    for (const other of this.ctx.getWebSockets()) {
      if (other !== ws) other.send(message);
    }
  }

  webSocketClose(ws) {
    try {
      ws.close(1000, "bye");
    } catch {
      // すでに閉じている
    }
    for (const other of this.ctx.getWebSockets()) {
      if (other !== ws) {
        send(other, { k: "peer_left" });
        other.close(1000, "peer_left");
      }
    }
  }

  webSocketError(ws) {
    this.webSocketClose(ws);
  }
}
