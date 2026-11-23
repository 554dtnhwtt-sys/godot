// Procedural 3D models for every champion and monster.
// Each builder returns a rig (see rig.js) that the unit view animates.
import * as THREE from 'three';
import { MatBank, buildRig, eyes, mouth, mesh, group, G, rbox, lathe, tube, extrudeShape } from './rig.js';

// ───────────────────────── accessories ─────────────────────────
function hairCap(rig, mat, o = {}) {
  const r = rig.headR;
  const cap = mesh(G.sphere(r * 1.08, 28, 18), mat, [0, r * (o.lift ?? 0.12), -r * 0.08], [-(o.tilt ?? 0.25), 0, 0], [1.02, o.h ?? 0.85, 1.02]);
  // cut the front by scaling a fringe
  rig.head.add(cap);
  if (o.fringe !== false) {
    for (let i = -2; i <= 2; i++) {
      const f = mesh(G.cone(r * 0.22, r * 0.55, 8), mat, [i * r * 0.28, r * 0.5, r * 0.72], [2.2, 0, i * 0.22], 1);
      rig.head.add(f);
    }
  }
  return cap;
}

function longHair(rig, mat, len = 0.5, width = 1) {
  const r = rig.headR;
  const back = mesh(lathe([[0.001, 0], [r * 0.95 * width, -0.02], [r * 1.0 * width, -len * 0.5], [r * 0.75 * width, -len], [0.001, -len - 0.02]], 18), mat, [0, r * 0.15, -r * 0.45], [0.18, 0, 0], [1, 1, 0.55]);
  rig.head.add(back);
  return back;
}

function braid(rig, mat, side = 0, len = 0.45) {
  const r = rig.headR;
  const g = group(rig.head, [side * r * 0.7, -r * 0.1, -r * 0.6]);
  for (let i = 0; i < 6; i++) g.add(mesh(G.sphere(r * 0.2 * (1 - i * 0.08), 12, 10), mat, [side * 0.02 * i, -i * len / 6, -i * 0.03]));
  return g;
}

function ears(rig, mat, type, inner) {
  const r = rig.headR;
  const out = [];
  for (const s of [-1, 1]) {
    let e;
    if (type === 'fox' || type === 'wolf') {
      e = group(rig.head, [s * r * 0.55, r * 0.75, -r * 0.05], [0, 0, -s * 0.35]);
      e.add(mesh(G.cone(r * 0.32, r * 0.85, 4), mat, [0, r * 0.3, 0], [0, Math.PI / 4, 0], [1, 1, 0.45]));
      if (inner) e.add(mesh(G.cone(r * 0.2, r * 0.6, 4), inner, [0, r * 0.25, r * 0.06], [0, Math.PI / 4, 0], [1, 1, 0.3]));
    } else if (type === 'fin') {
      e = mesh(extrudeShape([[0, 0], [0.18, 0.1], [0.22, -0.02], [0.15, -0.08], [0.05, -0.05]], 0.02, 0.01), mat, [s * r * 0.95, 0, 0], [0, s > 0 ? 0 : Math.PI, 0.2], 1);
      rig.head.add(e);
    } else if (type === 'elf') {
      e = mesh(G.cone(r * 0.14, r * 0.7, 6), mat, [s * r * 0.98, r * 0.05, -r * 0.05], [0, 0, -s * 1.25]);
      rig.head.add(e);
    }
    out.push(e);
  }
  return out;
}

function beard(rig, mat, o = {}) {
  const r = rig.headR;
  const g = group(rig.head, [0, -r * 0.35, r * 0.45]);
  g.add(mesh(G.sphere(r * 0.62, 20, 16), mat, [0, -r * 0.18, 0], [0.2, 0, 0], [1.15, 1.0, 0.75]));
  if (o.braid) {
    for (let i = 0; i < 4; i++) g.add(mesh(G.sphere(r * 0.2 * (1 - i * 0.12), 10, 8), mat, [0, -r * (0.75 + i * 0.28), r * 0.12], [0, 0, 0]));
    if (o.ring) g.add(mesh(G.torus(r * 0.16, r * 0.05, 6, 14), o.ring, [0, -r * 1.05, r * 0.12], [Math.PI / 2, 0, 0]));
  }
  if (o.moustache !== false) {
    for (const s of [-1, 1]) g.add(mesh(G.capsule(r * 0.09, r * 0.35, 6), mat, [s * r * 0.24, r * 0.02, r * 0.38], [0, 0, s * 1.2]));
  }
  return g;
}

function nose(rig, mat, size = 0.13) {
  const r = rig.headR;
  rig.head.add(mesh(G.sphere(r * size, 12, 10), mat, [0, -r * 0.18, r * 0.98]));
}

function shoulderPads(rig, mat, size = 1, spikes = null) {
  const out = [];
  for (const [arm, s] of [[rig.armL, -1], [rig.armR, 1]]) {
    const p = mesh(G.dome(0.13 * size, 18, 12, Math.PI / 2), mat, [s * 0.01, 0.02, 0], [0, 0, 0], [1.15, 0.85, 1.1]);
    arm.add(p);
    if (spikes) arm.add(mesh(G.cone(0.04 * size, 0.16 * size, 6), spikes, [s * 0.05, 0.12 * size, 0], [0, 0, -s * 0.5]));
    out.push(p);
  }
  return out;
}

function belt(rig, mat, buckle) {
  const w = rig.o.torsoW ?? 0.3;
  const b = rig.o.bulk ?? 1;
  rig.torso.add(mesh(G.torus(w * 0.92 * b, 0.035, 6, 28), mat, [0, 0.06, 0], [Math.PI / 2, 0, 0], [1, 0.82, 1]));
  if (buckle) rig.torso.add(mesh(rbox(0.09, 0.07, 0.03, 0.01), buckle, [0, 0.06, w * 0.78 * b]));
}

function cape(rig, mat, len = 0.7, width = 0.55, o = {}) {
  const geo = new THREE.PlaneGeometry(width, len, 6, 8);
  geo.translate(0, -len / 2, 0);
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const y = pos.getY(i);
    pos.setZ(i, -Math.abs(x) * 0.25 + y * 0.12);
    if (o.tattered && y < -len * 0.75) pos.setY(i, y + Math.sin(x * 40) * 0.05);
  }
  geo.computeVertexNormals();
  mat.side = THREE.DoubleSide;
  const c = mesh(geo, mat, [0, 0.05, -0.02], [0.12, 0, 0]);
  rig.back.add(c);
  rig.anim.push((t) => { c.rotation.x = 0.14 + Math.sin(t * 2.2) * 0.05 + (rig.moving ? 0.25 : 0); });
  return c;
}

function tail(rig, mat, tip, o = {}) {
  const g = group(rig.hips, [0, 0.0, -(rig.o.torsoW ?? 0.3) * 0.7]);
  const n = o.segments ?? 6;
  const segs = [];
  let parent = g;
  for (let i = 0; i < n; i++) {
    const sg = group(parent, [0, 0.02, -0.07], [i === 0 ? -0.6 : 0.18, 0, 0]);
    const s = (o.size ?? 0.09) * (o.bushy ? 1 + Math.sin((i / n) * Math.PI) * 0.9 : 1 - i * 0.08);
    sg.add(mesh(G.sphere(s, 12, 10), i >= n - 2 && tip ? tip : mat, [0, 0, -0.04], [0, 0, 0], [1, 1, 1.4]));
    segs.push(sg);
    parent = sg;
  }
  rig.anim.push((t) => { segs.forEach((s, i) => { s.rotation.y = Math.sin(t * 2.4 - i * 0.6) * 0.18; }); });
  return g;
}

// ───────── weapons ─────────
function hammer(bank, headMat, handleMat, size = 1) {
  const w = new THREE.Group();
  w.add(mesh(G.cyl(0.03 * size, 0.035 * size, 0.62 * size, 8), handleMat, [0, 0.25 * size, 0]));
  w.add(mesh(rbox(0.26 * size, 0.16 * size, 0.16 * size, 0.03), headMat, [0, 0.58 * size, 0]));
  w.add(mesh(G.cyl(0.07 * size, 0.07 * size, 0.04 * size, 12), headMat, [0.14 * size, 0.58 * size, 0], [0, 0, Math.PI / 2]));
  return w;
}

function blade(bank, mat, len = 0.6, width = 0.07, o = {}) {
  const w = new THREE.Group();
  const grip = o.grip || bank.std(0x3a2a20, { rough: 0.8 });
  w.add(mesh(G.cyl(0.022, 0.022, 0.16, 8), grip, [0, 0.0, 0]));
  w.add(mesh(rbox(width * 2.6, 0.035, 0.05, 0.012), o.guard || bank.metal(0xd8b060), [0, 0.09, 0]));
  const shape = [[-width, 0], [width, 0], [width * 0.9, len * 0.8], [0, len], [-width * 0.9, len * 0.8]];
  w.add(mesh(extrudeShape(shape, 0.02, 0.012), mat, [0, 0.1, 0]));
  return w;
}

function axe(bank, headMat, handleMat) {
  const w = new THREE.Group();
  w.add(mesh(G.cyl(0.025, 0.03, 0.55, 8), handleMat, [0, 0.2, 0]));
  w.add(mesh(extrudeShape([[0, 0.05], [0.2, 0.14], [0.24, 0], [0.2, -0.14], [0, -0.05]], 0.03, 0.012), headMat, [0.02, 0.42, 0]));
  w.add(mesh(G.cone(0.03, 0.1, 6), headMat, [-0.04, 0.42, 0], [0, 0, Math.PI / 2]));
  return w;
}

function staff(bank, shaftMat, len = 1.0) {
  const w = new THREE.Group();
  w.add(mesh(G.cyl(0.025, 0.03, len, 8), shaftMat, [0, len * 0.35, 0]));
  w.userData.top = len * 0.85;
  return w;
}

function bow(bank, mat, stringMat, size = 1) {
  const w = new THREE.Group();
  const curve = [];
  for (let i = 0; i <= 8; i++) {
    const t = i / 8 - 0.5;
    curve.push([Math.cos(t * 2.4) * 0.18 * size - 0.18 * size, t * 0.95 * size, 0]);
  }
  w.add(mesh(tube(curve, 0.022 * size, 20, 6), mat));
  w.add(mesh(G.cyl(0.004, 0.004, 0.88 * size, 4), stringMat, [-0.255 * size, 0, 0]));
  return w;
}

