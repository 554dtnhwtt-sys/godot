// The flow of a whole game: rounds, phases, income, pairings, fights and eliminations.
// Works for single-player (one human + seven rival Wardens) and for online lobbies,
// where remote humans send board snapshots and every client computes every fight.
import { RNG, hashString } from '../core/rng.js';
import { CHAMPIONS, CHAMPION_BY_ID } from '../data/champions.js';
import { COMPONENT_ORDER, ITEMS } from '../data/items.js';
import { BOONS, MONSTER_WAVES, RIVALS, STAGE_DAMAGE, BOON_ROUNDS, PLANNING_SECONDS, roundKind, roundsInStage } from '../data/world.js';
import { cellIndex } from '../core/hex.js';
import { Combat, TPS } from './sim.js';
import { Player, Pool } from './player.js';
import { botPlanning, botPickBoon, botPickDraft, arrange, equip } from './bot.js';

class Emitter {
  constructor() { this.handlers = {}; }
  on(ev, fn) { (this.handlers[ev] = this.handlers[ev] || []).push(fn); return () => this.off(ev, fn); }
  off(ev, fn) { this.handlers[ev] = (this.handlers[ev] || []).filter((f) => f !== fn); }
  emit(ev, ...args) { for (const f of this.handlers[ev] || []) f(...args); }
}

const h = (...parts) => hashString(parts.join('|'));

export class Match extends Emitter {
  // humans: [{ id, name, color, kind: 'human'|'remote' }]; localId: id of this client's player
  constructor({ seed, humans, localId, fillBots = true, net = null }) {
    super();
    this.seed = seed >>> 0;
    this.net = net;
    this.online = !!net;
    this.localRng = new RNG((Math.random() * 2 ** 32) >>> 0);
    this.pool = new Pool();
    this.botPool = this.online ? new Pool() : this.pool;
    this.players = [];
    humans.forEach((hm) => this.players.push(new Player({ id: hm.id, name: hm.name, color: hm.color, kind: hm.kind })));
    if (fillBots) {
      const rivals = new RNG(h(this.seed, 'rivals')).shuffle(RIVALS.slice());
      let k = 0;
      while (this.players.length < 8) {
        const r = rivals[k++ % rivals.length];
        const p = new Player({ id: `bot${k}`, name: r.name, color: r.color, kind: 'bot', rival: r });
        p.rng = new RNG(h(this.seed, 'bot', k));
        this.players.push(p);
      }
    }
    this.local = this.players.find((p) => p.id === localId);
    this.local.rng = this.localRng;
    this.stage = 1;
    this.round = 0;
    this.phase = 'intro';
    this.timeLeft = 3;
    this.phaseTotal = 3;
    this.viewCombat = null;
    this.viewFlip = false;
    this.viewOpponent = null;
    this.fightResults = [];
    this.pendingBoon = null;
    this.pendingDraft = null;
    this.placeCounter = this.players.length;
    this.combatSpeed = 1;
    this.lastRoundDamage = 0;
    this.history = [];
    this.waiting = false;
  }

  get rng() { return this.localRng; }
  alivePlayers() { return this.players.filter((p) => p.alive); }
  roundKey() { return `${this.stage}-${this.round}`; }
  kind() { return this.round === 0 ? 'opening' : roundKind(this.stage, this.round); }

  rngFor(p) { return p.rng || this.localRng; }
  poolFor(p) { return p.kind === 'bot' ? this.botPool : this.pool; }

  start() {
    for (const p of this.players) {
      if (p.kind === 'remote') continue;
      p.gold = 2;
      p.refreshShop(this.poolFor(p), this.rngFor(p), true);
    }
    this.emit('announce', 'welcome');
    this.setPhase('intro', 3.5);
  }

  setPhase(phase, seconds) {
    this.phase = phase;
    this.timeLeft = seconds;
    this.phaseTotal = seconds;
    this.emit('phase', phase);
    this.emit('update');
  }

  // ───────────────────────── round flow ─────────────────────────
  nextRound() {
    if (this.round === 0) {
      this.round = 1;
    } else {
      this.round++;
      if (this.round > roundsInStage(this.stage)) {
        this.stage++;
        this.round = 1;
      }
    }
    const kind = this.kind();
    if (kind === 'draft') this.beginDraft();
    else this.beginPlanning();
  }

  beginOpening() {
    this.round = 0;
    this.beginDraft(true);
  }

