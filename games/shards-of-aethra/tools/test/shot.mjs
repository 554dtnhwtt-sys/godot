// Usage: node shot.mjs out.png [waitMs] [width] [height] [script]
import { createRequire } from 'node:module';
const require = createRequire(process.env.PW_ROOT + '/');
const { chromium } = require('playwright');
import http from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
const [out, wait = '2500', w = '1600', h = '900', script = ''] = process.argv.slice(2);
const root = new URL('../../dist/', import.meta.url).pathname;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.webp': 'image/webp', '.mp3': 'audio/mpeg', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  let p = join(root, decodeURIComponent(req.url.split('?')[0]));
  if (existsSync(p) && statSync(p).isDirectory()) p = join(p, 'index.html');
  if (!existsSync(p)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[extname(p)] || 'application/octet-stream' });
  res.end(readFileSync(p));
}).listen(0);
const port = server.address().port;
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
const logs = [];
page.on('console', (m) => logs.push(m.type() + ': ' + m.text()));
page.on('pageerror', (e) => logs.push('PAGEERROR: ' + e.message));
await page.goto(`http://localhost:${port}/index.html${process.env.QS || ''}`);
await page.waitForTimeout(+wait);
if (script) { await page.evaluate(script); await page.waitForTimeout(+wait); }
await page.screenshot({ path: out });
console.log(logs.slice(0, 30).join('\n'));
await browser.close();
server.close();