function spear(bank, shaftMat, tipMat, len = 1.3) {
  const w = new THREE.Group();
  w.add(mesh(G.cyl(0.022, 0.022, len, 8), shaftMat, [0, len * 0.3, 0]));
  w.add(mesh(G.cone(0.05, 0.2, 6), tipMat, [0, len * 0.8 + 0.08, 0]));
  return w;
}

function orb(bank, color, r = 0.08) {
  const m = mesh(G.sphere(r, 16, 12), bank.glow(color, 3));
  return m;
}

// Attach a weapon group to a hand. rx tilts it forward.
function hold(hand, weapon, rx = Math.PI / 2, ry = 0, rz = 0, offset = [0, 0, 0]) {
  weapon.rotation.set(rx, ry, rz);
  weapon.position.set(...offset);
  hand.add(weapon);
  return weapon;
}

function flameTongues(rig, parent, colors, n = 7, spread = 0.18, height = 0.3, pos = [0, 0, 0]) {
  const g = group(parent, pos);
  const tongues = [];
  for (let i = 0; i < n; i++) {
    const m = mesh(G.cone(0.06 + (i % 3) * 0.02, height * (0.6 + (i % 4) * 0.2), 8), rig.bank.glow(colors[i % colors.length], 2.6), [Math.cos(i * 2.4) * spread, 0, Math.sin(i * 2.4) * spread], [0, 0, 0]);
    g.add(m);
    tongues.push({ m, ph: i * 1.3, base: m.position.clone() });
  }
  rig.anim.push((t) => { for (const f of tongues) { const k = 1 + Math.sin(t * 9 + f.ph) * 0.18; f.m.scale.set(1, k, 1); f.m.rotation.z = Math.sin(t * 6 + f.ph) * 0.15; } });
  return g;
}

function floaty(rig, obj, amp = 0.05, speed = 2) {
  const y0 = obj.position.y;
  const ph = Math.random() * 6;
  rig.anim.push((t) => { obj.position.y = y0 + Math.sin(t * speed + ph) * amp; });
}

function spinner(rig, obj, speed = 2, axis = 'y') {
  rig.anim.push((t, dt) => { obj.rotation[axis] += speed * dt; });
}

// ───────────────────────── champions ─────────────────────────
const B = {};

B.brakka = (bank) => {
  const brass = bank.metal(0xc89040, 0.35);
  const rig = buildRig(bank, { skin: 0xe9a77e, top: 0x8a5a34, legs: 0x3a2a22, boots: 0x2a1c16, torsoW: 0.36, torsoH: 0.4, bulk: 1.18, legLen: 0.3, headR: 0.3, armR: 0.085, armLen: 0.3, handScale: 1.45, handMat: bank.std(0x2c2622, { rough: 0.6, emissive: 0xff5a1a, ei: 0.25 }) });
  eyes(rig, '#3a2414', { brows: 0xc8582a, angry: true, size: 0.28 });
  nose(rig, rig.skinMat, 0.16);
  beard(rig, bank.std(0xe0682a, { rough: 0.85 }), { braid: true, ring: brass });
  rig.torso.add(mesh(rbox(0.5, 0.42, 0.06, 0.03), bank.std(0x221c1a, { rough: 0.9 }), [0, 0.16, 0.27], [0.08, 0, 0]));
  shoulderPads(rig, brass, 1.35);
  belt(rig, bank.std(0x3a2618), brass);
  for (const hand of [rig.handL, rig.handR]) hand.add(mesh(G.torus(0.09, 0.03, 6, 14), bank.glow(0xff6a1a, 1.4), [0, 0.05, 0], [Math.PI / 2, 0, 0]));
  hold(rig.handR, hammer(bank, bank.metal(0x5a5a64, 0.4), bank.std(0x6a4428)), 0.5, 0, 0, [0, -0.02, 0.02]);
  // Anvil shield
  const anvil = new THREE.Group();
  anvil.add(mesh(rbox(0.42, 0.18, 0.2, 0.03), bank.metal(0x4a4a54, 0.45), [0, 0.1, 0]));
  anvil.add(mesh(rbox(0.22, 0.12, 0.16, 0.02), bank.metal(0x3a3a44, 0.45), [0, -0.03, 0]));
  anvil.add(mesh(G.cone(0.08, 0.2, 8), bank.metal(0x4a4a54, 0.45), [0.28, 0.12, 0], [0, 0, -Math.PI / 2]));
  anvil.add(mesh(rbox(0.12, 0.02, 0.12, 0.005), bank.glow(0xff7a2a, 1.5), [0, 0.2, 0]));
  hold(rig.handL, anvil, 0, Math.PI / 2, 0, [-0.08, -0.02, 0.08]);
  return rig;
};

B.marlo = (bank) => {
  const rig = buildRig(bank, { skin: 0x4fb3ad, top: 0x5a8a3a, legs: 0x2d5a6a, boots: 0x2d5a6a, torsoW: 0.27, torsoH: 0.38, legLen: 0.42, headR: 0.27 });
  eyes(rig, '#1a4a6a', { brows: 0x1e3f7a });
  mouth(rig, { color: 0x2a3a4a });
  const hair = bank.std(0x1e3f8a, { rough: 0.7 });
  hairCap(rig, hair, { h: 0.9 });
  for (let i = 0; i < 6; i++) rig.head.add(mesh(G.cone(0.05, 0.16, 6), hair, [Math.cos(i) * 0.18, rig.headR * 0.95, Math.sin(i * 2) * 0.12], [Math.sin(i) * 0.6, 0, Math.cos(i) * 0.5]));
  ears(rig, bank.std(0x3a9a96, { rough: 0.5 }), 'fin');
  rig.torso.add(mesh(G.torus(0.25, 0.04, 6, 24), bank.std(0x6a9a3a, { rough: 0.8 }), [0, 0.18, 0], [Math.PI / 2 + 0.2, 0, 0.3], [1, 0.85, 1]));
  const coral = bank.std(0xff8a5a, { rough: 0.5 });
  for (const arm of [rig.armL, rig.armR]) arm.add(mesh(G.cyl(0.085, 0.09, 0.14, 10), coral, [0, -0.26, 0]));
  hold(rig.handR, spear(bank, bank.metal(0x9aa8b0, 0.35), bank.metal(0xdce6ee, 0.25), 1.35), Math.PI / 2 - 0.1, 0, 0, [0, 0, -0.1]);
  return rig;
};

B.fennick = (bank) => {
  const rig = buildRig(bank, { skin: 0xf2c6a4, top: 0x3f7a3a, legs: 0x6a4a2a, boots: 0x4a3020, torsoW: 0.26, torsoH: 0.38, legLen: 0.42, headR: 0.27 });
  eyes(rig, '#8a5a14', { brows: 0xc8581a, blush: true });
  mouth(rig, { color: 0x8a3a2a });
  const hair = bank.std(0xe0702a, { rough: 0.75 });
  hairCap(rig, hair, { h: 0.88 });
  ears(rig, hair, 'fox', bank.std(0xfff0e0));
  // Hood down on shoulders
  rig.torso.add(mesh(G.torus(0.22, 0.07, 8, 20), bank.cloth(0x356a32), [0, 0.42, -0.04], [Math.PI / 2 - 0.3, 0, 0]));
  cape(rig, bank.cloth(0x2f6a2c), 0.62, 0.5);
  tail(rig, hair, bank.std(0xfff4ea), { bushy: true, size: 0.08, segments: 6 });
  belt(rig, bank.std(0x5a3a22), bank.metal(0xc8a060));
  const b = bow(bank, bank.std(0x8a5a32, { rough: 0.6 }), bank.basic(0xf0e8d0), 1.0);
  for (let i = 0; i < 4; i++) b.add(mesh(G.sphere(0.03, 8, 6), bank.std(i % 2 ? 0xff9ac8 : 0xfff2a0, { emissive: 0x332200 }), [-0.3 + Math.cos(i) * 0.02, -0.35 + i * 0.22, 0.02]));
  hold(rig.handL, b, 0, Math.PI / 2, 0, [0, 0, 0.05]);
  rig.ranged = 'bow';
  return rig;
};

B.skitter = (bank) => {
  const body = bank.std(0x2a1840, { rough: 0.25, metal: 0.3, rimColor: 0xb070ff, rim: 0.7 });
  const rig = buildRig(bank, { skinMat: body, topMat: body, legsMat: body, bootsMat: body, torsoW: 0.24, torsoH: 0.3, legLen: 0.3, headR: 0.32, armLen: 0.34, armR: 0.06, handScale: 1.1, hunch: 0.3 });
  eyes(rig, '#c070ff', { glow: true, count: 4, size: 0.22, spread: 0.3 });
  const grin = mesh(G.torus(rig.headR * 0.42, 0.018, 6, 20, Math.PI), bank.glow(0xd8a0ff, 1.6), [0, -rig.headR * 0.38, rig.headR * 0.86], [0, 0, Math.PI]);
  rig.head.add(grin);
  for (const s of [-1, 1]) rig.head.add(mesh(tube([[0, 0, 0], [s * 0.08, 0.12, -0.02], [s * 0.04, 0.22, -0.08]], 0.03, 10, 6), bank.std(0x5a3a7a, { rough: 0.4 }), [s * 0.16, rig.headR * 0.65, 0]));
  const clawM = bank.std(0xd8c8ff, { rough: 0.2, emissive: 0x7a3aff, ei: 0.6 });
  for (const hand of [rig.handL, rig.handR]) for (let i = -1; i <= 1; i++) hand.add(mesh(G.cone(0.025, 0.2, 6), clawM, [i * 0.04, -0.08, 0.06], [0.6, 0, i * 0.2]));
  // Void wisps
  const wisp = bank.basic(0xa060ff, { add: true, opacity: 0.5 });
  const wisps = [];
  for (let i = 0; i < 5; i++) { const m = mesh(G.sphere(0.06, 8, 6), wisp, [(i - 2) * 0.06, 0.1, -0.05]); rig.back.add(m); wisps.push(m); }
  rig.anim.push((t) => wisps.forEach((m, i) => { const k = (t * 0.8 + i * 0.2) % 1; m.position.y = 0.1 + k * 0.45; m.scale.setScalar(1.2 - k); }));
  return rig;
};

