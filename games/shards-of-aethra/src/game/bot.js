// Computer-controlled Wardens. They shop, level, combine relics and position
// units with simple but sensible priorities so the lobby feels alive.
import { CHAMPION_BY_ID } from '../data/champions.js';
import { ITEMS, COMPONENT_ORDER, combineKey } from '../data/items.js';
import { TRAITS } from '../data/traits.js';
import { countTraits, traitTier } from './units.js';

const TARGET_LEVEL = { 1: 3, 2: 5, 3: 6, 4: 8, 5: 8, 6: 9, 7: 9, 8: 10 };

function role(id) {
  const ch = CHAMPION_BY_ID[id];
  if (ch.traits.includes('shadow')) return 'assassin';
  if (ch.stats.range > 1) return 'back';
  return 'front';
}

function unitScore(p, u, counts) {
  const ch = CHAMPION_BY_ID[u.id];
  let s = ch.cost * 10 * Math.pow(u.star, 2.2) + u.items.length * 6;
  for (const t of ch.traits) {
    const n = counts[t] || 0;
    if (p.rival && p.rival.likes.includes(t)) s += 6;
    s += n * 2;
  }
  return s;
}

export function botPlanning(p, match) {
  const pool = match.poolFor(p);
  const rng = match.rngFor(p);
  const { stage } = match;
  const style = p.rival ? p.rival.style : 'balanced';
  let reserve = style === 'econ' ? 50 : style === 'aggressive' ? 10 : 30;
  if (stage <= 2) reserve = Math.min(reserve, 20);
  if (p.hp < 45) reserve = Math.min(reserve, 10);
  if (p.hp < 25) reserve = 0;

  // Level up toward the target for this stage.
  const target = TARGET_LEVEL[Math.min(8, stage)] + (style === 'aggressive' && stage >= 3 ? 1 : 0);
  let guard = 0;
  while (p.level < Math.min(10, target) && p.gold - 4 >= Math.min(reserve, 20) && guard++ < 20) p.buyXp();

  const wanted = (id) => {
    const ch = CHAMPION_BY_ID[id];
    const owned = p.allUnits().filter((u) => u.id === id).length;
    if (owned >= 1) return 3 + owned;
    const likes = p.rival ? ch.traits.filter((t) => p.rival.likes.includes(t)).length : 0;
    if (likes) return 2 + likes;
    if (ch.cost >= 4 && p.level >= 7) return 2;
    if (p.boardCount() + p.benchUnits().length < p.maxBoard() + 1) return 1;
    return 0;
  };

  const shopPass = () => {
    for (let i = 0; i < 5; i++) {
      const id = p.shop[i];
      if (!id) continue;
      const cost = CHAMPION_BY_ID[id].cost;
      const w = wanted(id);
      const spendable = p.gold - cost >= (w >= 4 ? 0 : reserve);
      if (w >= 2 && spendable) p.buy(i, pool);
      else if (w === 1 && p.gold - cost >= reserve + 4) p.buy(i, pool);
    }
  };
  shopPass();
  // Roll down when rich or desperate.
  let rolls = 0;
  const maxRolls = stage >= 4 ? 8 : stage >= 3 ? 3 : 0;
  while (rolls < maxRolls && p.gold - 2 >= reserve) {
    p.refreshShop(pool, rng);
    shopPass();
    rolls++;
  }
  sellExcess(p, pool);
  arrange(p);
  equip(p);
}

function sellExcess(p, pool) {
  // Keep the bench from overflowing: sell 1-star units that do not pair.
  const bench = p.benchUnits();
  if (bench.length < 7) return;
  const counts = p.traitCounts();
  const loners = bench
    .filter((u) => u.star === 1 && p.allUnits().filter((x) => x.id === u.id).length === 1)
    .sort((a, b) => unitScore(p, a, counts) - unitScore(p, b, counts));
  for (const u of loners.slice(0, bench.length - 5)) p.sell(u.uid, pool);
}

export function arrange(p) {
  const all = p.allUnits();
  const counts = countTraits(all);
  all.sort((a, b) => unitScore(p, b, counts) - unitScore(p, a, counts));
  const chosen = [];
  const ids = new Set();
  for (const u of all) {
    if (chosen.length >= p.maxBoard()) break;
    if (ids.has(u.id) && all.some((x) => !ids.has(x.id) && !chosen.includes(x))) continue;
    chosen.push(u);
    ids.add(u.id);
  }
  for (const u of all) {
    if (chosen.length >= p.maxBoard()) break;
    if (!chosen.includes(u)) chosen.push(u);
  }
  // Clear and re-place.
  p.board.fill(null);
  p.bench.fill(null);
  const front = [24, 23, 25, 22, 26, 21, 27];
  const mid = [17, 16, 18, 15, 19, 14, 20];
  const back = [3, 2, 4, 1, 5, 0, 6, 10, 9, 11];
  const corners = [0, 6, 7, 13];
  for (const u of chosen) {
    const r = role(u.id);
    const lists = r === 'front' ? [front, mid, back] : r === 'assassin' ? [corners, back, mid] : [back, mid, front];
    let placed = false;
    for (const list of lists) {
      const cell = list.find((c) => !p.board[c]);
      if (cell !== undefined) { p.board[cell] = u; placed = true; break; }
    }
    if (!placed) p.board[p.board.findIndex((x) => !x)] = u;
  }
  for (const u of all) {
    if (chosen.includes(u)) continue;
    const slot = p.freeBenchSlot();
    if (slot >= 0) p.bench[slot] = u;
  }
}

export function equip(p) {
  // Combine loose components into the best completed relics, then hand them out.
  const comps = p.items.filter((i) => ITEMS[i].component);
  const done = p.items.filter((i) => !ITEMS[i].component);
  comps.sort((a, b) => COMPONENT_ORDER.indexOf(a) - COMPONENT_ORDER.indexOf(b));
  while (comps.length >= 2) {
    const a = comps.shift();
    const b = comps.shift();
    done.push(combineKey(a, b));
  }
  p.items = comps;
  const board = p.boardUnits().slice().sort((a, b) => {
    const ca = CHAMPION_BY_ID[a.id];
    const cb = CHAMPION_BY_ID[b.id];
    return (cb.cost * b.star) - (ca.cost * a.star);
  });
  for (const it of done) {
    const stats = ITEMS[it].stats;
    const tanky = (stats.armor || 0) + (stats.mr || 0) + (stats.hp || 0) / 8 > 20;
    const target = board.find((u) => u.items.length < 3 && (tanky ? role(u.id) === 'front' : role(u.id) !== 'front'))
      || board.find((u) => u.items.length < 3);
    if (target) target.items.push(it);
    else p.items.push(it);
  }
}

export function botPickBoon(p, offers) {
  const order = ['hoard', 'warband', 'vamp', 'phoenix', 'cache', 'feather', 'surge', 'ironclad', 'hearty', 'precision', 'tithe', 'study'];
  const sorted = offers.slice().sort((a, b) => {
    const ia = order.indexOf(a.id);
    const ib = order.indexOf(b.id);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
  });
  return sorted[0].id;
}

export function botPickDraft(p, offers) {
  let best = 0;
  let bestScore = -1;
  offers.forEach((o, i) => {
    const owned = p.allUnits().filter((u) => u.id === o.champ).length;
    const ch = CHAMPION_BY_ID[o.champ];
    const likes = p.rival ? ch.traits.filter((t) => p.rival.likes.includes(t)).length : 0;
    const s = owned * 3 + likes * 2 + ch.cost;
    if (s > bestScore) { bestScore = s; best = i; }
  });
  return best;
}

export { TRAITS, traitTier };
