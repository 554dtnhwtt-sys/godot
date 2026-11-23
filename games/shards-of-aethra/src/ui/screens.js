// Title screen, codex (champions, factions, relics, world lore), settings and online lobby.
import { CHAMPIONS, COST_COLORS, CHAMPION_BY_ID } from '../data/champions.js';
import { TRAITS, TRAIT_ORDER } from '../data/traits.js';
import { ITEMS, COMPONENT_ORDER, statLine } from '../data/items.js';
import { WORLD_LORE, GAME_TITLE } from '../data/world.js';
import { abilityText } from '../game/units.js';
import { itemIconURL, traitIconURL } from './icons.js';
import { portraitStyle } from './portraits.js';

const $ = (s, r = document) => r.querySelector(s);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export class Screens {
  constructor(app) {
    this.app = app;
    const root = document.getElementById('screens');
    root.innerHTML = `
      <div id="title" class="screen show"><div class="t-inner">
        <div class="logo"><h1>${GAME_TITLE.replace(' of ', '<br><span style="font-size:.45em;letter-spacing:.5em">OF</span><br>')}</h1><div class="tag">AN AUTO-BATTLER OF THE SHATTERED SKY</div></div>
        <div id="loading"><i></i></div>
        <div class="menu-col" id="title-menu" hidden>
          <button class="btn primary" id="t-play">Play</button>
          <button class="btn" id="t-online">Play online</button>
          <button class="btn" id="t-codex">Champions &amp; Lore</button>
          <button class="btn" id="t-settings">Settings</button>
          <div class="note">You against seven rival Wardens. Buy champions, combine three into a stronger star, forge relics and be the last Warden standing.</div>
        </div>
      </div></div>
      <div id="codex" class="screen"><div class="sheet panel brass">
        <header><h2>Codex</h2><div class="tabs"><button class="btn on" data-tab="champions">Champions</button><button class="btn" data-tab="factions">Traits</button><button class="btn" data-tab="relics">Relics</button><button class="btn" data-tab="world">The World</button><button class="btn" data-tab="howto">How to play</button></div><button class="btn x" id="codex-x">Close</button></header>
        <div class="body" id="codex-body"></div></div></div>
      <div id="settings" class="screen"><div class="sheet panel brass" style="inset:18vh 28vw">
        <header><h2>Settings</h2><button class="btn x" id="set-x">Close</button></header>
        <div class="body"><div class="settings-grid" id="set-grid"></div></div></div></div>
      <div id="lobby" class="screen"><div class="sheet panel brass" style="inset:10vh 22vw">
        <header><h2>Play online</h2><button class="btn x" id="lob-x">Back</button></header>
        <div class="body"><div class="lobby-box" id="lobby-box"></div></div></div></div>
      <div class="rotate-hint">Turn your device sideways for the best view of the arena.</div>`;
    $('#t-play').addEventListener('click', () => { app.audio.sfx('click'); app.startSolo(); });
    $('#t-online').addEventListener('click', () => { app.audio.sfx('click'); this.openLobby(); });
    $('#t-codex').addEventListener('click', () => { app.audio.sfx('click'); this.openCodex(); });
    $('#t-settings').addEventListener('click', () => { app.audio.sfx('click'); this.openSettings(); });
    $('#codex-x').addEventListener('click', () => this.close('codex'));
    $('#set-x').addEventListener('click', () => this.close('settings'));
    $('#lob-x').addEventListener('click', () => { this.close('lobby'); app.leaveLobby(); });
    document.querySelectorAll('#codex .tabs .btn').forEach((b) => b.addEventListener('click', () => this.codexTab(b.dataset.tab)));
  }

  setTitleArt(url) { $('#title').style.backgroundImage = `url(${url})`; }
  progress(k) { $('#loading i').style.width = `${Math.round(k * 100)}%`; }
  ready() { $('#loading').hidden = true; $('#title-menu').hidden = false; }
  show(id) { $(`#${id}`).classList.add('show'); }
  close(id) { $(`#${id}`).classList.remove('show'); }
  hideTitle() { this.close('title'); }
  showTitle() { this.show('title'); }

  // ───────────────────────── codex ─────────────────────────
  openCodex() {
    this.show('codex');
    this.codexTab(this.tab || 'champions');
  }

  codexTab(tab) {
    this.tab = tab;
    document.querySelectorAll('#codex .tabs .btn').forEach((b) => b.classList.toggle('on', b.dataset.tab === tab));
    const body = $('#codex-body');
    body.scrollTop = 0;
    if (tab === 'champions') {
      const sorted = CHAMPIONS.slice().sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name));
      body.innerHTML = `<div class="codex-grid">${sorted.map((c) => `<div class="codex-card" data-id="${c.id}" style="--cc:${COST_COLORS[c.cost]}" tabindex="0"><div class="cc-art" style="${portraitStyle(c.id)}"></div><div class="cc-body"><div class="cc-name">${c.name}</div><div class="cc-sub">${c.cost} gold &middot; ${c.traits.map((t) => TRAITS[t].name).join(' / ')}</div></div></div>`).join('')}</div>`;
      body.querySelectorAll('.codex-card').forEach((el) => el.addEventListener('click', () => this.champDetail(el.dataset.id)));
    } else if (tab === 'factions') {
      body.innerHTML = TRAIT_ORDER.map((id) => {
        const t = TRAITS[id];
        const members = CHAMPIONS.filter((c) => c.traits.includes(id)).map((c) => c.name).join(', ');
        return `<div class="faction" style="--tc:${t.color}"><img src="${traitIconURL(id, t.levels.length - 1)}" alt=""><div><h4>${t.name} <small style="color:var(--muted);font-family:var(--ui)">${t.kind === 'origin' ? 'Origin' : 'Class'}</small></h4>${t.lore ? `<p><i>${t.lore}</i></p>` : ''}<p>${t.desc}</p>${t.levels.map((l, i) => `<p>(${l}) ${t.tiers[i]}</p>`).join('')}<p class="members">${members}</p></div></div>`;
      }).join('');
    } else if (tab === 'relics') {
      const comps = COMPONENT_ORDER.map((id) => `<div class="recipe-row"><img src="${itemIconURL(id)}" alt=""><div><b>${ITEMS[id].name}</b><span>${ITEMS[id].desc}</span></div></div>`).join('');
      const done = Object.values(ITEMS).filter((i) => !i.component).map((it) => `<div class="recipe-row"><img src="${itemIconURL(it.id)}" alt=""><div><b>${it.name}</b><span class="rr-parts"><img src="${itemIconURL(it.recipe[0])}" alt=""> + <img src="${itemIconURL(it.recipe[1])}" alt=""> &nbsp;${statLine(it.stats)}</span><span>${it.desc}</span></div></div>`).join('');
      body.innerHTML = `<div class="lore-section"><h3>Components</h3><p>Monsters drop relic components. Drag one onto a champion. Two components on the same champion fuse into a completed relic. A champion holds up to three.</p></div><div class="recipes">${comps}</div><div class="lore-section" style="margin-top:1.6rem"><h3>Completed relics</h3></div><div class="recipes">${done}</div>`;
    } else if (tab === 'world') {
      body.innerHTML = WORLD_LORE.map((s) => `<div class="lore-section"><h3>${s.heading}</h3><p>${s.text}</p></div>`).join('') +
        `<div class="lore-section"><h3>The six shards</h3>${['ember', 'tide', 'wild', 'hollow', 'gear', 'frost'].map((id) => `<div class="faction" style="--tc:${TRAITS[id].color}"><img src="${traitIconURL(id, 1)}" alt=""><div><h4>${TRAITS[id].name}</h4><p>${TRAITS[id].lore}</p></div></div>`).join('')}</div>`;
    } else if (tab === 'howto') {
      body.innerHTML = `<div class="lore-section"><h3>The round</h3><p>Each round has a planning phase and a combat phase. While planning, buy champions from the shop at the bottom, drag them from your bench onto the hex board, and arrange them. When the timer runs out your champions fight on their own against another Warden's board.</p></div>
        <div class="lore-section"><h3>Stars</h3><p>Three copies of the same champion fuse into a two-star champion with far more health and damage. Three two-stars become a three-star. Cards that would complete an upgrade glow in the shop.</p></div>
        <div class="lore-section"><h3>Gold</h3><p>You earn gold every round: a base income, one gold of interest for every ten you hold (up to five), and a bonus for winning or losing streaks. Spend it on champions, on refreshing the shop (2 gold, D) or on experience (4 gold, F). Higher levels let you field more champions and find rarer ones.</p></div>
        <div class="lore-section"><h3>Traits</h3><p>Champions share origins and classes. Field enough different champions of a trait and the whole team gains its bonus. Active traits are listed on the left; hover them to read what they do.</p></div>
        <div class="lore-section"><h3>Health</h3><p>Losing a fight costs your Warden health: a base amount for the stage plus more for every enemy champion left standing. At zero you are out. The last Warden standing wins.</p></div>
        <div class="lore-section"><h3>Controls</h3><p>Drag champions to move them. Drag a champion onto the shop to sell it, or hover it and press E. Click a champion to see its stats, ability and lore. Drag relics from the left onto champions.</p></div>`;
    }
  }

  champDetail(id) {
    const c = CHAMPION_BY_ID[id];
    const body = $('#codex-body');
    body.innerHTML = `<button class="btn" id="cd-back" style="margin-bottom:1rem">&larr; All champions</button>
      <div class="codex-detail"><div class="cd-art" style="${portraitStyle(id)};--cc:${COST_COLORS[c.cost]}"></div>
      <div><h3>${c.name}</h3><div class="cd-title">${c.title} &middot; <span style="color:${COST_COLORS[c.cost]}">${c.cost} gold</span> &middot; ${c.traits.map((t) => TRAITS[t].name).join(' / ')}</div>
      <p>${c.lore}</p>
      <div class="i-ab panel" style="padding:.7rem;margin:.8rem 0"><h4 style="margin:0 0 .3rem;font-family:var(--display);color:var(--brass-hi)">${c.ability.name}</h4><p style="margin:0">${abilityText(id, 1)}</p></div>
      <p style="color:var(--muted);margin-bottom:.2rem">Voice lines</p>
      <div class="lines">${[...c.lines.select.map((t, i) => ['select' + i, t]), ['ability', c.lines.ability], ['upgrade', c.lines.upgrade], ['death', c.lines.death]].map(([k, t]) => `<button class="btn" data-file="${id}_${k}">&#128266; “${esc(t)}”</button>`).join('')}</div>
      </div></div>`;
    $('#cd-back').addEventListener('click', () => this.codexTab('champions'));
    body.querySelectorAll('[data-file]').forEach((b) => b.addEventListener('click', () => { this.app.audio.unlock(); this.app.audio.playVoiceFile(b.dataset.file, 1); }));
  }

  // ───────────────────────── settings ─────────────────────────
  openSettings() {
    const a = this.app.audio;
    const grid = $('#set-grid');
    const row = (key, label) => `<label for="v-${key}">${label}</label><input type="range" id="v-${key}" min="0" max="1" step="0.05" value="${a.vol[key]}"><span id="vv-${key}">${Math.round(a.vol[key] * 100)}</span>`;
    grid.innerHTML = row('master', 'Master volume') + row('music', 'Music') + row('sfx', 'Effects') + row('voice', 'Voices') +
      `<label for="v-quality">Graphics</label><select id="v-quality"><option value="high">High</option><option value="medium">Medium</option><option value="low">Low</option></select><span></span>`;
    for (const k of ['master', 'music', 'sfx', 'voice']) {
      $(`#v-${k}`).addEventListener('input', (e) => { a.setVolume(k, +e.target.value); $(`#vv-${k}`).textContent = Math.round(e.target.value * 100); });
    }
    const q = $('#v-quality');
    q.value = this.app.quality;
    q.addEventListener('change', () => this.app.setQuality(q.value));
    this.show('settings');
  }

  // ───────────────────────── lobby ─────────────────────────
  openLobby() {
    this.show('lobby');
    this.app.openLobby($('#lobby-box'));
  }
}