  beginDraft(opening = false) {
    // Every Warden picks one champion (with a relic component) from a small offering.
    for (const p of this.alivePlayers()) {
      if (p.kind === 'remote') continue;
      const rng = this.rngFor(p);
      const pool = this.poolFor(p);
      const offers = [];
      const maxCost = opening ? 1 : Math.min(5, 1 + Math.floor(this.stage / 1.5));
      const used = new Set();
      for (let i = 0; i < 4; i++) {
        const cands = CHAMPIONS.filter((c) => c.cost <= maxCost && c.cost >= (opening ? 1 : Math.max(1, maxCost - 2)) && !used.has(c.id) && pool.left[c.id] > 0);
        const ch = rng.pick(cands.length ? cands : CHAMPIONS.filter((c) => c.cost === 1));
        used.add(ch.id);
        offers.push({ champ: ch.id, item: rng.pick(COMPONENT_ORDER) });
      }
      if (p === this.local) this.pendingDraft = offers;
      else this.applyDraft(p, offers[botPickDraft(p, offers)]);
    }
    this.emit('announce', 'draft');
    this.emit('draft-offer', this.pendingDraft);
    this.setPhase('draft', opening ? 20 : 15);
  }

  applyDraft(p, offer) {
    const pool = this.poolFor(p);
    pool.take(offer.champ);
    const res = p.addUnit(offer.champ, 1);
    if (!res) {
      p.gold += CHAMPION_BY_ID[offer.champ].cost;
      pool.give(offer.champ);
    }
    p.items.push(offer.item);
    if (p.kind === 'bot') { arrange(p); equip(p); }
    return res;
  }

  pickDraft(i) {
    if (!this.pendingDraft) return;
    const offer = this.pendingDraft[i];
    this.pendingDraft = null;
    const res = this.applyDraft(this.local, offer);
    if (res && res.merged.length) this.emit('starup', res.merged[0]);
    this.emit('voice', offer.champ, 'select');
    this.emit('update');
  }

  beginPlanning() {
    const key = this.roundKey();
    const first = this.stage === 1 && this.round === 1;
    for (const p of this.alivePlayers()) {
      if (p.kind === 'remote') continue;
      if (!first) {
        const inc = p.income(this.stage);
        p.gold += inc.total;
        if (p === this.local) this.emit('income', inc);
        const lv = p.addXp(2 + (p.hasBoon('study') ? 1 : 0));
        if (lv && p === this.local) { this.emit('announce', 'levelup'); this.emit('levelup', p.level); }
      }
      if (p.hasBoon('reroll')) p.freeRerolls = 1;
      if (!p.shopLocked || first) p.refreshShop(this.poolFor(p), this.rngFor(p), true);
      if (p === this.local) p.shopLocked = false;
    }
    // Boons
    if (BOON_ROUNDS.includes(key)) {
      for (const p of this.alivePlayers()) {
        if (p.kind === 'remote') continue;
        const rng = this.rngFor(p);
        const avail = BOONS.filter((b) => !p.boons.includes(b.id));
        const offers = rng.shuffle(avail.slice()).slice(0, 3);
        if (p === this.local) this.pendingBoon = offers;
        else this.applyBoon(p, botPickBoon(p, offers));
      }
      this.emit('announce', 'boon');
      this.emit('boon-offer', this.pendingBoon);
    }
    for (const p of this.alivePlayers()) if (p.kind === 'bot') botPlanning(p, this);
    const secs = this.stage === 1 ? 18 : PLANNING_SECONDS + (BOON_ROUNDS.includes(key) ? 10 : 0);
    if (this.kind() === 'pve') this.emit('announce', 'monsters');
    this.setPhase('planning', secs);
  }

  applyBoon(p, id) {
    p.boons.push(id);
    const rng = this.rngFor(p);
    if (id === 'tithe') p.gold += 14;
    if (id === 'study') p.addXp(8);
    if (id === 'cache') p.items.push(rng.pick(COMPONENT_ORDER), rng.pick(COMPONENT_ORDER));
    if (id === 'hoard') {
      const done = Object.keys(ITEMS).filter((k) => !ITEMS[k].component);
      p.items.push(rng.pick(done));
    }
    if (id === 'reroll') p.freeRerolls = 1;
    if (p.kind === 'bot') equip(p);
  }

  pickBoon(id) {
    if (!this.pendingBoon) return;
    this.pendingBoon = null;
    this.applyBoon(this.local, id);
    this.emit('update');
  }

