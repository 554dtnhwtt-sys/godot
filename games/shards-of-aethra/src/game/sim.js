// Deterministic combat simulation. 30 ticks per second, integer time, seeded RNG,
// and only + - * / sqrt in the maths, so every browser computes the same fight.
import { RNG } from '../core/rng.js';
import { CELLS, hexDist, neighbors, cellToWorld, mirrorCell, HEX_W, COLS, cellRow } from '../core/hex.js';
import { CHAMPION_BY_ID } from '../data/champions.js';
import { ITEMS } from '../data/items.js';
import { TRAITS } from '../data/traits.js';
import { MONSTERS } from '../data/world.js';
import { computeStats, monsterStats, countTraits, traitTier } from './units.js';
import { ABILITIES } from './abilities.js';

export const TPS = 30;
const MOVE_TICKS = 11;
const MAX_TICKS = 35 * TPS;

function mergeFx(items) {
  const fx = {};
  for (const id of items) {
    const it = ITEMS[id];
    if (!it || !it.fx) continue;
    for (const [k, v] of Object.entries(it.fx)) {
      if (typeof v === 'number' && typeof fx[k] === 'number') fx[k] += v;
      else fx[k] = v;
    }
  }
  return fx;
}

export class Combat {
  // home/away: { units: [{ owned:{uid,id,star,items}, cell }], boons:[] } ; or away.monsters: [{mon, cell, scale}]
  constructor({ seed = 1, home, away, stage = 1 }) {
    this.rng = new RNG(seed);
    this.tick = 0;
    this.units = [];
    this.byUid = new Map();
    this.queue = [];
    this.seq = 0;
    this.events = [];
    this.done = false;
    this.result = null;
    this.takedowns = [0, 0];
    this.boons = [new Set(home.boons || []), new Set(away.boons || [])];
    this.phoenixUsed = [false, false];
    this.stage = stage;
    let uid = 1;
    const add = (team, spec) => {
      const u = this.createUnit(team, spec, uid++);
      if (u) {
        this.units.push(u);
        this.byUid.set(u.uid, u);
      }
    };
    for (const spec of home.units || []) add(0, { ...spec });
    for (const spec of away.units || []) add(1, { ...spec, cell: mirrorCell(spec.cell) });
    for (const m of away.monsters || []) add(1, { mon: m.mon, cell: mirrorCell(m.cell), scale: m.scale || 1 });
    this.applyTraitsAndBoons(0, home);
    this.applyTraitsAndBoons(1, away);
    for (const u of this.units) u.nextAttack = this.rng.int(8);
    this.startOfCombat();
  }

  createUnit(team, spec, uid) {
    let st;
    let traits = [];
    let name;
    let id;
    let star = 1;
    let items = [];
    if (spec.mon) {
      st = monsterStats(spec.mon, spec.scale || 1);
      id = spec.mon;
      name = MONSTERS[spec.mon].name;
    } else {
      const ch = CHAMPION_BY_ID[spec.owned.id];
      if (!ch) return null;
      st = computeStats(spec.owned);
      traits = ch.traits;
      id = ch.id;
      name = ch.name;
      star = spec.owned.star;
      items = spec.owned.items.slice();
    }
    const fx = mergeFx(items);
    return {
      uid, ownerUid: spec.owned ? spec.owned.uid : 0, team, id, name, star, items, traits,
      isMonster: !!spec.mon, monsterScale: spec.scale || 1,
      maxHp: st.hp, hp: st.hp, ad: st.ad, baseAd: st.ad, ap: st.ap, as: st.as, armor: st.armor, mr: st.mr,
      range: st.range, crit: st.crit, critDmg: st.critDmg, mana: st.mana, maxMana: Math.max(10, st.maxMana - (fx.manaCostRed || 0)),
      cell: spec.cell, startCell: spec.cell, alive: true,
      target: null, nextAttack: 0, move: null,
      stunUntil: 0, rootUntil: 0, chillUntil: 0, castLock: 0, ccImmuneUntil: fx.ccImmune ? fx.ccImmune * TPS : 0,
      shields: [], burn: null, healCutUntil: 0, armorShredUntil: 0, armorShred: 0, mrShredUntil: 0, mrShred: 0,
      asBuffs: [], drBuffs: [], adBuffs: [],
      stacks: { duel: 0, rapid: 0, momentum: 0, warden: 0, gear: 0 },
      fx, tfx: {}, dmgAmp: 0, vamp: fx.vamp || 0, dr: fx.dr || 0, mdr: fx.mdr || 0,
      attackCount: 0, lowShieldUsed: false, thornsReady: 0, frenzyUntil: 0, frenzyDmg: 0,
      thornWallUntil: 0, thornWallDmg: 0, damageDealt: 0, damageTaken: 0, revived: false,
    };
  }

