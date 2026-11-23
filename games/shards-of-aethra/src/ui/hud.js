// In-game interface: stage tracker, traits, players, shop, relics, unit info and choice screens.
import { CHAMPION_BY_ID, COST_COLORS, CHAMPIONS } from '../data/champions.js';
import { TRAITS } from '../data/traits.js';
import { ITEMS, statLine } from '../data/items.js';
import { BOONS, roundKind, roundsInStage, BOON_ROUNDS } from '../data/world.js';
import { computeStats, abilityText, sellValue, activeTraits } from '../game/units.js';
import { itemIconURL, traitIconURL, glyphIconURL } from './icons.js';
import { portraitStyle } from './portraits.js';

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export class HUD {
  constructor({ audio }) {
    this.audio = audio;
    this.root = document.getElementById('hud');
    this.root.innerHTML = `
      <div id="menu">
        <button class="btn" id="m-codex" title="Champions and lore">Codex</button>
        <button class="btn" id="m-settings" title="Settings">Settings</button>
        <button class="btn" id="m-speed" title="Combat speed">1×</button>
      </div>
      <div id="roomtag"></div>
      <div id="stage"><div class="st-row panel brass"><span class="st-label"></span><span class="st-pips"></span></div>
        <div class="st-phase"><span class="st-name"></span><span class="st-timer"><i></i></span><span class="st-secs"></span></div>
        <div id="versus" class="panel"></div></div>
      <div id="traits"></div>
      <div id="players"></div>
      <div id="info" class="panel brass"></div>
      <div id="relics"></div>
      <div id="goldbox" class="panel brass"><span class="coin"></span><span class="g-n">0</span><span class="g-info"></span><span class="g-streak"></span></div>
      <div id="shopbar" class="panel brass">
        <div class="side">
          <div class="lvl panel"><div class="lvl-top"><span class="lvl-n">Level 1</span><span class="lvl-xp">0/2</span></div><div class="xpbar"><i></i></div><span class="lvl-units"></span></div>
          <button class="btn act" id="b-xp"><span>Buy XP <kbd>F</kbd></span><span class="cost"><span class="coin"></span>4</span></button>
          <button class="btn act" id="b-roll"><span>Refresh <kbd>D</kbd></span><span class="cost"><span class="coin"></span><b>2</b></span></button>
        </div>
        <div id="shop"></div>
        <button class="btn lockbtn" id="b-lock" title="Lock the shop for next round">&#128274;</button>
      </div>
      <div id="sellzone">Sell for <span class="gold" id="sell-val"></span> gold</div>
      <div id="subtitle"></div>
      <div id="toast"></div>
      <div id="banner"><h1></h1><p></p></div>
      <div id="m-boon" class="modal"></div>
      <div id="m-draft" class="modal"></div>
      <div id="m-end" class="modal"></div>
      <div id="tip" class="panel brass"></div>`;
    this.tip = $('#tip');
    this.selected = null;
    this.selectedCombat = null;
    this.speedIdx = 0;
    this.bindStatic();
    audio.subtitle = (text, dur) => this.showSubtitle(text, dur);
  }

  bind(match, world, app) {
    this.match = match;
    this.world = world;
    this.app = app;
    this.lastShopKey = '';
    this.render();
  }

  bindStatic() {
    $('#b-xp').addEventListener('click', () => { if (this.match.buyXp()) this.audio.sfx('xp'); else this.audio.sfx('error'); });
    $('#b-roll').addEventListener('click', () => this.reroll());
    $('#b-lock').addEventListener('click', () => { this.match.toggleLock(); this.audio.sfx('click'); });
    $('#m-codex').addEventListener('click', () => this.app.openCodex());
    $('#m-settings').addEventListener('click', () => this.app.openSettings());
    $('#m-speed').addEventListener('click', () => {
      const speeds = [1, 1.5, 2];
      this.speedIdx = (this.speedIdx + 1) % speeds.length;
      const s = speeds[this.speedIdx];
      this.match.combatSpeed = this.match.online ? 1 : s;
      this.world.speed = this.match.combatSpeed;
      $('#m-speed').textContent = `${this.match.combatSpeed}×`;
      this.audio.sfx('click');
    });
    window.addEventListener('keydown', (e) => {
      if (!this.match || e.target.tagName === 'INPUT') return;
      const k = e.key.toLowerCase();
      if (k === 'd') this.reroll();
      else if (k === 'f') { if (this.match.buyXp()) this.audio.sfx('xp'); }
      else if (k === 'e' && this.world.hoverView && this.world.planViews.has(this.world.hoverView.uid)) { this.match.sell(this.world.hoverView.uid); this.audio.sfx('sell'); }
      else if (k === 'escape') this.selectUnit(null);
    });
    document.addEventListener('pointermove', (e) => this.moveTip(e));
  }

  reroll() {
    if (this.match.reroll()) this.audio.sfx('reroll'); else this.audio.sfx('error');
  }

  // ───────────────────────── tooltip ─────────────────────────
  attachTip(el, html) {
    el.addEventListener('pointerenter', () => { this.tip.innerHTML = typeof html === 'function' ? html() : html; this.tip.classList.add('show'); });
    el.addEventListener('pointerleave', () => this.tip.classList.remove('show'));
  }
  moveTip(e) {
    if (!this.tip.classList.contains('show')) return;
    const w = this.tip.offsetWidth;
    const h = this.tip.offsetHeight;
    let x = e.clientX + 16;
    let y = e.clientY + 16;
    if (x + w > window.innerWidth - 8) x = e.clientX - w - 16;
    if (y + h > window.innerHeight - 8) y = e.clientY - h - 16;
    this.tip.style.left = `${Math.max(8, x)}px`;
    this.tip.style.top = `${Math.max(8, y)}px`;
  }
  traitTip(id, count = 0) {
    const t = TRAITS[id];
    const members = CHAMPIONS.filter((c) => c.traits.includes(id)).map((c) => c.name).join(', ');
    return `<h5><img src="${traitIconURL(id, 1)}" alt="">${t.name}</h5><p>${t.desc}</p>${t.levels.map((l, i) => `<p class="tier ${count >= l && (i === t.levels.length - 1 || count < t.levels[i + 1]) ? 'on' : ''}">(${l}) ${t.tiers[i]}</p>`).join('')}<p class="tier" style="margin-top:.4rem">${members}</p>`;
  }
  itemTip(id) {
    const it = ITEMS[id];
    if (!it) return '';
    const recipe = it.recipe ? `<div class="recipe"><img src="${itemIconURL(it.recipe[0])}" alt=""> + <img src="${itemIconURL(it.recipe[1])}" alt=""></div>` : '<p class="tier">Combine two components on a champion to forge a relic.</p>';
    return `<h5><img src="${itemIconURL(id)}" alt="">${it.name}</h5><p class="stat">${statLine(it.stats)}</p>${it.component ? '' : `<p>${it.desc}</p>`}${recipe}`;
  }

  // ───────────────────────── renderers ─────────────────────────
  render() {
    if (!this.match) return;
    this.renderStage();
    this.renderTraits();
    this.renderPlayers();
    this.renderShop();
    this.renderEconomy();
    this.renderRelics();
    if (this.selected) this.renderInfo();
  }

  renderStage() {
    const m = this.match;
    const label = m.round === 0 ? 'Opening Draft' : `Stage ${m.stage}-${m.round}`;
    $('#stage .st-label').textContent = label;
    const pips = [];
    if (m.round > 0) {
      const n = roundsInStage(m.stage);
      for (let r = 1; r <= n; r++) {
        const kind = roundKind(m.stage, r);
        const key = `${m.stage}-${r}`;
        const icon = kind === 'pve' ? 'skull' : kind === 'draft' ? 'chest' : BOON_ROUNDS.includes(key) ? 'star' : 'swords';
        const hist = m.local.history.find((h) => h.key === key);
        const cls = r === m.round ? 'now' : r < m.round ? (hist ? hist.res : 'done') : '';
        pips.push(`<span class="pip ${cls}"><img src="${glyphIconURL(icon, kind === 'pve' ? '#d8b0ff' : kind === 'draft' ? '#ffd27a' : '#e8e0d0')}" alt="${kind}"></span>`);
      }
    }
    const pipHtml = pips.join('');
    if (pipHtml !== this.lastPips) { $('#stage .st-pips').innerHTML = pipHtml; this.lastPips = pipHtml; }
    const names = { intro: 'The Convergence opens', draft: 'Choose a champion', planning: m.kind() === 'pve' ? 'Planning: monsters ahead' : 'Planning', combat: 'Combat', results: 'Round over', sync: 'Waiting for Wardens', gameover: 'Game over' };
    $('#stage .st-name').textContent = names[m.phase] || m.phase;
  }

  tick() {
    // Called every frame: timer only.
    const m = this.match;
    if (!m) return;
    const timed = m.phase === 'planning' || m.phase === 'draft' || m.phase === 'sync';
    const timer = $('#stage .st-timer');
    timer.style.visibility = timed ? 'visible' : 'hidden';
    const secs = Math.max(0, Math.ceil(m.timeLeft));
    $('#stage .st-secs').textContent = timed ? secs : '';
    if (timed) {
      timer.querySelector('i').style.width = `${Math.max(0, (m.timeLeft / m.phaseTotal) * 100)}%`;
      timer.classList.toggle('urgent', m.timeLeft < 6);
      if (secs !== this.lastSecs && secs <= 5 && secs > 0 && m.phase === 'planning') this.audio.sfx('tick', 0.6);
    }
    this.lastSecs = secs;
    if (this.selectedCombat) this.renderCombatInfo();
  }

  renderTraits() {
    const p = this.match.local;
    const list = activeTraits(p.traitCounts());
    const key = list.map((t) => `${t.id}${t.count}${t.tier}`).join('|');
    if (key === this.lastTraits) return;
    this.lastTraits = key;
    const el = $('#traits');
    el.innerHTML = '';
    for (const t of list) {
      const tr = TRAITS[t.id];
      const row = document.createElement('div');
      row.className = `trait ${t.tier >= 0 ? 'on' : 'off'}`;
      row.style.setProperty('--tc', tr.color);
      const steps = tr.levels.map((l, i) => (i === t.tier ? `<b>${l}</b>` : l)).join(' / ');
      row.innerHTML = `<img src="${traitIconURL(t.id, t.tier)}" alt=""><div class="t-body"><span class="t-name">${tr.name}</span><span class="t-steps">${steps}</span></div><span class="t-count">${t.count}</span>`;
      this.attachTip(row, () => this.traitTip(t.id, t.count));
      el.appendChild(row);
    }
  }

  renderPlayers() {
    const m = this.match;
    const sorted = m.players.slice().sort((a, b) => (b.alive - a.alive) || (b.hp - a.hp) || (a.place - b.place));
    const vsId = m.viewOpponent ? m.viewOpponent.id : null;
    const html = sorted.map((p) => {
      const initial = esc(p.name[0] || '?');
      const streak = Math.abs(p.streak) >= 2 ? `<span class="streak ${p.streak < 0 ? 'cold' : ''}">${p.streak > 0 ? '&#9650;' : '&#9660;'}${Math.abs(p.streak)}</span>` : '';
      const right = p.alive ? `<span class="pl-hpn">${Math.max(0, p.hp)}</span>` : `<span class="pl-place">#${p.place}</span>`;
      return `<div class="pl ${p === m.local ? 'me' : ''} ${p.id === vsId ? 'vs' : ''} ${p.alive ? '' : 'out'}"><span class="av" style="background:radial-gradient(circle at 35% 30%, #fff8, ${p.color} 45%, #000 140%)">${initial}</span><div class="pl-body"><div class="pl-name">${esc(p.name)} ${streak}</div><div class="pl-hp"><i style="width:${Math.max(0, p.hp)}%"></i></div></div>${right}</div>`;
    }).join('');
    if (html !== this.lastPlayers) { $('#players').innerHTML = html; this.lastPlayers = html; }
  }

  renderEconomy() {
    const p = this.match.local;
    $('#goldbox .g-n').textContent = p.gold;
    const inc = p.income(this.match.stage);
    $('#goldbox .g-info').textContent = `+${inc.interest} interest`;
    const s = $('#goldbox .g-streak');
    s.textContent = Math.abs(p.streak) >= 2 ? `${p.streak > 0 ? 'Win' : 'Loss'} streak ${Math.abs(p.streak)}` : '';
    s.className = `g-streak ${p.streak < 0 ? 'cold' : ''}`;
    $('.lvl-n').textContent = `Level ${p.level}`;
    const need = p.xpNeeded();
    $('.lvl-xp').textContent = p.level >= 10 ? 'Max' : `${p.xp}/${need}`;
    $('.xpbar i').style.width = p.level >= 10 ? '100%' : `${(p.xp / need) * 100}%`;
    $('#b-xp').disabled = p.gold < 4 || p.level >= 10;
    $('#b-roll').disabled = p.gold < 2 && p.freeRerolls <= 0;
    $('#b-roll b').textContent = p.freeRerolls > 0 ? 'Free' : '2';
    $('#b-lock').classList.toggle('on', p.shopLocked);
    $('.lvl-units').innerHTML = `Board <b>${p.boardCount()}/${p.maxBoard()}</b> champions`;
  }

  renderShop() {
    const p = this.match.local;
    const owned = {};
    for (const u of p.allUnits()) if (u.star === 1) owned[u.id] = (owned[u.id] || 0) + 1;
    const key = p.shop.join(',') + '|' + p.gold + '|' + JSON.stringify(owned);
    if (key === this.lastShopKey) return;
    this.lastShopKey = key;
    const el = $('#shop');
    el.innerHTML = '';
    p.shop.forEach((id, i) => {
      const card = document.createElement('div');
      if (!id) { card.className = 'card empty'; el.appendChild(card); return; }
      const ch = CHAMPION_BY_ID[id];
      const pair = (owned[id] || 0) >= 2;
      card.className = `card ${p.gold < ch.cost ? 'poor' : ''} ${pair ? 'pair' : ''}`;
      card.style.setProperty('--cc', COST_COLORS[ch.cost]);
      card.innerHTML = `<div class="art" style="${portraitStyle(id)}"></div><div class="shade"></div>
        <div class="c-traits">${ch.traits.map((t) => `<span><img src="${traitIconURL(t, 0)}" alt="">${TRAITS[t].name}</span>`).join('')}</div>
        ${pair ? '<span class="c-badge">&#9733; UPGRADE</span>' : ''}
        <span class="c-name">${ch.name}</span><span class="c-cost"><span class="coin"></span>${ch.cost}</span>`;
      card.addEventListener('click', () => {
        if (this.match.buy(i)) { this.audio.sfx('buy'); card.style.opacity = '0'; }
        else this.audio.sfx('error');
      });
      card.addEventListener('pointerenter', () => this.audio.sfx('hover', 0.5));
      this.attachTip(card, () => `<h5>${ch.name} <small style="color:${COST_COLORS[ch.cost]}">${ch.cost}&#9679;</small></h5><p class="tier">${ch.title}</p><p><b>${ch.ability.name}:</b> ${abilityText(id, 1)}</p>`);
      el.appendChild(card);
    });
  }

  renderRelics() {
    const p = this.match.local;
    const key = p.items.join(',');
    if (key === this.lastRelics) return;
    this.lastRelics = key;
    const el = $('#relics');
    el.innerHTML = '';
    for (let i = 0; i < 10; i++) {
      const id = p.items[i];
      const slot = document.createElement('div');
      slot.className = `relic ${id ? 'filled' : ''}`;
      if (id) {
        slot.innerHTML = `<img src="${itemIconURL(id)}" alt="${esc(ITEMS[id].name)}">`;
        this.attachTip(slot, () => this.itemTip(id));
        slot.addEventListener('pointerdown', (e) => this.dragRelic(e, i, id));
      }
      el.appendChild(slot);
    }
  }

  dragRelic(e, index, id) {
    e.preventDefault();
    this.tip.classList.remove('show');
    const ghost = document.createElement('img');
    ghost.src = itemIconURL(id);
    ghost.className = 'relic-ghost';
    ghost.style.left = `${e.clientX}px`;
    ghost.style.top = `${e.clientY}px`;
    document.body.appendChild(ghost);
    this.audio.sfx('pickup', 0.5);
    let hoverView = null;
    const move = (ev) => {
      ghost.style.left = `${ev.clientX}px`;
      ghost.style.top = `${ev.clientY}px`;
      const v = this.world.unitAtClient(ev.clientX, ev.clientY);
      if (v !== hoverView) {
        if (hoverView) hoverView.tint(0x000000, 0);
        hoverView = v;
        if (v) v.tint(0x5a4a10, 1);
      }
    };
    const up = (ev) => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
      ghost.remove();
      if (hoverView) hoverView.tint(0x000000, 0);
      const v = this.world.unitAtClient(ev.clientX, ev.clientY);
      if (v) {
        if (this.match.phase === 'combat' && v.where === 'board') { this.toast('Relics cannot be given to fighting champions.'); return; }
        if (this.match.equip(index, v.uid)) {
          this.audio.sfx('coin');
          this.world.vfx.burst(v.root.position.clone().setY(1.2), 0xffd27a, { n: 18, speed: 2.5, life: 0.5 });
          if (this.selected === v.uid) this.renderInfo();
        } else this.audio.sfx('error');
      }
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
  }

  // ───────────────────────── unit info ─────────────────────────
  selectUnit(uid) {
    this.selected = uid;
    this.selectedCombat = null;
    if (!uid) { $('#info').classList.remove('show'); return; }
    this.renderInfo();
    $('#info').classList.add('show');
  }

  selectCombatUnit(u) {
    this.selected = null;
    this.selectedCombat = u;
    this.renderCombatInfo(true);
    $('#info').classList.add('show');
  }

  infoHtml(id, star, items, stats, extra = '') {
    if (!CHAMPION_BY_ID[id]) return '';
    const ch = CHAMPION_BY_ID[id];
    const stars = '&#9733;'.repeat(star);
    const st = (label, v) => `<div><span>${label}</span><b>${v}</b></div>`;
    return `<button class="i-close" aria-label="Close">&#10005;</button>
      <div class="i-art" style="${portraitStyle(id)}"></div>
      <div class="i-head"><div class="i-name">${ch.name} <span style="color:${star === 3 ? '#7ae8ff' : star === 2 ? '#ffd45a' : '#c8d0dc'}">${stars}</span></div><div class="i-title">${ch.title} &middot; <span style="color:${COST_COLORS[ch.cost]}">${ch.cost} gold</span></div>
      <div class="i-traits">${ch.traits.map((t) => `<span data-trait="${t}"><img src="${traitIconURL(t, 0)}" alt="">${TRAITS[t].name}</span>`).join('')}</div></div>
      <div class="i-stats">${st('Health', Math.round(stats.hp))}${st('Attack', Math.round(stats.ad))}${st('Speed', stats.as.toFixed(2))}${st('Range', stats.range)}${st('Armor', Math.round(stats.armor))}${st('Magic Res', Math.round(stats.mr))}${st('Ability Pwr', Math.round(stats.ap))}${st('Mana', `${Math.round(stats.mana)}/${stats.maxMana}`)}</div>
      <div class="i-ab"><h4>${ch.ability.name}<small>${ch.ability.type}</small></h4><p>${abilityText(id, star, stats.ap)}</p></div>
      ${items.length ? `<div class="i-items">${items.map((i) => `<img src="${itemIconURL(i)}" data-item="${i}" alt="">`).join('')}</div>` : ''}
      <div class="i-lore">${ch.lore}</div>${extra}`;
  }

  renderInfo() {
    const loc = this.match.local.locate(this.selected);
    if (!loc) { this.selectUnit(null); return; }
    const u = loc.unit;
    const stats = computeStats(u);
    const value = sellValue(u);
    const el = $('#info');
    el.innerHTML = this.infoHtml(u.id, u.star, u.items, stats, `<div class="i-foot"><button class="btn" id="i-sell">Sell for ${value}<span class="coin" style="margin-left:.3rem"></span></button><button class="btn" id="i-voice">&#128266; Voice</button></div>`);
    this.wireInfo(el, u.id);
    $('#i-sell', el).addEventListener('click', () => { this.match.sell(u.uid); this.audio.sfx('sell'); this.selectUnit(null); });
  }

  renderCombatInfo(force = false) {
    const u = this.selectedCombat;
    if (!u) return;
    if (!force && this.lastCombatInfoT && performance.now() - this.lastCombatInfoT < 250) return;
    this.lastCombatInfoT = performance.now();
    const el = $('#info');
    if (u.isMonster) {
      el.innerHTML = `<button class="i-close" aria-label="Close">&#10005;</button><div class="i-head" style="margin-top:.8rem"><div class="i-name">${esc(u.name)}</div><div class="i-title">Monster of the Convergence</div></div><div class="i-stats"><div><span>Health</span><b>${Math.round(u.hp)}/${u.maxHp}</b></div><div><span>Attack</span><b>${u.ad}</b></div><div><span>Armor</span><b>${u.armor}</b></div><div><span>Magic Res</span><b>${u.mr}</b></div></div>`;
      $('.i-close', el).addEventListener('click', () => { this.selectedCombat = null; el.classList.remove('show'); });
      return;
    }
    const stats = { hp: u.hp, ad: u.ad, as: u.as, range: u.range, armor: u.armor, mr: u.mr, ap: u.ap, mana: u.mana, maxMana: u.maxMana };
    el.innerHTML = this.infoHtml(u.id, u.star, u.items, stats, `<div class="i-foot"><span class="tier" style="color:var(--muted);font-size:.8rem">Damage dealt ${Math.round(u.damageDealt)} &middot; taken ${Math.round(u.damageTaken)}</span></div>`);
    this.wireInfo(el, u.id);
  }

  wireInfo(el, id) {
    $('.i-close', el).addEventListener('click', () => { this.selected = null; this.selectedCombat = null; el.classList.remove('show'); });
    el.querySelectorAll('[data-trait]').forEach((t) => this.attachTip(t, () => this.traitTip(t.dataset.trait, this.match.local.traitCounts()[t.dataset.trait] || 0)));
    el.querySelectorAll('[data-item]').forEach((t) => this.attachTip(t, () => this.itemTip(t.dataset.item)));
    const vb = $('#i-voice', el);
    if (vb) vb.addEventListener('click', () => this.audio.voice(id, 'select'));
  }

  // ───────────────────────── sell zone ─────────────────────────
  showSellZone(on, view) {
    const z = $('#sellzone');
    z.classList.toggle('show', on);
    if (on && view) {
      const loc = this.match.local.locate(view.uid);
      $('#sell-val').textContent = loc ? sellValue(loc.unit) : '';
    }
  }
  sellHover(on) { $('#sellzone').classList.toggle('hot', on); }
  isOverSell(x, y) {
    const r = $('#shopbar').getBoundingClientRect();
    return x >= r.left - 20 && x <= r.right + 20 && y >= r.top - 10;
  }

  // ───────────────────────── modals ─────────────────────────
  showBoons(offers) {
    const el = $('#m-boon');
    if (!offers) { el.classList.remove('show'); return; }
    el.innerHTML = `<h2>Choose a Shard Boon</h2><div class="sub">A gift from the Starheart. It lasts for the rest of the game.</div><div class="choices">${offers.map((b) => `<div class="boon ${b.tier === 2 ? 't2' : ''}" data-id="${b.id}" tabindex="0"><div class="b-icon"><img src="${glyphIconURL(b.icon, '#ffe6a8', 96)}" alt=""></div><h3>${b.name}</h3><p>${b.desc}</p></div>`).join('')}</div><div class="timerline">The board stays live while you decide</div>`;
    el.querySelectorAll('.boon').forEach((b) => b.addEventListener('click', () => {
      this.match.pickBoon(b.dataset.id);
      this.audio.sfx('boon');
      el.classList.remove('show');
    }));
    el.classList.add('show');
  }

  showDraft(offers) {
    const el = $('#m-draft');
    if (!offers) { el.classList.remove('show'); return; }
    const opening = this.match.round === 0;
    el.innerHTML = `<h2>${opening ? 'Opening Draft' : 'Shard Draft'}</h2><div class="sub">${opening ? 'Pick your first champion. Each one arrives carrying a relic component.' : 'Claim a champion and the relic it carries.'}</div><div class="choices">${offers.map((o, i) => {
      const ch = CHAMPION_BY_ID[o.champ];
      return `<div class="draft" data-i="${i}" style="--cc:${COST_COLORS[ch.cost]}" tabindex="0"><div class="d-art" style="${portraitStyle(o.champ)}"><img class="d-item" src="${itemIconURL(o.item)}" alt="${esc(ITEMS[o.item].name)}"></div><div class="d-body"><div class="d-name">${ch.name}</div><div class="d-traits">${ch.traits.map((t) => `<span><img src="${traitIconURL(t, 0)}" alt=""> ${TRAITS[t].name}</span>`).join('')}</div></div></div>`;
    }).join('')}</div>`;
    el.querySelectorAll('.draft').forEach((d) => {
      d.addEventListener('click', () => {
        this.match.pickDraft(+d.dataset.i);
        this.audio.sfx('buy');
        el.classList.remove('show');
      });
      const o = offers[+d.dataset.i];
      this.attachTip(d.querySelector('.d-item'), () => this.itemTip(o.item));
    });
    el.classList.add('show');
  }

  hideModals() {
    for (const id of ['#m-boon', '#m-draft']) $(id).classList.remove('show');
  }

  banner(title, sub, lose = false) {
    const b = $('#banner');
    b.classList.remove('show', 'lose');
    void b.offsetWidth;
    $('h1', b).textContent = title;
    $('p', b).textContent = sub || '';
    b.classList.toggle('lose', lose);
    b.classList.add('show');
  }

  versus(opp, pve) {
    const v = $('#versus');
    if (!opp && !pve) { v.classList.remove('show'); return; }
    v.innerHTML = pve ? 'Monsters of the <b>Convergence</b>' : `Versus <b>${esc(opp.name)}</b>`;
    v.classList.add('show');
  }

  showSubtitle(text, dur) {
    const s = $('#subtitle');
    s.textContent = text;
    s.classList.add('show');
    clearTimeout(this.subT);
    this.subT = setTimeout(() => s.classList.remove('show'), Math.max(1.4, dur + 0.4) * 1000);
  }

  toast(text) {
    const t = $('#toast');
    t.textContent = text;
    t.classList.add('show');
    clearTimeout(this.toastT);
    this.toastT = setTimeout(() => t.classList.remove('show'), 1800);
  }

  showEnd(place, match) {
    const el = $('#m-end');
    const p = match.local;
    const suffix = place === 1 ? 'st' : place === 2 ? 'nd' : place === 3 ? 'rd' : 'th';
    const line = place === 1 ? 'The Starheart answers you. The Convergence bows to its new Warden.' : place <= 4 ? 'A strong showing. The shards will remember your name.' : 'The shards scatter. The Convergence will open again.';
    el.innerHTML = `<div class="end-place">${place}${suffix}</div><h2>${place === 1 ? 'Crowned Warden' : 'The Convergence Closes'}</h2><div class="sub">${line}</div>
      <div class="end-board">${p.boardUnits().map((u) => { const ch = CHAMPION_BY_ID[u.id]; return `<div class="mini" style="--cc:${COST_COLORS[ch.cost]}"><div style="${portraitStyle(u.id)}"></div>${ch.name} ${'&#9733;'.repeat(u.star)}</div>`; }).join('')}</div>
      <div class="menu-col"><button class="btn primary" id="e-again">Play again</button><button class="btn" id="e-title">Back to title</button></div>`;
    $('#e-again', el).addEventListener('click', () => { el.classList.remove('show'); this.app.restart(); });
    $('#e-title', el).addEventListener('click', () => { el.classList.remove('show'); this.app.toTitle(); });
    el.classList.add('show');
  }
}
