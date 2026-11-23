// The floating arena: sky-island, board, bench, trees, crystals, braziers and the shattered Starheart.
import * as THREE from 'three';
import { mergeGeometries, mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { CELLS, cellToWorld, benchToWorld, BENCH_SIZE, HEX_SIZE, cellRow } from '../core/hex.js';
import { stoneTexture, grassTexture, softDot, fbm, ringTexture, hexTileTexture, flagstoneTexture } from './textures.js';

const BOARD_Y = 0.42;

function hexShape(r) {
  const s = new THREE.Shape();
  for (let i = 0; i < 6; i++) {
    const a = Math.PI / 6 + (i * Math.PI) / 3;
    const x = Math.cos(a) * r;
    const y = Math.sin(a) * r;
    if (i === 0) s.moveTo(x, y);
    else s.lineTo(x, y);
  }
  s.closePath();
  return s;
}

function roundedRect(w, h, r) {
  const s = new THREE.Shape();
  s.moveTo(-w / 2 + r, -h / 2);
  s.lineTo(w / 2 - r, -h / 2);
  s.quadraticCurveTo(w / 2, -h / 2, w / 2, -h / 2 + r);
  s.lineTo(w / 2, h / 2 - r);
  s.quadraticCurveTo(w / 2, h / 2, w / 2 - r, h / 2);
  s.lineTo(-w / 2 + r, h / 2);
  s.quadraticCurveTo(-w / 2, h / 2, -w / 2, h / 2 - r);
  s.lineTo(-w / 2, -h / 2 + r);
  s.quadraticCurveTo(-w / 2, -h / 2, -w / 2 + r, -h / 2);
  return s;
}

// Wind sway for foliage and cloth, injected into standard materials.
export function addSway(mat, strength = 0.06, speed = 1.3, uniforms) {
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = uniforms.uTime;
    sh.vertexShader = 'uniform float uTime;\n' + sh.vertexShader.replace(
      '#include <begin_vertex>',
      `#include <begin_vertex>
       vec4 wp = modelMatrix * vec4(transformed, 1.0);
       float sw = sin(uTime*${speed.toFixed(2)} + wp.x*0.6 + wp.z*0.4) * ${strength.toFixed(3)} * max(0.0, position.y);
       transformed.x += sw; transformed.z += sw*0.6;`,
    );
  };
}

export class Arena {
  constructor(stage) {
    this.stage = stage;
    this.group = new THREE.Group();
    stage.scene.add(this.group);
    this.uniforms = { uTime: { value: 0 } };
    this.animated = [];
    this.buildIsland();
    this.buildBoard();
    this.buildBench();
    this.buildDecor();
    this.buildStarheart();
    this.buildMotes();
  }

