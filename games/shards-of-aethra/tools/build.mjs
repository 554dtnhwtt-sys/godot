// Bundles the game into dist/: a standalone page (index.html) for any static host,
// and artifact.html, the same page as a body fragment for claude.ai artifacts.
import * as esbuild from 'esbuild';
import { cpSync, mkdirSync, readFileSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const watch = process.argv.includes('--watch');

const shell = (body, full) => {
  const head = `<title>Shards of Aethra</title>
<meta name="description" content="An original 3D auto-battler: draft champions, forge relics and outlast seven rival Wardens.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;900&family=Barlow+Semi+Condensed:wght@400;500;600;700&display=swap">`;
  if (!full) return `${head}\n${body}`;
  return `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n${head}\n</head>\n<body>\n${body}\n</body>\n</html>\n`;
};

async function build() {
  if (existsSync(dist)) rmSync(dist, { recursive: true });
  mkdirSync(dist, { recursive: true });
  const res = await esbuild.build({
    entryPoints: [join(root, 'src/main.js')],
    bundle: true,
    minify: true,
    format: 'iife',
    target: ['es2020'],
    loader: { '.css': 'text' },
    write: false,
    legalComments: 'none',
  });
  const js = res.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
  writeFileSync(join(dist, 'game.js'), js);
  cpSync(join(root, 'public/assets'), join(dist, 'assets'), { recursive: true });
  const body = `<style>html,body{background:#07090f;margin:0;height:100%;overflow:hidden}</style>\n<div id="app"></div>`;
  writeFileSync(join(dist, 'index.html'), shell(`${body}\n<script src="game.js"></script>`, true));
  writeFileSync(join(dist, 'artifact.html'), shell(`${body}\n<script>${js}</script>`, false));
  console.log('built', (js.length / 1024).toFixed(0) + ' KB js');
}

await build();
if (watch) {
  const { watch: fsWatch } = await import('node:fs');
  let timer = null;
  fsWatch(join(root, 'src'), { recursive: true }, () => {
    clearTimeout(timer);
    timer = setTimeout(() => build().catch((e) => console.error(e.message)), 150);
  });
  console.log('watching src/ ...');
}