  applyTraitsAndBoons(team, side) {
    const mine = this.units.filter((u) => u.team === team && !u.isMonster);
    const counts = countTraits(mine.map((u) => ({ id: u.id })), side.emblems || {});
    const tiers = {};
    for (const id of Object.keys(TRAITS)) tiers[id] = traitTier(counts, id);
    this[`tiers${team}`] = tiers;
    const boons = this.boons[team];
    for (const u of mine) {
      const has = (t) => u.traits.includes(t) && tiers[t] >= 0;
      const f = (t) => TRAITS[t].fx[tiers[t]];
      if (has('ember')) { u.tfx.burn = f('ember').burn; u.dmgAmp += f('ember').dmgAmp || 0; }
      if (has('tide')) u.tfx.tideMana = f('tide').mana;
      if (tiers.tide >= 1) u.tfx.teamMana = TRAITS.tide.fx[tiers.tide].teamMana || 0;
      if (has('wild')) { u.tfx.regen = f('wild').regen; const extra = f('wild').hp || 0; u.maxHp += extra; u.hp += extra; }
      if (has('hollow')) u.tfx.trueDmg = f('hollow').trueDmg;
      if (has('gear')) { u.tfx.asStack = f('gear').asStack; if (f('gear').shield) this.addShield(u, f('gear').shield, 10 * TPS, false); }
      if (has('frost')) u.tfx.chill = f('frost').chill;
      if (tiers.frost >= 1) u.tfx.chillAmp = TRAITS.frost.fx[tiers.frost].chillAmp || 0;
      if (has('bulwark')) { u.armor += f('bulwark').resist; u.mr += f('bulwark').resist; }
      else if (tiers.bulwark >= 1) { u.armor += 20; u.mr += 20; }
      if (has('duelist')) u.tfx.asOnHit = f('duelist').asOnHit;
      if (has('ranger')) u.tfx.double = f('ranger').double;
      if (tiers.arcanist >= 0) u.ap += TRAITS.arcanist.fx[tiers.arcanist].teamAp;
      if (has('arcanist')) u.ap += f('arcanist').ap;
      if (has('shadow')) { u.crit += f('shadow').crit; u.critDmg += f('shadow').critDmg; u.tfx.abilityCrit = true; u.tfx.leap = true; }
      if (has('mender')) u.tfx.menderShield = f('mender').shield;
      if (u.fx.abilityCrit) u.tfx.abilityCrit = true;
      // boons
      if (boons.has('feather')) u.as *= 1.15;
      if (boons.has('ironclad')) { u.armor += 20; u.mr += 20; }
      if (boons.has('surge')) u.ap += 20;
      if (boons.has('hearty')) { u.maxHp += 180; u.hp += 180; }
      if (boons.has('precision')) { u.crit += 0.15; u.critDmg += 0.2; }
      if (boons.has('vamp')) u.vamp += 0.12;
      if (boons.has('mana')) u.mana += 20;
      if (u.fx.dmgAmp) u.dmgAmp += u.fx.dmgAmp;
    }
  }

  startOfCombat() {
    for (const u of this.units) {
      if (u.fx.startShieldAdj) {
        this.addShield(u, u.fx.startShieldAdj, 8 * TPS);
        for (const a of this.alliesAdjacent(u)) this.addShield(a, u.fx.startShieldAdj, 8 * TPS);
      }
    }
    // Shadowblades leap to the far backline.
    const leapers = this.units.filter((u) => u.tfx.leap);
    for (const u of leapers) {
      const enemyBack = u.team === 0 ? CELLS - 1 : 0;
      let best = -1;
      let bestScore = 1e9;
      for (let c = 0; c < CELLS; c++) {
        if (this.occupied(c)) continue;
        const row = cellRow(c);
        if (u.team === 0 && row < 4) continue;
        if (u.team === 1 && row > 3) continue;
        // close to the enemy back row and to some enemy
        const backDist = u.team === 0 ? 7 - row : row;
        let near = 99;
        for (const e of this.enemiesOf(u)) near = Math.min(near, hexDist(c, e.cell));
        const score = backDist * 3 + near * 2 + Math.abs((c % COLS) - (u.cell % COLS)) * 0.5 + c * 1e-4;
        if (score < bestScore) { bestScore = score; best = c; }
      }
      if (best >= 0) {
        const from = u.cell;
        u.cell = best;
        u.move = { from, to: best, start: 0, end: 14, leap: true };
        this.emit({ t: 'leap', uid: u.uid, from, to: best, ticks: 14 });
      }
    }
  }

