// A Warden: health, gold, level, bench, board, relics and shop.
import { CHAMPION_BY_ID, CHAMPIONS, POOL_SIZE, SHOP_ODDS, XP_TO_NEXT, MAX_LEVEL } from '../data/champions.js';
import { ITEMS, combineKey } from '../data/items.js';
import { BENCH_SIZE, HALF_ROWS, COLS } from '../core/hex.js';
import { makeOwnedUnit, sellValue, countTraits, activeTraits } from './units.js';

export const BOARD_CELLS = HALF_ROWS * COLS; // 28 cells on the home half
export const ITEM_BENCH_SIZE = 10;

export class Pool {
  constructor() {
    this.left = {};
    for (const c of CHAMPIONS) this.left[c.id] = POOL_SIZE[c.cost];
  }
  take(id, n = 1) { this.left[id] = Math.max(0, this.left[id] - n); }
  give(id, n = 1) { this.left[id] = Math.min(POOL_SIZE[CHAMPION_BY_ID[id].cost], this.left[id] + n); }
  roll(rng, level) {
    const odds = SHOP_ODDS[level];
    let r = rng.next() * 100;
    let tier = 1;
    for (let i = 0; i < 5; i++) {
      if (r < odds[i]) { tier = i + 1; break; }
      r -= odds[i];
    }
    for (let t = tier; t >= 1; t--) {
      const cands = CHAMPIONS.filter((c) => c.cost === t && this.left[c.id] > 0);
      const total = cands.reduce((s, c) => s + this.left[c.id], 0);
      if (!total) continue;
      let x = rng.next() * total;
      for (const c of cands) {
        x -= this.left[c.id];
        if (x < 0) return c.id;
      }
      return cands[cands.length - 1].id;
    }
    return null;
  }
}

export class Player {
  constructor({ id, name, color, kind = 'bot', rival = null }) {
    this.id = id;
    this.name = name;
    this.color = color;
    this.kind = kind; // 'human' | 'bot' | 'remote'
    this.rival = rival;
    this.hp = 100;
    this.gold = 0;
    this.level = 1;
    this.xp = 0;
    this.streak = 0;
    this.alive = true;
    this.place = 0;
    this.bench = new Array(BENCH_SIZE).fill(null);
    this.board = new Array(BOARD_CELLS).fill(null);
    this.items = [];
    this.shop = [null, null, null, null, null];
    this.shopLocked = false;
    this.boons = [];
    this.freeRerolls = 0;
    this.lastOpponent = null;
    this.lastResult = null; // 'win' | 'loss' | 'draw'
    this.history = [];
  }

  get isHuman() { return this.kind === 'human'; }
  hasBoon(id) { return this.boons.includes(id); }
  maxBoard() { return this.level + (this.hasBoon('warband') ? 1 : 0); }
  boardUnits() { return this.board.filter(Boolean); }
  benchUnits() { return this.bench.filter(Boolean); }
  allUnits() { return [...this.boardUnits(), ...this.benchUnits()]; }
  boardCount() { return this.boardUnits().length; }
  traitCounts() { return countTraits(this.boardUnits()); }
  traits() { return activeTraits(this.traitCounts()); }
  xpNeeded() { return XP_TO_NEXT[this.level] || 0; }

  addXp(n) {
    let leveled = false;
    if (this.level >= MAX_LEVEL) return false;
    this.xp += n;
    while (this.level < MAX_LEVEL && this.xp >= XP_TO_NEXT[this.level]) {
      this.xp -= XP_TO_NEXT[this.level];
      this.level++;
      leveled = true;
    }
    if (this.level >= MAX_LEVEL) this.xp = 0;
    return leveled;
  }

  buyXp() {
    if (this.gold < 4 || this.level >= MAX_LEVEL) return false;
    this.gold -= 4;
    return this.addXp(4) ? 'level' : true;
  }

  refreshShop(pool, rng, free = false) {
    if (!free) {
      if (this.freeRerolls > 0) this.freeRerolls--;
      else {
        if (this.gold < 2) return false;
        this.gold -= 2;
      }
    }
    for (let i = 0; i < 5; i++) this.shop[i] = pool.roll(rng, this.level);
    return true;
  }

  freeBenchSlot() { return this.bench.findIndex((x) => !x); }

  // Can this purchase complete a star-up even with a full bench?
  wouldCombine(id) {
    return this.allUnits().filter((u) => u.id === id && u.star === 1).length >= 2;
  }

  buy(slot, pool) {
    const id = this.shop[slot];
    if (!id) return null;
    const cost = CHAMPION_BY_ID[id].cost;
    if (this.gold < cost) return null;
    const free = this.freeBenchSlot();
    if (free < 0 && !this.wouldCombine(id)) return null;
    this.gold -= cost;
    this.shop[slot] = null;
    pool.take(id);
    const u = makeOwnedUnit(id, 1);
    if (free >= 0) this.bench[free] = u;
    else this.bench.push(u); // temporary, resolved by combine
    const merged = this.combineAll();
    return { unit: u, merged };
  }

  addUnit(id, star = 1) {
    const free = this.freeBenchSlot();
    if (free < 0) return null;
    const u = makeOwnedUnit(id, star);
    this.bench[free] = u;
    const merged = this.combineAll();
    return { unit: u, merged };
  }

  locate(uid) {
    let i = this.bench.findIndex((u) => u && u.uid === uid);
    if (i >= 0) return { where: 'bench', index: i, unit: this.bench[i] };
    i = this.board.findIndex((u) => u && u.uid === uid);
    if (i >= 0) return { where: 'board', index: i, unit: this.board[i] };
    return null;
  }

