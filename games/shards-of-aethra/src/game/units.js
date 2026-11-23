// Builds the combat-ready numbers for a champion: base stats, star level,
// relics, active traits and boons.
import { CHAMPION_BY_ID } from '../data/champions.js';
import { ITEMS } from '../data/items.js';
import { TRAITS, TRAIT_ORDER } from '../data/traits.js';
import { MONSTERS } from '../data/world.js';

export const STAR_HP = [1, 1.8, 3.24];
export const STAR_AD = [1, 1.5, 2.25];

let uidCounter = 1;
export function newUid() {
  return uidCounter++;
}

// A unit as owned by a player (bench or board), not yet in combat.
export function makeOwnedUnit(champId, star = 1) {
  return { uid: newUid(), id: champId, star, items: [] };
}

export function sellValue(u) {
  const c = CHAMPION_BY_ID[u.id].cost;
  if (u.star === 1) return c;
  const mult = u.star === 2 ? 3 : 9;
  return c * mult - (c > 1 ? 1 : 0);
}

// Count unique champions per trait on a board.
export function countTraits(boardUnits, extraEmblems = {}) {
  const seen = new Set();
  const counts = {};
  for (const u of boardUnits) {
    if (!u || seen.has(u.id)) continue;
    seen.add(u.id);
    const ch = CHAMPION_BY_ID[u.id];
    if (!ch) continue;
    for (const t of ch.traits) counts[t] = (counts[t] || 0) + 1;
  }
  for (const [t, n] of Object.entries(extraEmblems)) counts[t] = (counts[t] || 0) + n;
  return counts;
}

// Returns [{id, count, tier (-1 = inactive), next}] sorted the way the HUD shows them.
export function activeTraits(counts) {
  const out = [];
  for (const id of TRAIT_ORDER) {
    const n = counts[id] || 0;
    if (!n) continue;
    const levels = TRAITS[id].levels;
    let tier = -1;
    for (let i = 0; i < levels.length; i++) if (n >= levels[i]) tier = i;
    out.push({ id, count: n, tier, levels });
  }
  out.sort((a, b) => (b.tier - a.tier) || (b.count - a.count));
  return out;
}

export function traitTier(counts, id) {
  const n = counts[id] || 0;
  const levels = TRAITS[id].levels;
  let tier = -1;
  for (let i = 0; i < levels.length; i++) if (n >= levels[i]) tier = i;
  return tier;
}

// Base numbers for a champion at a star level, plus relic stats. Trait and boon
// effects are applied inside the combat sim because many of them are dynamic.
export function computeStats(owned) {
  const ch = CHAMPION_BY_ID[owned.id];
  const s = ch.stats;
  const k = owned.star - 1;
  const st = {
    hp: Math.round(s.hp * STAR_HP[k]),
    ad: Math.round(s.ad * STAR_AD[k]),
    as: s.as,
    armor: s.armor,
    mr: s.mr,
    range: s.range,
    ap: 0,
    crit: 0.25,
    critDmg: 1.4,
    mana: s.mana[0],
    maxMana: s.mana[1],
  };
  for (const itemId of owned.items) {
    const it = ITEMS[itemId];
    if (!it) continue;
    for (const [key, v] of Object.entries(it.stats)) {
      if (key === 'as') st.as *= 1 + v;
      else if (key === 'critDmg') st.critDmg += v;
      else st[key] = (st[key] || 0) + v;
    }
  }
  st.maxMana = Math.max(10, st.maxMana);
  return st;
}

export function monsterStats(monId, stageScale = 1) {
  const m = MONSTERS[monId];
  return {
    hp: Math.round(m.hp * stageScale), ad: Math.round(m.ad * stageScale), as: m.as, armor: m.armor, mr: m.mr,
    range: m.range, ap: 0, crit: 0, critDmg: 1.4, mana: 0, maxMana: 9999,
  };
}

// Ability value for the unit's star level.
export function abilityValue(champId, key, star) {
  const v = CHAMPION_BY_ID[champId].ability.v[key];
  if (!v) return 0;
  const raw = v[Math.min(star, 3) - 1];
  if (typeof raw === 'string' && raw.endsWith('%')) return parseFloat(raw) / 100;
  return raw;
}

// Human-readable ability description with numbers for the current star.
export function abilityText(champId, star, ap = 0) {
  const ab = CHAMPION_BY_ID[champId].ability;
  return ab.desc.replace(/\{(\w+)\}/g, (_, key) => {
    const vals = ab.v[key];
    if (!vals) return key;
    return vals.map((x, i) => {
      let shown = x;
      if (typeof x === 'number' && (key === 'dmg' || key === 'heal' || key === 'shield')) shown = Math.round(x * (1 + ap / 100));
      return i === star - 1 ? `<b>${shown}</b>` : `${shown}`;
    }).join('/');
  });
}