  // ───────────────────────── helpers ─────────────────────────
  emit(e) {
    e.tick = this.tick;
    this.events.push(e);
  }
  schedule(delay, fn) {
    this.queue.push({ at: this.tick + Math.max(0, delay), seq: this.seq++, fn });
  }
  living() { return this.units.filter((u) => u.alive); }
  enemiesOf(u) { return this.units.filter((e) => e.alive && e.team !== u.team); }
  alliesOf(u) { return this.units.filter((e) => e.alive && e.team === u.team); }
  occupied(cell, except) {
    for (const u of this.units) if (u.alive && u.cell === cell && u !== except) return true;
    return false;
  }
  alliesAdjacent(u) {
    const ns = neighbors(u.cell);
    return this.units.filter((a) => a.alive && a.team === u.team && a !== u && ns.includes(a.cell));
  }
  enemiesAdjacentTo(cell, team) {
    const ns = neighbors(cell);
    return this.units.filter((e) => e.alive && e.team !== team && ns.includes(e.cell));
  }
  enemiesWithin(cell, team, dist) {
    return this.units.filter((e) => e.alive && e.team !== team && hexDist(cell, e.cell) <= dist);
  }
  alliesWithin(cell, team, dist) {
    return this.units.filter((e) => e.alive && e.team === team && hexDist(cell, e.cell) <= dist);
  }
  nearestEnemy(u) {
    let best = null;
    let bd = 1e9;
    for (const e of this.units) {
      if (!e.alive || e.team === u.team) continue;
      const d = hexDist(u.cell, e.cell);
      if (d < bd || (d === bd && e.uid < best.uid)) { bd = d; best = e; }
    }
    return best;
  }
  lowestHpEnemy(u, maxDist = 99) {
    let best = null;
    for (const e of this.enemiesOf(u)) {
      if (hexDist(u.cell, e.cell) > maxDist) continue;
      if (!best || e.hp < best.hp || (e.hp === best.hp && e.uid < best.uid)) best = e;
    }
    return best;
  }
  lowestHpPctAlly(u, n = 1, exceptFull = false) {
    const al = this.alliesOf(u).filter((a) => !exceptFull || a.hp < a.maxHp);
    al.sort((a, b) => (a.hp / a.maxHp - b.hp / b.maxHp) || (a.uid - b.uid));
    return al.slice(0, n);
  }
  freeCellNear(cell, preferAwayFrom) {
    const ns = neighbors(cell).filter((c) => !this.occupied(c));
    if (!ns.length) return -1;
    if (preferAwayFrom != null) {
      ns.sort((a, b) => (hexDist(b, preferAwayFrom) - hexDist(a, preferAwayFrom)) || (a - b));
    }
    return ns[0];
  }
  blink(u, cell, kind = 'blink') {
    if (cell < 0) return;
    const from = u.cell;
    u.cell = cell;
    u.move = { from, to: cell, start: this.tick, end: this.tick + 6, leap: kind === 'leap' };
    this.emit({ t: kind, uid: u.uid, from, to: cell, ticks: 6 });
  }
  enemiesInLine(u, target, width = 0.95, length = 9) {
    const a = cellToWorld(u.cell);
    const b = cellToWorld(target.cell);
    let dx = b.x - a.x;
    let dz = b.z - a.z;
    const len = Math.sqrt(dx * dx + dz * dz) || 1;
    dx /= len; dz /= len;
    const maxT = length * HEX_W;
    const out = [];
    for (const e of this.enemiesOf(u)) {
      const p = cellToWorld(e.cell);
      const px = p.x - a.x;
      const pz = p.z - a.z;
      const t = px * dx + pz * dz;
      if (t < 0 || t > maxT) continue;
      const perp = Math.abs(px * dz - pz * dx);
      if (perp <= width) out.push({ e, t });
    }
    out.sort((x, y) => (x.t - y.t) || (x.e.uid - y.e.uid));
    return out.map((o) => o.e);
  }

