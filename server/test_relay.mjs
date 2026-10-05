// 中継サーバーの確かめ: node test_relay.mjs ws://127.0.0.1:8787
const base = process.argv[2] ?? "ws://127.0.0.1:8787";
const code = String(1000 + Math.floor(Math.random() * 9000));

function open(op, roomCode = code) {
  const ws = new WebSocket(`${base}/room/${roomCode}?op=${op}`);
  const inbox = [];
  const waiters = [];
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    const w = waiters.shift();
    if (w) w(msg);
    else inbox.push(msg);
  };
  ws.next = () =>
    new Promise((resolve, reject) => {
      if (inbox.length) return resolve(inbox.shift());
      const t = setTimeout(() => reject(new Error("timeout")), 5000);
      waiters.push((m) => {
        clearTimeout(t);
        resolve(m);
      });
    });
  ws.ready = new Promise((r) => (ws.onopen = r));
  return ws;
}

function check(cond, label) {
  if (!cond) {
    console.error("NG", label);
    process.exit(1);
  }
  console.log("ok", label);
}

const host = open("create");
await host.ready;
const taken = open("create");
check((await taken.next()).r === "taken", "same code cannot be created twice");
const missing = open("join", "0000" === code ? "0001" : "0000");
check((await missing.next()).r === "missing", "joining an empty room fails");
const guest = open("join");
check((await host.next()).role === "host", "host is told it is paired");
check((await guest.next()).role === "guest", "guest is told it is paired");
const third = open("join");
check((await third.next()).r === "full", "third player is refused");
host.send(JSON.stringify({ k: "in", u: 10, c: [] }));
check((await guest.next()).u === 10, "host message reaches guest");
guest.send(JSON.stringify({ k: "pick", m: "veteran" }));
check((await host.next()).m === "veteran", "guest message reaches host");
guest.close();
check((await host.next()).k === "peer_left", "host is told the guest left");
const again = open("create");
await again.ready;
await new Promise((r) => setTimeout(r, 300));
again.send(JSON.stringify({ k: "ping" }));
check(true, "room can be created again after both left");
again.close();
console.log("relay tests passed");
process.exit(0);