  // Merge three copies into one higher star, repeatedly. Returns list of upgraded units.
  combineAll() {
    const upgraded = [];
    let again = true;
    while (again) {
      again = false;
      for (const star of [1, 2]) {
        const groups = {};
        for (const u of this.allUnits()) {
          if (u.star !== star) continue;
          (groups[u.id] = groups[u.id] || []).push(u);
        }
        for (const [id, list] of Object.entries(groups)) {
          if (list.length < 3) continue;
          // Prefer keeping a copy that is on the board.
          const sorted = list.slice().sort((a, b) => {
            const la = this.locate(a.uid);
            const lb = this.locate(b.uid);
            return (la && la.where === 'board' ? 0 : 1) - (lb && lb.where === 'board' ? 0 : 1);
          });
          const [keep, ...rest] = sorted.slice(0, 3);
          const items = [...keep.items];
          for (const r of rest) {
            items.push(...r.items);
            this.removeUnit(r.uid);
          }
          keep.star = star + 1;
          keep.items = [];
          for (const it of items) {
            if (!this.giveItem(keep, it)) this.items.push(it);
          }
          upgraded.push(keep);
          // a unit that was waiting in overflow slot needs a home
          const loc = this.locate(keep.uid);
          if (!loc) {
            const free = this.freeBenchSlot();
            if (free >= 0) this.bench[free] = keep;
          }
          again = true;
          break;
        }
        if (again) break;
      }
    }
    // Clean the overflow slot.
    if (this.bench.length > 9) {
      const extra = this.bench.slice(9).filter(Boolean);
      this.bench.length = 9;
      for (const u of extra) {
        const free = this.freeBenchSlot();
        if (free >= 0) this.bench[free] = u;
      }
    }
    return upgraded;
  }

  removeUnit(uid) {
    let i = this.bench.findIndex((u) => u && u.uid === uid);
    if (i >= 0) { this.bench[i] = null; return true; }
    i = this.board.findIndex((u) => u && u.uid === uid);
    if (i >= 0) { this.board[i] = null; return true; }
    return false;
  }

  sell(uid, pool) {
    const loc = this.locate(uid);
    if (!loc) return 0;
    const u = loc.unit;
    const value = sellValue(u);
    this.gold += value;
    pool.give(u.id, u.star === 1 ? 1 : u.star === 2 ? 3 : 9);
    for (const it of u.items) this.items.push(it);
    this.removeUnit(uid);
    return value;
  }

  // Move a unit to bench slot or board cell, swapping with whatever is there.
  moveUnit(uid, dest) {
    const from = this.locate(uid);
    if (!from) return false;
    const arr = dest.where === 'bench' ? this.bench : this.board;
    if (dest.index < 0 || dest.index >= arr.length) return false;
    const other = arr[dest.index];
    if (dest.where === 'board' && from.where === 'bench' && !other && this.boardCount() >= this.maxBoard()) return false;
    const srcArr = from.where === 'bench' ? this.bench : this.board;
    srcArr[from.index] = other || null;
    arr[dest.index] = from.unit;
    return true;
  }

  // Equip an item on a unit. Components combine with a lone component.
  giveItem(unit, itemId) {
    const it = ITEMS[itemId];
    if (!it) return false;
    if (it.component) {
      const lastIdx = unit.items.length - 1;
      const last = unit.items[lastIdx];
      if (last && ITEMS[last].component) {
        unit.items[lastIdx] = combineKey(last, itemId);
        return 'combined';
      }
    }
    if (unit.items.length >= 3) return false;
    unit.items.push(itemId);
    return true;
  }

  equipFromBench(itemIndex, uid) {
    const loc = this.locate(uid);
    if (!loc) return false;
    const itemId = this.items[itemIndex];
    if (!itemId) return false;
    const ok = this.giveItem(loc.unit, itemId);
    if (ok) this.items.splice(itemIndex, 1);
    return ok;
  }

  // Put bench units on the board if there is room (done automatically before combat).
  autoFill() {
    while (this.boardCount() < this.maxBoard()) {
      const benchIdx = this.bench.findIndex(Boolean);
      if (benchIdx < 0) break;
      const u = this.bench[benchIdx];
      const ranged = CHAMPION_BY_ID[u.id].stats.range > 1;
      const order = ranged ? [3, 1, 5, 2, 4, 0, 6, 10, 8, 12] : [24, 22, 26, 23, 25, 21, 27, 17, 15, 19];
      let cell = order.find((c) => !this.board[c]);
      if (cell === undefined) cell = this.board.findIndex((x) => !x);
      if (cell < 0) break;
      this.board[cell] = u;
      this.bench[benchIdx] = null;
    }
  }

  // Snapshot of the board for combat and for sending to online opponents.
  snapshot() {
    const units = [];
    this.board.forEach((u, cell) => {
      if (u) units.push({ owned: { uid: u.uid, id: u.id, star: u.star, items: u.items.slice() }, cell });
    });
    return { units, boons: this.boons.slice() };
  }

  income(stage) {
    const base = stage === 1 ? 2 : 5;
    const cap = 5 + (this.hasBoon('interest') ? 2 : 0);
    const interest = Math.min(cap, Math.floor(this.gold / 10));
    const s = Math.abs(this.streak);
    const streak = s >= 5 ? 3 : s >= 4 ? 2 : s >= 2 ? 1 : 0;
    return { base, interest, streak, total: base + interest + streak };
  }
}