  effectiveAS(u) {
    let mult = 1;
    for (const b of u.asBuffs) if (b.until > this.tick) mult += b.v;
    mult += u.stacks.duel * (u.tfx.asOnHit || 0);
    mult += u.stacks.rapid * 0.05;
    mult += u.stacks.gear * (u.tfx.asStack || 0);
    if (u.fx.bloodrage && u.hp < u.maxHp * u.fx.bloodrage.at) mult += u.fx.bloodrage.as;
    let as = u.as * mult;
    if (this.tick < u.chillUntil) as *= 0.7;
    // enemy slow auras
    for (const e of this.units) {
      if (e.alive && e.team !== u.team && e.fx.slowAura && hexDist(e.cell, u.cell) <= 2) { as *= 1 - e.fx.slowAura; break; }
    }
    return Math.min(5, Math.max(0.2, as));
  }
  effectiveAD(u) {
    let ad = u.ad + u.stacks.momentum * 2;
    for (const b of u.adBuffs) if (b.until > this.tick) ad *= 1 + b.v;
    return ad;
  }
  effectiveAP(u) { return u.ap + u.stacks.momentum * 2; }
  abilityScale(u) { return 1 + this.effectiveAP(u) / 100; }

  addShield(u, amount, duration, emit = true) {
    if (!u.alive || amount <= 0) return;
    u.shields.push({ amt: amount, until: this.tick + duration });
    if (emit) this.emit({ t: 'shield', uid: u.uid, amount: Math.round(amount) });
  }
  shieldTotal(u) {
    let s = 0;
    for (const sh of u.shields) if (sh.until > this.tick) s += sh.amt;
    return s;
  }
  heal(u, amount, src) {
    if (!u.alive || amount <= 0) return 0;
    if (this.tick < u.healCutUntil) amount *= 0.67;
    const before = u.hp;
    u.hp = Math.min(u.maxHp, u.hp + amount);
    const got = u.hp - before;
    if (got >= 8) this.emit({ t: 'heal', uid: u.uid, amount: Math.round(got) });
    return got;
  }
  ccImmune(u) { return this.tick < u.ccImmuneUntil; }
  stun(u, ticks, kind = 'stun') {
    if (!u.alive || this.ccImmune(u)) return;
    u.stunUntil = Math.max(u.stunUntil, this.tick + ticks);
    this.emit({ t: kind, uid: u.uid, ticks });
  }
  chill(u, ticks) {
    if (!u.alive) return;
    const fresh = this.tick >= u.chillUntil;
    u.chillUntil = Math.max(u.chillUntil, this.tick + ticks);
    if (fresh) this.emit({ t: 'chill', uid: u.uid, ticks });
  }
  root(u, ticks) {
    if (!u.alive || this.ccImmune(u)) return;
    u.rootUntil = Math.max(u.rootUntil, this.tick + ticks);
    this.emit({ t: 'root', uid: u.uid, ticks });
  }
  applyBurn(src, tgt, pct) {
    if (!tgt.alive) return;
    const dps = Math.max(pct * tgt.maxHp, tgt.burn && tgt.burn.until > this.tick ? tgt.burn.dps : 0);
    tgt.burn = { dps, until: this.tick + 3 * TPS, src: src.uid };
    tgt.healCutUntil = this.tick + 3 * TPS;
  }

