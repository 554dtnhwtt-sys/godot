// Shards of Aethra — boot, title screen and the main loop.
import css from './ui/style.css';
import { Stage } from './render/scene.js';
import { Arena } from './render/arena.js';
import { VFX } from './render/vfx.js';
import { World } from './render/world.js';
import { HUD } from './ui/hud.js';
import { Screens } from './ui/screens.js';
import { Audio } from './audio/audio.js';
import { Match } from './game/match.js';
import { preparePortraits } from './ui/portraits.js';
import { Online } from './net/online.js';

const BASE = 'assets/';

function setupDom() {
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);
  const app = document.getElementById('app');
  app.insertAdjacentHTML('afterend', `<div id="bar-layer" class="layer"></div><div id="num-layer" class="layer"></div><div id="hud" class="hud" hidden></div><div id="screens"></div>`);
  return app;
}

function readQuality() {
  try { return localStorage.getItem('soa.quality') || 'high'; } catch { return 'high'; }
}

class App {
  constructor() {
    this.container = setupDom();
    this.quality = readQuality();
    this.audio = new Audio(BASE);
    this.stage = new Stage(this.container, this.quality);
    this.arena = new Arena(this.stage);
    this.vfx = new VFX(this.stage.scene);
    this.hud = new HUD({ audio: this.audio });
    this.world = new World({ stage: this.stage, arena: this.arena, vfx: this.vfx, hud: this.hud, audio: this.audio });
    this.screens = new Screens(this);
    this.online = new Online(this);
    this.match = null;
    this.last = performance.now();
    this.titleCam();
    requestAnimationFrame((t) => this.loop(t));
    this.boot();
    document.addEventListener('pointerdown', () => this.audio.unlock(), { once: false });
  }

  async boot() {
    const img = new Image();
    img.src = `${BASE}title.webp`;
    img.onload = () => this.screens.setTitleArt(img.src);
    let done = 0;
    const total = 3;
    await preparePortraits(BASE, () => { done++; this.screens.progress(Math.min(0.9, done / total)); });
    this.screens.progress(1);
    setTimeout(() => this.screens.ready(), 250);
  }

  titleCam() {
    this.stage.camBase.set(0, 23.5, 25.5);
    this.stage.camTarget.set(0, 0, 0.2);
  }
  gameCam() {
    this.stage.camBase.set(0, 30, 29.5);
    this.stage.camTarget.set(0, 0, 1.1);
  }

  setQuality(q) {
    this.quality = q;
    try { localStorage.setItem('soa.quality', q); } catch { /* ignore */ }
    this.stage.quality = q;
    this.stage.resize();
  }

  openCodex() { this.screens.openCodex(); }
  openSettings() { this.screens.openSettings(); }
  openLobby(el) { this.audio.unlock(); this.online.open(el); }
  leaveLobby() { this.online.leave(); }

  startSolo() {
    this.audio.unlock();
    const seed = (Math.random() * 2 ** 32) >>> 0;
    const name = this.online.myName();
    this.begin(new Match({ seed, humans: [{ id: 'me', name, color: '#f3d891', kind: 'human' }], localId: 'me' }));
  }

  begin(match) {
    if (this.match) this.teardown();
    this.match = match;
    this.screens.hideTitle();
    this.screens.close('lobby');
    document.getElementById('hud').hidden = false;
    this.gameCam();
    this.world.setMatch(match);
    this.hud.bind(match, this.world, this);
    this.wire(match);
    this.audio.playMusic('planning');
    match.start();
    this.world.syncPlanning();
  }