B.pim = (bank) => {
  const rig = buildRig(bank, { skin: 0xf2c4a4, top: 0x7a5030, legs: 0x4a3a2a, boots: 0x3a2618, torsoW: 0.24, torsoH: 0.3, legLen: 0.26, headR: 0.31, armLen: 0.26 });
  eyes(rig, '#2a4a6a', { brows: 0xffffff, size: 0.3 });
  nose(rig, bank.std(0xff8a7a, { rough: 0.5 }), 0.2);
  const hair = bank.std(0xe4e4ea, { rough: 0.9 });
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * Math.PI * 2;
    rig.head.add(mesh(G.sphere(0.1, 10, 8), hair, [Math.cos(a) * 0.24, 0.14 + Math.sin(i * 3) * 0.05, Math.sin(a) * 0.22 - 0.06]));
  }
  beard(rig, hair, { moustache: true });
  // Goggles on the forehead
  const gogM = bank.metal(0xb88a3a, 0.3);
  for (const s of [-1, 1]) {
    rig.head.add(mesh(G.torus(0.075, 0.025, 8, 16), gogM, [s * 0.11, rig.headR * 0.55, rig.headR * 0.76], [-0.6, 0, 0]));
    rig.head.add(mesh(G.sphere(0.068, 12, 8), bank.std(0x6ad8ff, { rough: 0.1, emissive: 0x1a5a7a, ei: 1 }), [s * 0.11, rig.headR * 0.55, rig.headR * 0.74], [0, 0, 0], [1, 1, 0.35]));
  }
  // Backpack with tesla coil
  const pack = mesh(rbox(0.3, 0.32, 0.18, 0.04), bank.metal(0xb86a3a, 0.4), [0, -0.05, 0.02]);
  rig.back.add(pack);
  rig.back.add(mesh(G.cyl(0.03, 0.03, 0.3, 8), gogM, [0.08, 0.22, 0]));
  const coil = mesh(G.sphere(0.07, 12, 10), bank.glow(0x7ae8ff, 3), [0.08, 0.4, 0]);
  rig.back.add(coil);
  rig.anim.push((t) => { coil.scale.setScalar(1 + Math.sin(t * 20) * 0.12); });
  // Wrench and bomb
  const wrench = new THREE.Group();
  wrench.add(mesh(G.cyl(0.025, 0.025, 0.4, 8), bank.metal(0x9aa0a8), [0, 0.15, 0]));
  wrench.add(mesh(G.torus(0.07, 0.03, 6, 12, Math.PI * 1.4), bank.metal(0x9aa0a8), [0, 0.38, 0], [0, 0, 0.9]));
  hold(rig.handR, wrench, Math.PI / 2 - 0.3);
  const bomb = new THREE.Group();
  bomb.add(mesh(G.sphere(0.11, 14, 10), bank.std(0x2a2a34, { rough: 0.4, metal: 0.4 })));
  const spark = mesh(G.sphere(0.035, 8, 6), bank.glow(0x7ae8ff, 4), [0, 0.15, 0]);
  bomb.add(spark);
  rig.anim.push((t) => spark.scale.setScalar(0.8 + Math.random() * 0.6));
  hold(rig.handL, bomb, 0, 0, 0, [0, -0.06, 0.06]);
  rig.ranged = 'throw';
  return rig;
};

B.snorri = (bank) => {
  const fur = bank.std(0xc2cad6, { rough: 0.95, rimColor: 0xbfe6ff, rim: 0.25 });
  const rig = buildRig(bank, { skinMat: fur, topMat: fur, legsMat: fur, bootsMat: fur, torsoW: 0.36, torsoH: 0.42, bulk: 1.15, legLen: 0.3, headR: 0.3, armLen: 0.34, armR: 0.11, handScale: 1.7, hunch: 0.12 });
  // Blue face
  rig.head.add(mesh(G.sphere(rig.headR * 0.78, 24, 16), bank.std(0x7ab8e8, { rough: 0.6 }), [0, -rig.headR * 0.08, rig.headR * 0.32], [0, 0, 0], [1, 0.9, 0.8]));
  eyes(rig, '#1a2a4a', { size: 0.26, spread: 0.3, y: 0.02 });
  mouth(rig, { open: true, color: 0x2a1a3a });
  // Fur tufts
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    rig.torso.add(mesh(G.sphere(0.12, 10, 8), fur, [Math.cos(a) * 0.36, 0.25 + Math.sin(i * 7) * 0.12, Math.sin(a) * 0.3]));
  }
  // Bone helmet with horns
  const bone = bank.std(0xe8dcc0, { rough: 0.7 });
  rig.head.add(mesh(G.dome(rig.headR * 1.04, 24, 12, Math.PI / 2.4), bone, [0, rig.headR * 0.1, -0.02]));
  for (const s of [-1, 1]) rig.head.add(mesh(tube([[0, 0, 0], [s * 0.12, 0.08, 0], [s * 0.16, 0.22, -0.04]], 0.04, 10, 6), bone, [s * rig.headR * 0.7, rig.headR * 0.5, 0]));
  const strap = bank.std(0x7a5030, { rough: 0.8 });
  for (const hand of [rig.handL, rig.handR]) hand.add(mesh(G.torus(0.13, 0.035, 6, 14), strap, [0, 0.04, 0], [Math.PI / 2, 0, 0]));
  const ice = bank.std(0xcff0ff, { rough: 0.1, emissive: 0x5ab0e0, ei: 0.5 });
  for (let i = 0; i < 4; i++) rig.torso.add(mesh(G.cone(0.025, 0.1, 5), ice, [(i - 1.5) * 0.12, 0.05, 0.3], [Math.PI, 0, 0]));
  return rig;
};

B.pyra = (bank) => {
  const robe = bank.cloth(0xa81e2a);
  const rig = buildRig(bank, { skin: 0xf2c0a0, topMat: robe, legs: 0x5a1218, boots: 0x2a1418, torsoW: 0.25, torsoH: 0.38, legLen: 0.42, headR: 0.27, skirt: 0xa81e2a, skirtLen: 0.36, skirtFlare: 1.5, skirtTrim: 0xe8b04a });
  eyes(rig, '#e0a020', { brows: 0xff7a1a, angry: true });
  mouth(rig, { color: 0x8a2a2a });
  flameTongues(rig, rig.head, [0xff8a1a, 0xffc040, 0xff4a1a], 11, 0.15, 0.42, [0, rig.headR * 0.62, -0.06]);
  hairCap(rig, bank.glow(0xff7a1a, 1.4), { h: 0.85, fringe: true });
  const obs = bank.std(0x1c1820, { rough: 0.2, metal: 0.6 });
  shoulderPads(rig, obs, 1.1, bank.glow(0xff7a1a, 1.2));
  belt(rig, bank.metal(0xe0b040), bank.glow(0xff9a30, 1.5));
  const fire = orb(bank, 0xff8a2a, 0.11);
  rig.handR.add(fire);
  fire.position.set(0, 0.05, 0.08);
  flameTongues(rig, rig.handR, [0xffc040, 0xff6a1a], 5, 0.05, 0.2, [0, 0.12, 0.08]);
  rig.ranged = 'cast';
  return rig;
};

B.nerissa = (bank) => {
  const gown = bank.std(0x1f9a96, { rough: 0.5, metal: 0.15 });
  const rig = buildRig(bank, { skin: 0xf0e2d6, topMat: gown, torsoW: 0.24, torsoH: 0.38, headR: 0.27, floating: true, floatY: 0.62, skirt: 0x1f8a8a, skirtLen: 0.62, skirtFlare: 1.5, skirtTrim: 0xf4ecd8 });
  eyes(rig, '#1a8a7a', { blush: true });
  mouth(rig, { color: 0x9a4a5a });
  const hair = bank.std(0x3fc8a0, { rough: 0.5 });
  hairCap(rig, hair, { h: 0.95 });
  longHair(rig, hair, 0.75, 1.2);
  const pearl = bank.std(0xfff8f0, { rough: 0.15, metal: 0.2 });
  for (let i = 0; i < 6; i++) rig.head.add(mesh(G.sphere(0.025, 8, 6), pearl, [Math.cos(i * 1.1) * 0.2, 0.2 - i * 0.03, -0.16]));
  ears(rig, bank.std(0x6ae0c8), 'fin');
  const st = staff(bank, bank.std(0xe8dcc8, { rough: 0.4 }), 1.0);
  const conch = mesh(G.cone(0.1, 0.24, 12), bank.std(0xffd8c8, { rough: 0.3, emissive: 0x6af0e0, ei: 0.5 }), [0, 0.92, 0], [0.4, 0, 0]);
  st.add(conch);
  st.add(mesh(G.sphere(0.06, 10, 8), bank.glow(0x7affe8, 2.5), [0, 0.86, 0.04]));
  hold(rig.handR, st, 0.15, 0, 0, [0, 0, 0.04]);
  rig.ranged = 'staff';
  return rig;
};

B.bramblehide = (bank) => {
  const fur = bank.std(0x6a4630, { rough: 0.95 });
  const rig = buildRig(bank, { skinMat: fur, topMat: fur, legsMat: fur, bootsMat: bank.std(0x2a1a14), torsoW: 0.4, torsoH: 0.46, bulk: 1.2, legLen: 0.32, headR: 0.3, armLen: 0.36, armR: 0.11, handScale: 1.4, hunch: 0.35 });
  rig.head.add(mesh(G.cyl(0.13, 0.17, 0.22, 12), bank.std(0x8a5a44, { rough: 0.8 }), [0, -0.08, 0.27], [Math.PI / 2, 0, 0]));
  rig.head.add(mesh(G.cyl(0.13, 0.13, 0.02, 12), bank.std(0x4a2a24), [0, -0.08, 0.385], [Math.PI / 2, 0, 0]));
  eyes(rig, '#6aff6a', { glow: true, size: 0.16, spread: 0.36, y: 0.12 });
  const tusk = bank.std(0xf4ead0, { rough: 0.4 });
  for (const s of [-1, 1]) rig.head.add(mesh(tube([[0, 0, 0], [s * 0.04, 0.06, 0.04], [s * 0.02, 0.16, 0.02]], 0.022, 8, 6), tusk, [s * 0.1, -0.16, 0.34]));
  ears(rig, fur, 'wolf');
  // Mossy back with brambles and flowers
  const moss = bank.std(0x4a8a3a, { rough: 1 });
  rig.torso.add(mesh(G.dome(0.4, 18, 12, Math.PI / 2), moss, [0, 0.4, -0.12], [-0.5, 0, 0], [1.1, 0.7, 1]));
  const thorn = bank.std(0x3a2a1a);
  for (let i = 0; i < 10; i++) rig.torso.add(mesh(G.cone(0.025, 0.14, 5), thorn, [Math.cos(i * 2.3) * 0.28, 0.55 + Math.sin(i * 1.7) * 0.1, -0.2 + Math.sin(i) * 0.15], [-0.8 + Math.sin(i) * 0.3, 0, Math.cos(i * 2.3) * 0.5]));
  for (let i = 0; i < 6; i++) rig.torso.add(mesh(G.sphere(0.04, 8, 6), bank.std(i % 2 ? 0xff9ac8 : 0xfff0f8, { emissive: 0x220011 }), [Math.cos(i * 1.9) * 0.25, 0.6 + Math.sin(i * 2.1) * 0.08, -0.1 + Math.sin(i * 3) * 0.12]));
  shoulderPads(rig, bank.std(0x8a6a42, { rough: 0.8 }), 1.5);
  return rig;
};

