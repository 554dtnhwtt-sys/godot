// Lore, boons (augments), monsters, rival Wardens and the round schedule.

export const GAME_TITLE = 'Shards of Aethra';

export const WORLD_LORE = [
  {
    heading: 'The Starheart',
    text: 'For ten thousand years a second sun hung above Aethra. The Starheart held the sky-isles aloft, kept the Hollow sealed beneath the world, and gave every living thing its light. Nobody alive remembers a night without it.',
  },
  {
    heading: 'The Sundering',
    text: 'Three hundred years ago the Starheart cracked. Some say the Hollow gnawed through it from below; some say a Warden tried to steal its fire. It burst into a thousand shards that rained across the world. Where they fell, power woke up: in the forges of the Cinder Peaks, in the drowned cities of the Reach, in the Thornwood\'s oldest roots, in the copper halls of Brassholm and in the endless winter of Rime. And in the Hollow, something very old began to climb.',
  },
  {
    heading: 'The Convergence',
    text: 'Now the shards are calling to each other. Once every cycle the Convergence opens: a ring of floating arenas where eight Wardens bind champions with shardlight and test them against each other. Whoever gathers enough shards can rebuild the Starheart, or remake it in their own image. Eight Wardens enter. Only one leaves crowned.',
  },
  {
    heading: 'Wardens',
    text: 'You are a Warden: one of the few who can hear the shards sing. Champions answer your call through shard-cards. Bind three of the same champion and the shards fuse, raising them to a higher star. Arm them with relics salvaged from the battlefield. Read your rivals. Spend wisely. The Convergence does not forgive.',
  },
];

// Boons are offered three at a time at 2-1, 3-2 and 4-2.
export const BOONS = [
  { id: 'tithe', name: 'Golden Tithe', icon: 'coin', tier: 1, desc: 'Gain 14 gold now.' },
  { id: 'study', name: 'Swift Study', icon: 'book', tier: 1, desc: 'Gain 8 XP now and 1 extra XP every round.' },
  { id: 'cache', name: 'Shard Cache', icon: 'chest', tier: 1, desc: 'Gain 2 random relic components.' },
  { id: 'hoard', name: 'Relic Hoard', icon: 'gem', tier: 2, desc: 'Gain a random completed relic.' },
  { id: 'feather', name: 'Featherlight', icon: 'wings', tier: 1, desc: 'Your champions gain 15% attack speed.' },
  { id: 'ironclad', name: 'Ironclad', icon: 'shield', tier: 1, desc: 'Your champions gain 20 Armor and MR.' },
  { id: 'surge', name: 'Arcane Surge', icon: 'star', tier: 1, desc: 'Your champions gain 20 Ability Power.' },
  { id: 'hearty', name: 'Hearty Stew', icon: 'heart', tier: 1, desc: 'Your champions gain 180 Health.' },
  { id: 'precision', name: 'Precision', icon: 'edge', tier: 1, desc: 'Your champions gain 15% Crit Chance and 20% Crit Damage.' },
  { id: 'vamp', name: 'Celestial Blessing', icon: 'drop', tier: 2, desc: 'Your champions heal for 12% of all damage they deal.' },
  { id: 'phoenix', name: 'Phoenix Feather', icon: 'flame', tier: 2, desc: 'The first champion of yours to die each combat is reborn with 40% Health.' },
  { id: 'warband', name: 'Warband', icon: 'crown', tier: 2, desc: 'You can field one more champion.' },
  { id: 'reroll', name: 'Fate Weaver', icon: 'dice', tier: 1, desc: 'Gain one free shop refresh every round.' },
  { id: 'secondwind', name: 'Second Wind', icon: 'leaf', tier: 1, desc: 'After 10s of combat, your champions heal 30% of their missing Health.' },
  { id: 'bounty', name: 'Blood Money', icon: 'skull', tier: 1, desc: 'Gain 1 gold whenever your team gets 3 takedowns in one combat.' },
  { id: 'interest', name: 'Tidal Wealth', icon: 'wave', tier: 1, desc: 'Your maximum interest is increased by 2 gold.' },
  { id: 'thrill', name: 'Thrill of the Hunt', icon: 'fang', tier: 1, desc: 'Your champions heal 250 Health after scoring a takedown.' },
  { id: 'mana', name: 'Wellspring', icon: 'tear', tier: 1, desc: 'Your champions start combat with 20 extra mana.' },
];

