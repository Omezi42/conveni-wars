// 中継サーバーの確かめ: node test_relay.mjs ws://127.0.0.1:8787
const base = process.argv[2] ?? "ws://127.0.0.1:8787";
const code = String(1000 + Math.floor(Math.random() * 9000));

function open(op, roomCode = code) {
  const path = op === "match" ? "/match" : `/room/${roomCode}?op=${op}`;
  const ws = new WebSocket(`${base}${path}`);
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

const first = open("match");
await first.ready;
await new Promise((r) => setTimeout(r, 300));
const second = open("match");
check((await first.next()).role === "host", "random match: the waiting player becomes host");
check((await second.next()).role === "guest", "random match: the newcomer becomes guest");
first.send(JSON.stringify({ k: "pick", m: "idol" }));
check((await second.next()).m === "idol", "random match: messages reach the partner");
const third2 = open("match");
await third2.ready;
second.close();
check((await first.next()).k === "peer_left", "random match: the partner is told the other left");
const fourth = open("match");
check((await third2.next()).role === "host", "random match: a later pair forms separately");
check((await fourth.next()).role === "guest", "random match: the fourth player joins the third");
third2.close();
fourth.close();
console.log("relay tests passed");
process.exit(0);
