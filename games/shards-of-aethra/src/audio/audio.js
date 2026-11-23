// Music, synthesized sound effects and champion voice lines (Web Audio).
import { CHAMPIONS } from '../data/champions.js';
import { ANNOUNCER } from '../data/announcer.js';

const store = {
  get(k, d) { try { const v = localStorage.getItem('soa.' + k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('soa.' + k, JSON.stringify(v)); } catch { /* storage unavailable */ } },
};

export class Audio {
  constructor(base = 'assets/') {
    this.base = base;
    this.ctx = null;
    this.buffers = new Map();
    this.loading = new Map();
    this.vol = store.get('vol', { master: 0.8, music: 0.55, sfx: 0.7, voice: 0.9 });
    this.music = { current: null, nodes: {} };
    this.lastSfx = {};
    this.voicePlaying = null;
    this.subtitle = null;
  }

  // Must be called from a user gesture.
  unlock() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = new AC();
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.master.gain.value = this.vol.master;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14;
    comp.ratio.value = 3;
    this.master.connect(comp).connect(ctx.destination);
    this.musicBus = ctx.createGain();
    this.musicBus.gain.value = this.vol.music;
    this.musicBus.connect(this.master);
    this.sfxBus = ctx.createGain();
    this.sfxBus.gain.value = this.vol.sfx;
    this.sfxBus.connect(this.master);
    this.voiceBus = ctx.createGain();
    this.voiceBus.gain.value = this.vol.voice;
    this.voiceBus.connect(this.master);
    // Shared reverb for effects.
    this.reverb = ctx.createConvolver();
    this.reverb.buffer = this.impulse(1.6, 2.6);
    const rv = ctx.createGain();
    rv.gain.value = 0.22;
    this.reverb.connect(rv).connect(this.sfxBus);
    this.noiseBuf = this.makeNoise();
    this.prefetch();
  }

  now() { return this.ctx ? this.ctx.currentTime : performance.now() / 1000; }

  setVolume(kind, v) {
    this.vol[kind] = v;
    store.set('vol', this.vol);
    if (!this.ctx) return;
    const bus = { master: this.master, music: this.musicBus, sfx: this.sfxBus, voice: this.voiceBus }[kind];
    if (bus) bus.gain.setTargetAtTime(v, this.ctx.currentTime, 0.05);
  }

  impulse(sec, decay) {
    const ctx = this.ctx;
    const len = Math.floor(ctx.sampleRate * sec);
    const b = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const d = b.getChannelData(c);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
    }
    return b;
  }

  makeNoise() {
    const ctx = this.ctx;
    const b = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    return b;
  }

  async load(path) {
    if (this.buffers.has(path)) return this.buffers.get(path);
    if (this.loading.has(path)) return this.loading.get(path);
    const p = fetch(this.base + path)
      .then((r) => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); })
      .then((ab) => new Promise((res, rej) => this.ctx.decodeAudioData(ab, res, rej)))
      .then((buf) => { this.buffers.set(path, buf); return buf; })
      .catch(() => null);
    this.loading.set(path, p);
    return p;
  }

  prefetch() {
    const files = ['music/planning.mp3', 'music/combat.mp3'];
    for (const c of CHAMPIONS) files.push(`voice/${c.id}_select0.mp3`, `voice/${c.id}_ability.mp3`);
    for (const k of Object.keys(ANNOUNCER.lines)) files.push(`voice/announcer_${k}.mp3`);
    let i = 0;
    const next = () => { if (i < files.length) this.load(files[i++]).then(next); };
    for (let k = 0; k < 4; k++) next();
  }

  // ───────────── music ─────────────
  async playMusic(name, fade = 1.5) {
    if (!this.ctx) return;
    if (this.music.current === name) return;
    this.music.current = name;
    const buf = await this.load(`music/${name}.mp3`);
    if (!buf || this.music.current !== name) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    for (const [k, n] of Object.entries(this.music.nodes)) {
      n.gain.gain.cancelScheduledValues(t);
      n.gain.gain.setValueAtTime(n.gain.gain.value, t);
      n.gain.gain.linearRampToValueAtTime(0, t + fade);
      n.src.stop(t + fade + 0.1);
      delete this.music.nodes[k];
    }
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    src.loopStart = 0.03;
    src.loopEnd = buf.duration - 0.03;
    const gain = ctx.createGain();
    gain.gain.value = 0;
    gain.gain.linearRampToValueAtTime(1, t + fade);
    src.connect(gain).connect(this.musicBus);
    src.start(t, 0.03);
    this.music.nodes[name] = { src, gain };
  }

  duckMusic(amount = 0.45, dur = 1.6) {
    if (!this.ctx) return;
    const g = this.musicBus.gain;
    const t = this.ctx.currentTime;
    g.cancelScheduledValues(t);
    g.setValueAtTime(g.value, t);
    g.linearRampToValueAtTime(this.vol.music * amount, t + 0.08);
    g.linearRampToValueAtTime(this.vol.music, t + dur);
  }

  // ───────────── voice ─────────────
  async playVoiceFile(file, vol = 1, text = '') {
    if (!this.ctx) return;
    const buf = await this.load(`voice/${file}.mp3`);
    if (!buf) return;
    if (this.voicePlaying) { try { this.voicePlaying.stop(); } catch { /* already stopped */ } }
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const g = this.ctx.createGain();
    g.gain.value = vol;
    src.connect(g).connect(this.voiceBus);
    src.start();
    this.voicePlaying = src;
    this.duckMusic(0.5, buf.duration + 0.4);
    if (this.subtitle && text) this.subtitle(text, buf.duration);
  }

  voice(champId, kind, vol = 1) {
    const ch = CHAMPIONS.find((c) => c.id === champId);
    if (!ch) return;
    let file;
    let text;
    if (kind === 'select') {
      const i = Math.floor(Math.random() * ch.lines.select.length);
      file = `${champId}_select${i}`;
      text = ch.lines.select[i];
    } else {
      file = `${champId}_${kind}`;
      text = ch.lines[kind];
    }
    this.playVoiceFile(file, vol, `${ch.name}: “${text}”`);
  }

  announce(key) {
    const text = ANNOUNCER.lines[key];
    if (!text) return;
    this.playVoiceFile(`announcer_${key}`, 1, '');
  }

  // ───────────── synthesized effects ─────────────
  env(g, t, a, peak, d) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
  }

  tone(type, f0, f1, dur, peak = 0.3, o = {}) {
    const ctx = this.ctx;
    const t = ctx.currentTime + (o.delay || 0);
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(f0, t);
    if (f1 !== f0) osc.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    if (o.detune) osc.detune.value = o.detune;
    const g = ctx.createGain();
    this.env(g, t, o.attack ?? 0.005, peak, dur);
    let node = osc.connect(g);
    if (o.filter) {
      const f = ctx.createBiquadFilter();
      f.type = o.filter;
      f.frequency.value = o.ff || 2000;
      node = g.connect(f);
    }
    node.connect(this.sfxBus);
    if (o.verb) node.connect(this.reverb);
    osc.start(t);
    osc.stop(t + dur + (o.attack ?? 0.005) + 0.05);
  }

  noise(dur, type, f0, f1, peak = 0.3, o = {}) {
    const ctx = this.ctx;
    const t = ctx.currentTime + (o.delay || 0);
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuf;
    const f = ctx.createBiquadFilter();
    f.type = type;
    f.Q.value = o.q ?? 1;
    f.frequency.setValueAtTime(f0, t);
    f.frequency.exponentialRampToValueAtTime(Math.max(30, f1), t + dur);
    const g = ctx.createGain();
    this.env(g, t, o.attack ?? 0.005, peak, dur);
    src.connect(f).connect(g).connect(this.sfxBus);
    if (o.verb) g.connect(this.reverb);
    src.start(t, Math.random());
    src.stop(t + dur + 0.1);
  }

  sfx(name, vol = 1, alt = false) {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const minGap = { hit: 0.04, swing: 0.05, shot: 0.05, bow: 0.05, zap: 0.06, shield: 0.15, death: 0.08 }[name] || 0.02;
    if (this.lastSfx[name] && now - this.lastSfx[name] < minGap) return;
    this.lastSfx[name] = now;
    const v = vol;
    const T = (...a) => this.tone(...a);
    const N = (...a) => this.noise(...a);
    switch (name) {
      case 'click': T('triangle', 880, 660, 0.06, 0.12 * v); break;
      case 'hover': T('sine', 1400, 1500, 0.03, 0.04 * v); break;
      case 'buy': T('triangle', 988, 988, 0.08, 0.18 * v); T('triangle', 1318, 1318, 0.18, 0.16 * v, { delay: 0.06, verb: true }); N(0.12, 'highpass', 6000, 8000, 0.05 * v); break;
      case 'coin': T('square', 1568, 1568, 0.05, 0.06 * v, { filter: 'lowpass', ff: 4000 }); T('square', 2093, 2093, 0.15, 0.06 * v, { delay: 0.05, filter: 'lowpass', ff: 4000 }); break;
      case 'sell': T('triangle', 1318, 784, 0.18, 0.15 * v, { verb: true }); N(0.2, 'bandpass', 3000, 6000, 0.06 * v); break;
      case 'reroll': N(0.3, 'bandpass', 800, 3200, 0.2 * v, { q: 2 }); T('sine', 400, 900, 0.25, 0.08 * v); break;
      case 'xp': T('sine', 523, 1046, 0.3, 0.14 * v, { verb: true }); T('sine', 784, 1568, 0.3, 0.08 * v, { delay: 0.05 }); break;
      case 'levelup': [523, 659, 784, 1046].forEach((f, i) => T('triangle', f, f, 0.35, 0.14 * v, { delay: i * 0.07, verb: true })); N(0.6, 'highpass', 4000, 9000, 0.05 * v, { delay: 0.2 }); break;
      case 'star2': [659, 830, 988, 1318].forEach((f, i) => T('sine', f, f, 0.6, 0.15 * v, { delay: i * 0.06, verb: true })); N(0.8, 'bandpass', 5000, 9000, 0.08 * v); break;
      case 'star3': [523, 659, 784, 1046, 1318, 1568].forEach((f, i) => T('triangle', f, f, 0.9, 0.14 * v, { delay: i * 0.07, verb: true })); T('sine', 130, 65, 1.0, 0.3 * v); break;
      case 'pickup': T('sine', 500, 800, 0.1, 0.1 * v); break;
      case 'place': T('sine', 300, 180, 0.1, 0.18 * v); N(0.08, 'lowpass', 1200, 400, 0.12 * v); break;
      case 'error': T('square', 220, 180, 0.15, 0.08 * v, { filter: 'lowpass', ff: 1200 }); break;
      case 'tick': T('sine', 1200, 1200, 0.04, 0.08 * v); break;
      case 'swing': N(0.16, 'bandpass', 1200, 4000, 0.22 * v, { q: 1.5, attack: 0.02 }); break;
      case 'slash': N(0.22, 'bandpass', 2400, 700, 0.35 * v, { q: 2, attack: 0.01 }); T('sawtooth', 300, 120, 0.15, 0.06 * v, { filter: 'lowpass', ff: 1500 }); break;
      case 'claw': N(0.12, 'bandpass', 3000, 1500, 0.3 * v, { q: 3 }); N(0.1, 'bandpass', 2000, 900, 0.2 * v, { q: 3, delay: 0.05 }); break;
      case 'hit': T('sine', alt ? 160 : 220, 70, 0.12, 0.3 * v); N(0.08, 'lowpass', 2500, 500, 0.25 * v); break;
      case 'bow': N(0.12, 'bandpass', 900, 2600, 0.2 * v, { q: 4 }); T('triangle', 180, 90, 0.08, 0.1 * v); break;
      case 'shot': N(0.18, 'lowpass', 3000, 300, 0.35 * v); T('sine', 120, 50, 0.15, 0.3 * v); break;
      case 'cannon': N(0.4, 'lowpass', 1400, 120, 0.4 * v, { verb: true }); T('sine', 90, 35, 0.35, 0.45 * v); break;
      case 'boom': N(0.6, 'lowpass', 2000, 80, 0.45 * v, { verb: true }); T('sine', 70, 30, 0.5, 0.5 * v); break;
      case 'zap': T('sawtooth', 1800, 200, 0.12, 0.08 * v, { filter: 'bandpass', ff: 2500 }); N(0.1, 'highpass', 5000, 8000, 0.08 * v); break;
      case 'cast': T('sine', 330, 660, 0.35, 0.12 * v, { attack: 0.05, verb: true }); T('sine', 495, 990, 0.35, 0.06 * v, { attack: 0.05 }); break;
      case 'shield': T('sine', 880, 1320, 0.25, 0.08 * v, { verb: true }); break;
      case 'death': T('sine', 300, 80, 0.4, 0.15 * v); N(0.4, 'bandpass', 1200, 300, 0.1 * v, { verb: true }); break;
      case 'slam': T('sine', 110, 40, 0.5, 0.5 * v); N(0.5, 'lowpass', 1500, 100, 0.4 * v, { verb: true }); break;
      case 'roar': T('sawtooth', 160, 90, 0.6, 0.12 * v, { filter: 'lowpass', ff: 900, attack: 0.05 }); N(0.6, 'bandpass', 600, 300, 0.2 * v, { q: 2, attack: 0.05 }); break;
      case 'water': N(0.6, 'bandpass', 500, 2500, 0.25 * v, { q: 0.8, attack: 0.05, verb: true }); break;
      case 'fire': N(0.7, 'bandpass', 400, 1800, 0.3 * v, { q: 0.7, attack: 0.08, verb: true }); T('sine', 200, 400, 0.4, 0.06 * v); break;
      case 'throw': N(0.25, 'bandpass', 600, 2000, 0.15 * v, { q: 2, attack: 0.03 }); break;
      case 'chime': [1046, 1318, 1568].forEach((f, i) => T('sine', f, f, 0.8, 0.08 * v, { delay: i * 0.08, verb: true })); break;
      case 'saw': T('sawtooth', 700, 900, 0.4, 0.06 * v, { filter: 'bandpass', ff: 1800 }); N(0.4, 'highpass', 3000, 6000, 0.08 * v); break;
      case 'beam': T('sawtooth', 220, 880, 0.5, 0.08 * v, { filter: 'lowpass', ff: 2500, attack: 0.05, verb: true }); T('sine', 110, 110, 0.5, 0.15 * v); break;
      case 'devour': T('sawtooth', 90, 40, 0.8, 0.2 * v, { filter: 'lowpass', ff: 600, verb: true }); N(0.8, 'lowpass', 800, 100, 0.3 * v); break;
      case 'wind': N(1.4, 'bandpass', 400, 1600, 0.25 * v, { q: 0.8, attack: 0.3, verb: true }); break;
      case 'blink': T('sine', 1600, 400, 0.15, 0.1 * v); N(0.12, 'highpass', 4000, 7000, 0.08 * v); break;
      case 'leap': N(0.25, 'bandpass', 500, 1500, 0.15 * v, { q: 1.5 }); break;
      case 'victory': [523, 659, 784, 1046].forEach((f, i) => T('triangle', f, f, 0.8, 0.12 * v, { delay: i * 0.12, verb: true })); break;
      case 'defeat': [392, 349, 311, 262].forEach((f, i) => T('triangle', f, f, 0.7, 0.1 * v, { delay: i * 0.16, verb: true })); break;
      case 'round': T('sine', 196, 196, 1.2, 0.18 * v, { verb: true, attack: 0.02 }); T('sine', 294, 294, 1.2, 0.1 * v, { verb: true }); N(1.2, 'lowpass', 600, 100, 0.12 * v); break;
      case 'boon': [784, 988, 1175, 1568].forEach((f, i) => T('sine', f, f, 1.0, 0.1 * v, { delay: i * 0.05, verb: true })); break;
      default: break;
    }
  }
}
