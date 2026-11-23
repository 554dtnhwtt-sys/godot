import { Combat } from '../../src/game/sim.js';
import { CHAMPIONS } from '../../src/data/champions.js';
import { RNG } from '../../src/core/rng.js';
import { ITEMS } from '../../src/data/items.js';

const rng = new RNG(42);
const itemIds = Object.keys(ITEMS).filter((k) => !ITEMS[k].component);
function randomBoard(n, maxCost, star) {
  const cells = rng.shuffle([...Array(28).keys()]).slice(0, n);
  return cells.map((cell, i) => {
    const pool = CHAMPIONS.filter((c) => c.cost <= maxCost);
    const ch = rng.pick(pool);
    const items = rng.chance(0.5) ? [rng.pick(itemIds)] : [];
    return { owned: { uid: i + 1, id: ch.id, star, items }, cell };
  });
}
let wins = [0, 0, 0];
let totalTicks = 0;
const t0 = Date.now();
for (let i = 0; i < 300; i++) {
  const home = { units: randomBoard(7, 5, 2), boons: ['phoenix'] };
  const away = { units: randomBoard(7, 5, 2), boons: [] };
  const seed = 1000 + i;
  const a = new Combat({ seed, home, away }).runToEnd();
  const b = new Combat({ seed, home, away }).runToEnd();
  if (a.ticks !== b.ticks || a.winner !== b.winner) { console.log('NONDETERMINISTIC', i); process.exit(1); }
  wins[a.winner + 1]++;
  totalTicks += a.ticks;
}
console.log('draw/home/away', wins, 'avg secs', (totalTicks / 300 / 30).toFixed(1), 'ms per fight', ((Date.now() - t0) / 600).toFixed(2));
// monster round
const mon = new Combat({ seed: 5, home: { units: randomBoard(3, 1, 1) }, away: { monsters: [{ mon: 'shardling', cell: 3 }, { mon: 'shardgolem', cell: 10 }] } }).runToEnd();
console.log('monster round winner', mon.winner, 'ticks', mon.ticks);
// per champion 1v1 sanity: each champ 2* vs brakka 2*
const res = [];
for (const c of CHAMPIONS) {
  let w = 0;
  for (let s = 0; s < 10; s++) {
    const r = new Combat({ seed: s, home: { units: [{ owned: { uid: 1, id: c.id, star: 2, items: [] }, cell: 10 }] }, away: { units: [{ owned: { uid: 2, id: 'sigrun', star: 2, items: [] }, cell: 10 }] } }).runToEnd();
    if (r.winner === 0) w++;
  }
  res.push(`${c.id}:${w}`);
}
console.log(res.join(' '));
