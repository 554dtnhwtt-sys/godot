// Icons for relics, traits and boons, painted on canvas and cached as data URLs.
import { ITEMS } from '../data/items.js';
import { TRAITS } from '../data/traits.js';

const cache = new Map();

function glyph(g, name, s) {
  // Draws a white glyph centred in an s x s box. Caller sets fill/stroke styles.
  const m = s / 2;
  const P = (pts) => { g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x * s, y * s) : g.moveTo(x * s, y * s))); g.closePath(); g.fill(); };
  const C = (x, y, r) => { g.beginPath(); g.arc(x * s, y * s, r * s, 0, Math.PI * 2); g.fill(); };
  const L = (pts, w = 0.07) => { g.lineWidth = w * s; g.lineCap = 'round'; g.lineJoin = 'round'; g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x * s, y * s) : g.moveTo(x * s, y * s))); g.stroke(); };
  const A = (x, y, r, a0, a1, w = 0.07) => { g.lineWidth = w * s; g.lineCap = 'round'; g.beginPath(); g.arc(x * s, y * s, r * s, a0, a1); g.stroke(); };
  switch (name) {
    case 'sword': P([[0.5, 0.12], [0.58, 0.22], [0.56, 0.62], [0.44, 0.62], [0.42, 0.22]]); P([[0.3, 0.62], [0.7, 0.62], [0.7, 0.69], [0.3, 0.69]]); P([[0.46, 0.69], [0.54, 0.69], [0.54, 0.86], [0.46, 0.86]]); break;
    case 'bow': A(0.62, 0.5, 0.36, Math.PI * 0.62, Math.PI * 1.38, 0.08); L([[0.36, 0.17], [0.36, 0.83]], 0.03); L([[0.2, 0.5], [0.8, 0.5]], 0.04); P([[0.82, 0.5], [0.72, 0.44], [0.72, 0.56]]); break;
    case 'shield': P([[0.5, 0.14], [0.8, 0.24], [0.76, 0.56], [0.5, 0.86], [0.24, 0.56], [0.2, 0.24]]); break;
    case 'cloak': P([[0.5, 0.14], [0.66, 0.22], [0.82, 0.84], [0.5, 0.74], [0.18, 0.84], [0.34, 0.22]]); break;
    case 'rod': L([[0.3, 0.82], [0.62, 0.36]], 0.08); P([[0.7, 0.14], [0.84, 0.3], [0.7, 0.46], [0.56, 0.3]]); break;
    case 'tear': g.beginPath(); g.moveTo(m, s * 0.12); g.bezierCurveTo(s * 0.86, s * 0.52, s * 0.78, s * 0.86, m, s * 0.86); g.bezierCurveTo(s * 0.22, s * 0.86, s * 0.14, s * 0.52, m, s * 0.12); g.fill(); break;
    case 'heart': g.beginPath(); g.moveTo(m, s * 0.84); g.bezierCurveTo(s * 0.1, s * 0.55, s * 0.12, s * 0.16, m, s * 0.32); g.bezierCurveTo(s * 0.88, s * 0.16, s * 0.9, s * 0.55, m, s * 0.84); g.fill(); break;
    case 'glove': P([[0.3, 0.86], [0.28, 0.44], [0.34, 0.2], [0.42, 0.2], [0.44, 0.4], [0.47, 0.16], [0.55, 0.16], [0.56, 0.4], [0.6, 0.2], [0.68, 0.22], [0.66, 0.46], [0.74, 0.36], [0.8, 0.4], [0.7, 0.66], [0.66, 0.86]]); break;
    case 'skull': C(0.5, 0.44, 0.27); P([[0.36, 0.6], [0.64, 0.6], [0.62, 0.84], [0.38, 0.84]]); g.globalCompositeOperation = 'destination-out'; C(0.4, 0.46, 0.07); C(0.6, 0.46, 0.07); g.globalCompositeOperation = 'source-over'; break;
    case 'bolt': P([[0.56, 0.1], [0.26, 0.54], [0.48, 0.54], [0.4, 0.9], [0.76, 0.42], [0.54, 0.42]]); break;
    case 'aegis': P([[0.5, 0.12], [0.84, 0.24], [0.8, 0.58], [0.5, 0.88], [0.2, 0.58], [0.16, 0.24]]); g.globalCompositeOperation = 'destination-out'; P([[0.5, 0.26], [0.56, 0.44], [0.74, 0.44], [0.6, 0.56], [0.66, 0.74], [0.5, 0.62], [0.34, 0.74], [0.4, 0.56], [0.26, 0.44], [0.44, 0.44]]); g.globalCompositeOperation = 'source-over'; break;
    case 'fang': P([[0.3, 0.16], [0.7, 0.16], [0.62, 0.5], [0.5, 0.86], [0.42, 0.5]]); break;
    case 'rune': L([[0.5, 0.14], [0.5, 0.86]], 0.08); L([[0.5, 0.3], [0.74, 0.16]], 0.08); L([[0.5, 0.5], [0.28, 0.36]], 0.08); L([[0.5, 0.62], [0.74, 0.76]], 0.08); break;
    case 'spear': L([[0.24, 0.86], [0.66, 0.34]], 0.07); P([[0.8, 0.14], [0.76, 0.42], [0.66, 0.34], [0.58, 0.24]]); break;
    case 'axe': L([[0.36, 0.86], [0.6, 0.2]], 0.07); g.beginPath(); g.moveTo(0.56 * s, 0.18 * s); g.quadraticCurveTo(0.95 * s, 0.25 * s, 0.82 * s, 0.6 * s); g.lineTo(0.5 * s, 0.4 * s); g.closePath(); g.fill(); break;
    case 'edge': P([[0.82, 0.12], [0.86, 0.2], [0.34, 0.72], [0.26, 0.66]]); P([[0.18, 0.62], [0.4, 0.84], [0.34, 0.88], [0.12, 0.66]]); L([[0.22, 0.78], [0.14, 0.86]], 0.07); break;
    case 'wings': for (const sd of [-1, 1]) { g.beginPath(); g.moveTo(m, s * 0.5); g.quadraticCurveTo(m + sd * s * 0.45, s * 0.1, m + sd * s * 0.42, s * 0.6); g.quadraticCurveTo(m + sd * s * 0.2, s * 0.5, m, s * 0.66); g.fill(); } break;
    case 'chevron': for (let i = 0; i < 3; i++) P([[0.2, 0.7 - i * 0.2], [0.5, 0.5 - i * 0.2], [0.8, 0.7 - i * 0.2], [0.8, 0.8 - i * 0.2], [0.5, 0.6 - i * 0.2], [0.2, 0.8 - i * 0.2]]); break;
    case 'twin': L([[0.18, 0.74], [0.72, 0.2]], 0.06); L([[0.3, 0.84], [0.84, 0.32]], 0.06); P([[0.82, 0.12], [0.8, 0.28], [0.66, 0.26]]); P([[0.92, 0.24], [0.9, 0.4], [0.76, 0.38]]); break;
    case 'flux': A(0.5, 0.5, 0.3, 0, Math.PI * 1.6, 0.08); P([[0.8, 0.5], [0.68, 0.34], [0.92, 0.34]]); C(0.5, 0.5, 0.1); break;
    case 'orb': C(0.5, 0.5, 0.26); g.globalCompositeOperation = 'destination-out'; P([[0.52, 0.28], [0.4, 0.52], [0.5, 0.52], [0.46, 0.72], [0.6, 0.46], [0.5, 0.46]]); g.globalCompositeOperation = 'source-over'; break;
    case 'sash': L([[0.2, 0.3], [0.8, 0.7]], 0.14); C(0.5, 0.5, 0.1); break;
    case 'fist': P([[0.26, 0.4], [0.74, 0.4], [0.78, 0.7], [0.66, 0.86], [0.34, 0.86], [0.22, 0.7]]); for (let i = 0; i < 4; i++) C(0.31 + i * 0.13, 0.34, 0.07); break;
    case 'tower': P([[0.3, 0.86], [0.3, 0.3], [0.24, 0.3], [0.24, 0.16], [0.36, 0.16], [0.36, 0.24], [0.46, 0.24], [0.46, 0.16], [0.54, 0.16], [0.54, 0.24], [0.64, 0.24], [0.64, 0.16], [0.76, 0.16], [0.76, 0.3], [0.7, 0.3], [0.7, 0.86]]); break;
    case 'cuirass': P([[0.24, 0.2], [0.4, 0.16], [0.5, 0.26], [0.6, 0.16], [0.76, 0.2], [0.74, 0.62], [0.5, 0.86], [0.26, 0.62]]); break;
    case 'locket': C(0.5, 0.56, 0.24); A(0.5, 0.26, 0.1, Math.PI, Math.PI * 2, 0.05); break;
    case 'frost': for (let i = 0; i < 3; i++) { const a = (i * Math.PI) / 3; L([[0.5 - Math.cos(a) * 0.34, 0.5 - Math.sin(a) * 0.34], [0.5 + Math.cos(a) * 0.34, 0.5 + Math.sin(a) * 0.34]], 0.06); } C(0.5, 0.5, 0.08); break;
    case 'sun': C(0.5, 0.5, 0.17); for (let i = 0; i < 8; i++) { const a = (i * Math.PI) / 4; L([[0.5 + Math.cos(a) * 0.26, 0.5 + Math.sin(a) * 0.26], [0.5 + Math.cos(a) * 0.38, 0.5 + Math.sin(a) * 0.38]], 0.06); } break;
    case 'mirror': g.beginPath(); g.ellipse(m, s * 0.44, s * 0.24, s * 0.3, 0, 0, Math.PI * 2); g.fill(); L([[0.5, 0.74], [0.5, 0.88]], 0.08); break;
    case 'scale': for (let r = 0; r < 3; r++) for (let c = 0; c < 3 - (r % 2); c++) { g.beginPath(); g.arc((0.28 + c * 0.22 + (r % 2) * 0.11) * s, (0.32 + r * 0.18) * s, 0.11 * s, 0, Math.PI); g.fill(); } break;
    case 'ion': C(0.5, 0.5, 0.12); A(0.5, 0.5, 0.3, 0, Math.PI * 2, 0.04); L([[0.5, 0.1], [0.5, 0.24]], 0.05); L([[0.5, 0.76], [0.5, 0.9]], 0.05); L([[0.1, 0.5], [0.24, 0.5]], 0.05); L([[0.76, 0.5], [0.9, 0.5]], 0.05); break;
    case 'chalice': P([[0.24, 0.18], [0.76, 0.18], [0.7, 0.42], [0.56, 0.52], [0.56, 0.72], [0.68, 0.84], [0.32, 0.84], [0.44, 0.72], [0.44, 0.52], [0.3, 0.42]]); break;
    case 'drop': glyph(g, 'tear', s); break;
    case 'charm': P([[0.5, 0.14], [0.78, 0.5], [0.5, 0.86], [0.22, 0.5]]); break;
    case 'crown': P([[0.16, 0.72], [0.18, 0.3], [0.34, 0.5], [0.5, 0.22], [0.66, 0.5], [0.82, 0.3], [0.84, 0.72]]); P([[0.16, 0.76], [0.84, 0.76], [0.84, 0.84], [0.16, 0.84]]); break;
    case 'book': P([[0.18, 0.24], [0.48, 0.3], [0.48, 0.84], [0.18, 0.76]]); P([[0.52, 0.3], [0.82, 0.24], [0.82, 0.76], [0.52, 0.84]]); break;
    case 'morning': C(0.5, 0.5, 0.2); for (let i = 0; i < 8; i++) { const a = (i * Math.PI) / 4; P([[0.5 + Math.cos(a) * 0.18, 0.5 + Math.sin(a) * 0.18 - 0.04], [0.5 + Math.cos(a) * 0.36, 0.5 + Math.sin(a) * 0.36], [0.5 + Math.cos(a) * 0.18 + 0.04, 0.5 + Math.sin(a) * 0.18]]); } break;
    case 'gem': P([[0.3, 0.22], [0.7, 0.22], [0.86, 0.4], [0.5, 0.86], [0.14, 0.4]]); break;
    case 'tears': g.save(); g.translate(-s * 0.13, s * 0.06); g.scale(0.75, 0.75); glyph(g, 'tear', s); g.restore(); g.save(); g.translate(s * 0.38, s * 0.06); g.scale(0.75, 0.75); glyph(g, 'tear', s); g.restore(); break;
    case 'tideheart': glyph(g, 'heart', s); break;
    case 'coin': C(0.5, 0.5, 0.32); g.globalCompositeOperation = 'destination-out'; C(0.5, 0.5, 0.2); g.globalCompositeOperation = 'source-over'; C(0.5, 0.5, 0.12); break;
    case 'colossus': glyph(g, 'heart', s); g.globalCompositeOperation = 'destination-out'; L([[0.5, 0.38], [0.5, 0.66]], 0.08); L([[0.36, 0.52], [0.64, 0.52]], 0.08); g.globalCompositeOperation = 'source-over'; break;
    case 'rage': P([[0.5, 0.1], [0.62, 0.38], [0.86, 0.3], [0.7, 0.54], [0.84, 0.82], [0.5, 0.68], [0.16, 0.82], [0.3, 0.54], [0.14, 0.3], [0.38, 0.38]]); break;
    case 'dice': P([[0.2, 0.2], [0.8, 0.2], [0.8, 0.8], [0.2, 0.8]]); g.globalCompositeOperation = 'destination-out'; C(0.34, 0.34, 0.07); C(0.66, 0.66, 0.07); C(0.5, 0.5, 0.07); g.globalCompositeOperation = 'source-over'; break;
    case 'chest': P([[0.16, 0.42], [0.84, 0.42], [0.84, 0.84], [0.16, 0.84]]); g.beginPath(); g.moveTo(0.16 * s, 0.38 * s); g.quadraticCurveTo(m, 0.06 * s, 0.84 * s, 0.38 * s); g.fill(); break;
    // trait glyphs
    case 'flame': g.beginPath(); g.moveTo(m, s * 0.1); g.bezierCurveTo(s * 0.92, s * 0.5, s * 0.78, s * 0.9, m, s * 0.9); g.bezierCurveTo(s * 0.18, s * 0.9, s * 0.12, s * 0.56, s * 0.36, s * 0.4); g.quadraticCurveTo(s * 0.4, s * 0.58, s * 0.46, s * 0.6); g.quadraticCurveTo(s * 0.34, s * 0.3, m, s * 0.1); g.fill(); break;
    case 'wave': g.beginPath(); g.moveTo(s * 0.1, s * 0.7); g.bezierCurveTo(s * 0.2, s * 0.2, s * 0.7, s * 0.1, s * 0.86, s * 0.4); g.bezierCurveTo(s * 0.6, s * 0.28, s * 0.5, s * 0.5, s * 0.62, s * 0.62); g.bezierCurveTo(s * 0.74, s * 0.72, s * 0.86, s * 0.66, s * 0.9, s * 0.7); g.lineTo(s * 0.9, s * 0.86); g.lineTo(s * 0.1, s * 0.86); g.fill(); break;
    case 'leaf': g.beginPath(); g.moveTo(s * 0.18, s * 0.84); g.bezierCurveTo(s * 0.1, s * 0.3, s * 0.5, s * 0.12, s * 0.86, s * 0.14); g.bezierCurveTo(s * 0.88, s * 0.5, s * 0.6, s * 0.86, s * 0.18, s * 0.84); g.fill(); break;
    case 'eye': g.beginPath(); g.moveTo(s * 0.08, m); g.quadraticCurveTo(m, s * 0.1, s * 0.92, m); g.quadraticCurveTo(m, s * 0.9, s * 0.08, m); g.fill(); g.globalCompositeOperation = 'destination-out'; C(0.5, 0.5, 0.16); g.globalCompositeOperation = 'source-over'; C(0.5, 0.5, 0.08); break;
    case 'gear': C(0.5, 0.5, 0.26); for (let i = 0; i < 8; i++) { g.save(); g.translate(m, m); g.rotate((i * Math.PI) / 4); g.fillRect(-0.07 * s, -0.38 * s, 0.14 * s, 0.14 * s); g.restore(); } g.globalCompositeOperation = 'destination-out'; C(0.5, 0.5, 0.1); g.globalCompositeOperation = 'source-over'; break;
    case 'snow': glyph(g, 'frost', s); break;
    case 'swords': g.save(); g.translate(m, m); g.rotate(0.7); g.translate(-m, -m); glyph(g, 'sword', s); g.restore(); g.save(); g.translate(m, m); g.rotate(-0.7); g.translate(-m, -m); glyph(g, 'sword', s); g.restore(); break;
    case 'star': { g.beginPath(); for (let i = 0; i < 10; i++) { const r = i % 2 ? 0.16 : 0.38; const a = -Math.PI / 2 + (i * Math.PI) / 5; g.lineTo((0.5 + Math.cos(a) * r) * s, (0.52 + Math.sin(a) * r) * s); } g.closePath(); g.fill(); break; }
    case 'dagger': P([[0.5, 0.08], [0.58, 0.5], [0.5, 0.6], [0.42, 0.5]]); P([[0.3, 0.6], [0.7, 0.6], [0.7, 0.66], [0.3, 0.66]]); P([[0.46, 0.66], [0.54, 0.66], [0.54, 0.88], [0.46, 0.88]]); break;
    case 'cross': P([[0.4, 0.14], [0.6, 0.14], [0.6, 0.4], [0.86, 0.4], [0.86, 0.6], [0.6, 0.6], [0.6, 0.86], [0.4, 0.86], [0.4, 0.6], [0.14, 0.6], [0.14, 0.4], [0.4, 0.4]]); break;
    default: C(0.5, 0.5, 0.25);
  }
}

