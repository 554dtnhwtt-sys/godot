// Shared building blocks for the procedural chibi champions: a simple rig
// (hips, legs, torso, head, arms, hands) plus materials with rim light and hit flash.
import * as THREE from 'three';
import { eyeTexture } from './textures.js';

// ───────────── materials ─────────────
export function rimify(mat, rimColor = 0xffffff, rimStrength = 0.35) {
  mat.userData.rim = { value: new THREE.Color(rimColor).multiplyScalar(rimStrength) };
  mat.userData.flash = { value: 0 };
  mat.userData.fade = { value: 0 };
  mat.userData.tint = { value: new THREE.Color(0, 0, 0) };
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uRim = mat.userData.rim;
    sh.uniforms.uFlash = mat.userData.flash;
    sh.uniforms.uFade = mat.userData.fade;
    sh.uniforms.uTint = mat.userData.tint;
    sh.fragmentShader = 'uniform vec3 uRim; uniform float uFlash; uniform float uFade; uniform vec3 uTint;\n' + sh.fragmentShader
      .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        float fres = pow(1.0 - clamp(abs(dot(normal, normalize(vViewPosition))), 0.0, 1.0), 2.6);
        totalEmissiveRadiance += uRim * fres + uTint + vec3(uFlash);`)
      .replace('#include <dithering_fragment>', `#include <dithering_fragment>
        if (uFade > 0.0) {
          float n = fract(sin(dot(floor(gl_FragCoord.xy*0.5), vec2(12.9898,78.233)))*43758.5453);
          if (n < uFade) discard;
        }`);
  };
  mat.customProgramCacheKey = () => 'rimmed';
  return mat;
}

export class MatBank {
  constructor(rim = 0xfff0dd) {
    this.rim = rim;
    this.list = [];
  }
  std(color, o = {}) {
    const m = new THREE.MeshStandardMaterial({ color, roughness: o.rough ?? 0.62, metalness: o.metal ?? 0, emissive: o.emissive ?? 0x000000, emissiveIntensity: o.ei ?? 1, map: o.map || null, flatShading: !!o.flat, transparent: !!o.transparent, opacity: o.opacity ?? 1, side: o.side ?? THREE.FrontSide });
    rimify(m, o.rimColor ?? this.rim, o.rim ?? 0.22);
    this.list.push(m);
    return m;
  }
  skin(color) { return this.std(color, { rough: 0.55, rim: 0.4 }); }
  cloth(color) { return this.std(color, { rough: 0.85 }); }
  metal(color, rough = 0.3) { return this.std(color, { rough, metal: 0.85, rim: 0.25 }); }
  glow(color, ei = 2.0) { return this.std(color, { emissive: color, ei, rough: 0.3 }); }
  basic(color, o = {}) {
    const m = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: o.opacity ?? 1, blending: o.add ? THREE.AdditiveBlending : THREE.NormalBlending, depthWrite: !o.add, side: o.side ?? THREE.FrontSide });
    m.userData.basic = true;
    this.list.push(m);
    return m;
  }
}

// ───────────── geometry helpers ─────────────
const GEO = new Map();
function cached(key, make) {
  if (!GEO.has(key)) GEO.set(key, make());
  return GEO.get(key);
}
export const G = {
  sphere: (r = 1, w = 28, h = 20) => cached(`s${r}|${w}|${h}`, () => new THREE.SphereGeometry(r, w, h)),
  dome: (r = 1, w = 24, h = 12, theta = Math.PI / 2) => cached(`dm${r}|${w}|${h}|${theta}`, () => new THREE.SphereGeometry(r, w, h, 0, Math.PI * 2, 0, theta)),
  capsule: (r, l, seg = 10) => cached(`c${r}|${l}|${seg}`, () => new THREE.CapsuleGeometry(r, l, 6, seg)),
  cyl: (rt, rb, h, seg = 16, open = false) => cached(`y${rt}|${rb}|${h}|${seg}|${open}`, () => new THREE.CylinderGeometry(rt, rb, h, seg, 1, open)),
  cone: (r, h, seg = 16) => cached(`k${r}|${h}|${seg}`, () => new THREE.ConeGeometry(r, h, seg)),
  box: (x, y, z) => cached(`b${x}|${y}|${z}`, () => new THREE.BoxGeometry(x, y, z)),
  torus: (r, t, rs = 10, ts = 28, arc = Math.PI * 2) => cached(`t${r}|${t}|${rs}|${ts}|${arc}`, () => new THREE.TorusGeometry(r, t, rs, ts, arc)),
  octa: (r) => cached(`o${r}`, () => new THREE.OctahedronGeometry(r, 0)),
  ico: (r, d = 0) => cached(`i${r}|${d}`, () => new THREE.IcosahedronGeometry(r, d)),
  dodeca: (r) => cached(`d${r}`, () => new THREE.DodecahedronGeometry(r, 0)),
};

export function rbox(w, h, d, r = 0.05) {
  return cached(`rb${w}|${h}|${d}|${r}`, () => {
    const s = new THREE.Shape();
    const x = -w / 2; const y = -h / 2;
    s.moveTo(x + r, y); s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r);
    s.lineTo(x + w, y + h - r); s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    s.lineTo(x + r, y + h); s.quadraticCurveTo(x, y + h, x, y + h - r);
    s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
    const g = new THREE.ExtrudeGeometry(s, { depth: d - r * 2, bevelEnabled: true, bevelSize: r, bevelThickness: r, bevelSegments: 3, curveSegments: 4 });
    g.translate(0, 0, -(d - r * 2) / 2);
    return g;
  });
}

export function lathe(points, seg = 24) {
  return cached(`l${points.flat().join(',')}|${seg}`, () => new THREE.LatheGeometry(points.map(([x, y]) => new THREE.Vector2(x, y)), seg));
}

export function tube(pts, r = 0.05, seg = 16, rseg = 8) {
  return cached(`tb${pts.flat().join(',')}|${r}|${seg}`, () => new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts.map((p) => new THREE.Vector3(...p))), seg, r, rseg, false));
}

export function extrudeShape(points, depth = 0.04, bevel = 0.015) {
  return cached(`ex${points.flat().join(',')}|${depth}|${bevel}`, () => {
    const s = new THREE.Shape();
    points.forEach(([x, y], i) => (i ? s.lineTo(x, y) : s.moveTo(x, y)));
    s.closePath();
    const g = new THREE.ExtrudeGeometry(s, { depth, bevelEnabled: bevel > 0, bevelSize: bevel, bevelThickness: bevel, bevelSegments: 2 });
    g.translate(0, 0, -depth / 2);
    return g;
  });
}

export function mesh(geo, mat, p = [0, 0, 0], r = [0, 0, 0], s = 1) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(p[0], p[1], p[2]);
  m.rotation.set(r[0], r[1], r[2]);
  if (Array.isArray(s)) m.scale.set(s[0], s[1], s[2]);
  else m.scale.setScalar(s);
  m.castShadow = !mat.userData.basic;
  return m;
}

export function group(parent, p = [0, 0, 0], r = [0, 0, 0]) {
  const g = new THREE.Group();
  g.position.set(p[0], p[1], p[2]);
  g.rotation.set(r[0], r[1], r[2]);
  if (parent) parent.add(g);
  return g;
}

// ───────────── the rig ─────────────
// opts: skin, top, legs, boots, height (hip height), torsoH, torsoW, headR, armLen, armR, legR,
//       bulk, hunch, floating (no legs), skirt
export function buildRig(bank, o) {
  const root = new THREE.Group();
  const body = group(root);
  const hipY = o.floating ? (o.floatY ?? 0.55) : (o.legLen ?? 0.42);
  const hips = group(body, [0, hipY, 0]);
  const rig = { root, body, hips, bank, anim: [], parts: {}, o };
  rig.update = (t, dt) => { for (const f of rig.anim) f(t, dt); };
  const w = o.torsoW ?? 0.3;
  const th = o.torsoH ?? 0.42;
  const skinM = o.skinMat || bank.skin(o.skin ?? 0xf2c6a0);
  rig.skinMat = skinM;
  const topM = o.topMat || bank.cloth(o.top ?? 0x445566);
  rig.topMat = topM;
  // Legs
  if (!o.floating) {
    const legsM = o.legsMat || bank.cloth(o.legs ?? 0x3a3a48);
    const bootsM = o.bootsMat || bank.std(o.boots ?? 0x3a2a20, { rough: 0.7 });
    const legL = group(hips, [-w * 0.42, 0, 0]);
    const legR = group(hips, [w * 0.42, 0, 0]);
    const ll = (o.legLen ?? 0.42) - 0.06;
    const lr = o.legR ?? 0.085;
    for (const leg of [legL, legR]) {
      leg.add(mesh(G.capsule(lr, ll * 0.6), legsM, [0, -ll * 0.45, 0]));
      leg.add(mesh(rbox(lr * 2.3, 0.1, lr * 3.3, 0.04), bootsM, [0, -ll + 0.02, lr * 0.5]));
    }
    rig.legL = legL;
    rig.legR = legR;
  }
  if (o.skirt) {
    const sm = o.skirtMat || bank.cloth(o.skirt);
    const len = o.skirtLen ?? 0.5;
    const flare = o.skirtFlare ?? 1.6;
    const sk = mesh(lathe([[0.001, -len], [w * flare, -len], [w * (flare * 0.92), -len * 0.6], [w * 1.05, -len * 0.2], [w * 0.9, 0.05], [0.001, 0.06]], 28), sm, [0, 0.02, 0]);
    hips.add(sk);
    rig.skirt = sk;
    if (o.skirtTrim) hips.add(mesh(G.torus(w * flare * 0.99, 0.025, 6, 32), bank.metal(o.skirtTrim), [0, -len + 0.02, 0], [Math.PI / 2, 0, 0]));
  }
  // Torso
  const torso = group(hips, [0, 0.02, 0], [o.hunch ?? 0, 0, 0]);
  rig.torso = torso;
  const bulk = o.bulk ?? 1;
  const chest = mesh(G.sphere(1, 24, 18), topM, [0, th * 0.55, 0], [0, 0, 0], [w * bulk, th * 0.62, w * 0.82 * bulk]);
  torso.add(chest);
  rig.chest = chest;
  const belly = mesh(G.sphere(1, 20, 14), o.bellyMat || topM, [0, th * 0.18, 0.01], [0, 0, 0], [w * 0.9 * bulk, th * 0.3, w * 0.75 * bulk]);
  torso.add(belly);
  // Neck + head
  const headR = o.headR ?? 0.27;
  const neckY = th * 1.02;
  const head = group(torso, [0, neckY + headR * 0.82, 0.02]);
  rig.head = head;
  rig.headR = headR;
  if (!o.noHead) {
    const hm = mesh(G.sphere(headR, 32, 24), o.headMat || skinM, [0, 0, 0], [0, 0, 0], [1, o.headSquash ?? 0.96, 0.98]);
    head.add(hm);
    rig.headMesh = hm;
  }
  // Arms
  const armLen = o.armLen ?? 0.34;
  const armR = o.armR ?? 0.07;
  const shoulderX = w * bulk * 0.95;
  const shoulderY = th * 0.86;
  const armM = o.armMat || topM;
  const handM = o.handMat || skinM;
  const mkArm = (side) => {
    const sh = group(torso, [side * shoulderX, shoulderY, 0], [0, 0, side * (o.armSpread ?? 0.12)]);
    sh.add(mesh(G.capsule(armR, armLen * 0.7), armM, [0, -armLen * 0.45, 0]));
    const hand = group(sh, [0, -armLen, 0.0]);
    hand.add(mesh(G.sphere(armR * (o.handScale ?? 1.25), 14, 10), handM));
    return { sh, hand };
  };
  const L = mkArm(-1);
  const R = mkArm(1);
  rig.armL = L.sh; rig.handL = L.hand;
  rig.armR = R.sh; rig.handR = R.hand;
  rig.back = group(torso, [0, th * 0.6, -w * 0.75]);
  rig.height = hipY + th + headR * 2 + 0.05;
  return rig;
}

// Big glossy chibi eyes.
export function eyes(rig, color = '#3a2414', o = {}) {
  const r = rig.headR;
  const glow = !!o.glow;
  const tex = eyeTexture(color, glow);
  const mat = glow
    ? rig.bank.basic(0xffffff, {})
    : new THREE.MeshBasicMaterial({ map: tex, transparent: true });
  if (glow) { mat.map = tex; mat.blending = THREE.AdditiveBlending; mat.depthWrite = false; mat.color.set(0xffffff); }
  if (!glow) rig.bank.list.push(mat);
  const sz = o.size ?? 0.34;
  const geo = new THREE.CircleGeometry(r * sz, 20);
  const spread = o.spread ?? 0.36;
  const y = o.y ?? -0.02;
  const count = o.count ?? 2;
  const out = [];
  const xs = count === 1 ? [0] : count === 4 ? [-spread * 1.1, -spread * 0.45, spread * 0.45, spread * 1.1] : [-spread, spread];
  for (const ex of xs) {
    const yy = count === 4 ? y + (Math.abs(ex) > spread ? 0.06 : -0.02) * r * 3 : y;
    const dir = new THREE.Vector3(ex, yy, 0.93).normalize();
    const e = new THREE.Mesh(geo, mat);
    e.position.copy(dir.multiplyScalar(r * 1.005));
    e.lookAt(e.position.clone().multiplyScalar(2));
    e.scale.set(o.wide ?? 1, o.tall ?? 1.15, 1);
    rig.head.add(e);
    out.push(e);
  }
  rig.eyes = out;
  if (o.brows) {
    const bm = rig.bank.std(o.brows, { rough: 0.9 });
    for (const ex of xs) {
      const b = mesh(G.capsule(r * 0.045, r * 0.22, 6), bm, [ex * r * 1.0, (y + 0.3) * r, r * 0.9], [0, 0, Math.PI / 2 + (ex > 0 ? -0.25 : 0.25) * (o.angry ? 1.6 : 0.6)]);
      rig.head.add(b);
    }
  }
  if (o.blush) {
    const bm = rig.bank.basic(0xff8a8a, { opacity: 0.35 });
    for (const ex of [-0.55, 0.55]) {
      const dir = new THREE.Vector3(ex, -0.32, 0.8).normalize();
      const b = new THREE.Mesh(new THREE.CircleGeometry(r * 0.13, 12), bm);
      b.position.copy(dir.multiplyScalar(r * 1.01));
      b.lookAt(b.position.clone().multiplyScalar(2));
      rig.head.add(b);
    }
  }
  return out;
}

export function mouth(rig, o = {}) {
  const r = rig.headR;
  const m = rig.bank.std(o.color ?? 0x5a2a2a, { rough: 0.8 });
  const geo = o.open ? G.sphere(r * 0.12, 12, 8) : G.capsule(r * 0.03, r * 0.14, 6);
  const me = mesh(geo, m, [0, -r * 0.42, r * 0.9], [0, 0, o.open ? 0 : Math.PI / 2], o.open ? [1.3, 0.8, 0.5] : 1);
  rig.head.add(me);
  return me;
}