B.rivet = (bank) => {
  const brass = bank.metal(0xc89a48, 0.28);
  const dark = bank.metal(0x5a4a3a, 0.5);
  const rig = buildRig(bank, { skinMat: brass, topMat: brass, legsMat: dark, bootsMat: brass, torsoW: 0.24, torsoH: 0.4, legLen: 0.44, legR: 0.06, headR: 0.22, armLen: 0.36, armR: 0.055, handMat: dark, hunch: 0.2 });
  rig.headMesh.scale.set(1, 0.9, 1.05);
  const eye = mesh(G.sphere(0.075, 16, 12), bank.glow(0x6af0ff, 3.5), [0, 0.01, rig.headR * 0.92], [0, 0, 0], [1, 1, 0.5]);
  rig.head.add(eye);
  rig.head.add(mesh(G.torus(0.085, 0.018, 8, 20), dark, [0, 0.01, rig.headR * 0.9]));
  // Chest gear
  const gear = new THREE.Group();
  gear.add(mesh(G.cyl(0.1, 0.1, 0.03, 12), bank.metal(0xe0b860, 0.25), [0, 0, 0], [Math.PI / 2, 0, 0]));
  for (let i = 0; i < 8; i++) gear.add(mesh(G.box(0.04, 0.04, 0.03), bank.metal(0xe0b860, 0.25), [Math.cos(i * Math.PI / 4) * 0.11, Math.sin(i * Math.PI / 4) * 0.11, 0], [0, 0, i * Math.PI / 4]));
  gear.add(mesh(G.sphere(0.035, 10, 8), bank.glow(0x6af0ff, 2.5), [0, 0, 0.02]));
  gear.position.set(0, 0.28, 0.2);
  rig.torso.add(gear);
  spinner(rig, gear, 2.5, 'z');
  for (const s of [-1, 1]) rig.torso.add(mesh(G.cyl(0.03, 0.04, 0.1, 8), dark, [s * 0.15, 0.48, -0.1]));
  // Saw blades on both forearms
  for (const hand of [rig.handL, rig.handR]) {
    const saw = new THREE.Group();
    saw.add(mesh(G.cyl(0.16, 0.16, 0.012, 24), bank.metal(0xd8dce4, 0.2)));
    for (let i = 0; i < 12; i++) saw.add(mesh(G.cone(0.025, 0.06, 4), bank.metal(0xd8dce4, 0.2), [Math.cos(i * Math.PI / 6) * 0.17, 0, Math.sin(i * Math.PI / 6) * 0.17], [0, -i * Math.PI / 6, Math.PI / 2]));
    saw.position.set(0, -0.05, 0.08);
    saw.rotation.z = Math.PI / 2;
    hand.add(saw);
    spinner(rig, saw, 9, 'y');
  }
  return rig;
};

B.isolde = (bank) => {
  const armor = bank.metal(0xa8cce8, 0.35);
  const rig = buildRig(bank, { skin: 0xf6e4da, topMat: armor, legs: 0x6a8aa8, boots: 0xe8eef4, torsoW: 0.25, torsoH: 0.38, legLen: 0.44, headR: 0.27 });
  eyes(rig, '#5ab0e8', { brows: 0xe8eef4 });
  mouth(rig, { color: 0x9a6a7a });
  const hair = bank.std(0xdfe2e8, { rough: 0.6 });
  hairCap(rig, hair, { h: 0.9 });
  braid(rig, hair, 0, 0.5);
  rig.torso.add(mesh(G.torus(0.22, 0.08, 10, 22), bank.std(0xdedad4, { rough: 1 }), [0, 0.42, 0], [Math.PI / 2, 0, 0]));
  cape(rig, bank.cloth(0x7aa8d0), 0.55, 0.45);
  const iceM = bank.std(0xd8f4ff, { rough: 0.05, emissive: 0x7ad8ff, ei: 1.4, transparent: true, opacity: 0.88 });
  const b = bow(bank, iceM, bank.basic(0xe0f8ff), 1.1);
  hold(rig.handL, b, 0, Math.PI / 2, 0, [0, 0, 0.05]);
  rig.ranged = 'bow';
  return rig;
};

B.kaldor = (bank) => {
  const rig = buildRig(bank, { skin: 0xd08860, top: 0x4a4a54, legs: 0x3a3a40, boots: 0x2a1e18, torsoW: 0.34, torsoH: 0.44, bulk: 1.15, legLen: 0.4, headR: 0.27, armR: 0.095, armLen: 0.36, armMat: bank.std(0xd08860, { rough: 0.5, emissive: 0x000000 }) });
  eyes(rig, '#3a1a0a', { brows: 0x1a1210, angry: true });
  beard(rig, bank.std(0x1a1412, { rough: 0.9 }), { braid: true });
  // Rune tattoos on the arms
  const rune = bank.glow(0xff6a1a, 2.2);
  for (const arm of [rig.armL, rig.armR]) for (let i = 0; i < 3; i++) arm.add(mesh(G.torus(0.098, 0.012, 4, 16), rune, [0, -0.1 - i * 0.07, 0], [Math.PI / 2, 0, i * 0.4]));
  const iron = bank.metal(0x3c3c46, 0.45);
  rig.head.add(mesh(G.dome(rig.headR * 1.06, 24, 12, Math.PI / 2.1), iron, [0, rig.headR * 0.08, 0]));
  for (const s of [-1, 1]) rig.head.add(mesh(tube([[0, 0, 0], [s * 0.14, 0.06, 0], [s * 0.2, 0.2, 0.04]], 0.035, 10, 6), bank.std(0xe8dcc0, { rough: 0.5 }), [s * rig.headR * 0.85, rig.headR * 0.35, 0]));
  rig.torso.add(mesh(lathe([[0.001, -0.02], [0.4, -0.02], [0.36, 0.14], [0.001, 0.16]], 20), bank.metal(0x6a6a74, 0.5), [0, -0.06, 0]));
  shoulderPads(rig, iron, 1.2, bank.metal(0xd8d0c0, 0.4));
  for (const hand of [rig.handL, rig.handR]) {
    const ax = axe(bank, bank.metal(0x3a3a44, 0.35), bank.std(0x5a3a22));
    flameTongues(rig, ax, [0xff7a1a, 0xffb040], 4, 0.06, 0.18, [0.12, 0.46, 0]);
    hold(hand, ax, Math.PI / 2 - 0.2, 0, 0, [0, -0.02, 0]);
  }
  return rig;
};

B.brine = (bank) => {
  const coat = bank.cloth(0x1d5a5a);
  const rig = buildRig(bank, { skin: 0xd8a888, topMat: coat, legs: 0x2a2a30, boots: 0x1a1414, torsoW: 0.3, torsoH: 0.42, bulk: 1.08, legLen: 0.38, headR: 0.27, skirt: 0x1d5a5a, skirtLen: 0.3, skirtFlare: 1.3 });
  eyes(rig, '#2a3a3a', { brows: 0xd8d8d8, angry: true });
  // eyepatch
  rig.head.add(mesh(G.sphere(0.07, 10, 8), bank.std(0x111111), [0.095, 0.0, rig.headR * 0.92], [0, 0, 0], [1, 1, 0.35]));
  rig.head.add(mesh(G.torus(rig.headR * 1.0, 0.01, 4, 30), bank.std(0x111111), [0, 0.02, 0], [0.1, 0, -0.3]));
  nose(rig, rig.skinMat, 0.16);
  const grey = bank.std(0xb8b8b4, { rough: 0.9 });
  beard(rig, grey, { braid: true, ring: bank.std(0x3a7a3a) });
  // Tricorn hat
  const hat = bank.std(0x1a1618, { rough: 0.7 });
  const h = group(rig.head, [0, rig.headR * 0.7, 0]);
  h.add(mesh(G.cyl(rig.headR * 1.35, rig.headR * 1.35, 0.03, 3), hat, [0, 0, 0], [0, Math.PI, 0]));
  h.add(mesh(G.cyl(rig.headR * 0.75, rig.headR * 0.9, 0.18, 16), hat, [0, 0.1, 0]));
  for (let i = 0; i < 5; i++) h.add(mesh(G.cone(0.03, 0.05, 6), bank.std(0xe8dcc0), [Math.cos(i * 1.3) * 0.2, 0.03, Math.sin(i * 1.3) * 0.2]));
  const gold = bank.metal(0xe0b050, 0.3);
  for (let i = 0; i < 3; i++) rig.torso.add(mesh(G.sphere(0.022, 8, 6), gold, [0.06, 0.15 + i * 0.12, 0.27]));
  shoulderPads(rig, gold, 1.0);
  // Hand-cannon
  const gun = new THREE.Group();
  gun.add(mesh(G.cyl(0.05, 0.065, 0.5, 12), bank.metal(0xc8963c, 0.3), [0, 0.28, 0]));
  gun.add(mesh(G.torus(0.065, 0.02, 6, 14), bank.metal(0x8a6a2a), [0, 0.52, 0], [Math.PI / 2, 0, 0]));
  gun.add(mesh(rbox(0.08, 0.16, 0.12, 0.02), bank.std(0x5a3a22), [0, 0.02, -0.03]));
  hold(rig.handR, gun, Math.PI / 2, 0, 0, [0, 0, 0.02]);
  rig.ranged = 'gun';
  return rig;
};

