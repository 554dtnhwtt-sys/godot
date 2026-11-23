// Shard relics. Eight components; any two combine into one of 36 completed relics.

export const COMPONENTS = {
  blade: { name: 'Ember Blade', stats: { ad: 12 }, color: '#ff7b47', glyph: 'sword', desc: '+12 Attack Damage' },
  bow: { name: 'Swift Bow', stats: { as: 0.12 }, color: '#f5d14a', glyph: 'bow', desc: '+12% Attack Speed' },
  plate: { name: 'Ward Plate', stats: { armor: 20 }, color: '#b9c3cf', glyph: 'shield', desc: '+20 Armor' },
  veil: { name: 'Mistweave Veil', stats: { mr: 20 }, color: '#9c7dff', glyph: 'cloak', desc: '+20 Magic Resist' },
  rod: { name: 'Shard Rod', stats: { ap: 12 }, color: '#4fb3ff', glyph: 'rod', desc: '+12 Ability Power' },
  tear: { name: 'Tidal Tear', stats: { mana: 15 }, color: '#3fe0d0', glyph: 'tear', desc: '+15 starting Mana' },
  belt: { name: "Titan's Belt", stats: { hp: 160 }, color: '#e8536a', glyph: 'heart', desc: '+160 Health' },
  glove: { name: "Gambler's Glove", stats: { crit: 0.2 }, color: '#7ee07a', glyph: 'glove', desc: '+20% Critical Strike Chance' },
};

export const COMPONENT_ORDER = ['blade', 'bow', 'plate', 'veil', 'rod', 'tear', 'belt', 'glove'];

