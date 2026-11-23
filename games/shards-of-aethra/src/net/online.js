// Online lobbies over the claude.ai artifact "room" channel.
// Every player keeps one presence object. The host (first to join) announces the game seed;
// each round every Warden posts a board snapshot, the host locks the round, and every client
// computes every fight itself with the deterministic combat sim, so all screens agree.
import { CHAMPIONS } from '../data/champions.js';
import { ITEMS } from '../data/items.js';
import { BOONS } from '../data/world.js';
import { Match } from '../game/match.js';
import { hashString } from '../core/rng.js';

const CHAMP_IDS = CHAMPIONS.map((c) => c.id);
const ITEM_IDS = Object.keys(ITEMS);
const BOON_IDS = BOONS.map((b) => b.id);
const COLORS = ['#f3d891', '#7fe8ff', '#ff8a6a', '#9cff8a', '#c89cff', '#ffb35a', '#6ab0ff', '#ff7ab8'];

function encodeSnap(s) {
  return {
    u: s.units.map((x) => [x.cell, CHAMP_IDS.indexOf(x.owned.id), x.owned.star, ...x.owned.items.map((i) => ITEM_IDS.indexOf(i))]),
    b: s.boons.map((b) => BOON_IDS.indexOf(b)).filter((i) => i >= 0),
  };
}

