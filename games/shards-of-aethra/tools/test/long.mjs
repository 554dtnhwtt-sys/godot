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
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errs = [];
page.on('pageerror', (e) => errs.push('PAGEERROR: ' + e.message + ' @ ' + (e.stack || '').split('\n')[1]));
page.on('console', (m) => { if (m.type() === 'error') errs.push('console: ' + m.text()); });
await page.goto(`http://localhost:${server.address().port}/index.html`, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#title-menu:not([hidden])', { timeout: 120000 });
await page.click('#t-play');
let shotBoon = false; let shotDraft = false;
const t0 = Date.now();
while (Date.now() - t0 < 240000) {
  const st = await page.evaluate(() => {
    const m = window.__app.match;
    if (!m) return { phase: 'none' };
    m.combatSpeed = 10;
    const p = m.local;
    // play a little: buy what we can afford and keep the board full
    if (m.phase === 'planning') {
      for (let i = 0; i < 5; i++) if (p.shop[i] && p.gold >= 6) m.buy(i);
      if (p.gold >= 14) m.buyXp();
      p.autoFill();
      for (let k = p.items.length - 1; k >= 0; k--) { const u = p.boardUnits()[k % Math.max(1, p.boardCount())]; if (u) m.equip(k, u.uid); }
    }
    return { phase: m.phase, key: m.roundKey(), boon: !!m.pendingBoon, draft: !!m.pendingDraft, hp: p.hp };
  });
  if (st.boon && !shotBoon) { await page.waitForTimeout(1500); await page.screenshot({ path: `${out}/l-boon.png` }); shotBoon = true; }
  if (st.draft && st.key !== '1-0' && !shotDraft && st.phase === 'draft') { await page.waitForTimeout(800); await page.screenshot({ path: `${out}/l-draft.png` }); shotDraft = true; }
  if (st.phase === 'gameover') break;
  await page.evaluate(() => { const m = window.__app.match; if (!m) return; if (m.pendingDraft) m.pickDraft(0); if (m.pendingBoon) { m.pickBoon(m.pendingBoon[0].id); document.querySelector('#m-boon').classList.remove('show'); } if (['intro', 'draft', 'planning', 'results'].includes(m.phase)) m.timeLeft = Math.min(m.timeLeft, 0.05); });
  await page.waitForTimeout(400);
}
await page.waitForTimeout(2500);
const fin = await page.evaluate(() => { const m = window.__app.match; return m ? { key: m.roundKey(), phase: m.phase, place: m.local.place, hp: m.local.hp } : null; });
console.log(JSON.stringify(fin));
await page.screenshot({ path: `${out}/l-end.png` });
console.log(errs.slice(0, 15).join('\n'));
await browser.close(); server.close();