B.elowen = (bank) => {
  const leaf = bank.std(0x9ab83a, { rough: 0.6, emissive: 0x2a3a00, ei: 0.4 });
  const rig = buildRig(bank, { skin: 0xd8c098, topMat: leaf, torsoW: 0.24, torsoH: 0.38, headR: 0.27, floating: true, floatY: 0.6, skirt: 0x8aa832, skirtLen: 0.6, skirtFlare: 1.6 });
  eyes(rig, '#4a8a2a', { blush: true });
  mouth(rig, { color: 0x8a5a3a });
  const hair = bank.std(0x4a8a3a, { rough: 0.7 });
  hairCap(rig, hair, { h: 0.95 });
  longHair(rig, hair, 0.7, 1.15);
  const wood = bank.std(0x8a6a44, { rough: 0.8 });
  for (const s of [-1, 1]) {
    rig.head.add(mesh(tube([[0, 0, 0], [s * 0.1, 0.14, -0.02], [s * 0.2, 0.26, -0.04], [s * 0.18, 0.36, 0.02]], 0.022, 12, 6), wood, [s * 0.12, rig.headR * 0.7, 0]));
    rig.head.add(mesh(tube([[0, 0, 0], [s * 0.08, 0.08, 0.02]], 0.015, 6, 5), wood, [s * 0.26, rig.headR * 0.7 + 0.18, -0.02]));
  }
  for (let i = 0; i < 8; i++) rig.head.add(mesh(G.sphere(0.035, 8, 6), bank.std(i % 2 ? 0xffb0d0 : 0xffffff, { emissive: 0x331122, ei: 0.5 }), [Math.cos(i * 0.8) * 0.22, rig.headR * 0.9 + Math.sin(i * 2) * 0.06, Math.sin(i * 1.3) * 0.08]));
  const st = staff(bank, wood, 1.05);
  const seed = mesh(G.sphere(0.07, 12, 10), bank.glow(0xb8ff6a, 2.8), [0, 0.94, 0]);
  st.add(seed);
  for (let i = 0; i < 3; i++) st.add(mesh(tube([[0, 0, 0], [Math.cos(i * 2.1) * 0.08, 0.08, Math.sin(i * 2.1) * 0.08], [Math.cos(i * 2.1) * 0.04, 0.16, Math.sin(i * 2.1) * 0.04]], 0.012, 8, 5), wood, [0, 0.86, 0]));
  hold(rig.handR, st, 0.15, 0, 0, [0, 0, 0.04]);
  rig.ranged = 'staff';
  return rig;
};

B.veyl = (bank) => {
  const robe = bank.std(0x24163a, { rough: 0.85, rimColor: 0xa060ff, rim: 0.6 });
  const rig = buildRig(bank, { skin: 0xd8d0e8, topMat: robe, armMat: robe, torsoW: 0.25, torsoH: 0.4, headR: 0.27, floating: true, floatY: 0.66, skirt: 0x24163a, skirtMat: robe, skirtLen: 0.66, skirtFlare: 1.55, headMat: bank.std(0x0a0612, { rough: 1 }) });
  // Hood
  rig.head.add(mesh(G.sphere(rig.headR * 1.18, 24, 16), robe, [0, 0.04, -0.06], [0, 0, 0], [1, 1.12, 1.1]));
  rig.head.add(mesh(G.cone(rig.headR * 0.6, 0.3, 12), robe, [0, rig.headR * 1.05, -0.12], [-0.6, 0, 0]));
  rig.head.add(mesh(G.sphere(rig.headR * 0.86, 20, 14), bank.std(0x050308, { rough: 1 }), [0, -0.01, rig.headR * 0.32], [0, 0, 0], [1, 1, 0.6]));
  eyes(rig, '#c080ff', { glow: true, size: 0.2, spread: 0.3, y: 0.02 });
  rig.eyes.forEach((e) => { e.position.z += 0.06; });
  const stars = bank.basic(0xd8b0ff, { add: true, opacity: 0.8 });
  for (let i = 0; i < 14; i++) {
    const a = i * 2.4;
    const s = mesh(G.sphere(0.012, 6, 4), stars, [Math.cos(a) * 0.3, -0.1 - (i % 5) * 0.1, Math.sin(a) * 0.3]);
    rig.hips.add(s);
  }
  // The floating eye
  const eyeOrb = group(rig.root, [0.55, 1.35, 0.1]);
  eyeOrb.add(mesh(G.sphere(0.17, 24, 18), bank.std(0xf4eef8, { rough: 0.2 })));
  eyeOrb.add(mesh(G.sphere(0.09, 16, 12), bank.glow(0xb060ff, 2.5), [0, 0, 0.12], [0, 0, 0], [1, 1, 0.5]));
  eyeOrb.add(mesh(G.sphere(0.045, 12, 8), bank.std(0x050008), [0, 0, 0.165], [0, 0, 0], [1, 1, 0.4]));
  const tentM = bank.std(0x5a2a8a, { rough: 0.5, emissive: 0x3a0a6a, ei: 0.5 });
  const tents = [];
  for (let i = 0; i < 5; i++) {
    const tg = group(eyeOrb, [0, -0.1, -0.05], [0.4, i * 1.25, 0]);
    tg.add(mesh(tube([[0, 0, 0], [0.04, -0.12, 0.02], [-0.02, -0.25, 0.04], [0.03, -0.38, 0]], 0.02, 10, 5), tentM));
    tents.push(tg);
  }
  rig.anim.push((t) => { eyeOrb.position.y = 1.35 + Math.sin(t * 1.8) * 0.08; tents.forEach((tg, i) => { tg.rotation.x = 0.4 + Math.sin(t * 3 + i) * 0.2; }); });
  rig.eyeOrb = eyeOrb;
  rig.ranged = 'cast';
  return rig;
};

B.hrimfang = (bank) => {
  const fur = bank.std(0xd2dae2, { rough: 0.9, rimColor: 0x9ad8ff, rim: 0.35 });
  const rig = buildRig(bank, { skinMat: fur, topMat: bank.cloth(0x1c2a48), legsMat: fur, bootsMat: fur, armMat: fur, torsoW: 0.28, torsoH: 0.42, legLen: 0.42, headR: 0.25, armLen: 0.38, hunch: 0.3 });
  rig.head.add(mesh(G.cone(0.13, 0.3, 12), fur, [0, -0.05, 0.27], [Math.PI / 2, 0, 0]));
  rig.head.add(mesh(G.sphere(0.04, 8, 6), bank.std(0x1a1a24), [0, -0.03, 0.42]));
  eyes(rig, '#7ad8ff', { glow: true, size: 0.17, spread: 0.36, y: 0.12 });
  ears(rig, fur, 'wolf', bank.std(0x8aa0b8));
  for (let i = 0; i < 6; i++) rig.torso.add(mesh(G.cone(0.06, 0.18, 6), fur, [Math.cos(i * 1.05) * 0.26, 0.5, Math.sin(i * 1.05) * 0.2], [0.5, i, 0]));
  cape(rig, bank.cloth(0x1c2a48), 0.6, 0.55, { tattered: true });
  tail(rig, fur, fur, { bushy: true, size: 0.07, segments: 5 });
  const ice = bank.std(0xdff6ff, { rough: 0.05, emissive: 0x6ad0ff, ei: 1.6 });
  for (const hand of [rig.handL, rig.handR]) for (let i = -1; i <= 1; i++) hand.add(mesh(G.cone(0.02, 0.22, 5), ice, [i * 0.035, -0.1, 0.07], [0.7, 0, i * 0.2]));
  return rig;
};

B.sigrun = (bank) => {
  const armor = bank.metal(0xb8cce0, 0.3);
  const rig = buildRig(bank, { skin: 0xf2d4c0, topMat: armor, legs: 0x5a6a80, boots: 0x8a9ab0, torsoW: 0.27, torsoH: 0.4, legLen: 0.42, headR: 0.27 });
  eyes(rig, '#4a8ac8', { brows: 0xc84a2a, angry: true });
  mouth(rig, { open: true, color: 0x6a2a2a });
  const red = bank.std(0xc8441e, { rough: 0.6 });
  hairCap(rig, red, { h: 0.7, fringe: false });
  braid(rig, red, 0.3, 0.6);
  const ice = bank.std(0xcfeeff, { rough: 0.05, emissive: 0x5ab8f0, ei: 1.0, transparent: true, opacity: 0.92 });
  rig.head.add(mesh(G.dome(rig.headR * 1.07, 24, 12, Math.PI / 2.2), ice, [0, rig.headR * 0.12, 0]));
  for (const s of [-1, 1]) rig.head.add(mesh(extrudeShape([[0, 0], [0.12, 0.08], [0.3, 0.26], [0.18, 0.1], [0.26, 0.12], [0.08, 0.0]], 0.02, 0.01), ice, [s * rig.headR * 0.9, rig.headR * 0.45, -0.02], [0, s > 0 ? 0 : Math.PI, 0.1]));
  rig.torso.add(mesh(G.torus(0.25, 0.09, 10, 22), bank.std(0xdedad4, { rough: 1 }), [0, 0.42, 0], [Math.PI / 2, 0, 0]));
  cape(rig, bank.cloth(0xc8d0da), 0.6, 0.5);
  shoulderPads(rig, armor, 1.15);
  const sw = blade(bank, ice, 0.82, 0.07, { guard: bank.metal(0x9ab8d8) });
  hold(rig.handR, sw, Math.PI / 2 - 0.15, 0, 0, [0, 0, 0]);
  return rig;
};

