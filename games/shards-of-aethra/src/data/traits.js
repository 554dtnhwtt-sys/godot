// Origins (where a champion's shard fell) and classes (how they fight).
// `levels` are the breakpoints; `fx` holds the numbers the combat sim reads per active tier.

export const TRAITS = {
  // ───────── Origins ─────────
  ember: {
    name: 'Emberforged', kind: 'origin', color: '#ff7a2e', icon: 'flame',
    levels: [2, 4],
    desc: 'Emberforged champions set their targets ablaze. Damage from Emberforged champions Burns, dealing a % of the target\'s max Health as true damage each second for 3s, and reduces healing on it by 33%.',
    tiers: ['1% max Health per second', '2.5% max Health per second, and Emberforged gain 20% damage'],
    fx: [{ burn: 0.01 }, { burn: 0.025, dmgAmp: 0.2 }],
    lore: 'Smiths and zealots of the Cinder Peaks, who temper their bodies in shardfire.',
  },
  tide: {
    name: 'Tidebound', kind: 'origin', color: '#2fd0c8', icon: 'wave',
    levels: [2, 4],
    desc: 'The tide always returns. Every 3 seconds, Tidebound champions restore mana.',
    tiers: ['6 mana', '14 mana, and all allies restore 4 mana'],
    fx: [{ mana: 6 }, { mana: 14, teamMana: 4 }],
    lore: 'Sea-folk of the Drowned Reach, whose cities rose from the ocean floor when the shards fell.',
  },
  wild: {
    name: 'Wildroot', kind: 'origin', color: '#66d65a', icon: 'leaf',
    levels: [2, 4],
    desc: 'Wildroot champions regenerate a % of their max Health every second.',
    tiers: ['1.5% per second', '3.5% per second, and they gain 200 Health'],
    fx: [{ regen: 0.015 }, { regen: 0.035, hp: 200 }],
    lore: 'Beasts and spirits of the Thornwood, a forest that woke up when a shard struck its oldest tree.',
  },
  hollow: {
    name: 'Hollow', kind: 'origin', color: '#a065ff', icon: 'eye',
    levels: [2, 4],
    desc: 'The hunger beneath the world. Hollow champions deal bonus true damage, increased against enemies below 50% Health.',
    tiers: ['12% bonus true damage', '30% bonus true damage'],
    fx: [{ trueDmg: 0.12 }, { trueDmg: 0.3 }],
    lore: 'Things that crawled up from the Hollow, the dark the Starheart once kept sealed.',
  },
  gear: {
    name: 'Gearwright', kind: 'origin', color: '#ffbf3c', icon: 'gear',
    levels: [2, 4],
    desc: 'Gearwright champions overclock as combat goes on, gaining attack speed every 4 seconds (stacks 4 times).',
    tiers: ['10% attack speed per stack', '22% attack speed per stack, and they start combat with a 250 shield'],
    fx: [{ asStack: 0.10 }, { asStack: 0.22, shield: 250 }],
    lore: 'Artificers of Brassholm, who learned to bottle shardlight and run it through copper.',
  },
  frost: {
    name: 'Frostborn', kind: 'origin', color: '#8fdcff', icon: 'snow',
    levels: [2, 4],
    desc: 'Frostborn attacks have a chance to Chill, reducing the target\'s attack speed by 30% for 2s.',
    tiers: ['25% chance', '50% chance, and Chilled enemies take 15% more damage'],
    fx: [{ chill: 0.25 }, { chill: 0.5, chillAmp: 0.15 }],
    lore: 'Clans of Rime, a land frozen in the instant of the Sundering and never thawed.',
  },

  // ───────── Classes ─────────
  bulwark: {
    name: 'Bulwark', kind: 'class', color: '#c9b37e', icon: 'shield',
    levels: [2, 4],
    desc: 'Bulwarks gain bonus Armor and Magic Resist.',
    tiers: ['+30 Armor & MR', '+70 Armor & MR, and other allies gain +20'],
    fx: [{ resist: 30 }, { resist: 70, teamResist: 20 }],
  },
  duelist: {
    name: 'Duelist', kind: 'class', color: '#e8695a', icon: 'swords',
    levels: [2, 4],
    desc: 'Every attack grants Duelists bonus attack speed, stacking up to 8 times.',
    tiers: ['6% per stack', '12% per stack'],
    fx: [{ asOnHit: 0.06 }, { asOnHit: 0.12 }],
  },
  ranger: {
    name: 'Ranger', kind: 'class', color: '#9ad35a', icon: 'bow',
    levels: [2, 4],
    desc: 'Ranger attacks have a chance to fire a second shot.',
    tiers: ['30% chance', '65% chance'],
    fx: [{ double: 0.3 }, { double: 0.65 }],
  },
  arcanist: {
    name: 'Arcanist', kind: 'class', color: '#6ab0ff', icon: 'star',
    levels: [2, 4],
    desc: 'Arcanists gain Ability Power. Your whole team gains some too.',
    tiers: ['Arcanists +25 AP, team +10 AP', 'Arcanists +70 AP, team +25 AP'],
    fx: [{ ap: 25, teamAp: 10 }, { ap: 70, teamAp: 25 }],
  },
  shadow: {
    name: 'Shadowblade', kind: 'class', color: '#c45bd6', icon: 'dagger',
    levels: [2, 4],
    desc: 'At the start of combat, Shadowblades leap to the enemy backline. They gain Critical Strike Chance and Critical Damage, and their abilities can critically strike.',
    tiers: ['+20% Crit Chance, +15% Crit Damage', '+45% Crit Chance, +40% Crit Damage'],
    fx: [{ crit: 0.2, critDmg: 0.15 }, { crit: 0.45, critDmg: 0.4 }],
  },
  mender: {
    name: 'Mender', kind: 'class', color: '#7ef0c4', icon: 'cross',
    levels: [2, 3],
    desc: 'Every 5 seconds, Menders shield the weakest ally for 4s.',
    tiers: ['180 shield', '420 shield'],
    fx: [{ shield: 180 }, { shield: 420 }],
  },
};

export const TRAIT_ORDER = ['ember', 'tide', 'wild', 'hollow', 'gear', 'frost', 'bulwark', 'duelist', 'ranger', 'arcanist', 'shadow', 'mender'];
