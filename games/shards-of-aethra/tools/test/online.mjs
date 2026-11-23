// Two browser pages play an online game through a fake "room" channel (BroadcastChannel),
// then we check that both computed the same health for every Warden.
import { createRequire } from 'node:module';
import http from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
const require = createRequire(process.env.PW_ROOT + '/');
const { chromium } = require('playwright');
const out = process.argv[2];
const root = new URL('../../dist/', import.meta.url).pathname;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.webp': 'image/webp', '.mp3': 'audio/mpeg' };
const server = http.createServer((req, res) => {
  let p = join(root, decodeURIComponent(req.url.split('?')[0]));
  if (existsSync(p) && statSync(p).isDirectory()) p = join(p, 'index.html');
  if (!existsSync(p)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[extname(p)] || 'application/octet-stream' });
  res.end(readFileSync(p));
}).listen(0);
const fakeRoom = () => {
  const me = Math.random().toString(36).slice(2, 10);
  const rooms = {};
  window.claude = { use: async (name) => name !== 'room' ? null : {
    join: async (rn) => {
      if (rooms[rn]) return rooms[rn];
      const ch = new BroadcastChannel('fake-' + rn);
      const peers = new Map();
      const subs = [];
      let mine = {};
      const notify = () => { const list = [...peers.entries()].map(([peer, presence]) => ({ peer, presence, sameTab: peer === me, isMe: peer === me, guest: false, kind: 'viewer', by: null, updatedAt: Date.now() })); setTimeout(() => subs.forEach((f) => f({ peers: list, joined: [], left: [], updated: [] })), 0); };
      peers.set(me, mine);
      ch.onmessage = (ev) => { const d = ev.data; if (d.t === 'p') { peers.set(d.peer, d.presence); notify(); } if (d.t === 'hello') ch.postMessage({ t: 'p', peer: me, presence: mine }); if (d.t === 'bye') { peers.delete(d.peer); notify(); } };
      ch.postMessage({ t: 'hello' });
      const room = {
        name: rn,
        presence: async (patch) => { mine = { ...mine }; for (const [k, v] of Object.entries(patch)) { if (v === null) delete mine[k]; else mine[k] = v; } peers.set(me, mine); ch.postMessage({ t: 'p', peer: me, presence: mine }); notify(); },
        peers: () => [...peers.entries()].map(([peer, presence]) => ({ peer, presence, sameTab: peer === me, isMe: peer === me, guest: false, kind: 'viewer', by: null })),
        onPeers: (fn) => { subs.push(fn); notify(); return () => {}; },
        leave: async () => { ch.postMessage({ t: 'bye', peer: me }); ch.close(); },
        connected: () => true,
      };
      rooms[rn] = room;
      return room;
    },
  } };
};
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: 1200, height: 700 } });
await ctx.addInitScript(fakeRoom);
const url = `http://localhost:${server.address().port}/index.html`;
const A = await ctx.newPage();
const B = await ctx.newPage();
const logs = [];
for (const [n, p] of [['A', A], ['B', B]]) p.on('pageerror', (e) => logs.push(n + ' PAGEERROR: ' + e.message + ' ' + e.stack));
await A.goto(url, { waitUntil: 'domcontentloaded', timeout: 90000 }); await B.goto(url, { waitUntil: 'domcontentloaded', timeout: 90000 });
await A.waitForSelector('#title-menu:not([hidden])', { timeout: 120000 });
await B.waitForSelector('#title-menu:not([hidden])', { timeout: 120000 });
await A.click('#t-online'); await A.waitForSelector('#lb-create'); await A.fill('#lb-name', 'Alva'); await A.click('#lb-create');
await A.waitForTimeout(800);
const code = await A.evaluate(() => window.__app.online.code);
await B.click('#t-online'); await B.waitForSelector('#lb-join'); await B.fill('#lb-name', 'Bjorn'); await B.fill('#lb-code', code); await B.click('#lb-join');
await A.waitForTimeout(1500);
await A.screenshot({ path: `${out}/o1-lobby.png` });
await A.click('#lb-start');
await A.waitForTimeout(2500);
const ff = async () => { for (const p of [A, B]) await p.evaluate(() => { const m = window.__app.match; if (!m) return; if (m.pendingDraft) m.pickDraft(0); if (m.pendingBoon) m.pickBoon(m.pendingBoon[0].id); if (['intro', 'draft', 'planning', 'results'].includes(m.phase)) m.timeLeft = Math.min(m.timeLeft, 0.05); m.combatSpeed = 8; }); };
for (let i = 0; i < 60; i++) {
  await ff();
  await A.waitForTimeout(700);
}
const state = async (p) => p.evaluate(() => { const m = window.__app.match; return { key: m.roundKey(), phase: m.phase, hp: m.players.map((x) => `${x.name}:${x.hp}`).join(' ') }; });
const sa = await state(A); const sb = await state(B);
console.log('A', JSON.stringify(sa)); console.log('B', JSON.stringify(sb));
await A.screenshot({ path: `${out}/o2-game.png` });
console.log(logs.slice(0, 10).join('\n'));
await browser.close(); server.close();