B.thalassa = (bank) => {
  const robe = bank.std(0x16807a, { rough: 0.45, metal: 0.25 });
  const rig = buildRig(bank, { skin: 0xdcecdf, topMat: robe, torsoW: 0.26, torsoH: 0.4, headR: 0.27, floating: true, floatY: 0.66, skirt: 0x167a78, skirtLen: 0.66, skirtFlare: 1.7, skirtTrim: 0xe8b84a });
  eyes(rig, '#20c0b0', { brows: 0x2a8a8a });
  mouth(rig, { color: 0x6a3a4a });
  const water = bank.std(0x5fe8e0, { rough: 0.05, emissive: 0x1a8a8a, ei: 1.0, transparent: true, opacity: 0.82 });
  hairCap(rig, water, { h: 0.95 });
  longHair(rig, water, 0.85, 1.25);
  const gold = bank.metal(0xe8b84a, 0.25);
  const crown = group(rig.head, [0, rig.headR * 0.75, 0]);
  crown.add(mesh(G.torus(rig.headR * 0.78, 0.025, 6, 24), gold, [0, 0, 0], [Math.PI / 2, 0, 0]));
  for (let i = 0; i < 7; i++) crown.add(mesh(G.cone(0.035, 0.16 + (i === 3 ? 0.08 : 0), 6), i % 2 ? bank.std(0xff7a6a, { rough: 0.4 }) : gold, [Math.cos(Math.PI * 0.15 + i * 0.12 * Math.PI) * rig.headR * 0.78, 0.08, Math.sin(Math.PI * 0.15 + i * 0.12 * Math.PI) * rig.headR * 0.78]));
  shoulderPads(rig, gold, 1.0);
  const tri = new THREE.Group();
  tri.add(mesh(G.cyl(0.02, 0.025, 1.2, 8), gold, [0, 0.4, 0]));
  for (let i = -1; i <= 1; i++) tri.add(mesh(G.cone(0.03, 0.2, 6), gold, [i * 0.08, 1.08 + (i ? 0 : 0.04), 0]));
  tri.add(mesh(G.torus(0.09, 0.015, 6, 16, Math.PI), gold, [0, 0.98, 0], [0, 0, Math.PI]));
  hold(rig.handR, tri, 0.12, 0, 0, [0, 0, 0.04]);
  const ring = new THREE.Group();
  for (let i = 0; i < 14; i++) ring.add(mesh(G.sphere(0.05 + (i % 3) * 0.015, 10, 8), water, [Math.cos(i * 0.45) * 0.6, 0, Math.sin(i * 0.45) * 0.6]));
  ring.position.y = 0.9;
  rig.root.add(ring);
  rig.anim.push((t) => { ring.rotation.y = t * 1.2; ring.rotation.x = Math.sin(t * 0.8) * 0.25; });
  rig.ranged = 'staff';
  return rig;
};

B.grumbark = (bank) => {
  const bark = bank.std(0x6a4a2e, { rough: 1, flat: false });
  const rig = buildRig(bank, { skinMat: bark, topMat: bark, legsMat: bark, bootsMat: bank.std(0x4a3420), torsoW: 0.42, torsoH: 0.6, bulk: 1.1, legLen: 0.4, legR: 0.13, headR: 0.3, armLen: 0.5, armR: 0.12, handScale: 1.6, hunch: 0.12 });
  rig.headMesh.scale.set(0.95, 1.15, 0.9);
  eyes(rig, '#9aff6a', { glow: true, size: 0.16, spread: 0.32, y: 0.1 });
  const moss = bank.std(0x6a9a3a, { rough: 1 });
  rig.head.add(mesh(lathe([[0.001, 0], [0.2, -0.02], [0.18, -0.25], [0.08, -0.45], [0.001, -0.5]], 14), moss, [0, -0.12, 0.16], [0.15, 0, 0], [1, 1, 0.55]));
  rig.head.add(mesh(G.dome(rig.headR * 1.02, 18, 10, Math.PI / 3), moss, [0, 0.06, 0]));
  const twig = bank.std(0x5a3a22, { rough: 1 });
  for (let i = 0; i < 5; i++) rig.head.add(mesh(tube([[0, 0, 0], [Math.cos(i) * 0.1, 0.18, Math.sin(i * 2) * 0.05], [Math.cos(i) * 0.16, 0.3, 0]], 0.025, 8, 5), twig, [(i - 2) * 0.09, rig.headR * 0.7, -0.05]));
  for (let i = 0; i < 12; i++) rig.torso.add(mesh(G.cone(0.05, 0.4, 5), bark, [Math.cos(i * 0.52) * 0.38, 0.35 + Math.sin(i * 1.7) * 0.15, Math.sin(i * 0.52) * 0.3], [0, i * 0.52, 0.06]));
  // Mushrooms and a nest
  for (const [x, z] of [[-0.42, 0], [-0.36, 0.1], [0.4, -0.05]]) {
    rig.torso.add(mesh(G.cyl(0.025, 0.03, 0.08, 6), bank.std(0xf0e8d8), [x, 0.66, z]));
    rig.torso.add(mesh(G.dome(0.08, 12, 8, Math.PI / 2), bank.std(0xd8302a, { rough: 0.5 }), [x, 0.7, z]));
  }
  rig.torso.add(mesh(G.torus(0.09, 0.04, 6, 12), bank.std(0x8a6a3a, { rough: 1 }), [0.38, 0.72, -0.12], [Math.PI / 2, 0, 0]));
  rig.torso.add(mesh(G.sphere(0.035, 8, 6), bank.std(0xa8d8ff), [0.38, 0.74, -0.12]));
  for (const hand of [rig.handL, rig.handR]) for (let i = 0; i < 4; i++) hand.add(mesh(G.cone(0.04, 0.2, 5), bark, [Math.cos(i * 1.6) * 0.07, -0.12, Math.sin(i * 1.6) * 0.07], [Math.PI + Math.sin(i) * 0.3, 0, Math.cos(i * 1.6) * 0.3]));
  rig.scale = 1.25;
  return rig;
};

B.nyxara = (bank) => {
  const skin = bank.std(0x5a3aa0, { rough: 0.4, rimColor: 0xd0a0ff, rim: 0.6 });
  const cloak = bank.std(0x1a0e2a, { rough: 0.8, transparent: true, opacity: 0.94 });
  const rig = buildRig(bank, { skinMat: skin, topMat: bank.std(0x2a1a44, { rough: 0.5 }), legs: 0x2a1a44, boots: 0x140a1e, torsoW: 0.24, torsoH: 0.4, legLen: 0.46, headR: 0.26 });
  eyes(rig, '#ffffff', { glow: true, size: 0.2, spread: 0.36 });
  const hair = bank.std(0xd8d4e8, { rough: 0.4 });
  hairCap(rig, hair, { h: 0.9 });
  longHair(rig, hair, 0.8, 1.0);
  const stars = bank.glow(0xe8d8ff, 3);
  for (let i = 0; i < 7; i++) rig.torso.add(mesh(G.sphere(0.012, 6, 4), stars, [Math.cos(i * 2.2) * 0.2, 0.2 + i * 0.05, 0.24]));
  for (const arm of [rig.armL, rig.armR]) for (let i = 0; i < 3; i++) arm.add(mesh(G.sphere(0.01, 6, 4), stars, [0.07, -0.1 - i * 0.07, 0.03]));
  cape(rig, cloak, 0.8, 0.6, { tattered: true });
  const smoke = bank.basic(0x8a50d0, { add: true, opacity: 0.35 });
  const puffs = [];
  for (let i = 0; i < 6; i++) { const m = mesh(G.sphere(0.12, 8, 6), smoke, [0, 0, -0.1]); rig.back.add(m); puffs.push(m); }
  rig.anim.push((t) => puffs.forEach((m, i) => { const k = (t * 0.5 + i / 6) % 1; m.position.set(Math.sin(i * 2 + t) * 0.15, -0.3 - k * 0.5, -0.2 - k * 0.3); m.scale.setScalar(0.5 + k); m.material.opacity = 0.35 * (1 - k); }));
  const cres = bank.std(0xe8e0ff, { rough: 0.1, metal: 0.6, emissive: 0x9a6aff, ei: 1.2 });
  for (const [hand, s] of [[rig.handL, -1], [rig.handR, 1]]) {
    const c = mesh(G.torus(0.2, 0.025, 6, 20, Math.PI * 1.1), cres, [0, 0.0, 0.18], [0, Math.PI / 2, s * 0.5]);
    hand.add(c);
  }
  return rig;
};

B.vexa = (bank) => {
  const rig = buildRig(bank, { skin: 0xf2cdb2, top: 0x7a4a2a, legs: 0x3a3a44, boots: 0x2a1e18, torsoW: 0.26, torsoH: 0.38, legLen: 0.44, headR: 0.27 });
  eyes(rig, '#2a8a8a', { brows: 0x1a7a7a });
  mouth(rig, { color: 0x8a4a4a });
  const hair = bank.std(0x2ab8b0, { rough: 0.6 });
  hairCap(rig, hair, { h: 0.9 });
  const gm = bank.metal(0xb88a3a, 0.3);
  for (const s of [-1, 1]) {
    rig.head.add(mesh(G.torus(0.07, 0.022, 8, 16), gm, [s * 0.1, rig.headR * 0.62, rig.headR * 0.62], [-0.9, 0, 0]));
    rig.head.add(mesh(G.sphere(0.063, 12, 8), bank.std(0xffb04a, { rough: 0.1, emissive: 0x6a3a00 }), [s * 0.1, rig.headR * 0.62, rig.headR * 0.6], [0, 0, 0], [1, 1, 0.35]));
  }
  // Copper prosthetic arm (left)
  const copper = bank.metal(0xc8743a, 0.3);
  rig.armL.children.forEach((c) => { if (c.isMesh) c.material = copper; });
  rig.armL.add(mesh(G.sphere(0.06, 10, 8), copper, [0, -0.17, 0]));
  rig.handL.children.forEach((c) => { if (c.isMesh) c.material = copper; });
  belt(rig, bank.std(0x4a2e1a), gm);
  // Arc rifle
  const rifle = new THREE.Group();
  rifle.add(mesh(G.cyl(0.035, 0.04, 0.8, 10), bank.metal(0xc8963c, 0.3), [0, 0.3, 0]));
  rifle.add(mesh(rbox(0.07, 0.24, 0.1, 0.02), bank.std(0x5a3a22), [0, -0.06, -0.02]));
  const coils = [];
  for (let i = 0; i < 3; i++) { const c = mesh(G.torus(0.06, 0.015, 6, 14), bank.glow(0x7ae8ff, 2.5), [0, 0.3 + i * 0.12, 0], [Math.PI / 2, 0, 0]); rifle.add(c); coils.push(c); }
  rig.anim.push((t) => coils.forEach((c, i) => { c.material.emissiveIntensity = 1.5 + Math.sin(t * 12 + i) * 1.2; }));
  hold(rig.handR, rifle, Math.PI / 2, 0, 0, [0, 0, 0]);
  rig.ranged = 'gun';
  return rig;
};