function canvas(s) {
  const c = document.createElement('canvas');
  c.width = c.height = s;
  return c;
}

export function itemIconURL(id, size = 96) {
  const key = `item:${id}:${size}`;
  if (cache.has(key)) return cache.get(key);
  const it = ITEMS[id];
  const c = canvas(size);
  const g = c.getContext('2d');
  const r = size * 0.16;
  const rr = (x, y, w, h, rad) => { g.beginPath(); g.moveTo(x + rad, y); g.arcTo(x + w, y, x + w, y + h, rad); g.arcTo(x + w, y + h, x, y + h, rad); g.arcTo(x, y + h, x, y, rad); g.arcTo(x, y, x + w, y, rad); g.closePath(); };
  if (!it) { cache.set(key, ''); return ''; }
  const [c1, c2] = it.colors.length > 1 ? it.colors : [it.colors[0], it.colors[0]];
  const grd = g.createLinearGradient(0, 0, size, size);
  grd.addColorStop(0, c1);
  grd.addColorStop(0.49, shade(c1, -0.35));
  grd.addColorStop(0.51, shade(c2, -0.35));
  grd.addColorStop(1, c2);
  rr(2, 2, size - 4, size - 4, r);
  g.fillStyle = '#0b0f1a';
  g.fill();
  rr(5, 5, size - 10, size - 10, r * 0.8);
  g.fillStyle = grd;
  g.fill();
  const shine = g.createRadialGradient(size * 0.35, size * 0.25, 0, size * 0.5, size * 0.5, size * 0.7);
  shine.addColorStop(0, 'rgba(255,255,255,0.35)');
  shine.addColorStop(1, 'rgba(0,0,0,0.35)');
  g.fillStyle = shine;
  g.fill();
  g.lineWidth = size * 0.05;
  g.strokeStyle = it.component ? '#aeb6c4' : '#e8c070';
  rr(4, 4, size - 8, size - 8, r * 0.85);
  g.stroke();
  // glyph with drop shadow
  g.save();
  g.translate(size * 0.16, size * 0.16);
  const gs = size * 0.68;
  g.shadowColor = 'rgba(0,0,0,0.7)';
  g.shadowBlur = size * 0.06;
  g.shadowOffsetY = size * 0.02;
  g.fillStyle = '#fffaf0';
  g.strokeStyle = '#fffaf0';
  glyph(g, it.glyph, gs);
  g.restore();
  const url = c.toDataURL('image/png');
  cache.set(key, url);
  return url;
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255; let gg = (n >> 8) & 255; let b = n & 255;
  const f = (v) => Math.max(0, Math.min(255, Math.round(amt < 0 ? v * (1 + amt) : v + (255 - v) * amt)));
  r = f(r); gg = f(gg); b = f(b);
  return `rgb(${r},${gg},${b})`;
}