// Monster rounds. Each monster is built by the renderer from `look`.
export const MONSTERS = {
  shardling: { name: 'Shardling', hp: 320, ad: 22, as: 0.6, armor: 10, mr: 10, range: 1, look: 'shardling' },
  shardgolem: { name: 'Shard Golem', hp: 700, ad: 40, as: 0.55, armor: 25, mr: 25, range: 1, look: 'golem' },
  riftwolf: { name: 'Rift Wolf', hp: 900, ad: 70, as: 0.75, armor: 30, mr: 30, range: 1, look: 'wolf' },
  alphawolf: { name: 'Alpha Rift Wolf', hp: 1700, ad: 110, as: 0.75, armor: 40, mr: 40, range: 1, look: 'wolf', scale: 1.35 },
  sentinel: { name: 'Brass Sentinel', hp: 2100, ad: 120, as: 0.6, armor: 60, mr: 40, range: 1, look: 'golem', tint: '#c08a3a', scale: 1.3 },
  drake: { name: 'Ancient Drake', hp: 5600, ad: 180, as: 0.6, armor: 70, mr: 70, range: 2, look: 'drake', scale: 1.6 },
  behemoth: { name: 'Hollow Behemoth', hp: 9000, ad: 260, as: 0.55, armor: 90, mr: 90, range: 1, look: 'golem', tint: '#5a2c8a', scale: 1.8 },
  starwyrm: { name: 'The Starwyrm', hp: 14000, ad: 320, as: 0.65, armor: 100, mr: 100, range: 2, look: 'drake', tint: '#ffd36a', scale: 2.0 },
};

export const MONSTER_WAVES = {
  '1-1': [['shardling', 3, 1], ['shardling', 3, 5]],
  '1-2': [['shardling', 2, 2], ['shardling', 3, 3], ['shardling', 2, 5]],
  '1-3': [['shardling', 2, 1], ['shardgolem', 3, 3], ['shardling', 2, 5]],
  '2-7': [['riftwolf', 2, 2], ['alphawolf', 3, 3], ['riftwolf', 2, 4]],
  '3-7': [['sentinel', 2, 2], ['sentinel', 2, 4]],
  '4-7': [['drake', 2, 3]],
  '5-7': [['behemoth', 2, 3]],
  '6-7': [['starwyrm', 2, 3]],
  '7-7': [['starwyrm', 2, 2], ['behemoth', 2, 4]],
};

// Rival Wardens controlled by the computer.
export const RIVALS = [
  { name: 'Ashveil', color: '#ff7a2e', likes: ['ember', 'duelist'], style: 'aggressive' },
  { name: 'Coralyn', color: '#2fd0c8', likes: ['tide', 'arcanist'], style: 'econ' },
  { name: 'Mirefox', color: '#66d65a', likes: ['wild', 'ranger'], style: 'balanced' },
  { name: 'Gloomhorn', color: '#a065ff', likes: ['hollow', 'shadow'], style: 'aggressive' },
  { name: 'Copperjack', color: '#ffbf3c', likes: ['gear', 'shadow'], style: 'balanced' },
  { name: 'Rimeheart', color: '#8fdcff', likes: ['frost', 'bulwark'], style: 'econ' },
  { name: 'Duskwhisper', color: '#c45bd6', likes: ['hollow', 'arcanist'], style: 'balanced' },
  { name: 'Brassbeard', color: '#c9b37e', likes: ['gear', 'duelist'], style: 'aggressive' },
];

// Stage layout: stage 1 is three monster rounds; later stages are
// PvP, PvP, PvP, Draft, PvP, PvP, Monsters.
export function roundKind(stage, round) {
  if (stage === 1) return 'pve';
  if (round === 4) return 'draft';
  if (round === 7) return 'pve';
  return 'pvp';
}

export function roundsInStage(stage) {
  return stage === 1 ? 3 : 7;
}

// Base damage a losing Warden takes, by stage.
export const STAGE_DAMAGE = { 1: 0, 2: 2, 3: 5, 4: 8, 5: 10, 6: 12, 7: 17, 8: 150 };

export const BOON_ROUNDS = ['2-1', '3-2', '4-2'];

export const PLANNING_SECONDS = 30;
export const COMBAT_MAX_SECONDS = 35;