  wire(m) {
    const hud = this.hud;
    const world = this.world;
    const audio = this.audio;
    let lastAnnounce = 0;
    m.on('update', () => { hud.render(); if (!m.viewCombat || m.phase !== 'combat') world.syncPlanning(); else world.syncPlanning(); });
    m.on('phase', (ph) => {
      hud.render();
      if (ph === 'planning') { audio.playMusic('planning'); audio.sfx('round', 0.7); hud.hideModals(); if (m.pendingBoon) hud.showBoons(m.pendingBoon); }
      if (ph === 'draft') { hud.showDraft(m.pendingDraft); audio.playMusic('planning'); }
      if (ph === 'combat') { audio.playMusic('combat', 0.8); hud.showDraft(null); hud.showBoons(null); }
      if (ph === 'results' || ph === 'sync') { hud.showDraft(null); hud.showBoons(null); }
    });
    m.on('announce', (key) => {
      const now = performance.now();
      const important = ['welcome', 'first', 'eliminated', 'star3', 'finaltwo'].includes(key);
      if (!important && now - lastAnnounce < 1800) return;
      lastAnnounce = now;
      setTimeout(() => audio.announce(key), key === 'combat' ? 150 : 0);
    });
    m.on('draft-offer', (offers) => { if (m.phase === 'draft' || offers) hud.showDraft(offers); });
    m.on('boon-offer', (offers) => { if (offers) setTimeout(() => hud.showBoons(m.pendingBoon), 600); });
    m.on('combat-start', (combat, info) => {
      if (combat) world.startCombat(combat, info);
      hud.versus(info.opponent, info.pve);
      hud.render();
    });
    m.on('combat-end', () => { world.endCombat(); hud.versus(null); hud.render(); });
    m.on('round-result', ({ won, dmg, pve }) => {
      m.local.history.push({ key: m.roundKey(), res: won ? 'win' : 'loss' });
      if (won) { hud.banner('VICTORY', pve ? 'The monsters fall' : 'Your champions stand triumphant'); audio.sfx('victory'); }
      else { hud.banner('DEFEAT', dmg ? `Your Warden takes ${dmg} damage` : 'A narrow escape', true); audio.sfx('defeat'); }
      hud.render();
    });
    m.on('starup', (u) => {
      world.starUp(u);
      audio.sfx(u.star >= 3 ? 'star3' : 'star2');
      m.emit('announce', u.star >= 3 ? 'star3' : 'star2');
      setTimeout(() => audio.voice(u.id, 'upgrade'), 900);
    });
    m.on('bought', (id) => { if (Math.random() < 0.5) world.voice(id, 'select', 0.85); });
    m.on('levelup', () => audio.sfx('levelup'));
    m.on('error', (msg) => { hud.toast(msg); audio.sfx('error'); });
    m.on('loot', (loot) => { audio.sfx('coin'); hud.toast(`Loot: ${loot.items.length} relic${loot.items.length > 1 ? 's' : ''} and ${loot.gold} gold`); });
    m.on('income', () => audio.sfx('coin', 0.6));
    m.on('player-out', () => hud.render());
    m.on('voice', (id, kind) => world.voice(id, kind));
    m.on('gameover', (place) => {
      audio.playMusic('theme');
      setTimeout(() => hud.showEnd(place, m), 1200);
    });
  }

  teardown() {
    if (!this.match) return;
    this.match.handlers = {};
    this.world.endCombat();
    for (const v of this.world.planViews.values()) v.dispose();
    this.world.planViews.clear();
    this.match = null;
  }

  restart() {
    if (this.match && this.match.online) { this.toTitle(); return; }
    this.startSolo();
  }

  toTitle() {
    this.teardown();
    this.online.leave();
    document.getElementById('hud').hidden = true;
    this.titleCam();
    this.screens.showTitle();
    this.audio.playMusic('theme');
  }

  loop(now) {
    const real = Math.min(0.25, (now - this.last) / 1000);
    const dt = Math.min(0.05, real);
    this.last = now;
    if (this.match) this.match.update(real);
    this.world.update(dt);
    this.vfx.update(dt);
    this.arena.update(dt, this.stage.time);
    this.stage.render(dt);
    this.hud.tick();
    requestAnimationFrame((t) => this.loop(t));
  }
}

function start() {
  try {
    window.__app = new App();
  } catch (e) {
    document.body.insertAdjacentHTML('beforeend', `<div style="position:fixed;inset:0;display:grid;place-items:center;background:#0a0e18;color:#ece4cf;font:16px system-ui;padding:24px;text-align:center">Shards of Aethra needs WebGL 2 to run. Try a recent desktop browser.<br><small style="opacity:.6">${String(e.message || e)}</small></div>`);
    throw e;
  }
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
else start();