  // Core damage routine. Returns damage dealt to health + shields.
  dealDamage(src, tgt, raw, type, opts = {}) {
    if (!tgt || !tgt.alive || raw <= 0) return 0;
    let dmg = raw;
    let crit = false;
    if (src) {
      dmg *= 1 + src.dmgAmp;
      for (const b of src.adBuffs) if (b.until > this.tick && opts.ability) dmg *= 1 + b.v;
      if (src.tfx.chillAmp && this.tick < tgt.chillUntil) dmg *= 1 + src.tfx.chillAmp;
      const canCrit = opts.attack || (opts.ability && (src.tfx.abilityCrit || src.fx.abilityCrit));
      if (canCrit && !tgt.fx.critImmune && type !== 'true' && this.rng.chance(Math.min(1, src.crit))) {
        crit = true;
        dmg *= src.critDmg;
      }
    }
    let mit = 1;
    if (type === 'physical') {
      const shred = this.tick < tgt.armorShredUntil ? tgt.armorShred : 0;
      const armor = Math.max(0, (tgt.armor + tgt.stacks.warden * 3 + (tgt.stacks.momentum >= 25 ? 25 : 0)) * (1 - shred));
      mit = 100 / (100 + armor);
    } else if (type === 'magic') {
      let shred = this.tick < tgt.mrShredUntil ? tgt.mrShred : 0;
      for (const e of this.units) {
        if (e.alive && e.team !== tgt.team && e.fx.mrAura && hexDist(e.cell, tgt.cell) <= 2) { shred = Math.max(shred, e.fx.mrAura); break; }
      }
      const mr = Math.max(0, (tgt.mr + tgt.stacks.warden * 3 + (tgt.stacks.momentum >= 25 ? 25 : 0)) * (1 - shred));
      mit = (100 / (100 + mr)) * (1 - tgt.mdr);
    }
    let post = dmg * mit;
    let dr = tgt.dr;
    for (const b of tgt.drBuffs) if (b.until > this.tick) dr += b.v;
    post *= Math.max(0.1, 1 - dr);
    // Shields absorb first.
    let remaining = post;
    for (const sh of tgt.shields) {
      if (sh.until <= this.tick || sh.amt <= 0) continue;
      const take = Math.min(sh.amt, remaining);
      sh.amt -= take;
      remaining -= take;
      if (remaining <= 0) break;
    }
    tgt.shields = tgt.shields.filter((s) => s.amt > 0.5 && s.until > this.tick);
    tgt.hp -= remaining;
    tgt.damageTaken += post;
    if (src) src.damageDealt += post;
    // Mana from taking damage.
    if (tgt.castLock <= this.tick && !tgt.isMonster) tgt.mana = Math.min(tgt.maxMana + 40, tgt.mana + Math.min(42, raw * 0.01 + post * 0.03));
    this.emit({ t: 'dmg', uid: tgt.uid, src: src ? src.uid : 0, amount: Math.round(post), type, crit, ability: !!opts.ability });

    if (src && src.alive !== undefined) {
      // Omnivamp & bloodrage
      let vamp = src.vamp;
      if (src.fx.bloodrage && src.hp < src.maxHp * src.fx.bloodrage.at) vamp += src.fx.bloodrage.vamp;
      if (vamp > 0 && src.alive) this.heal(src, post * vamp, src);
      if (src.fx.allyHeal && src.alive) {
        const [low] = this.lowestHpPctAlly(src, 1);
        if (low) this.heal(low, post * src.fx.allyHeal, src);
      }
      // Hollow bonus true damage
      if (src.tfx.trueDmg && type !== 'true' && !opts.noProc) {
        const bonus = raw * src.tfx.trueDmg * (tgt.hp < tgt.maxHp * 0.5 ? 1.5 : 1);
        this.dealDamage(src, tgt, bonus, 'true', { noProc: true });
      }
      // Burns
      if (!opts.noProc) {
        if (src.tfx.burn) this.applyBurn(src, tgt, src.tfx.burn);
        if (opts.ability && src.fx.abilityBurn) this.applyBurn(src, tgt, 0.02);
      }
    }
    // Defensive procs on the target.
    if (opts.attack && src) {
      if (tgt.fx.stackResist && tgt.stacks.warden < tgt.fx.stackResist.max) tgt.stacks.warden++;
      if (tgt.fx.momentum && tgt.stacks.momentum < 25) tgt.stacks.momentum++;
      if (tgt.thornWallUntil > this.tick && this.shieldTotal(tgt) > 0) this.dealDamage(tgt, src, tgt.thornWallDmg, 'magic', { noProc: true });
      if (tgt.fx.thorns && this.tick >= tgt.thornsReady) {
        tgt.thornsReady = this.tick + tgt.fx.thorns.cd * TPS;
        for (const e of this.enemiesAdjacentTo(tgt.cell, tgt.team)) this.dealDamage(tgt, e, tgt.fx.thorns.dmg, 'magic', { noProc: true });
        this.emit({ t: 'vfx', kind: 'thorns', uid: tgt.uid });
      }
    }
    // Low health relic triggers
    if (tgt.alive && tgt.fx.lowShield && !tgt.lowShieldUsed && tgt.hp > 0 && tgt.hp < tgt.maxHp * tgt.fx.lowShield.at) {
      tgt.lowShieldUsed = true;
      this.addShield(tgt, tgt.maxHp * tgt.fx.lowShield.pct, 5 * TPS);
      if (tgt.fx.lowShield.as) tgt.asBuffs.push({ v: tgt.fx.lowShield.as, until: 1e9 });
      if (tgt.fx.lowShield.ad) tgt.adBuffs.push({ v: tgt.fx.lowShield.ad, until: 1e9 });
    }
    if (tgt.hp <= 0) this.kill(tgt, src);
    return post;
  }

