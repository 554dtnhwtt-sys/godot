// Writes the list of every voice line the game needs, for tools/gen_voices.py.
import { CHAMPIONS } from '../src/data/champions.js';
import { ANNOUNCER } from '../src/data/announcer.js';
import { writeFileSync } from 'node:fs';

const out = [];
for (const c of CHAMPIONS) {
  const { select, ability, upgrade, death } = c.lines;
  select.forEach((t, i) => out.push({ file: `${c.id}_select${i}`, text: t, ...c.voice }));
  out.push({ file: `${c.id}_ability`, text: ability, ...c.voice });
  out.push({ file: `${c.id}_upgrade`, text: upgrade, ...c.voice });
  out.push({ file: `${c.id}_death`, text: death, ...c.voice });
}
for (const [key, text] of Object.entries(ANNOUNCER.lines)) {
  out.push({ file: `announcer_${key}`, text, ...ANNOUNCER.voice });
}
writeFileSync(process.argv[2], JSON.stringify(out, null, 1));
console.log(out.length, 'lines');
