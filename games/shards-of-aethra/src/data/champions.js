// Shards of Aethra — champion roster.
// Every champion, its stats, its ability numbers, its voice and its lore live here.
// Ability behaviour is implemented in src/game/abilities.js, keyed by champion id.

export const COST_COLORS = {
  1: '#9aa4b1',
  2: '#3fbf6a',
  3: '#3b8cf0',
  4: '#b35cf2',
  5: '#f2b53b',
};

// stats: hp, ad, as (attacks/s), armor, mr, range (hexes), mana [start, max]
// ability.v: per-star values [1★, 2★, 3★]; the description uses {name} placeholders.
export const CHAMPIONS = [
  // ───────────────────────────── 1 COST ─────────────────────────────
  {
    id: 'brakka', name: 'Brakka', title: 'the Anvil', cost: 1, traits: ['ember', 'bulwark'],
    stats: { hp: 650, ad: 50, as: 0.6, armor: 45, mr: 45, range: 1, mana: [30, 80] },
    ability: {
      name: 'Anvil Slam', type: 'magic',
      desc: 'Slams his anvil down, dealing {dmg} magic damage to adjacent enemies and stunning them for 1.25s. Gains a {shield} shield for 4s.',
      v: { dmg: [150, 225, 350], shield: [220, 320, 480] },
    },
    voice: { v: 'am_onyx', speed: 0.92, pitch: 0.86, fx: 'forge' },
    lines: {
      select: ['The forge never sleeps!', "Hammer's hot. Let's get to work."],
      ability: 'Anvil!',
      upgrade: 'Tempered and true!',
      death: 'The fire... goes out...',
    },
    lore: "Brakka was the last apprentice of the Cinder Peaks' great forge when the Starheart shattered. A burning shard fell straight into his anvil. He has carried it, anvil and all, into every fight since, and he swears it hums when trouble is near.",
  },
  {
    id: 'marlo', name: 'Marlo', title: 'Reefrunner', cost: 1, traits: ['tide', 'duelist'],
    stats: { hp: 600, ad: 55, as: 0.75, armor: 30, mr: 30, range: 1, mana: [0, 60] },
    ability: {
      name: 'Riptide Lunge', type: 'physical',
      desc: 'Lunges through his target, dealing {dmg} physical damage and gaining {as} attack speed for 4s.',
      v: { dmg: [200, 300, 460], as: ['40%', '50%', '70%'] },
    },
    voice: { v: 'am_puck', speed: 1.1, pitch: 1.1, fx: 'none' },
    lines: {
      select: ["Tide's turning, and it's turning my way!", 'Catch me if you can!'],
      ability: 'Riptide!',
      upgrade: "Now I'm a real wave!",
      death: 'Back to... the deep...',
    },
    lore: 'The fastest runner in the drowned city of Corallis, Marlo learned to fight by racing sharks through sunken bell towers. He joined the Convergence on a dare and has refused to leave ever since.',
  },
  {
    id: 'fennick', name: 'Fennick', title: 'Thornwood Scout', cost: 1, traits: ['wild', 'ranger'],
    stats: { hp: 500, ad: 55, as: 0.75, armor: 20, mr: 20, range: 4, mana: [0, 60] },
    ability: {
      name: 'Thornshot', type: 'physical',
      desc: 'Fires a piercing thorn arrow through her target, dealing {dmg} physical damage to every enemy in a line.',
      v: { dmg: [190, 285, 430] },
    },
    voice: { v: 'af_sky', speed: 1.05, pitch: 1.04, fx: 'none' },
    lines: {
      select: ['Eyes sharp, tail sharper.', 'The wood whispers. I listen.'],
      ability: 'Loose!',
      upgrade: 'Even the old oaks are impressed!',
      death: 'Tell the woods... I tried...',
    },
    lore: 'Fennick guards the outer paths of the Thornwood, where the trees walk at night. She has never missed a shot, though she claims the one time she did, the arrow simply came back.',
  },
  {
    id: 'skitter', name: 'Skitter', title: 'Void Nibbler', cost: 1, traits: ['hollow', 'shadow'],
    stats: { hp: 500, ad: 60, as: 0.75, armor: 25, mr: 25, range: 1, mana: [0, 50] },
    ability: {
      name: 'Gnash', type: 'physical',
      desc: 'Leaps onto the weakest enemy within 3 hexes and gnashes it for {dmg} physical damage.',
      v: { dmg: [220, 330, 500] },
    },
    voice: { v: 'am_puck', speed: 1.12, pitch: 1.32, fx: 'imp' },
    lines: {
      select: ['Hehehe... shiny...', 'Skitter hungry. Skitter go!'],
      ability: 'Nom nom!',
      upgrade: 'Skitter BIGGER now!',
      death: 'Skitter... fade...',
    },
    lore: 'Skitter crawled out of a crack in the Hollow looking for something to eat. It found the Convergence, which is full of things to eat. It is very happy here.',
  },
  {
    id: 'pim', name: 'Pim Sparkwhistle', title: 'Mad Tinker', cost: 1, traits: ['gear', 'arcanist'],
    stats: { hp: 480, ad: 40, as: 0.65, armor: 20, mr: 20, range: 4, mana: [20, 70] },
    ability: {
      name: 'Spark Bomb', type: 'magic',
      desc: 'Lobs a sparking bomb at his target, dealing {dmg} magic damage to it and half as much to adjacent enemies.',
      v: { dmg: [210, 315, 470] },
    },
    voice: { v: 'bm_fable', speed: 1.15, pitch: 1.16, fx: 'none' },
    lines: {
      select: ['Ooh! What does this button do?', 'Calculations complete. Probably!'],
      ability: 'Fire in the hole!',
      upgrade: 'Version two point oh!',
      death: "That... wasn't in the blueprint...",
    },
    lore: "Pim has been banned from four of Brassholm's five workshops. The fifth one exploded before it could ban him. He insists every invention works perfectly, eventually.",
  },
  {
    id: 'snorri', name: 'Snorri', title: 'Little Avalanche', cost: 1, traits: ['frost', 'bulwark'],
    stats: { hp: 700, ad: 45, as: 0.55, armor: 40, mr: 40, range: 1, mana: [40, 90] },
    ability: {
      name: 'Frosty Roar', type: 'magic',
      desc: 'Roars, dealing {dmg} magic damage to adjacent enemies and Chilling them (−30% attack speed) for 3s. Gains {armor} Armor and MR for the rest of combat.',
      v: { dmg: [120, 180, 280], armor: [25, 35, 55] },
    },
    voice: { v: 'am_fenrir', speed: 1.0, pitch: 1.12, fx: 'none' },
    lines: {
      select: ['Snorri smash! ...gently.', 'Brr! Good fighting weather!'],
      ability: 'Rooooar!',
      upgrade: 'Snorri grow big like papa!',
      death: 'Snorri... sleepy...',
    },
    lore: 'Snorri is the smallest yeti of the Rime clans, which still makes him taller than most people. He followed the Pale Queen\'s banner south because he heard the Convergence has snowball fights. It does not.',
  },

  // ───────────────────────────── 2 COST ─────────────────────────────
  {
    id: 'pyra', name: 'Pyra Vell', title: 'the Kindled', cost: 2, traits: ['ember', 'arcanist'],
    stats: { hp: 550, ad: 40, as: 0.65, armor: 20, mr: 20, range: 4, mana: [20, 70] },
    ability: {
      name: 'Cinder Bloom', type: 'magic',
      desc: 'Hurls a blooming fireball that explodes on her target, dealing {dmg} magic damage to it and adjacent enemies and Burning them.',
      v: { dmg: [240, 360, 560] },
    },
    voice: { v: 'af_bella', speed: 1.05, pitch: 1.0, fx: 'none' },
    lines: {
      select: ['Burn bright, burn fast!', "You wanted warmth? I'll give you a wildfire."],
      ability: 'Bloom!',
      upgrade: 'Hotter. HOTTER!',
      death: 'Embers... remember me...',
    },
    lore: "Pyra's hair caught fire the day a shard fell outside her village, and it has not gone out since. The Cinder Peaks call her a prodigy. Her old teachers call her a fire hazard.",
  },
  {
    id: 'nerissa', name: 'Nerissa', title: 'Pearl Siren', cost: 2, traits: ['tide', 'mender'],
    stats: { hp: 600, ad: 35, as: 0.6, armor: 25, mr: 30, range: 3, mana: [30, 80] },
    ability: {
      name: 'Song of the Deep', type: 'heal',
      desc: 'Sings to the two weakest allies, healing them for {heal} and reducing the damage they take by 20% for 4s.',
      v: { heal: [230, 320, 460] },
    },
    voice: { v: 'af_heart', speed: 0.95, pitch: 1.0, fx: 'ocean' },
    lines: {
      select: ["Listen to the tide's lullaby.", 'The ocean remembers every song.'],
      ability: 'Rise with the tide.',
      upgrade: 'My voice carries further now.',
      death: 'The song... ends...',
    },
    lore: 'Sirens of the Drowned Reach once sang ships onto the rocks. Nerissa sings sailors back to life instead, which the other sirens consider deeply embarrassing.',
  },
  {
    id: 'bramblehide', name: 'Bramblehide', title: 'Thornback Guardian', cost: 2, traits: ['wild', 'bulwark'],
    stats: { hp: 800, ad: 55, as: 0.55, armor: 50, mr: 40, range: 1, mana: [40, 100] },
    ability: {
      name: 'Thorn Wall', type: 'shield',
      desc: 'Raises his brambles, gaining a {shield} shield for 5s. While shielded, attackers take {thorns} magic damage.',
      v: { shield: [380, 540, 800], thorns: [40, 60, 90] },
    },
    voice: { v: 'am_onyx', speed: 0.88, pitch: 0.78, fx: 'beast' },
    lines: {
      select: ['Hrrmph. Thorns up.', 'Roots deep. I do not move.'],
      ability: 'Bristle!',
      upgrade: 'The forest grows strong.',
      death: 'Return... to the soil...',
    },
    lore: 'Bramblehide has slept against the same hill for two hundred years, and the hill has grown into him. When the Thornwood calls, he simply stands up and brings the hill along.',
  },
  {
    id: 'rivet', name: 'Rivet', title: 'Clockwork Stalker', cost: 2, traits: ['gear', 'shadow'],
    stats: { hp: 600, ad: 65, as: 0.75, armor: 30, mr: 25, range: 1, mana: [0, 60] },
    ability: {
      name: 'Sawblade Rush', type: 'physical',
      desc: 'Spins its saws, dealing {dmg} physical damage to its target and adjacent enemies and Shredding their Armor by 30% for 4s.',
      v: { dmg: [230, 345, 520] },
    },
    voice: { v: 'am_echo', speed: 1.0, pitch: 0.95, fx: 'robot' },
    lines: {
      select: ['Target acquired.', 'Gears turning. Blades spinning.'],
      ability: 'Engage.',
      upgrade: 'Upgrade installed.',
      death: 'System... failure...',
    },
    lore: 'Built to guard the Brassholm vaults, Rivet was left running for a century after its makers died. It kept guarding. Then it started hunting the people who came to rob the vault. Now it hunts for the Wardens, and nobody is sure who winds it up.',
  },
  {
    id: 'isolde', name: 'Isolde', title: 'Frostfletch', cost: 2, traits: ['frost', 'ranger'],
    stats: { hp: 550, ad: 60, as: 0.7, armor: 20, mr: 20, range: 4, mana: [0, 60] },
    ability: {
      name: 'Glacial Arrow', type: 'magic',
      desc: 'Looses an ice arrow at her target, dealing {dmg} magic damage and Chilling it (−30% attack speed) for 3s.',
      v: { dmg: [260, 390, 590] },
    },
    voice: { v: 'bf_isabella', speed: 0.97, pitch: 1.0, fx: 'ice' },
    lines: {
      select: ["Winter's aim is true.", 'Cold hands. Steady heart.'],
      ability: 'Freeze!',
      upgrade: 'The frost deepens.',
      death: 'So... cold...',
    },
    lore: 'Isolde carved her bow from a glacier that has never melted. Hunters of Rime say her arrows do not miss; they simply wait, frozen in the air, until their target walks into them.',
  },

  // ───────────────────────────── 3 COST ─────────────────────────────
  {
    id: 'kaldor', name: 'Kaldor', title: 'Forgeheart', cost: 3, traits: ['ember', 'duelist'],
    stats: { hp: 850, ad: 70, as: 0.75, armor: 40, mr: 35, range: 1, mana: [0, 70] },
    ability: {
      name: 'Molten Frenzy', type: 'buff',
      desc: 'For 5s, gains {as} attack speed and his attacks deal {dmg} bonus magic damage and Burn.',
      v: { as: ['60%', '75%', '100%'], dmg: [50, 75, 125] },
    },
    voice: { v: 'am_michael', speed: 0.98, pitch: 0.9, fx: 'forge' },
    lines: {
      select: ['My axes are thirsty!', "Strike while the iron's hot!"],
      ability: 'Frenzy!',
      upgrade: 'Forged anew!',
      death: 'Cooled... at last...',
    },
    lore: "Kaldor tattooed the forge-runes of his clan onto his own arms with molten iron. They have glowed ever since. In battle they burn so hot that his axes catch fire, which he considers a feature.",
  },
  {
    id: 'brine', name: 'Captain Brine', title: 'Scourge of the Reach', cost: 3, traits: ['tide', 'ranger'],
    stats: { hp: 750, ad: 70, as: 0.7, armor: 30, mr: 30, range: 4, mana: [20, 90] },
    ability: {
      name: 'Broadside', type: 'physical',
      desc: 'Fires {count} cannonballs at random enemies, each dealing {dmg} physical damage.',
      v: { count: [4, 4, 6], dmg: [160, 240, 380] },
    },
    voice: { v: 'bm_george', speed: 0.94, pitch: 0.88, fx: 'none' },
    lines: {
      select: ['Hoist the colors, ye dogs!', 'The sea takes what it is owed.'],
      ability: 'Fire the broadside!',
      upgrade: 'Promoted to admiral! Har!',
      death: 'The deep... is calling...',
    },
    lore: 'Brine Marrow has sunk thirty ships, drowned twice, and come back both times angrier. He claims the sea spat him out because it could not stand his singing.',
  },
  {
    id: 'elowen', name: 'Elowen', title: 'Bloomwarden', cost: 3, traits: ['wild', 'mender'],
    stats: { hp: 750, ad: 40, as: 0.65, armor: 30, mr: 35, range: 3, mana: [40, 90] },
    ability: {
      name: 'Verdant Bloom', type: 'heal',
      desc: 'Blooms, healing all allies within 2 hexes for {heal}. Roots the nearest enemy for 1.5s.',
      v: { heal: [220, 320, 480] },
    },
    voice: { v: 'af_river', speed: 0.94, pitch: 1.0, fx: 'grove' },
    lines: {
      select: ['Every root remembers the light.', 'Grow, little ones.'],
      ability: 'Bloom!',
      upgrade: 'Spring answers my call.',
      death: 'Wither... and return...',
    },
    lore: 'Elowen was a sapling when the Starheart still shone. She remembers its light on her leaves, and she is the only one in the Thornwood who believes it can be rebuilt without burning the world.',
  },
  {
    id: 'veyl', name: 'Veyl', title: 'the Gazing Dark', cost: 3, traits: ['hollow', 'arcanist'],
    stats: { hp: 700, ad: 40, as: 0.65, armor: 25, mr: 30, range: 4, mana: [20, 80] },
    ability: {
      name: 'Gaze of Nothing', type: 'magic',
      desc: 'Her eye stares into the target, dealing {dmg} magic damage and stunning it for 1s.',
      v: { dmg: [380, 570, 900] },
    },
    voice: { v: 'af_kore', speed: 0.92, pitch: 0.9, fx: 'void' },
    lines: {
      select: ['I have already seen your ending.', 'The void looks back.'],
      ability: 'Behold.',
      upgrade: 'My sight widens.',
      death: 'The darkness... welcomes me...',
    },
    lore: 'Veyl traded her eyes to the Hollow for a single glimpse of what lies beneath the world. The Hollow gave her a better one in return. It floats beside her, and it never blinks.',
  },
  {
    id: 'hrimfang', name: 'Hrimfang', title: 'the Frost Hunter', cost: 3, traits: ['frost', 'shadow'],
    stats: { hp: 750, ad: 75, as: 0.75, armor: 35, mr: 30, range: 1, mana: [0, 70] },
    ability: {
      name: 'Frostbite Pounce', type: 'physical',
      desc: 'Pounces on the weakest enemy, dealing {dmg} physical damage and Chilling it for 3s.',
      v: { dmg: [320, 480, 740] },
    },
    voice: { v: 'am_fenrir', speed: 0.95, pitch: 0.86, fx: 'beast' },
    lines: {
      select: ['The hunt begins at dusk.', 'I smell fear... and frost.'],
      ability: 'Pounce!',
      upgrade: 'The pack grows stronger.',
      death: 'The moon... fades...',
    },
    lore: 'Hrimfang was a man once, a hunter who followed a white wolf into a blizzard and never came out. Something did come out. It still answers to his name, mostly.',
  },
  {
    id: 'sigrun', name: 'Sigrun', title: "Winter's Edge", cost: 3, traits: ['frost', 'duelist'],
    stats: { hp: 850, ad: 70, as: 0.7, armor: 40, mr: 35, range: 1, mana: [20, 80] },
    ability: {
      name: 'Glacier Cleave', type: 'physical',
      desc: 'Cleaves her target and the enemies beside it for {dmg} physical damage and gains {armor} Armor for 5s.',
      v: { dmg: [250, 375, 580], armor: [30, 45, 70] },
    },
    voice: { v: 'bf_emma', speed: 0.98, pitch: 0.95, fx: 'none' },
    lines: {
      select: ['My blade sings of winter.', 'Stand fast, or fall.'],
      ability: 'Cleave!',
      upgrade: 'The halls of Rime can wait!',
      death: 'The snow... claims me...',
    },
    lore: "Sigrun won her ice-forged helm by beating the Pale Queen's champion in single combat. She was fourteen. Twenty years later, nobody has managed to take it back.",
  },

  // ───────────────────────────── 4 COST ─────────────────────────────
  {
    id: 'thalassa', name: 'Thalassa', title: 'the Tidecaller', cost: 4, traits: ['tide', 'arcanist'],
    stats: { hp: 850, ad: 50, as: 0.7, armor: 30, mr: 35, range: 4, mana: [30, 100] },
    ability: {
      name: 'Rogue Wave', type: 'magic',
      desc: 'Summons a towering wave through her target, dealing {dmg} magic damage to every enemy in its path and knocking them up for 1s.',
      v: { dmg: [420, 630, 1400] },
    },
    voice: { v: 'af_aoede', speed: 0.93, pitch: 0.97, fx: 'ocean' },
    lines: {
      select: ['The ocean answers only to me.', 'Kneel before the tide.'],
      ability: 'Rise, ocean!',
      upgrade: 'The deep crowns its queen.',
      death: 'Return me... to the sea...',
    },
    lore: "Thalassa raised Corallis from the sea floor with a single song and a single shard. She rules the Drowned Reach the way the tide rules the shore: gently, until it doesn't.",
  },
  {
    id: 'grumbark', name: 'Grumbark', title: 'the Elder', cost: 4, traits: ['wild', 'bulwark'],
    stats: { hp: 1100, ad: 70, as: 0.55, armor: 60, mr: 50, range: 1, mana: [50, 120] },
    ability: {
      name: 'Earthen Wrath', type: 'magic',
      desc: 'Stomps the ground, dealing {dmg} magic damage to adjacent enemies, stunning them for 1.5s and healing himself for 20% of his max Health.',
      v: { dmg: [260, 390, 950] },
    },
    voice: { v: 'am_onyx', speed: 0.8, pitch: 0.72, fx: 'giant' },
    lines: {
      select: ['Hmmm... young ones... always in such a hurry...', 'I have stood... for a thousand years.'],
      ability: 'Roooot!',
      upgrade: 'My rings... grow wider...',
      death: 'Timber...',
    },
    lore: 'Grumbark is the oldest living thing in the Thornwood. He took one step toward the Convergence when the shards began to call. It took him eleven years. He arrived exactly on time.',
  },
  {
    id: 'nyxara', name: "Nyx'ara", title: 'the Unseen', cost: 4, traits: ['hollow', 'shadow'],
    stats: { hp: 800, ad: 85, as: 0.8, armor: 35, mr: 35, range: 1, mana: [0, 60] },
    ability: {
      name: 'Eclipse', type: 'physical',
      desc: 'Blinks behind the weakest enemy and strikes for {dmg} physical damage. If it dies, she strikes another enemy for half damage.',
      v: { dmg: [560, 840, 2100] },
    },
    voice: { v: 'af_nicole', speed: 0.95, pitch: 0.95, fx: 'void' },
    lines: {
      select: ['You never see the blade.', 'The shadows are my sisters.'],
      ability: 'Eclipse.',
      upgrade: 'Darker still.',
      death: 'Into... the void...',
    },
    lore: "Nyx'ara was born during the eclipse that followed the Sundering, and the dark has kept her ever since. She can step through any shadow. In the Convergence, everything casts one.",
  },
  {
    id: 'vexa', name: 'Vexa Coil', title: 'Arc Engineer', cost: 4, traits: ['gear', 'ranger'],
    stats: { hp: 750, ad: 75, as: 0.8, armor: 30, mr: 30, range: 4, mana: [20, 80] },
    ability: {
      name: 'Arc Chain', type: 'magic',
      desc: 'Fires a bolt of lightning that chains between {count} enemies, dealing {dmg} magic damage to each.',
      v: { count: [4, 5, 7], dmg: [310, 465, 1100] },
    },
    voice: { v: 'af_jessica', speed: 1.05, pitch: 1.0, fx: 'none' },
    lines: {
      select: ['Charged and ready!', 'Science beats steel. Every time.'],
      ability: 'Overload!',
      upgrade: 'Maximum voltage!',
      death: 'Short... circuit...',
    },
    lore: 'Vexa lost her arm testing her first arc-rifle and built a better one before the bandages came off. Brassholm calls her a genius. She would like them to call her something with more syllables.',
  },
  {
    id: 'ilsa', name: 'Ilsa', title: 'Phoenix Abbess', cost: 4, traits: ['ember', 'mender'],
    stats: { hp: 900, ad: 45, as: 0.65, armor: 35, mr: 40, range: 3, mana: [40, 100] },
    ability: {
      name: 'Rebirth Flame', type: 'heal',
      desc: 'Calls the phoenix, healing every ally for {heal} and Burning enemies within 2 hexes for {dmg} magic damage.',
      v: { heal: [160, 240, 560], dmg: [160, 240, 560] },
    },
    voice: { v: 'bf_lily', speed: 0.93, pitch: 1.0, fx: 'cathedral' },
    lines: {
      select: ['From ash, we rise.', 'The flame forgives. I do not.'],
      ability: 'Rise again!',
      upgrade: 'My wings unfold.',
      death: 'I will... return...',
    },
    lore: 'The abbey of the Phoenix burned down seven times. Each time, Ilsa walked out of the ashes and rebuilt it. She has stopped counting how many times she has died. The phoenix has not.',
  },

  // ───────────────────────────── 5 COST ─────────────────────────────
  {
    id: 'morgath', name: "Mor'Gath", title: 'Rift Sovereign', cost: 5, traits: ['hollow', 'bulwark'],
    stats: { hp: 1300, ad: 80, as: 0.6, armor: 60, mr: 60, range: 1, mana: [60, 130] },
    ability: {
      name: 'Devour', type: 'true',
      desc: 'Devours the weakest enemy within 2 hexes, dealing {dmg} true damage and healing for 25% of his max Health.',
      v: { dmg: [800, 1200, 9999] },
    },
    voice: { v: 'am_onyx', speed: 0.82, pitch: 0.64, fx: 'abyss' },
    lines: {
      select: ['All things end in me.', 'I am the hunger beneath the world.'],
      ability: 'Devour.',
      upgrade: 'The rift widens.',
      death: 'This... is not... the end.',
    },
    lore: "Mor'Gath is what the Hollow becomes when it is given a shape. He wears the crown of shards he tore from the Starheart's dying core, and he does not want to rebuild it. He wants to finish eating it.",
  },
  {
    id: 'magna', name: 'Magna', title: 'Iron Valkyrie', cost: 5, traits: ['gear', 'duelist'],
    stats: { hp: 1100, ad: 85, as: 0.8, armor: 50, mr: 45, range: 1, mana: [30, 100] },
    ability: {
      name: 'Orbital Lance', type: 'magic',
      desc: 'Launches into the sky and crashes onto her target, dealing {dmg} magic damage to it and adjacent enemies and knocking them up for 1.5s.',
      v: { dmg: [620, 930, 3000] },
    },
    voice: { v: 'af_alloy', speed: 0.98, pitch: 0.98, fx: 'mech' },
    lines: {
      select: ['Iron wings, unbroken will.', "Brassholm's finest, at your command."],
      ability: 'From above!',
      upgrade: 'Ascension protocol complete.',
      death: 'Wings... failing...',
    },
    lore: 'Magna was a test pilot who volunteered to be sealed inside the Valkyrie engine when its last pilot died. She has not taken the armor off in nine years. She is no longer certain she could.',
  },
  {
    id: 'eira', name: 'Eira', title: 'the Pale Queen', cost: 5, traits: ['frost', 'arcanist'],
    stats: { hp: 1000, ad: 50, as: 0.7, armor: 40, mr: 50, range: 4, mana: [50, 140] },
    ability: {
      name: 'Eternal Winter', type: 'magic',
      desc: 'Calls down a blizzard on every enemy, dealing {dmg} magic damage and freezing them for 1.5s.',
      v: { dmg: [300, 450, 2000] },
    },
    voice: { v: 'bf_emma', speed: 0.9, pitch: 0.96, fx: 'cathedral' },
    lines: {
      select: ['Winter is not cruel. It is honest.', 'Bow, and be preserved.'],
      ability: 'Eternal winter!',
      upgrade: 'The whole world turns white.',
      death: 'Spring... wins... this time...',
    },
    lore: 'Eira froze her own heart to survive the Sundering winter, and Rime has been frozen with it ever since. She enters the Convergence to rebuild the Starheart and finally, she says, to feel warm.',
  },
];