function decodeSnap(e, salt) {
  if (!e || !Array.isArray(e.u)) return { units: [], boons: [] };
  const units = [];
  e.u.slice(0, 12).forEach((a, k) => {
    if (!Array.isArray(a)) return;
    const [cell, ci, star, ...items] = a;
    const id = CHAMP_IDS[ci];
    if (!id || !(cell >= 0 && cell < 28) || ![1, 2, 3].includes(star)) return;
    units.push({ owned: { uid: 100000 + salt * 100 + k, id, star, items: items.slice(0, 3).map((i) => ITEM_IDS[i]).filter(Boolean) }, cell });
  });
  const boons = (e.b || []).map((i) => BOON_IDS[i]).filter(Boolean);
  return { units, boons };
}

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export class Online {
  constructor(app) {
    this.app = app;
    this.room = null;
    this.lobby = null;
    this.joinedAt = 0;
    this.match = null;
    this.waiters = [];
  }

  myName() {
    try { return (localStorage.getItem('soa.name') || 'Warden').slice(0, 16); } catch { return 'Warden'; }
  }
  setName(n) {
    try { localStorage.setItem('soa.name', n); } catch { /* ignore */ }
  }

  async open(el) {
    this.el = el;
    el.innerHTML = `<p class="lobby-status">Connecting to the Convergence…</p>`;
    let room = null;
    try { room = window.claude && window.claude.use ? await window.claude.use('room') : null; } catch { room = null; }
    this.room = room;
    if (!room) {
      el.innerHTML = `<p class="lobby-status">Online lobbies work when this game is opened as a shared claude.ai artifact by signed-in players. Share the artifact with friends, open it, and you can create a room here.</p>
        <p class="lobby-status">In this view you can still play the full game against seven rival Wardens.</p>
        <div class="menu-col" style="margin:0 auto"><button class="btn primary" id="lb-solo">Play solo</button></div>`;
      el.querySelector('#lb-solo').addEventListener('click', () => this.app.startSolo());
      return;
    }
    this.renderJoin();
  }

  renderJoin(msg = '') {
    const el = this.el;
    el.innerHTML = `<label>Your Warden name<input id="lb-name" maxlength="16" value="${esc(this.myName())}"></label>
      <div class="menu-col" style="width:100%"><button class="btn primary" id="lb-create">Create a room</button></div>
      <label>Or join with a room code<input id="lb-code" maxlength="8" placeholder="e.g. K7QF2" style="text-transform:uppercase"></label>
      <div class="menu-col" style="width:100%"><button class="btn" id="lb-join">Join room</button></div>
      <p class="lobby-status">${msg || 'Rooms hold up to eight Wardens. Empty seats can be filled with rival Wardens.'}</p>`;
    const nameEl = el.querySelector('#lb-name');
    nameEl.addEventListener('change', () => this.setName(nameEl.value.trim() || 'Warden'));
    el.querySelector('#lb-create').addEventListener('click', () => {
      this.setName(nameEl.value.trim() || 'Warden');
      const code = Array.from({ length: 5 }, () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Math.floor(Math.random() * 32)]).join('');
      this.join(code);
    });
    el.querySelector('#lb-join').addEventListener('click', () => {
      this.setName(nameEl.value.trim() || 'Warden');
      const code = el.querySelector('#lb-code').value.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
      if (code.length < 3) return;
      this.join(code);
    });
  }

  async join(code) {
    this.code = code;
    try {
      this.lobby = await this.room.join(`soa-${code.toLowerCase()}`);
    } catch (e) {
      this.renderJoin(`Could not join that room (${esc(e && e.code ? e.code : 'error')}).`);
      return;
    }
    this.joinedAt = Date.now();
    this.started = false;
    await this.lobby.presence({ v: 1, n: this.myName(), t: this.joinedAt, st: 'lobby', fill: true }).catch(() => {});
    this.unsub = this.lobby.onPeers(() => this.onPeers());
    this.renderRoom();
  }

  peers() {
    return this.lobby ? this.lobby.peers().filter((p) => p.presence && p.presence.v === 1) : [];
  }

  hostPeer(list = this.peers()) {
    const cand = list.filter((p) => p.presence.st !== 'out');
    cand.sort((a, b) => (a.presence.t - b.presence.t) || (a.peer < b.peer ? -1 : 1));
    return cand[0] || null;
  }

  isHost() {
    const h = this.hostPeer();
    return !!h && h.sameTab;
  }

  renderRoom() {
    if (!this.lobby || this.started) return;
    const el = this.el;
    const list = this.peers().filter((p) => p.presence.st === 'lobby');
    const host = this.hostPeer(list);
    const me = list.find((p) => p.sameTab);
    el.innerHTML = `<p class="lobby-status">Room code <b style="font-family:var(--display);font-size:1.6rem;color:var(--brass-hi);letter-spacing:.2em">${esc(this.code)}</b><br>Share this artifact with your friends and give them the code. They join from “Play online”.</p>
      <div class="lobby-list">${list.map((p, i) => `<div class="pl ${p.sameTab ? 'me' : ''}"><span class="av" style="background:${COLORS[i % 8]}">${esc((p.presence.n || '?')[0])}</span><div class="pl-body"><div class="pl-name">${esc(p.presence.n || 'Warden')}${p === host ? ' &middot; host' : ''}${p.guest ? ' &middot; guest' : ''}</div></div></div>`).join('')}</div>
      ${host && host.sameTab ? `<label style="flex-direction:row;align-items:center;gap:.5rem"><input type="checkbox" id="lb-fill" checked style="width:auto"> Fill empty seats with rival Wardens</label><div class="menu-col" style="width:100%"><button class="btn primary" id="lb-start" ${list.length < 1 ? 'disabled' : ''}>Start game (${list.length} ${list.length === 1 ? 'Warden' : 'Wardens'})</button></div>` : `<p class="lobby-status">Waiting for the host to start…</p>`}`;
    const start = el.querySelector('#lb-start');
    if (start) start.addEventListener('click', () => this.hostStart(el.querySelector('#lb-fill').checked));
    if (!me) el.insertAdjacentHTML('beforeend', '<p class="lobby-status">Connecting…</p>');
  }

  async hostStart(fill) {
    const list = this.peers().filter((p) => p.presence.st === 'lobby').slice(0, 8);
    const seed = (Math.random() * 2 ** 32) >>> 0;
    const g = { id: seed.toString(36), seed, ids: list.map((p) => p.peer), names: list.map((p) => (p.presence.n || 'Warden').slice(0, 16)), fill };
    await this.lobby.presence({ st: 'game', g }).catch(() => {});
    this.startGame(g);
  }

  onPeers() {
    if (!this.started) {
      // Did the host start a game that includes us?
      const host = this.hostPeer();
      const mine = this.peers().find((p) => p.sameTab);
      if (host && !host.sameTab && host.presence.g && mine && host.presence.g.ids.includes(mine.peer)) {
        this.lobby.presence({ st: 'game', g: host.presence.g }).catch(() => {});
        this.startGame(host.presence.g);
        return;
      }
      this.renderRoom();
      return;
    }
    this.checkRound();
  }

  startGame(g) {
    if (this.started) return;
    this.started = true;
    this.game = g;
    const me = this.peers().find((p) => p.sameTab);
    const myPeer = me ? me.peer : null;
    const humans = g.ids.map((peer, i) => ({ id: `p:${peer}`, name: g.names[i], color: COLORS[i % 8], kind: peer === myPeer ? 'human' : 'remote' }));
    this.myId = `p:${myPeer}`;
    this.lastSnaps = {};
    this.locks = {};
    const match = new Match({ seed: g.seed, humans, localId: this.myId, fillBots: g.fill !== false, net: this });
    this.match = match;
    this.app.begin(match);
    match.on('gameover', () => { if (this.lobby) this.lobby.presence({ st: 'out' }).catch(() => {}); });
    match.on('player-out', (p) => { if (p === match.local && this.lobby) this.lobby.presence({ st: 'out' }).catch(() => {}); });
    document.getElementById('roomtag').textContent = `Online room ${this.code}`;
  }

  // Called by Match at the end of planning. Resolves with { playerId: snapshot } for remote players.
  submitRound(match, key, snap, pub) {
    const enc = encodeSnap(snap);
    this.lobby.presence({ sub: { k: key, s: enc, h: pub.hp, l: pub.level } }).catch(() => {});
    return new Promise((resolve) => {
      this.waiters.push({ key, resolve, since: Date.now() });
      this.checkRound();
      // Safety net: if the host vanishes and nobody locks, resolve with what we have.
      setTimeout(() => this.forceResolve(key), 25000);
    });
  }

  alivePeers() {
    if (!this.match) return [];
    return this.match.players.filter((p) => p.kind !== 'bot' && p.alive).map((p) => p.id.slice(2));
  }

  checkRound() {
    if (!this.match || !this.waiters.length) return;
    const peers = this.peers();
    const byPeer = new Map(peers.map((p) => [p.peer, p]));
    const w = this.waiters[0];
    const key = w.key;
    // Host: decide the lock when everyone alive has submitted (or after 12s).
    if (this.isHost()) {
      const alive = this.alivePeers();
      const have = alive.filter((peer) => { const p = byPeer.get(peer); return p && p.presence.sub && p.presence.sub.k === key; });
      const timedOut = Date.now() - w.since > 12000;
      const missing = alive.filter((peer) => !have.includes(peer) && byPeer.has(peer));
      if (!missing.length || timedOut) {
        const lock = { k: key, have };
        if (!this.myLock || this.myLock.k !== key) {
          this.myLock = lock;
          this.lobby.presence({ lock }).catch(() => {});
        }
      } else if (!this.retryT) {
        this.retryT = setTimeout(() => { this.retryT = null; this.checkRound(); }, 1000);
      }
    }
    const host = this.hostPeer();
    const lock = host ? (host.sameTab ? this.myLock : host.presence.lock) : null;
    if (!lock || lock.k !== key) return;
    // Gather snapshots named in the lock; wait if one has not reached us yet.
    const snaps = {};
    for (const peer of lock.have) {
      const p = byPeer.get(peer);
      const id = `p:${peer}`;
      if (id === this.myId) continue;
      if (!p || !p.presence.sub || p.presence.sub.k !== key) {
        if (Date.now() - w.since < 8000) { if (!this.retryT) this.retryT = setTimeout(() => { this.retryT = null; this.checkRound(); }, 500); return; }
        continue;
      }
      snaps[id] = decodeSnap(p.presence.sub.s, hashString(peer) % 997);
      const pl = this.match.players.find((x) => x.id === id);
      if (pl) { pl.level = p.presence.sub.l || pl.level; }
    }
    if (!lock.have.includes(this.myId.slice(2))) snaps.__selfStale = true;
    this.waiters.shift();
    w.resolve(snaps);
  }

  forceResolve(key) {
    const w = this.waiters.find((x) => x.key === key);
    if (!w) return;
    this.waiters = this.waiters.filter((x) => x !== w);
    w.resolve({});
  }

  leave() {
    if (this.unsub) this.unsub();
    if (this.lobby) this.lobby.leave().catch(() => {});
    this.lobby = null;
    this.started = false;
    this.match = null;
    this.waiters = [];
  }
}
