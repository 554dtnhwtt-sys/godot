// Particles, projectiles, shockwaves, beams and light flashes.
import * as THREE from 'three';
import { softDot, ringTexture, sparkle } from './textures.js';

const MAX = 2600;

export class VFX {
  constructor(scene) {
    this.scene = scene;
    // GPU particle buffer (CPU simulated)
    const geo = new THREE.BufferGeometry();
    this.pos = new Float32Array(MAX * 3);
    this.col = new Float32Array(MAX * 3);
    this.size = new Float32Array(MAX);
    this.alpha = new Float32Array(MAX);
    geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('psize', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setDrawRange(0, 0);
    this.geo = geo;
    const mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      uniforms: { uTex: { value: softDot(64) }, uScale: { value: 600 } },
      vertexShader: `attribute float psize; attribute float alpha; attribute vec3 color; varying float vA; varying vec3 vC; uniform float uScale;
        void main(){ vA = alpha; vC = color; vec4 mv = modelViewMatrix*vec4(position,1.0); gl_Position = projectionMatrix*mv; gl_PointSize = psize*uScale/-mv.z; }`,
      fragmentShader: `uniform sampler2D uTex; varying float vA; varying vec3 vC; void main(){ vec4 t = texture2D(uTex, gl_PointCoord); gl_FragColor = vec4(vC*2.4, t.a*vA); }`,
    });
    this.points = new THREE.Points(geo, mat);
    this.points.frustumCulled = false;
    this.points.renderOrder = 10;
    scene.add(this.points);
    this.parts = [];
    this.effects = [];
    this.ringTex = ringTexture(256, 0.06);
    this.sparkTex = sparkle(64);
    this.dotTex = softDot(64);
    this.lights = [];
    for (let i = 0; i < 4; i++) {
      const l = new THREE.PointLight(0xffffff, 0, 6, 2);
      l.userData.t = 0;
      scene.add(l);
      this.lights.push(l);
    }
    this.tmp = new THREE.Color();
  }

  emit(p) {
    if (this.parts.length >= MAX) return;
    this.parts.push(p);
  }

  burst(pos, color, o = {}) {
    const n = o.n ?? 16;
    const c = new THREE.Color(color);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const up = o.up ?? 0.6;
      const sp = (o.speed ?? 3) * (0.4 + Math.random() * 0.8);
      const el = (Math.random() * 2 - 1) * 0.8 + up;
      this.emit({
        x: pos.x + (Math.random() - 0.5) * (o.spread ?? 0.1), y: pos.y + (Math.random() - 0.5) * (o.spread ?? 0.1), z: pos.z + (Math.random() - 0.5) * (o.spread ?? 0.1),
        vx: Math.cos(a) * sp * (o.flat ? 1 : 0.8), vy: el * sp * (o.flat ? 0.15 : 1), vz: Math.sin(a) * sp * (o.flat ? 1 : 0.8),
        life: 0, max: (o.life ?? 0.6) * (0.6 + Math.random() * 0.6), size: (o.size ?? 0.35) * (0.6 + Math.random() * 0.8),
        r: c.r, g: c.g, b: c.b, grav: o.gravity ?? 4, drag: o.drag ?? 2.5, shrink: o.shrink ?? 1,
      });
    }
  }

  rise(pos, color, o = {}) {
    const n = o.n ?? 14;
    const c = new THREE.Color(color);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const r = (o.radius ?? 0.5) * Math.sqrt(Math.random());
      this.emit({
        x: pos.x + Math.cos(a) * r, y: pos.y + Math.random() * 0.3, z: pos.z + Math.sin(a) * r,
        vx: 0, vy: (o.speed ?? 1.6) * (0.5 + Math.random()), vz: 0,
        life: -Math.random() * (o.stagger ?? 0.25), max: (o.life ?? 0.9), size: (o.size ?? 0.25) * (0.6 + Math.random() * 0.8),
        r: c.r, g: c.g, b: c.b, grav: -0.5, drag: 0.5, shrink: 0.6,
      });
    }
  }

  trail(pos, color, size = 0.25, life = 0.35) {
    const c = new THREE.Color(color);
    this.emit({ x: pos.x + (Math.random() - 0.5) * 0.05, y: pos.y + (Math.random() - 0.5) * 0.05, z: pos.z + (Math.random() - 0.5) * 0.05, vx: 0, vy: 0.2, vz: 0, life: 0, max: life, size, r: c.r, g: c.g, b: c.b, grav: 0, drag: 1, shrink: 1 });
  }

  light(pos, color, intensity = 18, dur = 0.35, dist = 7) {
    let l = this.lights.find((x) => x.userData.t <= 0) || this.lights.reduce((a, b) => (a.userData.t < b.userData.t ? a : b));
    l.position.copy(pos);
    l.position.y += 0.6;
    l.color.set(color);
    l.distance = dist;
    l.userData.t = dur;
    l.userData.dur = dur;
    l.userData.i = intensity;
    l.intensity = intensity;
  }

  ring(pos, color, radius = 1.5, dur = 0.5, o = {}) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), new THREE.MeshBasicMaterial({ map: this.ringTex, color: new THREE.Color(color).multiplyScalar(2.2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    m.rotation.x = -Math.PI / 2;
    m.position.set(pos.x, (o.y ?? pos.y) + 0.06, pos.z);
    m.renderOrder = 5;
    this.scene.add(m);
    this.effects.push({ obj: m, t: 0, dur, update: (k) => { const s = 0.2 + (o.ease === false ? k : 1 - Math.pow(1 - k, 3)) * radius; m.scale.set(s, s, s); m.material.opacity = (1 - k) * (o.opacity ?? 1); } });
  }

  disc(pos, color, radius, dur, o = {}) {
    const m = new THREE.Mesh(new THREE.CircleGeometry(1, 40), new THREE.MeshBasicMaterial({ map: this.dotTex, color: new THREE.Color(color).multiplyScalar(2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    m.rotation.x = -Math.PI / 2;
    m.position.set(pos.x, pos.y + 0.05, pos.z);
    m.scale.setScalar(radius);
    this.scene.add(m);
    this.effects.push({ obj: m, t: 0, dur, update: (k) => { m.material.opacity = Math.sin(k * Math.PI) * (o.opacity ?? 0.8); } });
  }

  pillar(pos, color, height = 6, dur = 1.0, width = 0.9) {
    const geo = new THREE.CylinderGeometry(width * 0.6, width, height, 24, 1, true);
    geo.translate(0, height / 2, 0);
    const m = new THREE.Mesh(geo, new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
      uniforms: { uC: { value: new THREE.Color(color) }, uA: { value: 1 } },
      vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0);} `,
      fragmentShader: `uniform vec3 uC; uniform float uA; varying vec2 vUv; void main(){ float a = (1.0-vUv.y) * (0.5+0.5*sin(vUv.x*40.0)) * uA; gl_FragColor = vec4(uC*2.6, a*0.7); }`,
    }));
    m.position.copy(pos);
    this.scene.add(m);
    this.effects.push({ obj: m, t: 0, dur, update: (k) => { m.material.uniforms.uA.value = Math.sin(Math.min(1, k * 1.4) * Math.PI); m.scale.set(1 + k * 0.3, 1, 1 + k * 0.3); m.rotation.y = k * 2; } });
  }

  sphereFlash(pos, color, radius = 1, dur = 0.4) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 14), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(2.2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    m.position.copy(pos);
    this.scene.add(m);
    this.effects.push({ obj: m, t: 0, dur, update: (k) => { m.scale.setScalar(radius * (0.3 + k * 0.9)); m.material.opacity = (1 - k) * 0.7; } });
  }

  bubble(target, color, dur = 3) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(0.85, 24, 16), new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      uniforms: { uC: { value: new THREE.Color(color) }, uA: { value: 1 } },
      vertexShader: `varying vec3 vN; varying vec3 vV; void main(){ vN = normalize(normalMatrix*normal); vec4 mv = modelViewMatrix*vec4(position,1.0); vV = normalize(-mv.xyz); gl_Position = projectionMatrix*mv; }`,
      fragmentShader: `uniform vec3 uC; uniform float uA; varying vec3 vN; varying vec3 vV; void main(){ float f = pow(1.0-abs(dot(vN,vV)),2.5); gl_FragColor = vec4(uC*1.8, (f*0.8+0.06)*uA); }`,
    }));
    this.scene.add(m);
    this.effects.push({ obj: m, t: 0, dur, update: (k) => {
      const p = target.root.position;
      m.position.set(p.x, p.y + 0.75 * target.root.scale.x, p.z);
      m.scale.setScalar(target.root.scale.x * (k < 0.1 ? k / 0.1 : 1));
      m.material.uniforms.uA.value = k > 0.85 ? (1 - k) / 0.15 : 1;
      if (target.dead) m.material.uniforms.uA.value = 0;
    } });
  }

  // A moving projectile. kind: arrow | icearrow | fireball | bomb | cannonball | bolt | bullet
  projectile(from, to, o = {}) {
    const kind = o.kind || 'bolt';
    const color = new THREE.Color(o.color || 0xffffff);
    let obj;
    if (kind === 'arrow' || kind === 'icearrow') {
      obj = new THREE.Group();
      const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.7, 5), new THREE.MeshBasicMaterial({ color: kind === 'icearrow' ? 0xcff4ff : 0xe8d2a0 }));
      shaft.rotation.x = Math.PI / 2;
      obj.add(shaft);
      const head = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.16, 6), new THREE.MeshBasicMaterial({ color: kind === 'icearrow' ? 0x9fe6ff : 0xdddddd }));
      head.rotation.x = Math.PI / 2;
      head.position.z = 0.42;
      obj.add(head);
    } else if (kind === 'bomb' || kind === 'cannonball') {
      obj = new THREE.Mesh(new THREE.SphereGeometry(kind === 'bomb' ? 0.14 : 0.16, 12, 8), new THREE.MeshStandardMaterial({ color: 0x2a2a30, roughness: 0.4, metalness: 0.5 }));
    } else {
      const s = kind === 'fireball' ? 0.9 : kind === 'bullet' ? 0.35 : 0.55;
      obj = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.dotTex, color: color.clone().multiplyScalar(2.5), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
      obj.scale.set(s, s, s);
      const core = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.dotTex, color: new THREE.Color(3, 3, 3), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
      core.scale.set(0.45, 0.45, 0.45);
      obj.add(core);
    }
    this.scene.add(obj);
    const dur = o.dur ?? 0.25;
    const arc = o.arc ?? (kind === 'bomb' || kind === 'cannonball' ? 2.2 : 0);
    const p0 = from.clone();
    const prev = new THREE.Vector3();
    this.effects.push({ obj, t: 0, dur, update: (k) => {
      const tgt = typeof to === 'function' ? to() : to;
      prev.copy(obj.position);
      obj.position.lerpVectors(p0, tgt, k);
      obj.position.y += Math.sin(k * Math.PI) * arc;
      if (kind === 'arrow' || kind === 'icearrow') obj.lookAt(tgt.x, tgt.y + Math.cos(k * Math.PI) * arc * 0.5, tgt.z);
      if (kind !== 'arrow' && kind !== 'bullet') this.trail(obj.position, color, kind === 'fireball' ? 0.5 : 0.28, kind === 'fireball' ? 0.4 : 0.25);
      if (kind === 'icearrow') this.trail(obj.position, color, 0.25, 0.3);
      if (kind === 'bomb' && Math.random() < 0.6) this.trail(obj.position.clone().add(new THREE.Vector3(0, 0.16, 0)), 0x9ff0ff, 0.18, 0.2);
    }, done: () => { if (o.onArrive) o.onArrive(typeof to === 'function' ? to() : to); } });
  }

  // Lightning / energy beam between two points.
  beam(from, to, color, dur = 0.25, o = {}) {
    const segs = o.jagged ? 10 : 2;
    const pts = [];
    for (let i = 0; i <= segs; i++) pts.push(new THREE.Vector3());
    const g = new THREE.BufferGeometry().setFromPoints(pts);
    const width = o.width ?? 0.12;
    const group = new THREE.Group();
    const line = new THREE.Line(g, new THREE.LineBasicMaterial({ color: new THREE.Color(3, 3, 3), transparent: true, blending: THREE.AdditiveBlending }));
    group.add(line);
    const glowSprites = [];
    for (let i = 0; i < segs * 2; i++) {
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.dotTex, color: new THREE.Color(color).multiplyScalar(2.4), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
      sp.scale.setScalar(width * 4);
      group.add(sp);
      glowSprites.push(sp);
    }
    this.scene.add(group);
    const reshape = () => {
      const a = typeof from === 'function' ? from() : from;
      const b = typeof to === 'function' ? to() : to;
      const arr = g.attributes.position.array;
      for (let i = 0; i <= segs; i++) {
        const k = i / segs;
        const j = o.jagged && i > 0 && i < segs ? 0.25 : 0;
        arr[i * 3] = a.x + (b.x - a.x) * k + (Math.random() - 0.5) * j;
        arr[i * 3 + 1] = a.y + (b.y - a.y) * k + (Math.random() - 0.5) * j;
        arr[i * 3 + 2] = a.z + (b.z - a.z) * k + (Math.random() - 0.5) * j;
      }
      g.attributes.position.needsUpdate = true;
      glowSprites.forEach((sp, i) => {
        const k = i / (glowSprites.length - 1);
        sp.position.set(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k);
      });
    };
    this.effects.push({ obj: group, t: 0, dur, update: (k) => {
      if (o.jagged || typeof from === 'function') reshape();
      else if (k === 0 || !group.userData.shaped) { reshape(); group.userData.shaped = true; }
      const a = 1 - k;
      line.material.opacity = a;
      for (const sp of glowSprites) sp.material.opacity = a * 0.9;
    } });
  }

  // Ground-level slam: ring + dust + debris.
  slam(pos, color, radius = 1.5) {
    this.ring(pos, color, radius * 1.4, 0.55);
    this.ring(pos, 0xffffff, radius, 0.35, { opacity: 0.6 });
    this.burst(pos, color, { n: 26, speed: 4.5, flat: true, life: 0.6, size: 0.4, gravity: 2 });
    this.burst(pos, 0xcab49a, { n: 14, speed: 2, up: 1, life: 0.8, size: 0.6, gravity: 3 });
    this.light(pos, color, 22, 0.35);
  }

  explosion(pos, color, radius = 1) {
    this.sphereFlash(pos.clone().add(new THREE.Vector3(0, 0.4, 0)), color, radius * 1.1, 0.35);
    this.ring(pos, color, radius * 1.8, 0.5);
    this.burst(pos.clone().add(new THREE.Vector3(0, 0.4, 0)), color, { n: 30, speed: 5, life: 0.55, size: 0.45, gravity: 5 });
    this.burst(pos.clone().add(new THREE.Vector3(0, 0.3, 0)), 0xffffff, { n: 8, speed: 3, life: 0.3, size: 0.3 });
    this.light(pos, color, 26, 0.4);
  }

  heal(pos, color = 0x7dff9a) {
    this.rise(pos, color, { n: 14, radius: 0.45, speed: 1.6, size: 0.28, life: 0.9 });
    this.ring(pos, color, 1.0, 0.6, { opacity: 0.7 });
  }

  update(dt) {
    // particles
    const P = this.parts;
    let n = 0;
    for (let i = 0; i < P.length; i++) {
      const p = P[i];
      p.life += dt;
      if (p.life >= p.max) continue;
      if (p.life >= 0) {
        p.vy -= p.grav * dt;
        const d = Math.exp(-p.drag * dt);
        p.vx *= d; p.vy *= d; p.vz *= d;
        p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
        if (p.y < 0.45 && p.grav > 0) { p.y = 0.45; p.vy *= -0.3; }
      }
      const k = Math.max(0, p.life) / p.max;
      this.pos[n * 3] = p.x; this.pos[n * 3 + 1] = p.y; this.pos[n * 3 + 2] = p.z;
      this.col[n * 3] = p.r; this.col[n * 3 + 1] = p.g; this.col[n * 3 + 2] = p.b;
      this.size[n] = p.size * (1 - k * p.shrink * 0.8);
      this.alpha[n] = p.life < 0 ? 0 : (k < 0.15 ? k / 0.15 : 1 - (k - 0.15) / 0.85);
      P[n] = p;
      n++;
    }
    P.length = n;
    this.geo.setDrawRange(0, n);
    for (const key of ['position', 'color', 'psize', 'alpha']) this.geo.attributes[key].needsUpdate = true;
    // effects
    for (let i = this.effects.length - 1; i >= 0; i--) {
      const e = this.effects[i];
      e.t += dt;
      const k = Math.min(1, e.t / e.dur);
      e.update(k);
      if (k >= 1) {
        this.scene.remove(e.obj);
        e.obj.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); });
        this.effects.splice(i, 1);
        if (e.done) e.done();
      }
    }
    for (const l of this.lights) {
      if (l.userData.t > 0) {
        l.userData.t -= dt;
        l.intensity = Math.max(0, l.userData.i * (l.userData.t / l.userData.dur));
      } else l.intensity = 0;
    }
  }
}