const TIER_COLORS = ['#7a5a3a', '#c8a464', '#b8c8d8', '#ffd86a'];
// tier: -1 inactive, 0 bronze, 1 silver/gold...
export function traitIconURL(id, tier = 0, size = 64) {
  const key = `trait:${id}:${tier}:${size}`;
  if (cache.has(key)) return cache.get(key);
  const tr = TRAITS[id];
  const c = canvas(size);
  const g = c.getContext('2d');
  const hex = (rad) => { g.beginPath(); for (let i = 0; i < 6; i++) { const a = Math.PI / 6 + (i * Math.PI) / 3; g.lineTo(size / 2 + Math.cos(a) * rad, size / 2 + Math.sin(a) * rad); } g.closePath(); };
  const maxTier = tr.levels.length - 1;
  const fill = tier < 0 ? '#2a3040' : tier >= maxTier ? '#e8b84a' : tier === 0 ? '#9a6a3e' : '#b8c4d4';
  hex(size * 0.48);
  g.fillStyle = '#0a0e18';
  g.fill();
  hex(size * 0.42);
  const grd = g.createLinearGradient(0, 0, 0, size);
  grd.addColorStop(0, shade(fill.startsWith('#') ? fill : '#888888', 0.25));
  grd.addColorStop(1, shade(fill.startsWith('#') ? fill : '#888888', -0.3));
  g.fillStyle = grd;
  g.fill();
  g.save();
  g.translate(size * 0.2, size * 0.2);
  g.fillStyle = tier < 0 ? '#8a94a8' : '#1a1410';
  g.strokeStyle = g.fillStyle;
  glyph(g, tr.icon, size * 0.6);
  g.restore();
  const url = c.toDataURL('image/png');
  cache.set(key, url);
  return url;
}

export function glyphIconURL(name, color = '#ffe2a0', size = 64) {
  const key = `glyph:${name}:${color}:${size}`;
  if (cache.has(key)) return cache.get(key);
  const c = canvas(size);
  const g = c.getContext('2d');
  g.fillStyle = color;
  g.strokeStyle = color;
  g.shadowColor = 'rgba(0,0,0,0.6)';
  g.shadowBlur = size * 0.05;
  glyph(g, name, size);
  const url = c.toDataURL('image/png');
  cache.set(key, url);
  return url;
}

export { TIER_COLORS };
