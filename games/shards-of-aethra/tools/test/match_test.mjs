import { Match } from '../../src/game/match.js';
import { botPlanning } from '../../src/game/bot.js';
import { RIVALS } from '../../src/data/world.js';

for (let g = 0; g < 5; g++) {
  const m = new Match({ seed: 100 + g, humans: [{ id: 'me', name: 'Me', color: '#fff', kind: 'human' }], localId: 'me' });
  m.local.rival = RIVALS[g % RIVALS.length];
  const log = [];
  m.on('phase', (ph) => {
    if (ph === 'planning') botPlanning(m.local, m);
    if (ph === 'draft' && m.pendingDraft) m.pickDraft(0);
  });
  m.on('boon-offer', (offers) => offers && m.pickBoon(offers[0].id));
  m.on('gameover', (place) => log.push('place ' + place));
  m.start();
  let it = 0;
  while (m.phase !== 'gameover' && it++ < 200000) m.update(0.5);
  const alive = m.players.map((p) => `${p.name}:${p.hp}${p.alive ? '' : '(' + p.place + ')'}`).join(' ');
  console.log(`game ${g}: ended ${m.roundKey()} iters ${it} ${log.join(',')} | ${alive}`);
  const me = m.local;
  console.log('   me level', me.level, 'board', me.boardUnits().map((u) => u.id + u.star + (u.items.length ? '[' + u.items.length + ']' : '')).join(' '));
}