  kill(u, src) {
    if (!u.alive) return;
    const team = u.team;
    if (!u.isMonster && this.boons[team].has('phoenix') && !this.phoenixUsed[team]) {
      this.phoenixUsed[team] = true;
      u.hp = u.maxHp * 0.4;
      u.burn = null;
      u.revived = true;
      this.emit({ t: 'revive', uid: u.uid });
      return;
    }
    u.alive = false;
    u.hp = 0;
    u.move = null;
    this.emit({ t: 'death', uid: u.uid, src: src ? src.uid : 0 });
    if (src) {
      this.takedowns[src.team]++;
      if (this.boons[src.team].has('thrill') && src.alive) this.heal(src, 250, src);
    }
  }

  // ───────────────────────── attacking ─────────────────────────
  startAttack(u, tgt) {
    const as = this.effectiveAS(u);
    const interval = Math.max(6, Math.round(TPS / as));
    u.nextAttack = this.tick + interval;
    const windup = Math.min(9, Math.max(3, Math.round(interval * 0.35)));
    const ranged = u.range >= 2;
    const dist = hexDist(u.cell, tgt.cell);
    const travel = ranged ? Math.max(2, Math.round(dist * 2.4)) : 0;
    this.emit({ t: 'attack', uid: u.uid, target: tgt.uid, ranged, windup, travel, interval });
    const tUid = tgt.uid;
    this.schedule(windup, () => {
      if (!u.alive || this.tick < u.stunUntil) return;
      const t = this.byUid.get(tUid);
      if (!t || !t.alive) return;
      if (ranged) {
        this.schedule(travel, () => this.attackHit(u, t, 1));
      } else {
        this.attackHit(u, t, 1);
      }
    });
  }

  attackHit(u, t, mult, isExtra = false) {
    if (!t.alive) return;
    const dmg = this.effectiveAD(u) * mult;
    this.dealDamage(u, t, dmg, 'physical', { attack: true });
    if (isExtra) return;
    u.attackCount++;
    if (!u.isMonster && u.castLock <= this.tick) u.mana = Math.min(u.maxMana + 40, u.mana + 10 + (u.fx.manaOnHit || 0));
    if (u.tfx.asOnHit && u.stacks.duel < 8) u.stacks.duel++;
    if (u.fx.asStackHit) u.stacks.rapid++;
    if (u.fx.momentum && u.stacks.momentum < 25) u.stacks.momentum++;
    if (u.fx.healOnHit) this.heal(u, u.maxHp * u.fx.healOnHit, u);
    if (u.tfx.chill && this.rng.chance(u.tfx.chill)) this.chill(t, 2 * TPS);
    if (u.frenzyUntil > this.tick && t.alive) {
      this.dealDamage(u, t, u.frenzyDmg * this.abilityScale(u), 'magic', { ability: true, noProc: false });
      this.applyBurn(u, t, 0.015);
    }
    if (u.isMonster && MONSTERS[u.id].look === 'drake') {
      for (const e of this.enemiesAdjacentTo(t.cell, u.team)) this.dealDamage(u, e, dmg * 0.5, 'magic', { noProc: true });
      this.emit({ t: 'vfx', kind: 'breath', uid: u.uid, target: t.uid });
    }
    // Stormstrike / Stormcaller sparks
    if (u.fx.spark && u.attackCount % u.fx.spark.every === 0) {
      const hits = [t, ...this.enemiesOf(u).filter((e) => e !== t).sort((a, b) => (hexDist(t.cell, a.cell) - hexDist(t.cell, b.cell)) || (a.uid - b.uid))].slice(0, u.fx.spark.targets);
      this.emit({ t: 'vfx', kind: 'spark', uid: u.uid, targets: hits.map((h) => h.uid) });
      for (const h of hits) {
        this.dealDamage(u, h, u.fx.spark.dmg, 'magic', { noProc: true });
        if (u.fx.spark.shredMr) { h.mrShred = 0.3; h.mrShredUntil = this.tick + 4 * TPS; }
      }
    }
    // Ranger double shot / Twinshot split
    if (u.tfx.double && this.rng.chance(u.tfx.double)) {
      const tu = t.uid;
      this.emit({ t: 'attack', uid: u.uid, target: tu, ranged: u.range >= 2, windup: 3, travel: 4, extra: true });
      this.schedule(7, () => { const tt = this.byUid.get(tu); if (tt && tt.alive && u.alive) this.attackHit(u, tt, 1, true); });
    }
    if (u.fx.split) {
      const other = this.enemiesOf(u).filter((e) => e !== t).sort((a, b) => (hexDist(u.cell, a.cell) - hexDist(u.cell, b.cell)) || (a.uid - b.uid))[0];
      if (other) {
        this.emit({ t: 'attack', uid: u.uid, target: other.uid, ranged: true, windup: 1, travel: 5, extra: true });
        this.schedule(6, () => { if (other.alive && u.alive) this.attackHit(u, other, u.fx.split, true); });
      }
    }
    if (u.fx.critShred && t.alive) { t.armorShred = 0.35; t.armorShredUntil = this.tick + 4 * TPS; }
  }

