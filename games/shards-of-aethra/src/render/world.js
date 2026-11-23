// Connects the game state to the 3D scene: places unit views, plays combat events
// as animation and effects, and handles dragging champions around.
import * as THREE from 'three';
import { UnitView } from './unitview.js';
import { cellToWorld, benchToWorld, mirrorCell, BENCH_SIZE, CELLS, cellRow } from '../core/hex.js';
import { CHAMPION_BY_ID } from '../data/champions.js';
import { TRAITS } from '../data/traits.js';
import { TPS } from '../game/sim.js';
import { BOARD_CELLS } from '../game/player.js';

const FACTION_COLOR = (id) => {
  const ch = CHAMPION_BY_ID[id];
  if (!ch) return 0xb070ff;
  return new THREE.Color(TRAITS[ch.traits[0]].color).getHex();
};

export class World {
  constructor({ stage, arena, vfx, hud, audio }) {
    this.stage = stage;
    this.scene = stage.scene;
    this.camera = stage.camera;
    this.arena = arena;
    this.vfx = vfx;
    this.hud = hud;
    this.audio = audio;
    this.barLayer = document.getElementById('bar-layer');
    this.numLayer = document.getElementById('num-layer');
    this.planViews = new Map(); // owned uid -> view
    this.combatViews = new Map(); // combat uid -> view
    this.combat = null;
    this.evIndex = 0;
    this.raycaster = new THREE.Raycaster();
    this.pointer = new THREE.Vector2();
    this.plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.42);
    this.drag = null;
    this.hoverView = null;
    this.selectedUid = null;
    this.lastVoice = 0;
    this.numCount = 0;
    this.speed = 1;
    this.bindInput();
  }

  setMatch(match) {
    this.match = match;
  }

  // ───────────────────────── planning views ─────────────────────────
  syncPlanning() {
    const p = this.match.local;
    const want = new Map();
    p.board.forEach((u, cell) => { if (u) want.set(u.uid, { u, where: 'board', index: cell }); });
    p.bench.forEach((u, slot) => { if (u) want.set(u.uid, { u, where: 'bench', index: slot }); });
    for (const [uid, v] of this.planViews) {
      const w = want.get(uid);
      if (!w || w.u.id !== v.spec.id) { v.dispose(); this.planViews.delete(uid); }
    }
    for (const [uid, w] of want) {
      let v = this.planViews.get(uid);
      const pos = w.where === 'board' ? cellToWorld(w.index) : benchToWorld(w.index);
      if (!v) {
        v = new UnitView(this, { uid, id: w.u.id, star: w.u.star, items: w.u.items, team: 'ally' });
        v.placeAt(pos.x, pos.z, w.where === 'bench' ? 0.4 : 0.42);
        v.facing = v.targetFacing = 0;
        this.planViews.set(uid, v);
        this.vfx.rise(new THREE.Vector3(pos.x, 0.45, pos.z), 0xbfe8ff, { n: 10, radius: 0.4, speed: 1.4, life: 0.6 });
      }
      if (v.star !== w.u.star) { v.setStar(w.u.star); v.setBarStars(); }
      v.setItems(w.u.items);
      v.where = w.where;
      v.index = w.index;
      if (!v.dragging) {
        const cur = v.root.position;
        if (Math.abs(cur.x - pos.x) > 0.01 || Math.abs(cur.z - pos.z) > 0.01) {
          if (v.moveFrom) v.moveTo.set(pos.x, 0.42, pos.z);
          else v.placeAt(pos.x, pos.z, 0.42);
        }
        v.targetFacing = 0;
      }
      const inCombat = !!this.combat && w.where === 'board';
      v.root.visible = !inCombat && !v.dead;
      v.hiddenByCombat = inCombat;
    }
  }

  planView(uid) { return this.planViews.get(uid); }

  starUp(owned) {
    const v = this.planViews.get(owned.uid);
    const pos = v ? v.root.position.clone() : new THREE.Vector3(0, 0.42, 6);
    const gold = owned.star >= 3 ? 0xffd86a : 0xbfe8ff;
    this.vfx.pillar(pos, gold, 7, 1.3, 1.0);
    this.vfx.rise(pos, gold, { n: 40, radius: 0.7, speed: 3, life: 1.2, size: 0.35 });
    this.vfx.ring(pos, gold, 2.6, 0.8);
    this.vfx.light(pos, gold, 30, 0.8);
    if (v) { v.flash(0.9); v.celebrateT = 0.8; }
  }

  // ───────────────────────── combat views ─────────────────────────
  startCombat(combat, { flip }) {
    this.combat = combat;
    this.flip = flip;
    this.myTeam = flip ? 1 : 0;
    this.evIndex = 0;
    for (const v of this.combatViews.values()) v.dispose();
    this.combatViews.clear();
    for (const u of combat.units) {
      const ally = u.team === this.myTeam;
      const v = new UnitView(this, { uid: u.uid, id: u.id, star: u.star, items: u.items, team: ally ? 'ally' : 'enemy', isMonster: u.isMonster, mon: u.isMonster ? u.id : null, monScale: u.monsterScale });
      const p = this.cellPos(u.cell);
      v.placeAt(p.x, p.z);
      v.facing = v.targetFacing = this.screenFacing(u.team);
      v.combatUnit = u;
      this.combatViews.set(u.uid, v);
      if (!ally) this.vfx.rise(new THREE.Vector3(p.x, 0.45, p.z), u.isMonster ? 0xc080ff : 0xff8a6a, { n: 12, radius: 0.5, speed: 2, life: 0.7 });
    }
    this.syncPlanning();
    this.arena.setHomeHalfVisible(true);
  }

  endCombat() {
    for (const v of this.combatViews.values()) v.dispose();
    this.combatViews.clear();
    this.combat = null;
    this.syncPlanning();
    this.arena.setHomeHalfVisible(false);
  }

  cellPos(cell) {
    return cellToWorld(this.flip ? mirrorCell(cell) : cell);
  }

  screenFacing(team) { return team === this.myTeam ? Math.PI : 0; }

  viewOf(uid) { return this.combatViews.get(uid); }

  handPos(v) {
    const p = v.root.position;
    const s = v.root.scale.x;
    const f = v.facing;
    return new THREE.Vector3(p.x + Math.sin(f) * 0.35 * s, p.y + 0.85 * s, p.z + Math.cos(f) * 0.35 * s);
  }
  chestPos(v) {
    const p = v.root.position;
    return new THREE.Vector3(p.x, p.y + 0.7 * v.root.scale.x * (v.rig.baseScale || 1), p.z);
  }

  processEvents() {
    const c = this.combat;
    if (!c) return;
    const evs = c.events;
    while (this.evIndex < evs.length) this.handleEvent(evs[this.evIndex++]);
  }

  handleEvent(e) {
    const v = e.uid ? this.viewOf(e.uid) : null;
    const tick = 1 / TPS / this.speed;
    switch (e.t) {
      case 'move': {
        if (!v) break;
        const p = this.cellPos(e.to);
        v.moveToPos(p.x, p.z, e.ticks * tick);
        break;
      }
      case 'leap':
      case 'blink': {
        if (!v) break;
        const p = this.cellPos(e.to);
        if (e.t === 'blink') {
          this.vfx.burst(this.chestPos(v), 0xb080ff, { n: 18, speed: 3, life: 0.4 });
          v.placeAt(p.x, p.z);
          this.vfx.burst(new THREE.Vector3(p.x, 1, p.z), 0xb080ff, { n: 18, speed: 3, life: 0.4 });
          this.audio.sfx('blink');
        } else {
          v.moveToPos(p.x, p.z, Math.max(0.25, e.ticks * tick), true);
          this.audio.sfx('leap');
        }
        break;
      }
      case 'attack': {
        if (!v) break;
        const tv = this.viewOf(e.target);
        if (tv) v.faceToward(tv.root.position.x, tv.root.position.z);
        const dur = Math.min(0.55, Math.max(0.25, (e.interval || 15) * tick * 0.85));
        const release = Math.min(0.7, (e.windup || 5) * tick / dur);
        if (!e.extra) v.playAttack(dur, release);
        if (e.ranged && tv) {
          const kind = v.isMonster ? 'bolt' : v.weapon === 'bow' ? (v.spec.id === 'isolde' ? 'icearrow' : 'arrow') : v.weapon === 'gun' ? 'bullet' : 'bolt';
          const color = v.isMonster ? 0xffd040 : FACTION_COLOR(v.spec.id);
          const delay = (e.windup || 4) * tick;
          setTimeout(() => {
            if (!this.combat || v.dead) return;
            this.vfx.projectile(this.handPos(v), () => this.chestPos(tv), { kind, color, dur: Math.max(0.08, (e.travel || 4) * tick) });
            this.audio.sfx(v.weapon === 'gun' ? 'shot' : v.weapon === 'bow' ? 'bow' : 'zap', 0.5);
          }, delay * 1000);
        } else if (!e.ranged) {
          setTimeout(() => { if (this.combat && !v.dead) this.audio.sfx(v.isMonster ? 'claw' : 'swing', 0.45); }, (e.windup || 4) * tick * 1000);
        }
        break;
      }
      case 'dmg': {
        if (!v) break;
        const src = this.viewOf(e.src);
        if (e.amount <= 0) break;
        if (e.type !== 'true' || e.ability) v.playHit();
        const pos = this.chestPos(v);
        if (e.type === 'physical' && !e.ability) {
          this.vfx.burst(pos, e.crit ? 0xffd27a : 0xfff0d0, { n: e.crit ? 14 : 6, speed: e.crit ? 4 : 2.5, life: 0.3, size: 0.25, gravity: 2 });
          this.audio.sfx('hit', 0.35, src ? src.isMonster : false);
        }
        if (e.type === 'magic' && e.ability) this.vfx.burst(pos, src ? FACTION_COLOR(src.spec.id) : 0xa070ff, { n: 8, speed: 2.4, life: 0.35, size: 0.3 });
        this.damageNumber(v, e.amount, e.type, e.crit, e.ability);
        if (e.crit) this.stage.addShake(0.08);
        break;
      }
      case 'heal': {
        if (!v || e.amount < 25) break;
        this.vfx.heal(v.root.position.clone().setY(0.5));
        this.damageNumber(v, e.amount, 'heal');
        break;
      }
      case 'shield': {
        if (!v) break;
        this.vfx.bubble(v, 0xdff4ff, 2.5);
        this.audio.sfx('shield', 0.4);
        break;
      }
      case 'cast': {
        if (!v) break;
        const tv = this.viewOf(e.target);
        if (tv) v.faceToward(tv.root.position.x, tv.root.position.z);
        v.playCast();
        const col = FACTION_COLOR(v.spec.id);
        this.vfx.ring(v.root.position.clone().setY(0.45), col, 1.6, 0.6);
        this.vfx.rise(v.root.position.clone().setY(0.5), col, { n: 16, radius: 0.5, speed: 2.5, life: 0.6 });
        this.vfx.light(v.root.position, col, 16, 0.5);
        this.audio.sfx('cast', 0.6);
        if (v.spec.team === 'ally' || this.audio.now() - this.lastVoice > 3) this.voice(v.spec.id, 'ability', v.spec.team === 'ally' ? 1 : 0.6);
        break;
      }
      case 'vfx':
        this.abilityVfx(e, v);
        break;
      case 'stun':
      case 'knockup':
      case 'freeze': {
        if (!v) break;
        v.stun(e.ticks * tick);
        if (e.t === 'knockup') v.moveToPos(v.root.position.x, v.root.position.z, 0.45, true);
        if (e.t === 'freeze') { v.tint(0x6ac8ff, 0.6); setTimeout(() => v.tint(0x000000, 0), e.ticks * tick * 1000); }
        this.stunStars(v, e.ticks * tick);
        break;
      }
      case 'chill': {
        if (!v) break;
        v.tint(0x3a8acc, 0.35);
        this.vfx.burst(this.chestPos(v), 0xbfeaff, { n: 8, speed: 1.5, life: 0.5, size: 0.22, gravity: 1 });
        setTimeout(() => v.tint(0x000000, 0), e.ticks * tick * 1000);
        break;
      }
      case 'root': {
        if (!v) break;
        this.vfx.ring(v.root.position, 0x6fd04a, 1.2, e.ticks * tick, { opacity: 0.8, ease: false });
        break;
      }
      case 'death': {
        if (!v) break;
        v.die();
        this.vfx.burst(this.chestPos(v), v.spec.team === 'ally' ? 0xa8d8ff : 0xffa080, { n: 22, speed: 3, life: 0.7, size: 0.35, gravity: -1 });
        this.audio.sfx('death', 0.6);
        if (!v.isMonster && v.spec.team === 'ally') this.voice(v.spec.id, 'death', 0.9);
        break;
      }
      case 'revive': {
        if (!v) break;
        v.revive();
        this.vfx.pillar(v.root.position, 0xffa040, 5, 1.0);
        this.vfx.burst(this.chestPos(v), 0xffb050, { n: 30, speed: 4, life: 0.8 });
        this.audio.sfx('levelup', 0.7);
        break;
      }
      case 'end': {
        const winner = e.winner;
        for (const cv of this.combatViews.values()) {
          if (!cv.dead && cv.combatUnit.team === winner) cv.celebrate = true;
        }
        break;
      }
      default:
        break;
    }
  }

  abilityVfx(e, v) {
    const vfx = this.vfx;
    const col = e.color || 0xffffff;
    const tv = e.target ? this.viewOf(e.target) : null;
    const at = v ? v.root.position.clone().setY(0.45) : null;
    switch (e.kind) {
      case 'slam': if (at) setTimeout(() => { vfx.slam(at, col, 1.6 * (e.radius || 1)); this.stage.addShake(e.big ? 0.5 : 0.3); this.audio.sfx('slam', 0.8); }, 180); break;
      case 'roar': if (at) { vfx.ring(at, col, 2.4, 0.6); vfx.burst(this.chestPos(v), col, { n: 30, speed: 4, flat: true, life: 0.6 }); this.audio.sfx('roar', 0.7); } break;
      case 'lunge': if (v && tv) { vfx.beam(this.chestPos(v), this.chestPos(tv), col, 0.25, { width: 0.2 }); vfx.burst(this.chestPos(tv), col, { n: 20, speed: 3.5 }); this.audio.sfx('water', 0.6); } break;
      case 'lineshot': if (v && tv) { const a = this.handPos(v); const b = this.chestPos(tv); const dir = b.clone().sub(a).setY(0).normalize(); const end = a.clone().add(dir.multiplyScalar(12)); vfx.projectile(a, end, { kind: 'arrow', color: col, dur: 0.45 }); vfx.beam(a, end, col, 0.4, { width: 0.1 }); this.audio.sfx('bow', 0.8); } break;
      case 'gnash': case 'claw': if (tv) setTimeout(() => { vfx.burst(this.chestPos(tv), col, { n: 24, speed: 4, life: 0.4 }); this.audio.sfx('claw', 0.8); }, 200); break;
      case 'lob': case 'missile': if (v && tv) { const dur = (e.ticks || 8) / TPS / this.speed; vfx.projectile(this.handPos(v), this.chestPos(tv), { kind: e.projectile, color: col, dur }); this.audio.sfx(e.projectile === 'cannonball' ? 'cannon' : e.projectile === 'fireball' ? 'fire' : e.projectile === 'icearrow' ? 'bow' : 'throw', 0.7); } break;
      case 'explosion': { const p = cellToWorld(this.flip ? mirrorCell(e.cell) : e.cell); const pos = new THREE.Vector3(p.x, 0.45, p.z); vfx.explosion(pos, col, e.radius || 1); this.stage.addShake(0.25); this.audio.sfx('boom', 0.8); break; }
      case 'song': for (const uid of e.targets || []) { const a = this.viewOf(uid); if (a) { vfx.rise(a.root.position.clone().setY(0.5), col, { n: 18, speed: 2, life: 1 }); vfx.bubble(a, col, 2); } } if (at) vfx.ring(at, col, 2, 0.8); this.audio.sfx('chime', 0.6); break;
      case 'thornwall': if (v) { vfx.bubble(v, col, (e.ticks || 150) / TPS / this.speed); vfx.burst(this.chestPos(v), col, { n: 20, speed: 3 }); } break;
      case 'spin': if (at) { vfx.ring(at, col, 2, 0.35); vfx.burst(this.chestPos(v), 0xffffff, { n: 26, speed: 5, flat: true, life: 0.35, size: 0.2 }); this.audio.sfx('saw', 0.7); } break;
      case 'frostburst': if (v) { vfx.burst(this.chestPos(v), col, { n: 24, speed: 3, life: 0.6 }); vfx.ring(v.root.position, col, 1.4, 0.5); } break;
      case 'frenzy': if (v) { vfx.pillar(v.root.position, col, 3, 0.8, 0.7); this.audio.sfx('fire', 0.7); this.frenzy(v, col, (e.ticks || 150) / TPS / this.speed); } break;
      case 'bloom': if (at) { vfx.ring(at, col, 4, 0.9); vfx.rise(at, col, { n: 40, radius: 2, speed: 2, life: 1.1 }); this.audio.sfx('chime', 0.6); } break;
      case 'roots': if (v) vfx.burst(v.root.position.clone().setY(0.5), col, { n: 16, speed: 2, up: 1.5, life: 0.6 }); break;
      case 'beam': if (v && tv) { const eye = v.rig.eyeOrb; const from = () => (eye ? eye.getWorldPosition(new THREE.Vector3()) : this.handPos(v)); vfx.beam(from, () => this.chestPos(tv), col, (e.ticks || 14) / TPS / this.speed, { width: 0.18 }); this.audio.sfx('beam', 0.7); setTimeout(() => vfx.burst(this.chestPos(tv), col, { n: 24, speed: 3 }), 250); } break;
      case 'cleave': if (tv) setTimeout(() => { vfx.ring(tv.root.position, col, 2.2, 0.4); vfx.burst(this.chestPos(tv), col, { n: 24, speed: 4, flat: true }); this.audio.sfx('slash', 0.8); }, 160); break;
      case 'wave': if (v && tv) { const a = v.root.position.clone(); const b = tv.root.position.clone(); const dir = b.clone().sub(a).setY(0).normalize(); for (let i = 1; i <= 8; i++) { const p = a.clone().add(dir.clone().multiplyScalar(i * 1.4)); setTimeout(() => { vfx.burst(p.clone().setY(0.6), col, { n: 16, speed: 3, up: 1.5, life: 0.6, size: 0.45 }); vfx.ring(p.clone().setY(0.45), col, 1.2, 0.4); }, i * 60); } this.audio.sfx('water', 0.9); this.stage.addShake(0.3); } break;
      case 'eclipse': if (tv) setTimeout(() => { vfx.sphereFlash(this.chestPos(tv), 0x2a0a4a, 1.2, 0.35); vfx.burst(this.chestPos(tv), col, { n: 30, speed: 5 }); this.audio.sfx('slash', 0.9); }, 180); break;
      case 'chain': { const ids = e.targets || []; let prev = v; ids.forEach((uid, i) => { const t = this.viewOf(uid); const p0 = prev; if (t && p0) setTimeout(() => { vfx.beam(i === 0 ? this.handPos(p0) : this.chestPos(p0), this.chestPos(t), col, 0.3, { jagged: true, width: 0.12 }); vfx.burst(this.chestPos(t), col, { n: 12, speed: 3 }); }, i * 90); prev = t || prev; }); this.audio.sfx('zap', 0.9); break; }
      case 'phoenix': if (at) { vfx.pillar(at, col, 6, 1.1, 1.2); vfx.ring(at, col, 5, 0.9); vfx.rise(at, col, { n: 50, radius: 2.4, speed: 3, life: 1.1, size: 0.4 }); this.audio.sfx('fire', 0.9); this.stage.flash(0xffb060, 0.12); } break;
      case 'devour': if (v && tv) { vfx.beam(this.chestPos(v), this.chestPos(tv), col, 0.5, { width: 0.3 }); setTimeout(() => { vfx.sphereFlash(this.chestPos(tv), col, 1.5, 0.5); vfx.burst(this.chestPos(tv), col, { n: 40, speed: 5 }); this.stage.addShake(0.4); this.audio.sfx('devour', 1); }, 300); } break;
      case 'orbital': if (tv) { const p = tv.root.position.clone(); vfx.pillar(p, col, 14, 0.7, 1.0); this.audio.sfx('beam', 1); setTimeout(() => this.stage.addShake(0.6), 320); } break;
      case 'blizzard': { this.stage.flash(0xcfefff, 0.25); const enemyRows = []; for (let c = 0; c < CELLS; c++) { const mine = (cellRow(c) < 4) === (e.team === 0); if (!mine) enemyRows.push(c); } for (let i = 0; i < 70; i++) { const c = enemyRows[(Math.random() * enemyRows.length) | 0]; const p = this.cellPos(c); setTimeout(() => vfx.burst(new THREE.Vector3(p.x + (Math.random() - 0.5), 4 + Math.random() * 2, p.z + (Math.random() - 0.5)), col, { n: 3, speed: 0.5, gravity: 6, life: 0.9, size: 0.3 }), Math.random() * 500); } this.audio.sfx('wind', 1); this.stage.addShake(0.3); break; }
      case 'spark': { const ids = e.targets || []; let prev = v; ids.forEach((uid) => { const t = this.viewOf(uid); if (t && prev) vfx.beam(this.chestPos(prev), this.chestPos(t), 0x9fe8ff, 0.2, { jagged: true, width: 0.08 }); prev = t || prev; }); this.audio.sfx('zap', 0.4); break; }
      case 'thorns': if (v) vfx.burst(this.chestPos(v), 0x9fdc6a, { n: 10, speed: 3, flat: true, life: 0.3 }); break;
      case 'sunflare': if (at) vfx.ring(at, 0xff9a40, 2.2, 0.4, { opacity: 0.5 }); break;
      case 'tide': if (at) vfx.rise(at, 0x5ff0e0, { n: 6, radius: 0.4, speed: 1.6, life: 0.6, size: 0.2 }); break;
      case 'overclock': if (v) vfx.burst(this.chestPos(v), 0xffcc66, { n: 8, speed: 2, life: 0.3, size: 0.18 }); break;
      case 'mender': if (v && tv) vfx.beam(this.chestPos(v), this.chestPos(tv), 0x7ef0c4, 0.3, { width: 0.1 }); break;
      case 'pulse': if (at) vfx.ring(at, 0x5ff0e0, 2.5, 0.5, { opacity: 0.6 }); break;
      case 'zap': if (v && tv) vfx.beam(this.chestPos(v), this.chestPos(tv), 0x9fe8ff, 0.2, { jagged: true }); break;
      case 'breath': if (v && tv) { vfx.projectile(this.chestPos(v).add(new THREE.Vector3(0, 0.4, 0)), this.chestPos(tv), { kind: 'fireball', color: 0xff8a2a, dur: 0.25 }); setTimeout(() => vfx.explosion(tv.root.position.clone().setY(0.45), 0xff8a2a, 0.9), 250); } break;
      default: break;
    }
  }

  frenzy(v, col, dur) {
    const end = performance.now() + dur * 1000;
    const tick = () => {
      if (!this.combat || v.dead || performance.now() > end) return;
      this.vfx.trail(this.chestPos(v).add(new THREE.Vector3((Math.random() - 0.5) * 0.6, Math.random() * 0.6, (Math.random() - 0.5) * 0.6)), col, 0.35, 0.4);
      requestAnimationFrame(tick);
    };
    tick();
  }

  stunStars(v, dur) {
    const end = performance.now() + dur * 1000;
    const tick = () => {
      if (v.dead || performance.now() > end || !v.root.parent) return;
      const t = performance.now() / 1000;
      const h = v.headWorld(new THREE.Vector3());
      for (let i = 0; i < 3; i++) {
        const a = t * 5 + (i * Math.PI * 2) / 3;
        this.vfx.trail(new THREE.Vector3(h.x + Math.cos(a) * 0.35, h.y - 0.25, h.z + Math.sin(a) * 0.35), 0xffe680, 0.18, 0.12);
      }
      requestAnimationFrame(tick);
    };
    tick();
  }

  damageNumber(v, amount, type, crit, ability) {
    if (this.numCount > 60) return;
    const p = v.headWorld(new THREE.Vector3()).project(this.camera);
    const x = (p.x * 0.5 + 0.5) * this.stage.width + (Math.random() - 0.5) * 30;
    const y = (-p.y * 0.5 + 0.5) * this.stage.height + 10 + (Math.random() - 0.5) * 10;
    const el = document.createElement('div');
    el.className = `dmg ${type}${crit ? ' crit' : ''}${ability ? ' ab' : ''}`;
    el.textContent = type === 'heal' ? `+${amount}` : `${amount}`;
    el.style.left = `${x}px`;
    el.style.top = `${y}px`;
    this.numLayer.appendChild(el);
    this.numCount++;
    setTimeout(() => { el.remove(); this.numCount--; }, 950);
  }

  voice(id, kind, vol = 1) {
    const now = this.audio.now();
    if (kind !== 'death' && now - this.lastVoice < 2.2) return;
    this.lastVoice = now;
    this.audio.voice(id, kind, vol);
  }

  // ───────────────────────── input ─────────────────────────
  bindInput() {
    const el = this.stage.renderer.domElement;
    el.addEventListener('pointerdown', (e) => this.onDown(e));
    window.addEventListener('pointermove', (e) => this.onMove(e));
    window.addEventListener('pointerup', (e) => this.onUp(e));
    el.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  setPointer(e) {
    const r = this.stage.renderer.domElement.getBoundingClientRect();
    this.pointer.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    this.raycaster.setFromCamera(this.pointer, this.camera);
  }

  pickView(e, includeCombat = false) {
    this.setPointer(e);
    const boxes = [];
    for (const v of this.planViews.values()) if (v.root.visible) boxes.push(v.hitbox);
    if (includeCombat) for (const v of this.combatViews.values()) if (!v.dead) boxes.push(v.hitbox);
    const hits = this.raycaster.intersectObjects(boxes, false);
    return hits.length ? hits[0].object.userData.unitView : null;
  }

  groundPoint(e) {
    this.setPointer(e);
    const p = new THREE.Vector3();
    return this.raycaster.ray.intersectPlane(this.plane, p) ? p : null;
  }

  dropTarget(p) {
    if (!p) return null;
    // bench
    for (let i = 0; i < BENCH_SIZE; i++) {
      const b = benchToWorld(i);
      if (Math.abs(p.x - b.x) < 0.8 && Math.abs(p.z - b.z) < 0.9) return { where: 'bench', index: i };
    }
    let best = -1;
    let bd = 1e9;
    for (let c = 0; c < BOARD_CELLS; c++) {
      const w = cellToWorld(c);
      const d = (w.x - p.x) ** 2 + (w.z - p.z) ** 2;
      if (d < bd) { bd = d; best = c; }
    }
    if (bd < 1.0) return { where: 'board', index: best };
    return null;
  }

  onDown(e) {
    if (e.button === 2) return;
    if (!this.match || !this.match.local.alive) return;
    const v = this.pickView(e, true);
    if (!v) { this.hud.selectUnit(null); return; }
    if (this.combatViews.has(v.uid)) { this.hud.selectCombatUnit(v.combatUnit); return; }
    const inCombat = !!this.combat;
    if (inCombat && v.where === 'board') return;
    this.drag = { view: v, startX: e.clientX, startY: e.clientY, moved: false, from: { where: v.where, index: v.index } };
    e.preventDefault();
  }

  onMove(e) {
    if (this.drag) {
      const d = this.drag;
      if (!d.moved && Math.hypot(e.clientX - d.startX, e.clientY - d.startY) > 6) {
        d.moved = true;
        d.view.dragging = true;
        this.audio.sfx('pickup', 0.5);
        if (Math.random() < 0.35) this.voice(d.view.spec.id, 'select', 0.8);
        this.hud.showSellZone(true, d.view);
      }
      if (d.moved) {
        const p = this.groundPoint(e);
        if (p) {
          d.view.root.position.set(p.x, 0.42 + 0.3, p.z);
          d.view.moveFrom = null;
        }
        this.arena.clearGlows();
        const inCombat = !!this.combat;
        if (!inCombat) for (let c = 0; c < BOARD_CELLS; c++) this.arena.setCellGlow(c, 0x7fe8ff, 0.12);
        for (let i = 0; i < BENCH_SIZE; i++) this.arena.setBenchGlow(i, 0xffd27a, 0.15);
        const t = this.dropTarget(p);
        d.target = t;
        if (t && (t.where === 'bench' || !inCombat)) {
          if (t.where === 'board') this.arena.setCellGlow(t.index, 0xffffff, 0.85);
          else this.arena.setBenchGlow(t.index, 0xffffff, 0.9);
        }
        this.hud.sellHover(this.hud.isOverSell(e.clientX, e.clientY));
      }
      return;
    }
    // hover highlight
    const v = this.pickView(e, true);
    if (v !== this.hoverView) {
      if (this.hoverView) this.hoverView.tint(0x000000, 0);
      this.hoverView = v;
      if (v && !this.combatViews.has(v.uid)) v.tint(0x2a3a4a, 1);
      this.stage.renderer.domElement.style.cursor = v ? 'pointer' : 'default';
    }
  }

  onUp(e) {
    const d = this.drag;
    if (!d) return;
    this.drag = null;
    this.arena.clearGlows();
    this.hud.showSellZone(false);
    d.view.dragging = false;
    if (!d.moved) {
      this.hud.selectUnit(d.view.uid);
      this.voice(d.view.spec.id, 'select', 0.9);
      return;
    }
    if (this.hud.isOverSell(e.clientX, e.clientY)) {
      this.match.sell(d.view.uid);
      this.audio.sfx('sell');
      return;
    }
    const t = d.target;
    let ok = false;
    if (t) ok = this.match.moveUnit(d.view.uid, t);
    if (ok) this.audio.sfx('place', 0.6);
    this.syncPlanning();
    if (!ok) {
      const pos = d.from.where === 'board' ? cellToWorld(d.from.index) : benchToWorld(d.from.index);
      d.view.moveToPos(pos.x, pos.z, 0.15);
    }
  }

  unitAtClient(x, y) {
    const v = this.pickView({ clientX: x, clientY: y }, false);
    return v;
  }

  // ───────────────────────── frame ─────────────────────────
  update(dt) {
    this.processEvents();
    const cam = this.camera;
    const W = this.stage.width;
    const H = this.stage.height;
    for (const v of this.planViews.values()) {
      v.update(dt);
      if (v.celebrateT > 0) { v.celebrateT -= dt; v.celebrate = v.celebrateT > 0; }
      const visible = v.root.visible && !v.dragging;
      v.updateBar(cam, W, H, visible);
      if (visible) v.setStats(1, 1, 0, 0, 0);
    }
    for (const v of this.combatViews.values()) {
      v.update(dt);
      const u = v.combatUnit;
      if (u) {
        const shield = this.combat ? this.combat.shieldTotal(u) : 0;
        v.setStats(u.hp, u.maxHp, shield, u.mana, u.maxMana);
      }
      v.updateBar(cam, W, H, true);
    }
  }
}