// Completed relics. key: two component ids joined in COMPONENT_ORDER order.
const RAW = {
  'blade+blade': { name: 'Deathbringer', glyph: 'skull', bonus: { ad: 10 }, fx: { dmgAmp: 0.2 }, desc: 'Deal 20% more damage.' },
  'blade+bow': { name: 'Stormstrike Saber', glyph: 'bolt', fx: { spark: { every: 3, dmg: 70, targets: 3 } }, desc: 'Every third attack releases lightning that strikes 3 enemies for 70 magic damage.' },
  'blade+plate': { name: 'Last Stand Aegis', glyph: 'aegis', fx: { lowShield: { at: 0.5, pct: 0.25, as: 0.25 } }, desc: 'The first time the holder drops below 50% Health, gain a shield equal to 25% max Health and 25% attack speed.' },
  'blade+veil': { name: 'Bloodsong Blade', glyph: 'fang', fx: { vamp: 0.22 }, desc: 'Heal for 22% of all damage dealt.' },
  'blade+rod': { name: 'Runeblade', glyph: 'rune', fx: { vamp: 0.15, allyHeal: 0.15 }, desc: 'Heal for 15% of damage dealt. The weakest ally is healed for the same amount.' },
  'blade+tear': { name: 'Tidespear', glyph: 'spear', fx: { manaOnHit: 5 }, desc: 'Attacks restore 5 extra mana.' },
  'blade+belt': { name: "Titan's Cleaver", glyph: 'axe', fx: { lowShield: { at: 0.6, pct: 0.3, ad: 0.3 } }, desc: 'The first time the holder drops below 60% Health, gain a shield equal to 30% max Health and 30% more damage.' },
  'blade+glove': { name: "Executioner's Edge", glyph: 'edge', bonus: { critDmg: 0.2 }, fx: { abilityCrit: true }, desc: 'Abilities can critically strike. +20% Critical Damage.' },
  'bow+bow': { name: 'Rapidfire Wings', glyph: 'wings', fx: { asStackHit: 0.05 }, desc: 'Every attack grants 5% attack speed for the rest of combat.' },
  'bow+plate': { name: 'Momentum Plate', glyph: 'chevron', fx: { momentum: { per: 2, max: 25, resist: 25 } }, desc: 'Gain 2 Attack Damage and 2 Ability Power when attacking or being hit, up to 25 times. At full stacks, gain 25 Armor and MR.' },
  'bow+veil': { name: 'Twinshot Quiver', glyph: 'twin', fx: { split: 0.6 }, desc: 'Attacks fire an extra bolt at a second enemy for 60% damage.' },
  'bow+rod': { name: 'Arcflux Staff', glyph: 'flux', fx: { postCastAs: 0.6 }, desc: 'After casting, gain 60% attack speed for 5s.' },
  'bow+tear': { name: 'Stormcaller Orb', glyph: 'orb', fx: { spark: { every: 3, dmg: 80, targets: 4, shredMr: true } }, desc: 'Every third attack strikes 4 enemies for 80 magic damage and Shreds their Magic Resist by 30% for 4s.' },
  'bow+belt': { name: "Zealot's Sash", glyph: 'sash', fx: { healOnHit: 0.015 }, desc: 'Attacks heal the holder for 1.5% of their max Health.' },
  'bow+glove': { name: 'Sunder Gauntlet', glyph: 'fist', fx: { critShred: true }, desc: 'Critical strikes Shred the target\'s Armor by 35% for 4s.' },
  'plate+plate': { name: 'Bastion Plate', glyph: 'tower', bonus: { armor: 20 }, fx: { thorns: { dmg: 70, cd: 2 } }, desc: 'When hit, deal 70 magic damage to adjacent enemies (once every 2s).' },
  'plate+veil': { name: "Warden's Cuirass", glyph: 'cuirass', fx: { stackResist: { per: 3, max: 20 } }, desc: 'Gain 3 Armor and MR each time the holder is hit, up to 20 times.' },
  'plate+rod': { name: 'Dawn Locket', glyph: 'locket', fx: { startShieldAdj: 280 }, desc: 'At the start of combat, shield the holder and adjacent allies for 280.' },
  'plate+tear': { name: 'Frostward Aegis', glyph: 'frost', fx: { slowAura: 0.25 }, desc: 'Enemies within 2 hexes have 25% reduced attack speed.' },
  'plate+belt': { name: 'Sunflare Mantle', glyph: 'sun', fx: { burnAura: true }, desc: 'Every 2s, Burn adjacent enemies and reduce their healing by 33%.' },
  'plate+glove': { name: 'Mirrorguard', glyph: 'mirror', fx: { dr: 0.15, critImmune: true }, desc: 'Take 15% less damage. Immune to critical strikes.' },
  'veil+veil': { name: 'Dragonscale Veil', glyph: 'scale', bonus: { mr: 20 }, fx: { mdr: 0.3 }, desc: 'Take 30% less magic damage.' },
  'veil+rod': { name: 'Ion Mantle', glyph: 'ion', fx: { mrAura: 0.4, castZap: 140 }, desc: 'Enemies within 2 hexes have 40% less MR. When they cast, they take 140 magic damage.' },
  'veil+tear': { name: 'Chalice of Tides', glyph: 'chalice', fx: { manaRegen: 3 }, desc: 'Restore 3 mana every second.' },
  'veil+belt': { name: 'Lifewell Cloak', glyph: 'drop', fx: { regen: 0.03 }, desc: 'Heal 3% of max Health every second.' },
  'veil+glove': { name: 'Quicksilver Charm', glyph: 'charm', fx: { ccImmune: 15 }, desc: 'Immune to crowd control for the first 15s of combat.' },
  'rod+rod': { name: 'Archmage Crown', glyph: 'crown', bonus: { ap: 45 }, desc: 'Gain an extra 45 Ability Power.' },
  'rod+tear': { name: 'Codex of Echoes', glyph: 'book', fx: { manaAfterCast: 15 }, desc: 'After casting, the holder keeps 15 mana.' },
  'rod+belt': { name: 'Morningstar', glyph: 'morning', fx: { abilityBurn: true }, desc: 'Abilities Burn targets and reduce their healing by 33%.' },
  'rod+glove': { name: 'Jeweled Focus', glyph: 'gem', bonus: { crit: 0.1 }, fx: { abilityCrit: true }, desc: 'Abilities can critically strike. +10% Crit Chance.' },
  'tear+tear': { name: 'Twin Tears', glyph: 'tears', fx: { manaCostRed: 10 }, desc: 'Ability mana cost reduced by 10.' },
  'tear+belt': { name: 'Tide Heart', glyph: 'tideheart', fx: { healPulse: 0.12 }, desc: 'Every 5s, heal allies within 2 hexes for 12% of their missing Health.' },
  'tear+glove': { name: "Fortune's Locket", glyph: 'coin', fx: { goldOnWin: 1 }, desc: 'If the holder survives combat, gain 1 gold.' },
  'belt+belt': { name: 'Colossus Heart', glyph: 'colossus', bonus: { hp: 500 }, desc: 'Gain an extra 500 Health.' },
  'belt+glove': { name: 'Bloodrage Talisman', glyph: 'rage', fx: { bloodrage: { at: 0.5, as: 0.4, vamp: 0.15 } }, desc: 'Below 50% Health, gain 40% attack speed and heal for 15% of damage dealt.' },
  'glove+glove': { name: "Gambler's Fortune", glyph: 'dice', bonus: { crit: 0.1, critDmg: 0.3 }, desc: '+10% Crit Chance and +30% Critical Damage.' },
};

function addStats(a, b) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b || {})) out[k] = (out[k] || 0) + v;
  return out;
}

export const ITEMS = {};
for (const id of COMPONENT_ORDER) {
  ITEMS[id] = { id, component: true, ...COMPONENTS[id], colors: [COMPONENTS[id].color] };
}
for (const [key, it] of Object.entries(RAW)) {
  const [a, b] = key.split('+');
  const stats = addStats(addStats(COMPONENTS[a].stats, COMPONENTS[b].stats), it.bonus);
  ITEMS[key] = {
    id: key, component: false, name: it.name, glyph: it.glyph, stats, fx: it.fx || {},
    desc: it.desc, recipe: [a, b], colors: [COMPONENTS[a].color, COMPONENTS[b].color],
  };
}

export function combineKey(a, b) {
  const ia = COMPONENT_ORDER.indexOf(a);
  const ib = COMPONENT_ORDER.indexOf(b);
  if (ia < 0 || ib < 0) return null;
  return ia <= ib ? `${a}+${b}` : `${b}+${a}`;
}

export function statLine(stats) {
  const names = { ad: 'AD', as: 'AS', armor: 'Armor', mr: 'MR', ap: 'AP', mana: 'Mana', hp: 'Health', crit: 'Crit', critDmg: 'Crit Dmg' };
  return Object.entries(stats).map(([k, v]) => {
    const pct = k === 'as' || k === 'crit' || k === 'critDmg';
    return `+${pct ? Math.round(v * 100) + '%' : v} ${names[k] || k}`;
  }).join('  ');
}