  // ───────────────────────── movement ─────────────────────────
  pathStep(u, tgt) {
    // BFS from the unit to any free cell within attack range of the target.
    const prev = new Int16Array(CELLS).fill(-2);
    const q = [u.cell];
    prev[u.cell] = -1;
    let goal = -1;
    let head = 0;
    while (head < q.length) {
      const c = q[head++];
      if (c !== u.cell && hexDist(c, tgt.cell) <= u.range) { goal = c; break; }
      for (const nb of neighbors(c)) {
        if (prev[nb] !== -2) continue;
        if (this.occupied(nb, u)) continue;
        prev[nb] = c;
        q.push(nb);
      }
    }
    if (goal < 0) {
      // No route: step to any free neighbour that gets closer.
      let best = -1;
      let bd = hexDist(u.cell, tgt.cell);
      for (const nb of neighbors(u.cell)) {
        if (this.occupied(nb, u)) continue;
        const d = hexDist(nb, tgt.cell);
        if (d < bd) { bd = d; best = nb; }
      }
      return best;
    }
    let c = goal;
    while (prev[c] !== u.cell && prev[c] >= 0) c = prev[c];
    return c;
  }

  startMove(u, cell) {
    const from = u.cell;
    u.cell = cell;
    const ticks = this.tick < u.chillUntil ? MOVE_TICKS + 3 : MOVE_TICKS;
    u.move = { from, to: cell, start: this.tick, end: this.tick + ticks };
    this.emit({ t: 'move', uid: u.uid, from, to: cell, ticks });
  }

  acquireTarget(u) {
    let t = u.target ? this.byUid.get(u.target) : null;
    if (t && !t.alive) t = null;
    if (t) {
      const d = hexDist(u.cell, t.cell);
      if (d > u.range) {
        // Swap to something already in range if there is one.
        const near = this.nearestEnemy(u);
        if (near && hexDist(u.cell, near.cell) <= u.range) t = near;
      }
    } else {
      t = this.nearestEnemy(u);
    }
    u.target = t ? t.uid : null;
    return t;
  }

  cast(u) {
    const ab = ABILITIES[u.id];
    if (!ab) { u.mana = 0; return; }
    const target = this.acquireTarget(u) || this.nearestEnemy(u);
    if (!target) return;
    u.mana = u.fx.manaAfterCast || 0;
    u.castLock = this.tick + 12;
    this.emit({ t: 'cast', uid: u.uid, target: target.uid });
    // Ion Mantle punishes casting.
    for (const e of this.units) {
      if (e.alive && e.team !== u.team && e.fx.castZap && hexDist(e.cell, u.cell) <= 2) {
        this.dealDamage(e, u, e.fx.castZap, 'magic', { noProc: true });
        this.emit({ t: 'vfx', kind: 'zap', uid: e.uid, target: u.uid });
        break;
      }
    }
    if (!u.alive) return;
    ab(this, u, target);
    if (u.fx.postCastAs) u.asBuffs.push({ v: u.fx.postCastAs, until: this.tick + 5 * TPS });
  }

  act(u) {
    const t = this.tick;
    if (t < u.stunUntil || t < u.castLock) return;
    if (u.move) {
      if (t < u.move.end) return;
      u.move = null;
    }
    if (!u.isMonster && u.mana >= u.maxMana) {
      this.cast(u);
      return;
    }
    const tgt = this.acquireTarget(u);
    if (!tgt) return;
    const d = hexDist(u.cell, tgt.cell);
    if (d <= u.range) {
      if (t >= u.nextAttack) this.startAttack(u, tgt);
    } else if (t >= u.rootUntil) {
      const step = this.pathStep(u, tgt);
      if (step >= 0) this.startMove(u, step);
    }
  }