export const CHAMPION_BY_ID = Object.fromEntries(CHAMPIONS.map((c) => [c.id, c]));

// Portrait files that were painted for the game; others are rendered from the 3D model.
export const PAINTED_PORTRAITS = new Set([
  'brakka', 'marlo', 'fennick', 'skitter', 'pim', 'snorri', 'pyra', 'nerissa', 'bramblehide',
  'rivet', 'isolde', 'kaldor', 'brine', 'elowen', 'veyl', 'hrimfang', 'sigrun', 'thalassa',
  'grumbark', 'nyxara', 'vexa', 'ilsa', 'magna',
]);

// Copies of each champion in the shared pool, by cost.
export const POOL_SIZE = { 1: 29, 2: 22, 3: 18, 4: 12, 5: 10 };

// Shop odds (percent per cost tier) by player level.
export const SHOP_ODDS = {
  1: [100, 0, 0, 0, 0],
  2: [100, 0, 0, 0, 0],
  3: [75, 25, 0, 0, 0],
  4: [55, 30, 15, 0, 0],
  5: [45, 33, 20, 2, 0],
  6: [30, 40, 25, 5, 0],
  7: [19, 30, 35, 15, 1],
  8: [18, 25, 32, 22, 3],
  9: [10, 20, 25, 35, 10],
  10: [5, 10, 20, 40, 25],
};

// XP needed to go from level n to n+1.
export const XP_TO_NEXT = { 1: 2, 2: 2, 3: 6, 4: 10, 5: 20, 6: 36, 7: 48, 8: 76, 9: 84 };
export const MAX_LEVEL = 10;
