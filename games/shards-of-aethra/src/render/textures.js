// Procedural textures painted on canvases at load time.
import * as THREE from 'three';

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

// Value-noise helpers (JS side).
function hash2(x, y, s) {
  let h = x * 374761393 + y * 668265263 + s * 2147483647;
  h = (h ^ (h >>> 13)) * 1274126177;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}
export function valueNoise(x, y, s = 0) {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const xf = x - xi;
  const yf = y - yi;
  const u = xf * xf * (3 - 2 * xf);
  const v = yf * yf * (3 - 2 * yf);
  const a = hash2(xi, yi, s);
  const b = hash2(xi + 1, yi, s);
  const c = hash2(xi, yi + 1, s);
  const d = hash2(xi + 1, yi + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
export function fbm(x, y, oct = 4, s = 0) {
  let sum = 0;
  let amp = 0.5;
  let f = 1;
  for (let i = 0; i < oct; i++) {
    sum += amp * valueNoise(x * f, y * f, s + i * 17);
    amp *= 0.5;
    f *= 2.03;
  }
  return sum;
}

// Tileable-ish stone texture with cracks and speckle, returns {map, rough}.
export function stoneTexture(base = [92, 98, 112], size = 256, seed = 1, scale = 6) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const img = g.createImageData(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const nx = (x / size) * scale;
      const ny = (y / size) * scale;
      const n = fbm(nx, ny, 5, seed);
      const cr = Math.abs(fbm(nx * 1.7 + 3, ny * 1.7, 3, seed + 9) - 0.5);
      const crack = cr < 0.012 ? 0.8 : 1;
      const speck = hash2(x, y, seed) > 0.985 ? 1.15 : 1;
      const k = (0.8 + n * 0.4) * crack * speck;
      const i = (y * size + x) * 4;
      img.data[i] = Math.min(255, base[0] * k);
      img.data[i + 1] = Math.min(255, base[1] * k);
      img.data[i + 2] = Math.min(255, base[2] * k);
      img.data[i + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

export function grassTexture(size = 512, seed = 3) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const img = g.createImageData(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const n = fbm(x / 48, y / 48, 5, seed);
      const m = fbm(x / 9, y / 9, 2, seed + 5);
      const i = (y * size + x) * 4;
      const t = n * 0.8 + m * 0.35;
      img.data[i] = 62 + t * 52;
      img.data[i + 1] = 98 + t * 64;
      img.data[i + 2] = 44 + t * 30;
      img.data[i + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  // blades
  for (let k = 0; k < 2600; k++) {
    const x = hash2(k, 1, seed) * size;
    const y = hash2(k, 2, seed) * size;
    const l = 3 + hash2(k, 3, seed) * 6;
    g.strokeStyle = `rgba(${130 + hash2(k, 4, seed) * 60},${170 + hash2(k, 5, seed) * 50},${80},0.28)`;
    g.lineWidth = 1;
    g.beginPath();
    g.moveTo(x, y);
    g.lineTo(x + (hash2(k, 6, seed) - 0.5) * 3, y - l);
    g.stroke();
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

// Soft round particle sprite.
export function softDot(size = 64) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const grd = g.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  grd.addColorStop(0, 'rgba(255,255,255,1)');
  grd.addColorStop(0.25, 'rgba(255,255,255,0.8)');
  grd.addColorStop(0.6, 'rgba(255,255,255,0.18)');
  grd.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, size, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// Four-pointed sparkle.
export function sparkle(size = 64) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const m = size / 2;
  const grd = g.createRadialGradient(m, m, 0, m, m, m);
  grd.addColorStop(0, 'rgba(255,255,255,1)');
  grd.addColorStop(0.15, 'rgba(255,255,255,0.6)');
  grd.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grd;
  g.beginPath();
  g.moveTo(m, 0); g.quadraticCurveTo(m, m, size, m); g.quadraticCurveTo(m, m, m, size);
  g.quadraticCurveTo(m, m, 0, m); g.quadraticCurveTo(m, m, m, 0);
  g.fill();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export function ringTexture(size = 256, width = 0.08) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const m = size / 2;
  const grd = g.createRadialGradient(m, m, m * (1 - width * 3), m, m, m);
  grd.addColorStop(0, 'rgba(255,255,255,0)');
  grd.addColorStop(0.55, 'rgba(255,255,255,0.9)');
  grd.addColorStop(0.75, 'rgba(255,255,255,0.35)');
  grd.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, size, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// Contact shadow blob placed under every unit.
export function blobShadow(size = 128) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const m = size / 2;
  const grd = g.createRadialGradient(m, m, 0, m, m, m);
  grd.addColorStop(0, 'rgba(0,0,0,0.55)');
  grd.addColorStop(0.5, 'rgba(0,0,0,0.3)');
  grd.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, size, size);
  return new THREE.CanvasTexture(c);
}

// Fine hammered-metal style normal-ish bump used on armour.
export function bumpNoise(size = 128, seed = 11, scale = 10) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const img = g.createImageData(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const n = fbm((x / size) * scale, (y / size) * scale, 4, seed);
      const v = 90 + n * 120;
      const i = (y * size + x) * 4;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
      img.data[i + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

// Eye texture: big glossy iris with highlight, used on face decals.
export function eyeTexture(color = '#2a1a10', glow = false) {
  const s = 64;
  const c = canvas(s, s);
  const g = c.getContext('2d');
  g.fillStyle = glow ? color : '#fffaf0';
  g.beginPath(); g.ellipse(32, 32, 26, 30, 0, 0, Math.PI * 2); g.fill();
  if (!glow) {
    const grd = g.createRadialGradient(32, 36, 2, 32, 34, 22);
    grd.addColorStop(0, '#000');
    grd.addColorStop(0.35, color);
    grd.addColorStop(1, '#000');
    g.fillStyle = grd;
    g.beginPath(); g.ellipse(32, 35, 19, 23, 0, 0, Math.PI * 2); g.fill();
  } else {
    const grd = g.createRadialGradient(32, 32, 2, 32, 32, 30);
    grd.addColorStop(0, '#ffffff');
    grd.addColorStop(0.4, color);
    grd.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = grd;
    g.fillRect(0, 0, s, s);
  }
  g.fillStyle = '#fff';
  g.beginPath(); g.ellipse(24, 24, 7, 8, 0, 0, Math.PI * 2); g.fill();
  g.beginPath(); g.ellipse(40, 44, 3, 3, 0, 0, Math.PI * 2); g.fill();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// Painted hex tile: stone with bevel light, darker centre and an engraved inner hex.
export function hexTileTexture(size = 256, tone = [70, 84, 112], seed = 4) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const img = g.createImageData(size, size);
  const m = size / 2;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const dx = (x - m) / m;
      const dy = (y - m) / m;
      // hex distance (pointy-top in texture space)
      const ax = Math.abs(dx);
      const ay = Math.abs(dy);
      const hd = Math.max(ay * 0.866 + ax * 0.5, ax);
      const n = fbm(x / 28, y / 28, 4, seed);
      const fine = fbm(x / 6, y / 6, 2, seed + 3);
      let k = 0.78 + n * 0.32 + fine * 0.08;
      k *= 0.86 + 0.22 * Math.min(1, hd * 1.1);
      if (Math.abs(hd - 0.7) < 0.012) k *= 0.72;
      if (Math.abs(hd - 0.725) < 0.01) k *= 1.18;
      if (hd > 0.92) k *= 1.12;
      const i = (y * size + x) * 4;
      img.data[i] = Math.min(255, tone[0] * k);
      img.data[i + 1] = Math.min(255, tone[1] * k);
      img.data[i + 2] = Math.min(255, tone[2] * k);
      img.data[i + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
}

// Irregular flagstones for the plaza around the board.
export function flagstoneTexture(size = 512, seed = 21) {
  const c = canvas(size, size);
  const g = c.getContext('2d');
  const pts = [];
  for (let i = 0; i < 60; i++) pts.push([hash2(i, 1, seed) * size, hash2(i, 2, seed) * size, hash2(i, 3, seed)]);
  const img = g.createImageData(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let d1 = 1e9; let d2 = 1e9; let id = 0;
      for (let k = 0; k < pts.length; k++) {
        for (const ox of [-size, 0, size]) for (const oy of [-size, 0, size]) {
          const dx = x - pts[k][0] - ox; const dy = y - pts[k][1] - oy;
          const d = dx * dx + dy * dy;
          if (d < d1) { d2 = d1; d1 = d; id = k; } else if (d < d2) d2 = d;
        }
      }
      const edge = Math.sqrt(d2) - Math.sqrt(d1);
      const n = fbm(x / 30, y / 30, 3, seed);
      const tone = 0.75 + pts[id][2] * 0.25 + n * 0.2;
      const groove = edge < 3 ? 0.45 : edge < 5 ? 0.8 : 1;
      const i = (y * size + x) * 4;
      img.data[i] = 150 * tone * groove;
      img.data[i + 1] = 140 * tone * groove;
      img.data[i + 2] = 128 * tone * groove;
      img.data[i + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
}