B.ilsa = (bank) => {
  const gold = bank.std(0xe8a83a, { rough: 0.45, metal: 0.4 });
  const rig = buildRig(bank, { skin: 0xf2d0b8, topMat: gold, torsoW: 0.25, torsoH: 0.4, headR: 0.27, floating: true, floatY: 0.64, skirt: 0xb8281e, skirtLen: 0.64, skirtFlare: 1.65, skirtTrim: 0xffc04a });
  eyes(rig, '#8a4a14', { brows: 0x8a3a1a });
  mouth(rig, { color: 0x9a4a4a });
  const hair = bank.std(0x9a3a1e, { rough: 0.6 });
  hairCap(rig, hair, { h: 0.95 });
  longHair(rig, hair, 0.7, 1.1);
  // Feather layers on the robe
  const fea = [bank.std(0xd8381e, { rough: 0.7 }), bank.std(0xf0a030, { rough: 0.6 })];
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * Math.PI * 2;
    rig.hips.add(mesh(G.cone(0.08, 0.34, 4), fea[i % 2], [Math.cos(a) * 0.36, -0.42, Math.sin(a) * 0.36], [Math.PI + Math.sin(a) * 0.35, a, Math.cos(a) * 0.35], [1, 1, 0.35]));
  }
  // Fire halo
  const halo = mesh(G.torus(0.34, 0.03, 8, 40), bank.glow(0xffa030, 3), [0, rig.headR * 0.1, -0.2]);
  rig.head.add(halo);
  flameTongues(rig, halo, [0xffc040, 0xff7a1a], 10, 0.34, 0.14, [0, 0, 0]);
  rig.anim.push((t) => { halo.rotation.z = t * 0.6; });
  const st = staff(bank, bank.metal(0xe8b84a, 0.25), 1.15);
  const bird = new THREE.Group();
  bird.add(mesh(G.sphere(0.07, 12, 10), bank.glow(0xff9a30, 2), [0, 0, 0]));
  for (const s of [-1, 1]) bird.add(mesh(extrudeShape([[0, 0], [0.18, 0.1], [0.24, 0.02], [0.14, -0.04]], 0.015, 0.008), bank.glow(0xffc040, 1.8), [0, 0, 0], [0, s > 0 ? 0 : Math.PI, 0]));
  bird.position.y = 1.08;
  st.add(bird);
  flameTongues(rig, bird, [0xffd060, 0xff7a1a], 4, 0.04, 0.14, [0, 0.06, 0]);
  hold(rig.handR, st, 0.12, 0, 0, [0, 0, 0.04]);
  rig.ranged = 'staff';
  return rig;
};

B.morgath = (bank) => {
  const obs = bank.std(0x1a1422, { rough: 0.25, metal: 0.55, rimColor: 0xa060ff, rim: 0.7 });
  const crack = bank.glow(0xa050ff, 2.4);
  const rig = buildRig(bank, { skinMat: obs, topMat: obs, legsMat: obs, bootsMat: obs, torsoW: 0.42, torsoH: 0.56, bulk: 1.2, legLen: 0.42, legR: 0.12, headR: 0.26, armLen: 0.48, armR: 0.12, handScale: 1.5, hunch: 0.15 });
  eyes(rig, '#c070ff', { glow: true, size: 0.18, spread: 0.32, y: 0.05 });
  for (const s of [-1, 1]) rig.head.add(mesh(tube([[0, 0, 0], [s * 0.18, 0.1, -0.04], [s * 0.28, 0.3, -0.1], [s * 0.22, 0.46, -0.04]], 0.05, 12, 6), obs, [s * 0.16, 0.12, 0]));
  // Chest eye
  const ce = group(rig.torso, [0, 0.36, 0.42]);
  ce.add(mesh(G.sphere(0.13, 20, 14), bank.std(0xf2e8ff, { rough: 0.2 }), [0, 0, 0], [0, 0, 0], [1.2, 0.85, 0.6]));
  const iris = mesh(G.sphere(0.07, 14, 10), crack, [0, 0, 0.06], [0, 0, 0], [0.6, 1, 0.5]);
  ce.add(iris);
  for (let i = 0; i < 8; i++) rig.torso.add(mesh(G.box(0.02, 0.18 + (i % 3) * 0.06, 0.02), crack, [Math.cos(i * 0.8) * 0.36, 0.25 + Math.sin(i * 1.3) * 0.18, Math.sin(i * 0.8) * 0.3 + 0.12], [0, 0, i]));
  shoulderPads(rig, obs, 1.8, crack);
  // Floating shard crown
  const crown = group(rig.head, [0, 0.42, 0]);
  const shards = [];
  for (let i = 0; i < 7; i++) {
    const m = mesh(G.octa(0.07), bank.glow(0xb070ff, 2.2), [Math.cos(i * 0.9) * 0.28, 0, Math.sin(i * 0.9) * 0.28], [0, 0, 0], [0.6, 1.8, 0.6]);
    crown.add(m);
    shards.push(m);
  }
  rig.anim.push((t) => { crown.rotation.y = t * 0.7; shards.forEach((m, i) => { m.position.y = Math.sin(t * 2 + i) * 0.05; }); });
  // Tentacle cape
  const tm = bank.std(0x2a1840, { rough: 0.5, emissive: 0x2a0a4a, ei: 0.4 });
  const tents = [];
  for (let i = 0; i < 6; i++) {
    const tg = group(rig.back, [(i - 2.5) * 0.1, 0.1, 0], [0.4, 0, (i - 2.5) * 0.15]);
    tg.add(mesh(tube([[0, 0, 0], [0.02, -0.25, -0.1], [-0.04, -0.55, -0.18], [0.03, -0.8, -0.1]], 0.04, 12, 6), tm));
    tents.push(tg);
  }
  rig.anim.push((t) => tents.forEach((tg, i) => { tg.rotation.x = 0.45 + Math.sin(t * 2 + i) * 0.18; }));
  rig.scale = 1.45;
  return rig;
};

B.magna = (bank) => {
  const white = bank.std(0xe2ded6, { rough: 0.32, metal: 0.45 });
  const gold = bank.metal(0xe8b04a, 0.25);
  const rig = buildRig(bank, { skin: 0xf2cdb2, topMat: white, legsMat: white, bootsMat: gold, armMat: white, handMat: gold, torsoW: 0.3, torsoH: 0.42, legLen: 0.46, headR: 0.26 });
  eyes(rig, '#2a6a8a', { brows: 0x8a6a4a });
  const helm = bank.std(0xe2ded6, { rough: 0.28, metal: 0.5 });
  rig.head.add(mesh(G.dome(rig.headR * 1.08, 24, 16, Math.PI / 1.9), helm, [0, 0.02, -0.02]));
  rig.head.add(mesh(G.cone(0.05, 0.22, 6), gold, [0, rig.headR * 1.05, -0.02]));
  for (const s of [-1, 1]) rig.head.add(mesh(G.cone(0.03, 0.16, 5), gold, [s * rig.headR * 0.95, rig.headR * 0.3, 0], [0, 0, -s * 0.9]));
  const core = mesh(G.sphere(0.08, 16, 12), bank.glow(0x6af0ff, 3.5), [0, 0.3, 0.27]);
  rig.torso.add(core);
  rig.torso.add(mesh(G.torus(0.1, 0.022, 8, 20), gold, [0, 0.3, 0.26]));
  rig.anim.push((t) => { core.scale.setScalar(1 + Math.sin(t * 4) * 0.1); });
  shoulderPads(rig, gold, 1.35);
  belt(rig, gold, bank.glow(0x6af0ff, 2));
  // Brass feather wings with thrusters
  for (const s of [-1, 1]) {
    const wing = group(rig.back, [s * 0.12, 0.05, 0], [0.2, s * 0.5, s * 0.3]);
    for (let i = 0; i < 6; i++) wing.add(mesh(extrudeShape([[0, 0], [0.08, 0.02], [0.5 - i * 0.04, 0.08], [0.06, -0.03]], 0.015, 0.008), gold, [s * 0.04 * i, 0.2 - i * 0.08, -0.02 * i], [0, s > 0 ? 0 : Math.PI, 0.5 - i * 0.18]));
    wing.add(mesh(G.cyl(0.04, 0.05, 0.12, 10), bank.metal(0x6a6a74), [s * 0.05, -0.15, -0.05]));
    wing.add(mesh(G.cone(0.045, 0.18, 10), bank.glow(0x7ae8ff, 2.5), [s * 0.05, -0.28, -0.05], [Math.PI, 0, 0]));
    rig.anim.push((t) => { wing.rotation.z = s * (0.3 + Math.sin(t * 1.5) * 0.08); });
  }
  // Energy lance
  const lance = new THREE.Group();
  lance.add(mesh(G.cyl(0.03, 0.03, 0.4, 8), gold, [0, 0.0, 0]));
  lance.add(mesh(G.cone(0.08, 0.9, 12), bank.std(0xdff8ff, { rough: 0.1, emissive: 0x6ad8ff, ei: 1.8 }), [0, 0.62, 0]));
  lance.add(mesh(G.cyl(0.12, 0.06, 0.08, 12), gold, [0, 0.18, 0]));
  hold(rig.handR, lance, Math.PI / 2 - 0.1, 0, 0, [0, 0, 0]);
  rig.scale = 1.12;
  return rig;
};

