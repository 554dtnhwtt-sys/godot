// A champion or monster on the board: model, procedural animation and overhead bar.
import * as THREE from 'three';
import { buildChampion, buildMonster } from './models.js';
import { blobShadow } from './textures.js';
import { CHAMPION_BY_ID } from '../data/champions.js';
import { MONSTERS } from '../data/world.js';
import { ITEMS } from '../data/items.js';
import { itemIconURL } from '../ui/icons.js';

const STAR_SCALE = [1, 1.1, 1.22];
let shadowTex = null;
const tmpV = new THREE.Vector3();

function ease(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
function lerpAngle(a, b, t) {
  let d = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
  if (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}

export class UnitView {
  constructor(world, spec) {
    // spec: { id, star, items, team: 'ally'|'enemy', isMonster, mon, monScale, uid }
    this.world = world;
    this.spec = spec;
    this.uid = spec.uid;
    this.isMonster = !!spec.isMonster;
    if (this.isMonster) {
      const m = MONSTERS[spec.mon];
      this.rig = buildMonster(m.look, m.tint, (m.scale || 1) * (m.look === 'shardling' ? 2.0 : 1.5) * (spec.monScale || 1));
      this.weapon = 'claw';
    } else {
      this.rig = buildChampion(spec.id);
      const ch = CHAMPION_BY_ID[spec.id];
      this.weapon = this.rig.ranged || (ch.stats.range > 1 ? 'cast' : 'melee');
    }
    this.root = new THREE.Group();
    this.root.add(this.rig.root);
    if (!shadowTex) shadowTex = blobShadow();
    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 1.3), new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, depthWrite: false }));
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.02;
    shadow.renderOrder = 1;
    this.root.add(shadow);
    this.shadow = shadow;
    // invisible hit box for picking
    const hb = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 2.4, 8), new THREE.MeshBasicMaterial({ visible: false }));
    hb.position.y = 1.2;
    hb.userData.unitView = this;
    this.root.add(hb);
    this.hitbox = hb;
    world.scene.add(this.root);
    this.facing = spec.team === 'enemy' ? Math.PI : 0;
    this.targetFacing = this.facing;
    this.pos = new THREE.Vector3();
    this.moveFrom = null;
    this.moveTo = null;
    this.moveT = 0;
    this.moveDur = 0;
    this.leap = false;
    this.anim = { kind: null, t: 0, dur: 0.4, release: 0.5 };
    this.hitT = 1;
    this.stunT = 0;
    this.dead = false;
    this.deadT = 0;
    this.celebrate = false;
    this.time = Math.random() * 10;
    this.dragging = false;
    this.hover = false;
    this.setStar(spec.star || 1);
    this.makeBar();
  }

  setStar(star) {
    this.star = star;
    const s = STAR_SCALE[Math.min(3, star) - 1];
    this.root.scale.setScalar(s);
  }

  makeBar() {
    const el = document.createElement('div');
    el.className = `ubar ${this.spec.team}`;
    el.innerHTML = `<div class="ubar-stars"></div><div class="ubar-hp"><i class="ubar-fill"></i><i class="ubar-shield"></i><i class="ubar-ticks"></i></div><div class="ubar-mana"><i></i></div><div class="ubar-items"></div>`;
    this.world.barLayer.appendChild(el);
    this.bar = el;
    this.barFill = el.querySelector('.ubar-fill');
    this.barShield = el.querySelector('.ubar-shield');
    this.barTicks = el.querySelector('.ubar-ticks');
    this.manaFill = el.querySelector('.ubar-mana i');
    this.barStars = el.querySelector('.ubar-stars');
    this.barItems = el.querySelector('.ubar-items');
    if (this.isMonster) el.querySelector('.ubar-mana').style.display = 'none';
    this.setBarStars();
    this.setItems(this.spec.items || []);
    this.lastHp = -1;
  }

  setBarStars() {
    if (this.isMonster) { this.barStars.innerHTML = ''; return; }
    const cls = ['s1', 's2', 's3'][this.star - 1];
    this.barStars.className = `ubar-stars ${cls}`;
    this.barStars.innerHTML = '<b></b>'.repeat(this.star);
  }

  setItems(items) {
    const key = items.join(',');
    if (key === this.itemKey) return;
    this.itemKey = key;
    this.barItems.innerHTML = items.map((id) => `<img src="${itemIconURL(id)}" alt="${ITEMS[id] ? ITEMS[id].name : ''}">`).join('');
  }

  setStats(hp, maxHp, shield, mana, maxMana) {
    const total = Math.max(maxHp, hp + shield);
    const hpPct = Math.max(0, hp / total) * 100;
    const shPct = Math.max(0, shield / total) * 100;
    if (Math.abs(hpPct - this.lastHp) > 0.05 || Math.abs(shPct - (this.lastSh || 0)) > 0.05) {
      this.barFill.style.width = `${hpPct}%`;
      this.barShield.style.left = `${hpPct}%`;
      this.barShield.style.width = `${shPct}%`;
      this.lastHp = hpPct;
      this.lastSh = shPct;
    }
    if (maxHp !== this.lastMax) {
      this.lastMax = maxHp;
      const seg = Math.max(2, (250 / total) * 100);
      this.barTicks.style.backgroundSize = `${seg}% 100%`;
    }
    if (maxMana > 0 && maxMana < 9000) this.manaFill.style.width = `${Math.min(100, (mana / maxMana) * 100)}%`;
  }

  placeAt(x, z, y = 0.42) {
    this.pos.set(x, y, z);
    this.root.position.copy(this.pos);
    this.moveFrom = null;
  }

  moveToPos(x, z, dur, leap = false) {
    this.moveFrom = this.root.position.clone();
    this.moveTo = new THREE.Vector3(x, 0.42, z);
    this.moveT = 0;
    this.moveDur = Math.max(0.05, dur);
    this.leap = leap;
    this.faceToward(x, z);
  }

  faceToward(x, z) {
    const dx = x - this.root.position.x;
    const dz = z - this.root.position.z;
    if (dx * dx + dz * dz < 1e-4) return;
    this.targetFacing = Math.atan2(dx, dz);
  }

  playAttack(dur, release, kind) {
    this.anim = { kind: kind || this.weapon, t: 0, dur: Math.max(0.22, dur), release };
  }
  playCast() { this.anim = { kind: 'cast', t: 0, dur: 0.7, release: 0.4 }; }
  playHit() { this.hitT = 0; this.flash(0.55); }
  flash(v) { for (const m of this.rig.bank.list) if (m.userData.flash) m.userData.flash.value = Math.max(m.userData.flash.value, v); }
  tint(color, amount) {
    for (const m of this.rig.bank.list) if (m.userData.tint) m.userData.tint.value.set(color).multiplyScalar(amount);
  }
  stun(sec) { this.stunT = Math.max(this.stunT, sec); }
  die() {
    if (this.dead) return;
    this.dead = true;
    this.deadT = 0;
    this.bar.classList.add('gone');
  }
  revive() { this.dead = false; this.deadT = 0; this.bar.classList.remove('gone'); this.rig.root.visible = true; this.setFade(0); this.rig.body.rotation.x = 0; }
  setFade(v) {
    for (const m of this.rig.bank.list) {
      if (m.userData.fade) m.userData.fade.value = v;
      else if (m.userData.basic) m.opacity = Math.min(m.opacity, 1 - v);
    }
  }

  headWorld(out = tmpV) {
    const h = (this.rig.height || 1.4) * this.root.scale.x;
    out.set(this.root.position.x, this.root.position.y + h + 0.15, this.root.position.z);
    return out;
  }

  update(dt) {
    this.time += dt;
    const t = this.time;
    const rig = this.rig;
    // Movement
    let moving = false;
    if (this.moveFrom && !this.dragging) {
      this.moveT += dt;
      const k = Math.min(1, this.moveT / this.moveDur);
      const e = this.leap ? ease(k) : k;
      this.root.position.lerpVectors(this.moveFrom, this.moveTo, e);
      if (this.leap) this.root.position.y = 0.42 + Math.sin(k * Math.PI) * 1.6;
      moving = !this.leap;
      if (k >= 1) { this.moveFrom = null; this.leap = false; }
    }
    rig.moving = moving;
    this.facing = lerpAngle(this.facing, this.targetFacing, Math.min(1, dt * 10));
    rig.root.rotation.y = this.facing;

    // Base pose
    const o = rig.o || {};
    const breathe = Math.sin(t * 2.2) * 0.02;
    rig.body.position.set(0, 0, 0);
    rig.body.rotation.set(0, 0, 0);
    if (!rig.quad) {
      rig.torso.rotation.set((o.hunch || 0) + breathe, 0, 0);
      rig.head.rotation.set(Math.sin(t * 0.7) * 0.04, Math.sin(t * 0.5) * 0.12, 0);
      rig.armL.rotation.set(-0.25 + Math.sin(t * 2.2) * 0.05, 0, -(o.armSpread ?? 0.12) - 0.05);
      rig.armR.rotation.set(-0.35 + Math.sin(t * 2.2 + 1) * 0.05, 0, (o.armSpread ?? 0.12) + 0.05);
      if (rig.legL) { rig.legL.rotation.set(0, 0, 0); rig.legR.rotation.set(0, 0, 0); }
      if (o.floating) rig.body.position.y = Math.sin(t * 1.8) * 0.05;
      else rig.body.position.y = Math.abs(Math.sin(t * 2.2)) * 0.01;
      if (this.weapon === 'bow') rig.armL.rotation.x = -0.5;
    } else {
      rig.body.position.y = Math.sin(t * 2.4) * 0.02;
      if (rig.head) rig.head.rotation.set(Math.sin(t * 1.3) * 0.08, 0, 0);
      if (rig.legs) for (const l of rig.legs) l.rotation.x = 0;
    }

    // Walking
    if (moving) {
      const w = t * 13;
      if (!rig.quad) {
        if (rig.legL) { rig.legL.rotation.x = Math.sin(w) * 0.7; rig.legR.rotation.x = -Math.sin(w) * 0.7; }
        rig.armL.rotation.x += -Math.sin(w) * 0.5;
        rig.armR.rotation.x += Math.sin(w) * 0.5;
        rig.body.position.y += Math.abs(Math.sin(w)) * 0.07;
        rig.torso.rotation.x += 0.12;
      } else if (rig.legs) {
        rig.legs.forEach((l, i) => { l.rotation.x = Math.sin(w + (i % 2 ? Math.PI : 0) + (i > 1 ? Math.PI / 2 : 0)) * 0.6; });
        rig.body.position.y += Math.abs(Math.sin(w)) * 0.06;
      }
    }
    if (this.dragging) {
      rig.body.position.y += 0.15 + Math.sin(t * 8) * 0.04;
      if (!rig.quad && rig.legL) { rig.legL.rotation.x = 0.3; rig.legR.rotation.x = -0.2; }
      if (!rig.quad) { rig.armL.rotation.z -= 0.5; rig.armR.rotation.z += 0.5; }
    }

    // Attack / cast animations
    const a = this.anim;
    if (a.kind) {
      a.t += dt;
      const p = a.t / a.dur;
      if (p >= 1) a.kind = null;
      else this.poseAction(a.kind, p, a.release);
    }
    // Hit flinch
    if (this.hitT < 1) {
      this.hitT += dt * 6;
      const k = Math.sin(Math.min(1, this.hitT) * Math.PI);
      if (!rig.quad) rig.torso.rotation.x -= k * 0.22;
      rig.body.position.z -= k * 0.05;
    }
    // Flash decay
    for (const m of rig.bank.list) if (m.userData.flash && m.userData.flash.value > 0) m.userData.flash.value = Math.max(0, m.userData.flash.value - dt * 4);
    // Stun wobble
    if (this.stunT > 0) {
      this.stunT -= dt;
      rig.body.rotation.z = Math.sin(t * 10) * 0.08;
      if (!rig.quad && rig.head) rig.head.rotation.z = Math.sin(t * 7) * 0.2;
    }
    // Celebrate
    if (this.celebrate && !this.dead) {
      const j = Math.abs(Math.sin(t * 5 + this.uid));
      rig.body.position.y += j * 0.35;
      if (!rig.quad) { rig.armL.rotation.set(-2.8, 0, -0.4); rig.armR.rotation.set(-2.8, 0, 0.4); }
    }
    // Death
    if (this.dead) {
      this.deadT += dt;
      const k = Math.min(1, this.deadT / 0.5);
      rig.body.rotation.x = -ease(k) * 1.35;
      rig.body.position.y -= ease(k) * 0.15;
      const f = Math.max(0, (this.deadT - 0.55) / 0.7);
      this.setFade(Math.min(1, f));
      this.shadow.material.opacity = 1 - Math.min(1, f);
      if (f >= 1) { rig.root.visible = false; this.root.visible = false; }
    }
    rig.update(t, dt);
  }

  poseAction(kind, p, release) {
    const rig = this.rig;
    if (rig.quad) {
      // lunge and bite
      const k = p < release ? -Math.sin((p / release) * Math.PI * 0.5) * 0.3 : Math.sin(((p - release) / (1 - release)) * Math.PI) * 0.45;
      rig.body.position.z += Math.max(0, k);
      if (rig.head) rig.head.rotation.x += k * 0.8;
      return;
    }
    const torso = rig.torso;
    if (kind === 'melee' || kind === 'claw') {
      if (p < release) {
        const k = ease(p / release);
        rig.armR.rotation.x = -0.35 - k * 2.4;
        rig.armR.rotation.z = 0.2 + k * 0.3;
        torso.rotation.y = -k * 0.45;
        rig.body.position.z -= k * 0.06;
        if (kind === 'claw') rig.armL.rotation.x = -0.35 - k * 2.0;
      } else {
        const k = Math.min(1, (p - release) / 0.18);
        const back = Math.max(0, (p - release - 0.18) / (1 - release - 0.18));
        rig.armR.rotation.x = -2.75 + ease(k) * 3.1 - back * 0.35;
        rig.armR.rotation.z = 0.5 - k * 0.4;
        torso.rotation.y = -0.45 + ease(k) * 0.85 - back * 0.4;
        torso.rotation.x += 0.18 * (1 - back);
        rig.body.position.z += 0.18 * (1 - back);
        if (kind === 'claw') rig.armL.rotation.x = -2.35 + ease(k) * 2.6;
      }
    } else if (kind === 'bow') {
      const k = p < release ? ease(p / release) : 1 - (p - release) / (1 - release);
      rig.armL.rotation.set(-1.45, 0.25, -0.1);
      rig.armR.rotation.set(-1.4 + k * 0.1, -0.6 * k, 0.3);
      torso.rotation.y = 0.35;
      if (p > release && p < release + 0.1) rig.armR.rotation.y = 0.2;
    } else if (kind === 'gun') {
      rig.armR.rotation.set(-1.5, -0.1, 0.1);
      rig.armL.rotation.set(-1.2, 0.5, -0.2);
      if (p > release) {
        const k = Math.max(0, 1 - (p - release) * 6);
        rig.armR.rotation.x -= k * 0.5;
        torso.rotation.x -= k * 0.15;
      }
    } else if (kind === 'staff') {
      const k = p < release ? ease(p / release) : 1 - ease((p - release) / (1 - release));
      rig.armR.rotation.set(-0.4 - k * 1.6, 0, 0.2 + k * 0.2);
      rig.armL.rotation.set(-0.3 - k * 0.9, 0, -0.3);
      torso.rotation.x -= k * 0.1;
    } else if (kind === 'throw') {
      if (p < release) {
        const k = ease(p / release);
        rig.armL.rotation.x = -0.3 + k * 0.9;
        torso.rotation.y = k * 0.4;
      } else {
        const k = ease(Math.min(1, (p - release) / 0.3));
        rig.armL.rotation.x = 0.6 - k * 2.6;
        torso.rotation.y = 0.4 - k * 0.7;
      }
    } else if (kind === 'cast') {
      const up = p < release ? ease(p / release) : 1 - ease((p - release) / (1 - release));
      rig.armL.rotation.set(-0.3 - up * 2.4, 0, -0.5 * up);
      rig.armR.rotation.set(-0.3 - up * 2.4, 0, 0.5 * up);
      rig.body.position.y += up * 0.18;
      torso.rotation.x -= up * 0.15;
      if (rig.head) rig.head.rotation.x -= up * 0.2;
    }
  }

  updateBar(camera, width, height, visible) {
    if (!visible || this.dead) { if (!this.dead) this.bar.style.display = 'none'; return; }
    this.headWorld(tmpV);
    tmpV.project(camera);
    if (tmpV.z > 1) { this.bar.style.display = 'none'; return; }
    const x = (tmpV.x * 0.5 + 0.5) * width;
    const y = (-tmpV.y * 0.5 + 0.5) * height;
    this.bar.style.display = '';
    this.bar.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
  }

  dispose() {
    this.world.scene.remove(this.root);
    this.bar.remove();
    this.root.traverse((o) => { if (o.material && !Array.isArray(o.material)) o.material.dispose(); });
  }
}
