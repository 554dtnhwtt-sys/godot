// Protocol test without a browser: three Online clients share a fake room and play
// several rounds; every client must compute identical health for every Warden.
import { Online } from '../../src/net/online.js';
import { botPlanning } from '../../src/game/bot.js';
import { RIVALS } from '../../src/data/world.js';

globalThis.localStorage = { getItem: () => null, setItem: () => {} };
globalThis.document = { getElementById: () => ({ textContent: '' }) };
const bus = { peers: new Map(), subs: [] };
function fakeRoom(me) {
  return {
    join: async () => ({
      presence: async (patch) => {
        const cur = { ...(bus.peers.get(me) || {}) };
        for (const [k, v] of Object.entries(patch)) { if (v === null) delete cur[k]; else cur[k] = v; }
        bus.peers.set(me, cur);
        setTimeout(() => bus.subs.forEach((f) => f()), 5);
      },
      peers: () => [...bus.peers.entries()].map(([peer, presence]) => ({ peer, presence, sameTab: peer === me })),
      onPeers: (fn) => { bus.subs.push(fn); return () => {}; },
      leave: async () => {},
    }),
  };
}
const clients = [];
for (const name of ['alva', 'bjorn', 'cecilia']) {
  const app = { begin(m) { this.match = m; m.start(); }, startSolo() {} };
  const o = new Online(app);
  o.myName = () => name;
  o.room = fakeRoom(name);
  o.el = { innerHTML: '', querySelector: () => null, insertAdjacentHTML() {} };
  o.renderRoom = () => {};
  clients.push({ name, app, o });
}
// staggered join times
let t = 1000;
for (const c of clients) { await c.o.join('TEST'); c.o.joinedAt = t; await c.o.lobby.presence({ t: t++ }); }
await new Promise((r) => setTimeout(r, 50));
const host = clients.find((c) => c.o.isHost());
await host.o.hostStart(true);
await new Promise((r) => setTimeout(r, 100));
for (const c of clients) if (!c.app.match) throw new Error('client did not start: ' + c.name);
for (const c of clients) {
  const m = c.app.match;
  m.local.rival = RIVALS[clients.indexOf(c)];
  m.on('phase', (ph) => { if (ph === 'planning') botPlanning(m.local, m); if (ph === 'draft' && m.pendingDraft) m.pickDraft(0); });
  m.on('boon-offer', (o) => o && m.pickBoon(o[0].id));
  m.combatSpeed = 50;
  c.rounds = {};
  m.on('round-done', (k, hps) => { c.rounds[k] = hps.join(','); });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
for (let i = 0; i < 4000; i++) {
  for (const c of clients) { const m = c.app.match; if (m.phase !== 'gameover') m.update(0.6); }
  await sleep(2);
  if (clients.every((c) => c.app.match.phase === 'gameover' || !c.app.match.local.alive)) break;
}
const table = (c) => c.app.match.players.map((p) => `${p.name}:${p.hp}`).join(' ');
for (const c of clients) console.log(c.name.padEnd(8), c.app.match.roundKey(), c.app.match.phase, table(c));
const ref = clients[0].app.match;
// Compare health at the latest round all clients finished.
let same = 0; let diff = 0;
for (const k of Object.keys(clients[0].rounds)) {
  const vals = clients.map((c) => c.rounds[k]).filter(Boolean);
  if (vals.length < 2) continue;
  if (new Set(vals).size === 1) same++; else { diff++; console.log('MISMATCH', k, vals); }
}
console.log('rounds compared: identical', same, 'different', diff);
console.log('agree on stage reached by all:', new Set(clients.map((c) => c.app.match.local.history.length)).size === 1 ? 'same history length' : 'different history length');