  // ───────────────────────── local player actions ─────────────────────────
  canAct() { return this.local.alive && (this.phase === 'planning' || this.phase === 'combat' || this.phase === 'draft' || this.phase === 'results' || this.phase === 'intro'); }

  buy(slot) {
    const p = this.local;
    if (!this.canAct()) return false;
    const id = p.shop[slot];
    const res = p.buy(slot, this.pool);
    if (!res) { this.emit('error', p.freeBenchSlot() < 0 ? 'Your bench is full.' : 'Not enough gold.'); return false; }
    this.emit('bought', id);
    if (res.merged.length) {
      for (const u of res.merged) this.emit('starup', u);
    }
    this.emit('update');
    return true;
  }

  sell(uid) {
    if (!this.canAct()) return 0;
    const loc = this.local.locate(uid);
    if (!loc) return 0;
    if (this.phase === 'combat' && loc.where === 'board') { this.emit('error', 'Cannot sell fighting champions.'); return 0; }
    const g = this.local.sell(uid, this.pool);
    this.emit('sold', g);
    this.emit('update');
    return g;
  }

  reroll() {
    if (!this.canAct()) return false;
    const ok = this.local.refreshShop(this.pool, this.localRng);
    if (!ok) { this.emit('error', 'Not enough gold.'); return false; }
    this.emit('reroll');
    this.emit('update');
    return true;
  }

  buyXp() {
    if (!this.canAct()) return false;
    const r = this.local.buyXp();
    if (!r) { this.emit('error', this.local.level >= 10 ? 'Max level reached.' : 'Not enough gold.'); return false; }
    if (r === 'level') { this.emit('announce', 'levelup'); this.emit('levelup', this.local.level); }
    this.emit('xp');
    this.emit('update');
    return true;
  }

  toggleLock() {
    this.local.shopLocked = !this.local.shopLocked;
    this.emit('update');
  }

  moveUnit(uid, dest) {
    if (!this.canAct()) return false;
    const loc = this.local.locate(uid);
    if (!loc) return false;
    if (this.phase === 'combat' && (dest.where === 'board' || loc.where === 'board')) return false;
    const ok = this.local.moveUnit(uid, dest);
    if (!ok && dest.where === 'board') this.emit('error', `You can only field ${this.local.maxBoard()} champions. Level up to field more.`);
    this.emit('update');
    return ok;
  }

  equip(itemIndex, uid) {
    if (!this.canAct()) return false;
    const r = this.local.equipFromBench(itemIndex, uid);
    if (!r) { this.emit('error', 'That champion cannot hold more relics.'); return false; }
    if (r === 'combined') this.emit('announce', 'relic');
    this.emit('equipped');
    this.emit('update');
    return true;
  }

  // ───────────────────────── combat ─────────────────────────
  endPlanning() {
    for (const p of this.alivePlayers()) {
      if (p.kind === 'remote') continue;
      p.autoFill();
    }
    this.pendingBoon && this.pickBoon(this.pendingBoon[0].id);
    if (this.online) {
      this.waiting = true;
      this.setPhase('sync', 15);
      this.net.submitRound(this, this.roundKey(), this.local.snapshot(), this.local.publicState())
        .then((snaps) => { this.waiting = false; this.startCombat(snaps); });
    } else {
      this.startCombat(null);
    }
  }

