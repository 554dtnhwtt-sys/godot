// Clicks through menus and saves screenshots: node ui.mjs outdir "sel1;shotname1" "sel2;shotname2" ...
import { createRequire } from 'node:module';
import http from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
const require = createRequire(process.env.PW_ROOT + '/');
const { chromium } = require('playwright');
const [out, ...actions] = process.argv.slice(2);
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
const page = await browser.newPage({ viewport: { width: +(process.env.W || 1600), height: +(process.env.H || 900) } });
const logs = [];
page.on('pageerror', (e) => logs.push('PAGEERROR: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') logs.push('console: ' + m.text()); });
await page.goto(`http://localhost:${server.address().port}/index.html`);
await page.waitForSelector('#title-menu:not([hidden])', { timeout: 60000 });
for (const a of actions) {
  const [sel, name, js] = a.split(';');
  if (js) await page.evaluate(js);
  if (sel) await page.click(sel);
  await page.waitForTimeout(+(process.env.WAIT || 1200));
  if (name) await page.screenshot({ path: `${out}/${name}.png` });
}
console.log(logs.join('\n'));
await browser.close();
server.close();
