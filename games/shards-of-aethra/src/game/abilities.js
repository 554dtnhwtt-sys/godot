// Champion abilities. Each function runs inside the combat sim when the
// champion reaches full mana: (combat, caster, current target).
// Every visual hook is an emitted event; the renderer turns them into effects.
import { abilityValue } from './units.js';
import { hexDist } from '../core/hex.js';

const TPS = 30;
const v = (u, key) => abilityValue(u.id, key, u.star);

export const ABILITIES = {
  brakka(c, u) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'slam', uid: u.uid, color: '#ff8a3a', radius: 1 });
    c.schedule(6, () => {
      if (!u.alive) return;
      for (const e of c.enemiesAdjacentTo(u.cell, u.team)) {
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.stun(e, 38);
      }
      c.addShield(u, v(u, 'shield') * c.abilityScale(u), 4 * TPS);
    });
  },

  marlo(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'lunge', uid: u.uid, target: t.uid, color: '#3fe0d0' });
    c.schedule(5, () => {
      if (!u.alive || !t.alive) return;
      c.dealDamage(u, t, dmg, 'physical', { ability: true });
      u.asBuffs.push({ v: v(u, 'as'), until: c.tick + 4 * TPS });
    });
  },

  fennick(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const hits = c.enemiesInLine(u, t, 0.95, 9);
    c.emit({ t: 'vfx', kind: 'lineshot', uid: u.uid, target: t.uid, color: '#9cff6a', projectile: 'arrow' });
    hits.forEach((e, i) => c.schedule(4 + i * 2, () => c.dealDamage(u, e, dmg, 'physical', { ability: true })));
  },

  skitter(c, u) {
    const tgt = c.lowestHpEnemy(u, 3) || c.nearestEnemy(u);
    if (!tgt) return;
    const cell = c.freeCellNear(tgt.cell, u.cell);
    if (cell >= 0 && hexDist(u.cell, tgt.cell) > 1) c.blink(u, cell, 'leap');
    u.target = tgt.uid;
    c.emit({ t: 'vfx', kind: 'gnash', uid: u.uid, target: tgt.uid, color: '#b06bff' });
    c.schedule(7, () => { if (u.alive) c.dealDamage(u, tgt, v(u, 'dmg') * c.abilityScale(u), 'physical', { ability: true }); });
  },

  pim(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const travel = 6 + hexDist(u.cell, t.cell) * 2;
    c.emit({ t: 'vfx', kind: 'lob', uid: u.uid, target: t.uid, projectile: 'bomb', ticks: travel, color: '#5fd0ff' });
    const cell = t.cell;
    c.schedule(travel, () => {
      c.emit({ t: 'vfx', kind: 'explosion', cell, color: '#5fd0ff', radius: 1 });
      if (t.alive) c.dealDamage(u, t, dmg, 'magic', { ability: true });
      for (const e of c.enemiesAdjacentTo(cell, u.team)) if (e !== t) c.dealDamage(u, e, dmg * 0.5, 'magic', { ability: true });
    });
  },

  snorri(c, u) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'roar', uid: u.uid, color: '#9fe6ff', radius: 1 });
    c.schedule(5, () => {
      if (!u.alive) return;
      for (const e of c.enemiesAdjacentTo(u.cell, u.team)) {
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.chill(e, 3 * TPS);
      }
      const bonus = v(u, 'armor');
      u.armor += bonus;
      u.mr += bonus;
    });
  },

  pyra(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const travel = 5 + hexDist(u.cell, t.cell) * 2;
    c.emit({ t: 'vfx', kind: 'missile', uid: u.uid, target: t.uid, projectile: 'fireball', ticks: travel, color: '#ff7a2e' });
    const cell = t.cell;
    c.schedule(travel, () => {
      c.emit({ t: 'vfx', kind: 'explosion', cell, color: '#ff8a3a', radius: 1, fire: true });
      const hit = [t, ...c.enemiesAdjacentTo(cell, u.team).filter((e) => e !== t)];
      for (const e of hit) {
        if (!e.alive) continue;
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.applyBurn(u, e, 0.02);
      }
    });
  },

  nerissa(c, u) {
    const heal = v(u, 'heal') * c.abilityScale(u);
    const targets = c.lowestHpPctAlly(u, 2);
    c.emit({ t: 'vfx', kind: 'song', uid: u.uid, targets: targets.map((a) => a.uid), color: '#5ff0e0' });
    c.schedule(6, () => {
      for (const a of targets) {
        c.heal(a, heal, u);
        a.drBuffs.push({ v: 0.2, until: c.tick + 4 * TPS });
      }
    });
  },

  bramblehide(c, u) {
    const sh = v(u, 'shield') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'thornwall', uid: u.uid, color: '#7fdc5a', ticks: 5 * TPS });
    c.addShield(u, sh, 5 * TPS);
    u.thornWallUntil = c.tick + 5 * TPS;
    u.thornWallDmg = v(u, 'thorns') * c.abilityScale(u);
  },

  rivet(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'spin', uid: u.uid, color: '#ffcc66', radius: 1 });
    c.schedule(5, () => {
      if (!u.alive) return;
      const hit = new Set([t, ...c.enemiesAdjacentTo(u.cell, u.team)]);
      for (const e of hit) {
        if (!e.alive) continue;
        c.dealDamage(u, e, dmg, 'physical', { ability: true });
        e.armorShred = Math.max(e.armorShred, 0.3);
        e.armorShredUntil = c.tick + 4 * TPS;
      }
    });
  },

  isolde(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const travel = 4 + hexDist(u.cell, t.cell);
    c.emit({ t: 'vfx', kind: 'missile', uid: u.uid, target: t.uid, projectile: 'icearrow', ticks: travel, color: '#9fe6ff' });
    c.schedule(travel, () => {
      if (!t.alive) return;
      c.dealDamage(u, t, dmg, 'magic', { ability: true });
      c.chill(t, 3 * TPS);
      c.emit({ t: 'vfx', kind: 'frostburst', uid: t.uid, color: '#bff0ff' });
    });
  },

  kaldor(c, u) {
    c.emit({ t: 'vfx', kind: 'frenzy', uid: u.uid, color: '#ff6a1a', ticks: 5 * TPS });
    u.asBuffs.push({ v: v(u, 'as'), until: c.tick + 5 * TPS });
    u.frenzyUntil = c.tick + 5 * TPS;
    u.frenzyDmg = v(u, 'dmg');
  },

  brine(c, u) {
    const count = v(u, 'count');
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const enemies = c.enemiesOf(u);
    for (let i = 0; i < count; i++) {
      if (!enemies.length) break;
      const e = enemies[c.rng.int(enemies.length)];
      const travel = 8 + hexDist(u.cell, e.cell) * 2;
      c.schedule(i * 4, () => {
        if (!u.alive) return;
        c.emit({ t: 'vfx', kind: 'lob', uid: u.uid, target: e.uid, projectile: 'cannonball', ticks: travel, color: '#ffd27a' });
        const cell = e.cell;
        c.schedule(travel, () => {
          c.emit({ t: 'vfx', kind: 'explosion', cell, color: '#ffb35a', radius: 0.6, fire: true });
          if (e.alive) c.dealDamage(u, e, dmg, 'physical', { ability: true });
        });
      });
    }
  },

  elowen(c, u) {
    const heal = v(u, 'heal') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'bloom', uid: u.uid, color: '#a8ff7a', radius: 2 });
    c.schedule(6, () => {
      for (const a of c.alliesWithin(u.cell, u.team, 2)) c.heal(a, heal, u);
      const near = c.nearestEnemy(u);
      if (near) { c.root(near, 45); c.emit({ t: 'vfx', kind: 'roots', uid: near.uid, color: '#6fd04a' }); }
    });
  },

  veyl(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'beam', uid: u.uid, target: t.uid, color: '#b06bff', ticks: 14 });
    c.schedule(8, () => {
      if (!t.alive || !u.alive) return;
      c.dealDamage(u, t, dmg, 'magic', { ability: true });
      c.stun(t, 30);
    });
  },

  hrimfang(c, u) {
    const tgt = c.lowestHpEnemy(u) || c.nearestEnemy(u);
    if (!tgt) return;
    const cell = c.freeCellNear(tgt.cell, u.cell);
    if (cell >= 0 && hexDist(u.cell, tgt.cell) > 1) c.blink(u, cell, 'leap');
    u.target = tgt.uid;
    c.emit({ t: 'vfx', kind: 'claw', uid: u.uid, target: tgt.uid, color: '#bff0ff' });
    c.schedule(7, () => {
      if (!u.alive || !tgt.alive) return;
      c.dealDamage(u, tgt, v(u, 'dmg') * c.abilityScale(u), 'physical', { ability: true });
      c.chill(tgt, 3 * TPS);
    });
  },

  sigrun(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'cleave', uid: u.uid, target: t.uid, color: '#9fe6ff' });
    c.schedule(5, () => {
      if (!u.alive) return;
      const hit = new Set([t, ...c.enemiesAdjacentTo(t.cell, u.team).filter((e) => hexDist(e.cell, u.cell) <= 2)]);
      for (const e of hit) if (e.alive) c.dealDamage(u, e, dmg, 'physical', { ability: true });
      const ar = v(u, 'armor');
      u.armor += ar;
      c.schedule(5 * TPS, () => { u.armor -= ar; });
    });
  },

  thalassa(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const hits = c.enemiesInLine(u, t, 1.35, 9);
    c.emit({ t: 'vfx', kind: 'wave', uid: u.uid, target: t.uid, color: '#3fe0d0' });
    hits.forEach((e, i) => c.schedule(6 + i * 2, () => {
      if (!e.alive) return;
      c.dealDamage(u, e, dmg, 'magic', { ability: true });
      c.stun(e, 30, 'knockup');
    }));
  },

  grumbark(c, u) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'slam', uid: u.uid, color: '#8fdc5a', radius: 1.3, big: true });
    c.schedule(7, () => {
      if (!u.alive) return;
      for (const e of c.enemiesAdjacentTo(u.cell, u.team)) {
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.stun(e, 45);
      }
      c.heal(u, u.maxHp * 0.2, u);
    });
  },

  nyxara(c, u) {
    const strike = (mult, depth) => {
      const tgt = c.lowestHpEnemy(u) || c.nearestEnemy(u);
      if (!tgt || !u.alive) return;
      const cell = c.freeCellNear(tgt.cell, u.cell);
      if (cell >= 0) c.blink(u, cell, 'blink');
      u.target = tgt.uid;
      c.emit({ t: 'vfx', kind: 'eclipse', uid: u.uid, target: tgt.uid, color: '#c08cff' });
      c.schedule(6, () => {
        if (!u.alive || !tgt.alive) return;
        c.dealDamage(u, tgt, v(u, 'dmg') * c.abilityScale(u) * mult, 'physical', { ability: true });
        if (!tgt.alive && depth === 0) c.schedule(6, () => strike(0.5, 1));
      });
    };
    strike(1, 0);
  },

  vexa(c, u, t) {
    const count = v(u, 'count');
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const chain = [t];
    while (chain.length < count) {
      const last = chain[chain.length - 1];
      const next = c.enemiesOf(u).filter((e) => !chain.includes(e))
        .sort((a, b) => (hexDist(last.cell, a.cell) - hexDist(last.cell, b.cell)) || (a.uid - b.uid))[0];
      if (!next) break;
      chain.push(next);
    }
    c.emit({ t: 'vfx', kind: 'chain', uid: u.uid, targets: chain.map((e) => e.uid), color: '#7fe8ff' });
    chain.forEach((e, i) => c.schedule(5 + i * 3, () => { if (e.alive) c.dealDamage(u, e, dmg, 'magic', { ability: true }); }));
  },

  ilsa(c, u) {
    const heal = v(u, 'heal') * c.abilityScale(u);
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'phoenix', uid: u.uid, color: '#ffb347', radius: 2 });
    c.schedule(9, () => {
      for (const a of c.alliesOf(u)) c.heal(a, heal, u);
      for (const e of c.enemiesWithin(u.cell, u.team, 2)) {
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.applyBurn(u, e, 0.02);
      }
    });
  },

  morgath(c, u, t) {
    const tgt = c.lowestHpEnemy(u, 2) || t;
    if (!tgt) return;
    c.emit({ t: 'vfx', kind: 'devour', uid: u.uid, target: tgt.uid, color: '#9b5cff' });
    c.schedule(10, () => {
      if (!u.alive || !tgt.alive) return;
      c.dealDamage(u, tgt, v(u, 'dmg') * c.abilityScale(u), 'true', { ability: true });
      c.heal(u, u.maxHp * 0.25, u);
    });
  },

  magna(c, u, t) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    const cell = c.freeCellNear(t.cell, u.cell);
    if (cell >= 0) c.blink(u, cell, 'leap');
    c.emit({ t: 'vfx', kind: 'orbital', uid: u.uid, target: t.uid, color: '#7fe8ff' });
    const tc = t.cell;
    c.schedule(10, () => {
      if (!u.alive) return;
      c.emit({ t: 'vfx', kind: 'explosion', cell: tc, color: '#9ff0ff', radius: 1.2 });
      const hit = new Set([t, ...c.enemiesAdjacentTo(tc, u.team)]);
      for (const e of hit) {
        if (!e.alive) continue;
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.stun(e, 45, 'knockup');
      }
    });
  },

  eira(c, u) {
    const dmg = v(u, 'dmg') * c.abilityScale(u);
    c.emit({ t: 'vfx', kind: 'blizzard', uid: u.uid, team: u.team, color: '#cfefff' });
    c.schedule(12, () => {
      if (!u.alive) return;
      for (const e of c.enemiesOf(u)) {
        c.dealDamage(u, e, dmg, 'magic', { ability: true });
        c.stun(e, 45, 'freeze');
      }
    });
  },
};