  // snaps: { playerId: snapshot } for remote players (online only)
  startCombat(remoteSnaps) {
    const kind = this.kind();
    const alive = this.alivePlayers();
    const snapOf = (p) => {
      if (p.kind === 'remote') {
        const s = remoteSnaps && remoteSnaps[p.id];
        if (s) p.lastSnap = s;
        return p.lastSnap || { units: [], boons: [] };
      }
      if (this.online && p === this.local) {
        if (remoteSnaps && remoteSnaps.__selfStale && p.lastSnap) return p.lastSnap;
        p.lastSnap = p.snapshot();
        return p.lastSnap;
      }
      return p.snapshot();
    };
    const snaps = new Map(alive.map((p) => [p.id, snapOf(p)]));
    this.fightResults = [];
    const base = h(this.seed, this.stage, this.round);
    if (kind === 'pve') {
      const wave = MONSTER_WAVES[this.roundKey()] || MONSTER_WAVES['7-7'];
      const scale = 1 + Math.max(0, this.stage - 7) * 0.5;
      for (const p of alive) {
        const monsters = wave.map(([mon, r, c]) => ({ mon, cell: cellIndex(c, r), scale }));
        const combat = new Combat({ seed: h(base, p.id), home: snaps.get(p.id), away: { monsters }, stage: this.stage });
        this.fightResults.push({ a: p, b: null, combat, pve: true });
      }
    } else {
      // Deterministic pairing, avoiding a rematch of last round where possible.
      const order = alive.slice().sort((x, y) => (x.id < y.id ? -1 : 1));
      const prng = new RNG(h(base, 'pairs'));
      let best = null;
      for (let attempt = 0; attempt < 12; attempt++) {
        const sh = prng.shuffle(order.slice());
        let repeats = 0;
        for (let i = 0; i + 1 < sh.length; i += 2) if (sh[i].lastOpponent === sh[i + 1].id) repeats++;
        if (!best || repeats < best.repeats) best = { sh, repeats };
        if (!repeats) break;
      }
      const sh = best.sh;
      for (let i = 0; i < sh.length; i += 2) {
        let a = sh[i];
        let b = sh[i + 1];
        let ghost = false;
        if (!b) {
          const others = sh.filter((x) => x !== a);
          b = others[prng.int(others.length)];
          ghost = true;
        }
        const ia = this.players.indexOf(a);
        const ib = this.players.indexOf(b);
        const [home, away] = ia < ib || ghost ? [a, b] : [b, a];
        const combat = new Combat({ seed: h(base, home.id, away.id), home: snaps.get(home.id), away: snaps.get(away.id), stage: this.stage });
        this.fightResults.push({ a: home, b: away, combat, ghost });
      }
    }
    // Which fight do we watch?
    const mine = this.fightResults.find((f) => f.a === this.local || (f.b === this.local && !f.ghost));
    this.viewFight = mine || null;
    this.viewCombat = mine ? mine.combat : null;
    this.viewFlip = !!(mine && mine.b === this.local);
    this.viewOpponent = mine ? (mine.pve ? null : (this.viewFlip ? mine.a : mine.b)) : null;
    for (const f of this.fightResults) if (f !== mine) f.result = f.combat.runToEnd();
    this.emit('announce', 'combat');
    this.emit('combat-start', this.viewCombat, { flip: this.viewFlip, opponent: this.viewOpponent, pve: kind === 'pve', snaps });
    this.setPhase('combat', 60);
  }

  unitDamage(u) {
    if (u.isMonster) return 1;
    const cost = CHAMPION_BY_ID[u.id].cost;
    return u.star + (cost >= 4 ? 1 : 0);
  }

  finishCombat() {
    const kind = this.kind();
    const stageDmg = STAGE_DAMAGE[Math.min(8, this.stage)];
    const outcomes = [];
    for (const f of this.fightResults) {
      const r = f.result || f.combat.result || f.combat.runToEnd();
      f.result = r;
      const sides = f.pve ? [f.a] : [f.a, f.b];
      sides.forEach((p, idx) => {
        if (f.ghost && idx === 1) return;
        const won = r.winner === idx;
        const lost = r.winner !== idx; // a draw hurts both
        const enemySurv = r.survivors[1 - idx];
        let dmg = 0;
        if (lost) dmg = stageDmg + enemySurv.reduce((s, u) => s + this.unitDamage(u), 0);
        if (r.winner === -1) dmg = Math.max(1, Math.ceil(dmg * 0.5));
        if (kind !== 'pve' && kind !== 'opening' && this.stage === 1) dmg = 0;
        outcomes.push({ p, won, dmg, fight: f, takedowns: r.takedowns[idx], survivors: r.survivors[idx] });
      });
    }
    for (const o of outcomes) {
      const p = o.p;
      p.hp -= o.dmg;
      if (kind === 'pvp') {
        if (o.won) p.streak = p.streak >= 0 ? p.streak + 1 : 1;
        else p.streak = p.streak <= 0 ? p.streak - 1 : -1;
        p.lastOpponent = o.fight.pve ? null : (o.fight.a === p ? o.fight.b.id : o.fight.a.id);
      }
      p.lastResult = o.won ? 'win' : o.dmg ? 'loss' : 'draw';
      if (p.kind !== 'remote') {
        if (o.won && kind === 'pvp') p.gold += 1; // win bonus
        if (p.hasBoon('bounty') && o.takedowns >= 3) p.gold += 1;
        for (const u of o.survivors) if (u.fx && u.fx.goldOnWin) p.gold += u.fx.goldOnWin;
        if (kind === 'pve') this.giveLoot(p, o.won);
      }
      if (p === this.local) {
        this.lastRoundDamage = o.dmg;
        this.emit('round-result', { won: o.won, dmg: o.dmg, pve: kind === 'pve' });
        if (kind === 'pvp') {
          if (p.streak === 3 || p.streak === 5) this.emit('announce', 'streak');
          else if (p.streak === -3) this.emit('announce', 'losestreak');
          else this.emit('announce', o.won ? 'victory' : 'defeat');
        } else this.emit('announce', o.won ? 'victory' : 'defeat');
        if (p.hp > 0 && p.hp <= 25) this.emit('announce', 'lastround');
      }
    }
    // Eliminations, lowest health places last.
    const dead = this.players.filter((p) => p.alive && p.hp <= 0).sort((a, b) => a.hp - b.hp);
    for (const p of dead) {
      p.alive = false;
      p.place = this.placeCounter--;
      // Return their champions to the pool.
      if (p.kind !== 'remote') for (const u of p.allUnits()) this.poolFor(p).give(u.id, u.star === 1 ? 1 : u.star === 2 ? 3 : 9);
      this.emit('player-out', p);
      if (p !== this.local) this.emit('announce', 'fallen');
    }
    const alive = this.alivePlayers();
    if (alive.length === 2 && dead.length) this.emit('announce', 'finaltwo');
    this.viewCombat = null;
    this.emit('round-done', this.roundKey(), this.players.map((p) => p.hp));
    this.emit('combat-end');
    if (!this.local.alive || alive.length <= 1) {
      if (alive.length === 1) alive[0].place = 1;
      this.setPhase('gameover', 9999);
      this.emit('gameover', this.local.place || (this.local.alive ? 1 : this.local.place));
      if (this.local.place === 1) this.emit('announce', 'first');
      else if (!this.local.alive) this.emit('announce', 'eliminated');
      return;
    }
    this.setPhase('results', 2.5);
  }