  periodic() {
    const t = this.tick;
    const sec = t % TPS === 0 && t > 0;
    for (const u of this.units) {
      if (!u.alive) continue;
      if (u.burn && u.burn.until > t && t % 15 === 0) {
        const src = this.byUid.get(u.burn.src);
        this.dealDamage(src && src.alive ? src : null, u, u.burn.dps / 2, 'true', { noProc: true });
        if (!u.alive) continue;
      }
      if (!sec) continue;
      if (u.tfx.regen) this.heal(u, u.maxHp * u.tfx.regen, u);
      if (u.fx.regen) this.heal(u, u.maxHp * u.fx.regen, u);
      if (u.fx.manaRegen && u.castLock <= t) u.mana += u.fx.manaRegen;
      if (u.fx.burnAura && (t / TPS) % 2 === 0) {
        for (const e of this.enemiesAdjacentTo(u.cell, u.team)) this.applyBurn(u, e, 0.01);
        this.emit({ t: 'vfx', kind: 'sunflare', uid: u.uid });
      }
      const secs = t / TPS;
      if (secs % 3 === 0) {
        if (u.tfx.tideMana) u.mana += u.tfx.tideMana;
        if (u.tfx.teamMana) u.mana += u.tfx.teamMana;
        if (u.tfx.tideMana) this.emit({ t: 'vfx', kind: 'tide', uid: u.uid });
      }
      if (secs % 4 === 0 && u.tfx.asStack && u.stacks.gear < 4) {
        u.stacks.gear++;
        this.emit({ t: 'vfx', kind: 'overclock', uid: u.uid });
      }
      if (secs % 5 === 0) {
        if (u.tfx.menderShield) {
          const [low] = this.lowestHpPctAlly(u, 1);
          if (low) { this.addShield(low, u.tfx.menderShield * this.abilityScale(u), 4 * TPS); this.emit({ t: 'vfx', kind: 'mender', uid: u.uid, target: low.uid }); }
        }
        if (u.fx.healPulse) {
          for (const a of this.alliesWithin(u.cell, u.team, 2)) this.heal(a, (a.maxHp - a.hp) * u.fx.healPulse, u);
          this.emit({ t: 'vfx', kind: 'pulse', uid: u.uid });
        }
      }
    }
    if (t === 10 * TPS) {
      for (const team of [0, 1]) {
        if (!this.boons[team].has('secondwind')) continue;
        for (const u of this.units) if (u.alive && u.team === team) this.heal(u, (u.maxHp - u.hp) * 0.3, u);
      }
    }
  }

  step() {
    if (this.done) return;
    // Run scheduled actions due this tick, in order.
    if (this.queue.length) {
      this.queue.sort((a, b) => (a.at - b.at) || (a.seq - b.seq));
      while (this.queue.length && this.queue[0].at <= this.tick) {
        const job = this.queue.shift();
        job.fn();
      }
    }
    this.periodic();
    // Alternate the acting order every tick so neither side always strikes first.
    const n = this.units.length;
    if (this.tick % 2 === 0) for (let i = 0; i < n; i++) { const u = this.units[i]; if (u.alive) this.act(u); }
    else for (let i = n - 1; i >= 0; i--) { const u = this.units[i]; if (u.alive) this.act(u); }
    this.tick++;
    const homeAlive = this.units.some((u) => u.alive && u.team === 0);
    const awayAlive = this.units.some((u) => u.alive && u.team === 1);
    if (!homeAlive || !awayAlive || this.tick >= MAX_TICKS) {
      this.done = true;
      let winner = -1;
      if (homeAlive && !awayAlive) winner = 0;
      else if (awayAlive && !homeAlive) winner = 1;
      this.result = {
        winner,
        ticks: this.tick,
        survivors: [this.units.filter((u) => u.alive && u.team === 0), this.units.filter((u) => u.alive && u.team === 1)],
        takedowns: this.takedowns.slice(),
      };
      this.emit({ t: 'end', winner });
    }
  }

  runToEnd() {
    let guard = 0;
    while (!this.done && guard++ < MAX_TICKS + 10) this.step();
    return this.result;
  }
}
