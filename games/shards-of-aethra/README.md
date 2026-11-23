# Shards of Aethra

An original 3D auto-battler that runs in the browser. Eight Wardens draft champions,
combine them into stronger stars, forge relics and fight on a floating sky-arena until
one Warden is left.

- 25 champions in five cost tiers, each with its own 3D model, ability, lore and five voice lines
- 6 origins and 6 classes (traits), 8 relic components and 36 completed relics, 18 boons
- Full rounds: opening draft, monster rounds with loot, PvP, shard drafts, boons, streaks,
  interest, levels and shop odds, star-ups, eliminations
- Seven computer Wardens with their own play styles
- Online lobbies for up to eight players when the page is opened as a shared claude.ai artifact
- Orchestral soundtrack, synthesized effects and an announcer

## Run it

```sh
npm install
npm run build        # writes dist/
npx serve dist       # or any static file server; open http://localhost:3000
```

`dist/index.html` is a normal web page, so `dist/` can be uploaded to any static host
(GitHub Pages, Netlify, itch.io). `dist/artifact.html` is the same game as a body fragment
for claude.ai artifacts; the assets are published next to it under `assets/`.

## How online play works

Online play uses the artifact `room` channel. Every player keeps one presence object.
The first player in a room is the host and announces the game seed. Each round every
Warden posts a compact snapshot of their board; the host locks the round once everyone
has posted (or after a timeout), and then every client runs every fight itself with the
deterministic combat simulation (`src/game/sim.js`: fixed 30 Hz ticks, seeded random
numbers, no trigonometry). Because all clients compute the same results, nobody has to
trust anyone else's numbers. Computer Wardens fill empty seats and are simulated
identically on every client. If the host leaves, the next player to have joined takes over.

`tools/test/online_node.mjs` plays a three-player online game in Node and checks that
every client computed identical health for every Warden in every round.

## Project layout

| Path | What it holds |
| --- | --- |
| `src/data/` | Champions, traits, relics, boons, monsters, lore, announcer lines |
| `src/game/` | Combat simulation, abilities, player economy, bots, match flow |
| `src/render/` | Three.js scene, arena, procedural champion models, animation, effects |
| `src/ui/` | HUD, menus, codex, icons, portraits, styles |
| `src/audio/` | Music player, synthesized sound effects, voice lines |
| `src/net/` | Online lobby and round synchronisation |
| `public/assets/` | Portraits, title art, voice lines, music |
| `tools/` | Build script, voice and music generators, tests |

## Where the assets came from

- Champion portraits and title art were generated for this game with an image model.
  Mor'Gath and Eira have no painted portrait yet; the game renders their 3D model instead.
- Voice lines were synthesized with Kokoro TTS (`tools/gen_voices.py`) and given per-character
  effects with ffmpeg.
- The three music loops were composed as MIDI by `tools/compose_music.py` and rendered with
  FluidSynth and the FluidR3 GM soundfont.
- Everything else (models, arena, icons, effects, sounds) is generated in code at runtime.

## Controls

Drag champions between the bench and the board. Drag one onto the shop to sell it, or hover
it and press <kbd>E</kbd>. <kbd>D</kbd> refreshes the shop, <kbd>F</kbd> buys experience.
Drag relics from the left onto champions. Click a champion to see its stats, ability and lore.