  giveLoot(p, won) {
    const rng = this.rngFor(p);
    const loot = { items: [], gold: 0 };
    const key = this.roundKey();
    if (this.stage === 1) {
      loot.items.push(rng.pick(COMPONENT_ORDER));
      loot.gold = key === '1-3' ? 3 : 1;
    } else {
      const n = won ? 2 : 1;
      for (let i = 0; i < n; i++) loot.items.push(rng.pick(COMPONENT_ORDER));
      if (won && this.stage >= 4) {
        const done = Object.keys(ITEMS).filter((k) => !ITEMS[k].component);
        loot.items = [rng.pick(done)];
      }
      loot.gold = won ? 4 : 2;
    }
    p.items.push(...loot.items);
    if (p.items.length > 10) p.items.length = 10;
    p.gold += loot.gold;
    if (p.kind === 'bot') equip(p);
    if (p === this.local) this.emit('loot', loot);
  }

  // ───────────────────────── tick ─────────────────────────
  update(dt) {
    if (this.phase === 'gameover') return;
    if (this.phase === 'combat') {
      const c = this.viewCombat;
      if (c && !c.done) {
        this.combatAcc = (this.combatAcc || 0) + dt * TPS * this.combatSpeed;
        let steps = 0;
        while (this.combatAcc >= 1 && !c.done && steps < 12 * this.combatSpeed) { c.step(); this.combatAcc -= 1; steps++; }
        if (c.done) { this.combatAcc = 0; this.combatEndDelay = 2.2; }
      } else if (!c) {
        this.combatEndDelay = this.combatEndDelay ?? 1.5;
      }
      if (c && !c.done) return;
      this.combatEndDelay -= dt;
      if (this.combatEndDelay <= 0) { this.combatEndDelay = undefined; this.finishCombat(); }
      return;
    }
    if (this.phase === 'sync') {
      this.timeLeft -= dt;
      return;
    }
    if (this.net && this.net.externalClock && this.phase === 'planning') {
      this.timeLeft = Math.max(0, this.net.planningLeft(this));
    } else {
      this.timeLeft -= dt;
    }
    if (this.timeLeft > 0) return;
    if (this.phase === 'intro') this.beginOpening();
    else if (this.phase === 'draft') {
      if (this.pendingDraft) this.pickDraft(this.localRng.int(this.pendingDraft.length));
      this.nextRound();
    } else if (this.phase === 'planning') this.endPlanning();
    else if (this.phase === 'results') this.nextRound();
  }
}

// What other players may see about this player (online lobby list).
Player.prototype.publicState = function publicState() {
  return { hp: this.hp, level: this.level, gold: this.gold, streak: this.streak };
};