  buildIsland() {
    const grass = grassTexture();
    grass.repeat.set(6, 6);
    // Plateau top
    const topGeo = new THREE.CircleGeometry(17, 96);
    topGeo.rotateX(-Math.PI / 2);
    const pos = topGeo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);
      const d = Math.sqrt(x * x + z * z);
      pos.setY(i, -0.05 + fbm(x * 0.2, z * 0.2, 3, 7) * 0.25 * Math.min(1, d / 8) - Math.max(0, d - 15.5) * 0.4);
    }
    topGeo.computeVertexNormals();
    const top = new THREE.Mesh(topGeo, new THREE.MeshStandardMaterial({ map: grass, roughness: 0.95, color: 0xffffff }));
    top.receiveShadow = true;
    this.group.add(top);

    // Flagstone plaza around the board.
    const flag = flagstoneTexture();
    flag.repeat.set(3.2, 3.2);
    const plazaGeo = new THREE.CircleGeometry(12.2, 72);
    plazaGeo.rotateX(-Math.PI / 2);
    const plaza = new THREE.Mesh(plazaGeo, new THREE.MeshStandardMaterial({ map: flag, roughness: 0.92, color: 0xd9cfc4 }));
    plaza.position.y = 0.02;
    plaza.receiveShadow = true;
    this.group.add(plaza);
    const curb = new THREE.Mesh(new THREE.TorusGeometry(12.2, 0.22, 6, 96), new THREE.MeshStandardMaterial({ color: 0x9a8f86, roughness: 0.9 }));
    curb.rotation.x = Math.PI / 2;
    curb.position.y = 0.05;
    curb.scale.z = 0.5;
    this.group.add(curb);

    // Rocky underside: a jagged lathe hanging below the plateau.
    const pts = [];
    const depth = 22;
    for (let i = 0; i <= 24; i++) {
      const t = i / 24;
      const r = 17 * Math.pow(1 - t, 0.75) * (1 - t * 0.15) + 0.2;
      pts.push(new THREE.Vector2(r, -t * depth));
    }
    const lathe = new THREE.LatheGeometry(pts, 96);
    const lp = lathe.attributes.position;
    const colors = [];
    const c1 = new THREE.Color(0x8a6a52);
    const c2 = new THREE.Color(0x4a3a40);
    const c3 = new THREE.Color(0x6f7a5a);
    for (let i = 0; i < lp.count; i++) {
      const x = lp.getX(i);
      const y = lp.getY(i);
      const z = lp.getZ(i);
      const ang = Math.atan2(z, x);
      const n = fbm(ang * 3 + 10, y * 0.25, 4, 3);
      const k = 1 + (n - 0.5) * 0.45 * Math.min(1, -y / 3);
      lp.setXYZ(i, x * k, y + (fbm(ang * 5, y * 0.1, 2, 4) - 0.5) * 1.2 * Math.min(1, -y / 4), z * k);
      const strata = 0.5 + 0.5 * Math.sin(y * 1.6 + n * 4);
      const col = c1.clone().lerp(c2, Math.min(1, -y / depth + strata * 0.25));
      if (y > -1.2) col.lerp(c3, 0.6);
      colors.push(col.r, col.g, col.b);
    }
    lathe.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    lathe.computeVertexNormals();
    const rock = new THREE.Mesh(lathe, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95, flatShading: true }));
    rock.position.y = -0.1;
    this.group.add(rock);

    // Grass lip around the edge.
    const lip = new THREE.Mesh(new THREE.TorusGeometry(16.6, 0.55, 8, 96), new THREE.MeshStandardMaterial({ color: 0x5e9a46, roughness: 1 }));
    lip.rotation.x = Math.PI / 2;
    lip.position.y = -0.35;
    lip.scale.z = 0.6;
    this.group.add(lip);

    // Hanging roots and vines.
    const rootMat = new THREE.MeshStandardMaterial({ color: 0x4d3a2a, roughness: 1 });
    for (let i = 0; i < 26; i++) {
      const a = (i / 26) * Math.PI * 2 + Math.sin(i * 7.3) * 0.1;
      const len = 3 + ((i * 37) % 7);
      const curve = new THREE.CatmullRomCurve3([
        new THREE.Vector3(Math.cos(a) * 16.2, -0.6, Math.sin(a) * 16.2),
        new THREE.Vector3(Math.cos(a) * 16.6, -len * 0.4, Math.sin(a) * 16.6),
        new THREE.Vector3(Math.cos(a + 0.03) * 16.1, -len, Math.sin(a + 0.03) * 16.1),
      ]);
      const root = new THREE.Mesh(new THREE.TubeGeometry(curve, 8, 0.12 - (i % 3) * 0.03, 5), rootMat);
      this.group.add(root);
    }
  }

  buildBoard() {
    const stone = stoneTexture([96, 104, 122], 256, 2, 5);
    // Board slab
    const slabGeo = new THREE.ExtrudeGeometry(roundedRect(14.6, 13.6, 1.2), { depth: 0.4, bevelEnabled: true, bevelSize: 0.25, bevelThickness: 0.2, bevelSegments: 3, curveSegments: 10 });
    slabGeo.rotateX(-Math.PI / 2);
    const slabTex = stoneTexture([70, 74, 88], 256, 5, 4);
    slabTex.repeat.set(0.12, 0.12);
    const slab = new THREE.Mesh(slabGeo, new THREE.MeshStandardMaterial({ map: slabTex, roughness: 0.9, color: 0xb7bccc }));
    slab.position.y = -0.38;
    slab.receiveShadow = true;
    slab.castShadow = true;
    this.group.add(slab);

    // Brass trim around the slab.
    const trimShape = roundedRect(15.4, 14.4, 1.5);
    trimShape.holes.push(roundedRect(14.9, 13.9, 1.3));
    const trimGeo = new THREE.ExtrudeGeometry(trimShape, { depth: 0.1, bevelEnabled: true, bevelSize: 0.04, bevelThickness: 0.04, bevelSegments: 2, curveSegments: 12 });
    trimGeo.rotateX(-Math.PI / 2);
    const trim = new THREE.Mesh(trimGeo, new THREE.MeshStandardMaterial({ color: 0xd8a85a, metalness: 0.9, roughness: 0.32 }));
    trim.position.y = 0.17;
    this.group.add(trim);

    // Hex tiles (instanced).
    const tileGeo = new THREE.ExtrudeGeometry(hexShape(HEX_SIZE * 0.9), { depth: 0.08, bevelEnabled: true, bevelSize: 0.06, bevelThickness: 0.06, bevelSegments: 2 });
    tileGeo.rotateX(-Math.PI / 2);
    const tileTex = hexTileTexture(256, [104, 116, 140], 4);
    tileTex.repeat.set(1 / 1.92, 1 / 1.92);
    tileTex.offset.set(0.5, 0.5);
    const tileMat = new THREE.MeshStandardMaterial({ map: tileTex, roughness: 0.72, metalness: 0.08 });
    this.tiles = new THREE.InstancedMesh(tileGeo, tileMat, CELLS);
    this.tiles.receiveShadow = true;
    this.baseTileColors = [];
    const m = new THREE.Matrix4();
    for (let i = 0; i < CELLS; i++) {
      const { x, z } = cellToWorld(i);
      m.makeTranslation(x, BOARD_Y - 0.14, z);
      this.tiles.setMatrixAt(i, m);
      const home = cellRow(i) < 4;
      const jitter = 0.92 + ((i * 7919) % 13) / 100;
      const col = home ? new THREE.Color(0.72, 0.84, 1.02) : new THREE.Color(1.0, 0.74, 0.78);
      col.multiplyScalar(jitter);
      this.baseTileColors.push(col);
      this.tiles.setColorAt(i, col);
    }
    this.group.add(this.tiles);

    // Glowing hex outlines used for hover and drop targets.
    const ringGeo = new THREE.RingGeometry(HEX_SIZE * 0.78, HEX_SIZE * 0.92, 6, 1);
    ringGeo.rotateZ(Math.PI / 6);
    ringGeo.rotateX(-Math.PI / 2);
    this.rings = [];
    for (let i = 0; i < CELLS; i++) {
      const mat = new THREE.MeshBasicMaterial({ color: 0x7fe8ff, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending });
      const r = new THREE.Mesh(ringGeo, mat);
      const { x, z } = cellToWorld(i);
      r.position.set(x, BOARD_Y + 0.015, z);
      r.renderOrder = 2;
      this.group.add(r);
      this.rings.push(r);
    }

    // Faint shard-light line between the two halves.
    const line = new THREE.Mesh(new THREE.PlaneGeometry(13.2, 0.07), new THREE.MeshBasicMaterial({ color: new THREE.Color(0x9fe6ff).multiplyScalar(2), transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false }));
    line.rotation.x = -Math.PI / 2;
    line.position.set(0, BOARD_Y - 0.12, 0);
    this.group.add(line);
    this.midline = line;

    // Rune stones along the board edge.
    const runeMat = new THREE.MeshStandardMaterial({ color: 0x2b3350, emissive: 0x58c8ff, emissiveIntensity: 2.6, roughness: 0.4 });
    this.runeMat = runeMat;
    const runeGeo = new THREE.OctahedronGeometry(0.16, 0);
    for (let i = 0; i < 16; i++) {
      const side = i < 8 ? -1 : 1;
      const k = (i % 8) / 7;
      const r = new THREE.Mesh(runeGeo, runeMat);
      r.position.set(side * 7.55, 0.48, -5.8 + k * 11.6);
      r.scale.y = 1.8;
      this.group.add(r);
      this.animated.push((t) => { r.rotation.y = t * 0.8 + i; r.position.y = 0.5 + Math.sin(t * 1.4 + i) * 0.05; });
    }
  }

  buildBench() {
    const ledgeGeo = new THREE.ExtrudeGeometry(roundedRect(15.6, 2.3, 0.8), { depth: 0.3, bevelEnabled: true, bevelSize: 0.15, bevelThickness: 0.12, bevelSegments: 3 });
    ledgeGeo.rotateX(-Math.PI / 2);
    const tex = stoneTexture([84, 80, 90], 256, 9, 4);
    tex.repeat.set(0.15, 0.15);
    const ledge = new THREE.Mesh(ledgeGeo, new THREE.MeshStandardMaterial({ map: tex, roughness: 0.9, color: 0xb8b0c0 }));
    const bz = benchToWorld(0).z;
    ledge.position.set(0, -0.1, bz);
    ledge.receiveShadow = true;
    this.group.add(ledge);
    const padGeo = new THREE.ExtrudeGeometry(roundedRect(1.35, 1.35, 0.3), { depth: 0.08, bevelEnabled: true, bevelSize: 0.05, bevelThickness: 0.05, bevelSegments: 2 });
    padGeo.rotateX(-Math.PI / 2);
    const padMat = new THREE.MeshStandardMaterial({ color: 0x3a4258, roughness: 0.6, metalness: 0.2 });
    this.benchRings = [];
    const ringGeo = new THREE.RingGeometry(0.58, 0.68, 4, 1);
    ringGeo.rotateZ(Math.PI / 4);
    ringGeo.rotateX(-Math.PI / 2);
    for (let i = 0; i < BENCH_SIZE; i++) {
      const p = benchToWorld(i);
      const pad = new THREE.Mesh(padGeo, padMat);
      pad.position.set(p.x, 0.26, p.z);
      pad.receiveShadow = true;
      this.group.add(pad);
      const r = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ color: 0xffd27a, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false }));
      r.position.set(p.x, 0.42, p.z);
      this.group.add(r);
      this.benchRings.push(r);
    }
  }

  tree(x, z, s = 1, hue = 0) {
    const g = new THREE.Group();
    const trunkMat = new THREE.MeshStandardMaterial({ color: 0x6b4a34, roughness: 1 });
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.38, 2.6, 7), trunkMat);
    trunk.position.y = 1.3;
    trunk.castShadow = true;
    g.add(trunk);
    const palette = [[0x6fcf5a, 0x3f8f3a], [0xf2a0c8, 0xc86a9a], [0xf2c25a, 0xc8843a]][hue];
    const leafMat = new THREE.MeshStandardMaterial({ color: palette[0], roughness: 0.85, flatShading: false });
    addSway(leafMat, 0.05, 1.1, this.uniforms);
    const blobs = [[0, 3.1, 0, 1.4], [0.9, 2.7, 0.3, 1.0], [-0.8, 2.8, -0.2, 1.05], [0.2, 3.8, -0.3, 1.0], [-0.3, 2.5, 0.8, 0.9]];
    const geos = [];
    for (const [bx, by, bz, br] of blobs) {
      const geo = new THREE.IcosahedronGeometry(br, 2);
      const p = geo.attributes.position;
      for (let i = 0; i < p.count; i++) {
        const vx = p.getX(i); const vy = p.getY(i); const vz = p.getZ(i);
        const n = 1 + (fbm(vx * 2 + bx, vy * 2 + vz, 2, 5) - 0.5) * 0.25;
        p.setXYZ(i, vx * n + bx, vy * n * 0.85 + by, vz * n + bz);
      }
      geos.push(geo);
    }
    let merged = mergeGeometries(geos.map((gg) => { gg.deleteAttribute('normal'); gg.deleteAttribute('uv'); return mergeVertices(gg); }));
    merged.computeVertexNormals();
    const cols = [];
    const p = merged.attributes.position;
    const dark = new THREE.Color(palette[1]);
    const light = new THREE.Color(palette[0]).lerp(new THREE.Color(0xffffcc), 0.25);
    for (let i = 0; i < p.count; i++) {
      const t = THREE.MathUtils.clamp((p.getY(i) - 1.8) / 2.6, 0, 1);
      const c = dark.clone().lerp(light, t);
      cols.push(c.r, c.g, c.b);
    }
    merged.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
    leafMat.vertexColors = true;
    leafMat.color.set(0xffffff);
    const leaves = new THREE.Mesh(merged, leafMat);
    leaves.castShadow = true;
    g.add(leaves);
    g.position.set(x, 0, z);
    g.scale.setScalar(s);
    g.rotation.y = x * 1.3;
    this.group.add(g);
    return g;
  }

  crystalCluster(x, z, color, s = 1, light = false) {
    const g = new THREE.Group();
    const mat = new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 1.2, roughness: 0.18, metalness: 0.2 });
    const base = new THREE.Mesh(new THREE.DodecahedronGeometry(0.8, 0), new THREE.MeshStandardMaterial({ color: 0x5a5560, roughness: 1, flatShading: true }));
    base.scale.set(1.3, 0.5, 1.1);
    base.castShadow = true;
    g.add(base);
    const n = 5;
    for (let i = 0; i < n; i++) {
      const geo = new THREE.OctahedronGeometry(0.4, 0);
      geo.scale(1, 3 + (i % 3), 1);
      const c = new THREE.Mesh(geo, mat);
      const a = (i / n) * Math.PI * 2;
      c.position.set(Math.cos(a) * 0.45 * (i ? 1 : 0), 0.9 + (i ? 0 : 0.5), Math.sin(a) * 0.45 * (i ? 1 : 0));
      c.rotation.set(Math.cos(a) * 0.4 * (i ? 1 : 0), a, Math.sin(a) * 0.4 * (i ? 1 : 0));
      c.castShadow = true;
      g.add(c);
    }
    g.position.set(x, 0, z);
    g.scale.setScalar(s);
    this.group.add(g);
    this.animated.push((t) => { mat.emissiveIntensity = 1.3 + Math.sin(t * 2 + x) * 0.5; });
    if (light) {
      const pl = new THREE.PointLight(color, 14, 9, 2);
      pl.position.set(x, 2, z);
      this.group.add(pl);
    }
    return g;
  }

  brazier(x, z) {
    const g = new THREE.Group();
    const stoneMat = new THREE.MeshStandardMaterial({ color: 0x6a6470, roughness: 0.9 });
    const pillar = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.42, 1.4, 8), stoneMat);
    pillar.position.y = 0.7;
    pillar.castShadow = true;
    g.add(pillar);
    const bowl = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.32, 0.4, 12, 1, true), new THREE.MeshStandardMaterial({ color: 0xc8904a, metalness: 0.85, roughness: 0.35, side: THREE.DoubleSide }));
    bowl.position.y = 1.55;
    g.add(bowl);
    const coal = new THREE.Mesh(new THREE.CircleGeometry(0.55, 12), new THREE.MeshBasicMaterial({ color: 0xff8a3a }));
    coal.rotation.x = -Math.PI / 2;
    coal.position.y = 1.62;
    g.add(coal);
    // Flame sprites
    const flameTex = softDot();
    const flames = [];
    for (let i = 0; i < 7; i++) {
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: flameTex, color: new THREE.Color(i < 3 ? 0xffe08a : 0xff7a2e).multiplyScalar(2.2), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
      sp.position.y = 1.8;
      g.add(sp);
      flames.push({ sp, ph: i * 0.9 });
    }
    const pl = new THREE.PointLight(0xff9a4a, z < 0 ? 10 : 0, 7, 2);
    pl.position.y = 2.3;
    if (z < 0) g.add(pl);
    g.position.set(x, 0, z);
    this.group.add(g);
    this.animated.push((t) => {
      for (const f of flames) {
        const k = ((t * 1.6 + f.ph) % 1);
        f.sp.position.set(Math.sin(f.ph * 3 + t * 3) * 0.12, 1.75 + k * 1.1, Math.cos(f.ph * 2 + t * 2.4) * 0.12);
        const s = (1 - k) * 0.9 + 0.2;
        f.sp.scale.set(s, s * 1.3, s);
        f.sp.material.opacity = (1 - k) * 0.9;
      }
      pl.intensity = 9 + Math.sin(t * 13) * 1.2 + Math.sin(t * 7.3) * 1.0;
    });
  }

  banner(x, z, color) {
    const g = new THREE.Group();
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.09, 5.2, 8), new THREE.MeshStandardMaterial({ color: 0x3a2a20, roughness: 0.8 }));
    pole.position.y = 2.6;
    pole.castShadow = true;
    g.add(pole);
    const tip = new THREE.Mesh(new THREE.OctahedronGeometry(0.2, 0), new THREE.MeshStandardMaterial({ color: 0xe8c070, metalness: 0.9, roughness: 0.25 }));
    tip.position.y = 5.35;
    tip.scale.y = 1.8;
    g.add(tip);
    const clothGeo = new THREE.PlaneGeometry(1.4, 3, 6, 12);
    clothGeo.translate(0.72, -1.5, 0);
    const clothMat = new THREE.MeshStandardMaterial({ color, roughness: 0.7, side: THREE.DoubleSide });
    clothMat.onBeforeCompile = (sh) => {
      sh.uniforms.uTime = this.uniforms.uTime;
      sh.vertexShader = 'uniform float uTime;\n' + sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
        float k = position.x / 1.4;
        transformed.z += sin(uTime*2.2 + position.x*2.5 + position.y*0.8) * 0.22 * k;
        transformed.x -= abs(sin(uTime*1.3 + position.y)) * 0.05 * k;`);
    };
    const cloth = new THREE.Mesh(clothGeo, clothMat);
    cloth.position.set(0.05, 5.0, 0);
    cloth.castShadow = true;
    g.add(cloth);
    // Emblem
    const emb = new THREE.Mesh(new THREE.CircleGeometry(0.36, 6), new THREE.MeshStandardMaterial({ color: 0xffe2a0, emissive: 0xffc860, emissiveIntensity: 0.6, metalness: 0.6, roughness: 0.3, side: THREE.DoubleSide }));
    emb.position.set(0.77, 3.7, 0.02);
    g.add(emb);
    g.position.set(x, 0, z);
    this.group.add(g);
    return g;
  }

  buildDecor() {
    // Trees around the edge, kept out of the camera's view of the board.
    this.tree(-12.6, -6.5, 1.25, 0);
    this.tree(12.8, -7.2, 1.35, 1);
    this.tree(-10.5, -11.5, 1.1, 2);
    this.tree(10.0, -12.2, 1.05, 0);
    this.tree(-14.2, 1.5, 0.95, 1);
    this.tree(14.4, 0.5, 1.0, 0);
    this.tree(-4.5, -14.0, 1.2, 0);
    this.tree(5.5, -14.3, 1.1, 2);
    // Crystal clusters in faction colours.
    this.crystalCluster(-9.6, -9.0, 0xff7a2e, 1.1, true);
    this.crystalCluster(9.4, -9.4, 0x2fd0c8, 1.1, true);
    this.crystalCluster(-11.2, 6.5, 0xa065ff, 0.9);
    this.crystalCluster(11.4, 6.0, 0x8fdcff, 0.9);
    this.crystalCluster(-1.5, -12.6, 0x66d65a, 0.8);
    this.crystalCluster(2.0, -12.9, 0xffbf3c, 0.85);
    // Braziers at the four corners of the board.
    this.brazier(-8.6, -7.6);
    this.brazier(8.6, -7.6);
    this.brazier(-8.9, 5.6);
    this.brazier(8.9, 5.6);
    this.banner(-6.2, -9.8, 0x2a5aa8);
    this.banner(5.4, -9.8, 0xa83a3a);
    // Floating rocks around the island.
    const rockMat = new THREE.MeshStandardMaterial({ color: 0x8a7a6a, roughness: 1, flatShading: true });
    const grassMat = new THREE.MeshStandardMaterial({ color: 0x6aa84e, roughness: 1, flatShading: true });
    const spots = [[-26, 4, -18, 2.4], [28, -2, -24, 3.2], [-34, 8, -44, 4.5], [36, 10, -52, 5], [-20, -6, 14, 1.6], [24, -4, 10, 1.8], [0, 14, -70, 6]];
    for (const [x, y, z, s] of spots) {
      const g = new THREE.Group();
      const rk = new THREE.Mesh(new THREE.ConeGeometry(1, 2.2, 7, 2), rockMat);
      rk.rotation.x = Math.PI;
      rk.position.y = -1.1;
      g.add(rk);
      const gr = new THREE.Mesh(new THREE.CylinderGeometry(1.05, 1, 0.3, 7), grassMat);
      g.add(gr);
      g.position.set(x, y, z);
      g.scale.setScalar(s);
      this.group.add(g);
      this.animated.push((t) => { g.position.y = y + Math.sin(t * 0.4 + x) * 0.6; g.rotation.y = t * 0.03 + x; });
    }
  }

  buildStarheart() {
    const g = new THREE.Group();
    const coreMat = new THREE.MeshStandardMaterial({ color: 0xfff1c8, emissive: 0xffd27a, emissiveIntensity: 3.2, roughness: 0.2 });
    const core = new THREE.Mesh(new THREE.IcosahedronGeometry(3.2, 0), coreMat);
    g.add(core);
    const colors = [0xff7a2e, 0x2fd0c8, 0x66d65a, 0xa065ff, 0xffbf3c, 0x8fdcff];
    const shards = [];
    for (let i = 0; i < 18; i++) {
      const c = colors[i % 6];
      const m = new THREE.Mesh(new THREE.OctahedronGeometry(0.9 + (i % 4) * 0.35, 0), new THREE.MeshStandardMaterial({ color: c, emissive: c, emissiveIntensity: 2.4, roughness: 0.2 }));
      m.scale.y = 2.2;
      g.add(m);
      shards.push({ m, r: 6 + (i % 5) * 1.6, a: (i / 18) * Math.PI * 2, y: ((i * 53) % 11) - 5, s: 0.15 + (i % 3) * 0.06 });
    }
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: softDot(128), color: 0xffd8a0, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.85, fog: false }));
    glow.scale.set(34, 34, 1);
    g.add(glow);
    const ring = new THREE.Mesh(new THREE.PlaneGeometry(26, 26), new THREE.MeshBasicMaterial({ map: ringTexture(256, 0.05), color: 0xffe0a8, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, side: THREE.DoubleSide }));
    ring.rotation.x = Math.PI / 2.4;
    g.add(ring);
    g.position.set(-6, 34, -95);
    g.traverse((o) => { if (o.material) o.material.fog = false; });
    this.group.add(g);
    this.animated.push((t) => {
      core.rotation.y = t * 0.15;
      core.rotation.x = t * 0.07;
      coreMat.emissiveIntensity = 3 + Math.sin(t * 1.5) * 0.4;
      ring.rotation.z = t * 0.05;
      for (const s of shards) {
        const a = s.a + t * s.s;
        s.m.position.set(Math.cos(a) * s.r, s.y + Math.sin(t * 0.5 + s.a) * 0.6, Math.sin(a) * s.r * 0.6);
        s.m.rotation.y = t * 0.5 + s.a;
      }
    });
  }

  buildMotes() {
    const n = 220;
    const geo = new THREE.BufferGeometry();
    const pos = new Float32Array(n * 3);
    const seed = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 36;
      pos[i * 3 + 1] = Math.random() * 10;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 34 - 2;
      seed[i] = Math.random();
    }
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('seed', new THREE.BufferAttribute(seed, 1));
    const mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      uniforms: { uTime: this.uniforms.uTime, uTex: { value: softDot() }, uScale: { value: 260 } },
      vertexShader: `attribute float seed; uniform float uTime; uniform float uScale; varying float vA; varying vec3 vC;
        void main(){ vec3 p = position; float t = uTime*0.25 + seed*20.0;
          p.y = mod(position.y + uTime*(0.25+seed*0.35), 10.0);
          p.x += sin(t*1.3)*0.6; p.z += cos(t)*0.6;
          vA = smoothstep(0.0,1.5,p.y)*smoothstep(10.0,7.0,p.y)*(0.5+0.5*sin(uTime*3.0+seed*40.0));
          vC = mix(vec3(1.0,0.85,0.5), vec3(0.6,0.9,1.0), step(0.6, seed));
          vec4 mv = modelViewMatrix*vec4(p,1.0); gl_Position = projectionMatrix*mv; gl_PointSize = uScale*(0.05+seed*0.05)/-mv.z; }`,
      fragmentShader: `uniform sampler2D uTex; varying float vA; varying vec3 vC; void main(){ vec4 t = texture2D(uTex, gl_PointCoord); gl_FragColor = vec4(vC, t.a*vA*0.9); }`,
    });
    this.motes = new THREE.Points(geo, mat);
    this.group.add(this.motes);
  }

  // ───────────── interaction feedback ─────────────
  setCellGlow(cell, color, opacity) {
    const r = this.rings[cell];
    if (!r) return;
    r.material.color.set(color);
    r.material.opacity = opacity;
  }
  clearGlows() {
    for (const r of this.rings) r.material.opacity = 0;
    for (const r of this.benchRings) r.material.opacity = 0;
  }
  setBenchGlow(slot, color, opacity) {
    const r = this.benchRings[slot];
    if (!r) return;
    r.material.color.set(color);
    r.material.opacity = opacity;
  }
  setHomeHalfVisible(showEnemyTint) {
    this.midline.material.opacity = showEnemyTint ? 0.8 : 0.45;
  }

  update(dt, t) {
    this.uniforms.uTime.value = t;
    for (const f of this.animated) f(t);
  }
}

export { BOARD_Y };
