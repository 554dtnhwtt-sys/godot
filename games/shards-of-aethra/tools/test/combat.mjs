// Sets up two full boards mid-game and captures the fight.
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
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
const logs = [];
page.on('console', (m) => { if (!/GPU stall|GL Driver/.test(m.text())) logs.push(m.type() + ': ' + m.text()); });
page.on('pageerror', (e) => logs.push('PAGEERROR: ' + e.message + '\n' + e.stack));
await page.goto(`http://localhost:${server.address().port}/index.html`);
await page.waitForSelector('#title-menu:not([hidden])', { timeout: 60000 });
await page.click('#t-play');
await page.waitForTimeout(500);
await page.evaluate(() => { window.__app.match.timeLeft = 0.01; });
await page.waitForTimeout(800);
await page.evaluate(() => {
  const m = window.__app.match;
  if (m.pendingDraft) m.pickDraft(0);
  m.timeLeft = 0.01;
});
await page.waitForTimeout(800);
await page.evaluate(() => {
  const m = window.__app.match;
  m.stage = 4; m.round = 2;
  const mine = (process => null)();
  const A = [['grumbark', 24, ['plate+plate']], ['sigrun', 22, ['blade+veil']], ['kaldor', 26, ['blade+bow', 'bow+bow']], ['magna', 17, []], ['pyra', 2, ['rod+rod']], ['vexa', 4, ['bow+glove']], ['eira', 3, ['rod+tear']], ['nerissa', 0, []], ['nyxara', 6, ['blade+glove']]];
  const B = [['morgath', 24, []], ['bramblehide', 22, []], ['hrimfang', 20, []], ['rivet', 26, []], ['thalassa', 3, []], ['brine', 1, []], ['ilsa', 5, []], ['veyl', 2, []], ['skitter', 6, []]];
  let uid = 50000;
  m.local.level = 9;
  m.local.board.fill(null);
  m.local.bench.fill(null);
  for (const [id, c, items] of A) m.local.board[c] = { uid: uid++, id, star: 2, items };
  for (const p of m.players) {
    if (p === m.local) continue;
    p.board.fill(null);
    p.bench.fill(null);
    for (const [id, c] of B) p.board[c] = { uid: uid++, id, star: 2, items: ['blade'] };
  }
  m.local.bench[2] = { uid: uid++, id: 'pim', star: 1, items: [] };
  m.local.bench[5] = { uid: uid++, id: 'snorri', star: 3, items: [] };
  m.emit('update');
});
await page.waitForTimeout(1500);
await page.screenshot({ path: `${out}/c0-plan.png` });
await page.evaluate(() => { window.__app.match.timeLeft = 0.01; });
for (let i = 1; i <= 4; i++) {
  await page.waitForTimeout(+(process.env.STEP || 2500));
  await page.screenshot({ path: `${out}/c${i}.png` });
}
console.log(logs.slice(0, 30).join('\n'));
await browser.close();
server.close();