B.eira = (bank) => {
  const gown = bank.std(0xc8dcf0, { rough: 0.4, metal: 0.15, rimColor: 0xbfe8ff, rim: 0.35 });
  const rig = buildRig(bank, { skin: 0xf4ecf2, topMat: gown, torsoW: 0.25, torsoH: 0.42, headR: 0.27, floating: true, floatY: 0.72, skirt: 0xa8c8e8, skirtLen: 0.72, skirtFlare: 1.8, skirtTrim: 0x9ad8ff });
  eyes(rig, '#5ab8ff', { brows: 0xe8eef8 });
  mouth(rig, { color: 0x8a7a9a });
  const hair = bank.std(0xdfe4ee, { rough: 0.45 });
  hairCap(rig, hair, { h: 0.95 });
  longHair(rig, hair, 0.85, 1.2);
  const ice = bank.std(0xd8f4ff, { rough: 0.05, emissive: 0x6ac8ff, ei: 1.5, transparent: true, opacity: 0.9 });
  const crown = group(rig.head, [0, rig.headR * 0.72, 0]);
  for (let i = 0; i < 9; i++) {
    const a = Math.PI * (0.1 + i * 0.1);
    const h = 0.18 + (i === 4 ? 0.2 : i % 2 ? 0.05 : 0.12);
    crown.add(mesh(G.cone(0.035, h, 5), ice, [Math.cos(a) * rig.headR * 0.8, h / 2, Math.sin(a) * rig.headR * 0.8 - 0.04]));
  }
  rig.torso.add(mesh(lathe([[0.001, 0], [0.3, 0.02], [0.36, 0.22], [0.24, 0.3], [0.001, 0.31]], 20), ice, [0, 0.4, -0.06], [0.2, 0, 0], [1, 1, 0.5]));
  const sc = new THREE.Group();
  sc.add(mesh(G.cyl(0.02, 0.025, 0.9, 8), bank.metal(0xd8e8f8, 0.2), [0, 0.3, 0]));
  const gem = mesh(G.octa(0.1), ice, [0, 0.82, 0], [0, 0, 0], [1, 1.8, 1]);
  sc.add(gem);
  spinner(rig, gem, 1.5);
  hold(rig.handR, sc, 0.12, 0, 0, [0, 0, 0.04]);
  const flakes = [];
  const fm = bank.basic(0xffffff, { add: true, opacity: 0.8 });
  for (let i = 0; i < 12; i++) { const f = mesh(G.octa(0.025), fm); rig.root.add(f); flakes.push({ f, a: i * 0.52, r: 0.45 + (i % 3) * 0.12 }); }
  rig.anim.push((t) => flakes.forEach((o, i) => { const a = o.a + t * 0.8; o.f.position.set(Math.cos(a) * o.r, 0.3 + ((t * 0.3 + i * 0.13) % 1.4), Math.sin(a) * o.r); }));
  rig.scale = 1.08;
  rig.ranged = 'staff';
  return rig;
};

// ───────────────────────── monsters ─────────────────────────
const MON = {};
MON.shardling = (bank, tint) => {
  const c = new THREE.Color(tint || 0xb070ff);
  const cry = bank.std(c.getHex(), { rough: 0.1, emissive: c.getHex(), ei: 0.6, metal: 0.2 });
  const rig = buildRig(bank, { skinMat: cry, topMat: cry, legsMat: bank.std(0x4a4a5a), bootsMat: bank.std(0x3a3a48), torsoW: 0.2, torsoH: 0.22, legLen: 0.2, legR: 0.05, headR: 0.22, armLen: 0.16, armR: 0.04, noHead: false });
  rig.headMesh.geometry = G.octa(0.26);
  eyes(rig, '#1a2a3a', { size: 0.3, spread: 0.3 });
  for (let i = 0; i < 4; i++) rig.torso.add(mesh(G.octa(0.06), cry, [Math.cos(i * 1.6) * 0.15, 0.3, Math.sin(i * 1.6) * 0.12 - 0.08], [0, 0, 0], [0.6, 1.8, 0.6]));
  return rig;
};
MON.golem = (bank, tint) => {
  const stone = bank.std(tint ? new THREE.Color(tint).getHex() : 0x7a7480, { rough: 0.95, flat: true });
  const glow = bank.glow(0x7ae0ff, 1.8);
  const rig = buildRig(bank, { skinMat: stone, topMat: stone, legsMat: stone, bootsMat: stone, torsoW: 0.38, torsoH: 0.5, bulk: 1.2, legLen: 0.36, legR: 0.11, headR: 0.2, armLen: 0.46, armR: 0.12, handScale: 1.6, hunch: 0.2 });
  rig.headMesh.geometry = G.dodeca(0.22);
  rig.chest.geometry = G.dodeca(1);
  eyes(rig, '#7ae0ff', { glow: true, size: 0.2, spread: 0.3 });
  for (let i = 0; i < 4; i++) rig.torso.add(mesh(G.octa(0.08), glow, [Math.cos(i * 1.4) * 0.3, 0.5 + Math.sin(i) * 0.1, -0.18], [0.4, 0, 0], [0.6, 2, 0.6]));
  return rig;
};
MON.wolf = (bank, tint) => {
  const fur = bank.std(tint ? new THREE.Color(tint).getHex() : 0x2a2040, { rough: 0.7, rimColor: 0xa070ff, rim: 0.8 });
  const root = new THREE.Group();
  const body = group(root);
  const rig = { root, body, bank, anim: [], o: {}, quad: true };
  rig.update = (t, dt) => { for (const f of rig.anim) f(t, dt); };
  const torso = group(body, [0, 0.55, 0]);
  torso.add(mesh(G.capsule(0.22, 0.5, 12), fur, [0, 0, 0], [Math.PI / 2, 0, 0]));
  const head = group(torso, [0, 0.18, 0.42]);
  head.add(mesh(G.sphere(0.2, 18, 14), fur));
  head.add(mesh(G.cone(0.11, 0.28, 10), fur, [0, -0.04, 0.2], [Math.PI / 2, 0, 0]));
  for (const s of [-1, 1]) {
    head.add(mesh(G.cone(0.07, 0.18, 4), fur, [s * 0.11, 0.18, -0.02], [0, 0, -s * 0.3]));
    head.add(mesh(G.sphere(0.035, 8, 6), bank.glow(0xc080ff, 3), [s * 0.08, 0.04, 0.16]));
  }
  rig.head = head;
  rig.torso = torso;
  const legs = [];
  for (const [x, z] of [[-0.14, 0.28], [0.14, 0.28], [-0.14, -0.28], [0.14, -0.28]]) {
    const l = group(torso, [x, -0.05, z]);
    l.add(mesh(G.capsule(0.06, 0.3, 6), fur, [0, -0.22, 0]));
    legs.push(l);
  }
  rig.legs = legs;
  const tl = group(torso, [0, 0.05, -0.42], [0.6, 0, 0]);
  tl.add(mesh(G.cone(0.08, 0.4, 8), fur, [0, -0.2, 0], [Math.PI, 0, 0]));
  for (let i = 0; i < 5; i++) torso.add(mesh(G.octa(0.05), bank.glow(0xa060ff, 2), [0, 0.22, 0.25 - i * 0.12], [0, 0, 0], [0.6, 1.6, 0.6]));
  rig.height = 1.0;
  return rig;
};
MON.drake = (bank, tint) => {
  const c = tint ? new THREE.Color(tint).getHex() : 0x3a7a5a;
  const scale = bank.std(c, { rough: 0.45, metal: 0.2, rimColor: 0xffe0a0, rim: 0.6 });
  const belly = bank.std(0xe8d8a0, { rough: 0.6 });
  const root = new THREE.Group();
  const body = group(root);
  const rig = { root, body, bank, anim: [], o: {}, quad: true };
  rig.update = (t, dt) => { for (const f of rig.anim) f(t, dt); };
  const torso = group(body, [0, 0.6, 0]);
  torso.add(mesh(G.sphere(0.32, 20, 16), scale, [0, 0, 0], [0, 0, 0], [0.9, 0.85, 1.25]));
  torso.add(mesh(G.sphere(0.27, 16, 12), belly, [0, -0.08, 0.08], [0, 0, 0], [0.8, 0.7, 1.1]));
  const neck = group(torso, [0, 0.18, 0.3], [-0.5, 0, 0]);
  neck.add(mesh(G.capsule(0.12, 0.25, 8), scale, [0, 0.15, 0]));
  const head = group(neck, [0, 0.38, 0.05], [0.5, 0, 0]);
  head.add(mesh(G.sphere(0.17, 16, 12), scale, [0, 0, 0], [0, 0, 0], [1, 0.85, 1.3]));
  head.add(mesh(G.cone(0.09, 0.2, 8), scale, [0, -0.03, 0.22], [Math.PI / 2, 0, 0]));
  for (const s of [-1, 1]) {
    head.add(mesh(G.cone(0.035, 0.22, 6), belly, [s * 0.09, 0.12, -0.1], [-0.8, 0, -s * 0.3]));
    head.add(mesh(G.sphere(0.03, 8, 6), bank.glow(0xffd040, 3), [s * 0.08, 0.04, 0.12]));
  }
  rig.head = head;
  rig.torso = torso;
  const wings = [];
  for (const s of [-1, 1]) {
    const w = group(torso, [s * 0.2, 0.2, -0.05], [0, 0, s * 0.3]);
    const shape = [[0, 0], [s * 0.7, 0.35], [s * 0.85, 0.05], [s * 0.6, -0.1], [s * 0.4, -0.05], [s * 0.2, -0.12]];
    w.add(mesh(extrudeShape(shape, 0.01, 0), bank.std(new THREE.Color(c).multiplyScalar(0.7).getHex(), { rough: 0.6, side: THREE.DoubleSide }), [0, 0, 0], [Math.PI / 2 - 0.3, 0, 0]));
    wings.push({ w, s });
  }
  rig.anim.push((t) => wings.forEach(({ w, s }) => { w.rotation.z = s * (0.3 + Math.sin(t * 3) * 0.35); }));
  const legs = [];
  for (const [x, z] of [[-0.18, 0.2], [0.18, 0.2], [-0.18, -0.2], [0.18, -0.2]]) {
    const l = group(torso, [x, -0.2, z]);
    l.add(mesh(G.capsule(0.07, 0.22, 6), scale, [0, -0.15, 0]));
    legs.push(l);
  }
  rig.legs = legs;
  const tl = group(torso, [0, 0, -0.38], [0.3, 0, 0]);
  tl.add(mesh(G.cone(0.1, 0.6, 8), scale, [0, 0, -0.3], [-Math.PI / 2, 0, 0]));
  rig.height = 1.4;
  return rig;
};

export function buildChampion(id, opts = {}) {
  const bank = new MatBank();
  const fn = B[id];
  const rig = fn ? fn(bank) : B.brakka(bank);
  rig.id = id;
  rig.bank = bank;
  rig.root.traverse((o) => { if (o.isMesh && !o.material.userData.basic) o.castShadow = true; });
  const s = (rig.scale || 1) * 1.62;
  rig.baseScale = s;
  rig.root.scale.setScalar(s);
  rig.height = (rig.height || 1.4) * s;
  return rig;
}

export function buildMonster(look, tint, scale = 1) {
  const bank = new MatBank();
  const fn = MON[look] || MON.shardling;
  const rig = fn(bank, tint);
  rig.bank = bank;
  rig.id = look;
  rig.root.traverse((o) => { if (o.isMesh && !o.material.userData.basic) o.castShadow = true; });
  rig.baseScale = scale;
  rig.root.scale.setScalar(scale);
  rig.height = (rig.height || 1.2) * scale;
  return rig;
}

export const MODEL_IDS = Object.keys(B);
