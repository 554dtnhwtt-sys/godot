extends RefCounted
## Målade skepp i 2,5D. Skrovet är en målad bild som läggs på havsytan i samma snedvy
## som resten av världen, med en mörk skrovsida under däcket. Master, rår, segel, rigg och
## flagga ritas i höjdled ovanpå. Seglen är målade dukar som fylls av vinden, vrids efter
## vinden, fladdrar när de tappar vinden, revas när skeppet ligger still och kastar
## skuggor på däck och vatten. Skeppet krängar, gungar, brinner och sjunker.

const Y_SQUASH := 0.72
const H_K := 0.69                  # höjd → skärm (kameran tittar snett ned)
const SUN := Vector2(0.55, 0.38)   # skuggans förskjutning på havet per höjdenhet
const DECK := 0.045                # däckets höjd över vattnet (andel av längden)
const MAST_COL := Color(0.33, 0.22, 0.13)
const ROPE_COL := Color(0.16, 0.11, 0.07, 0.55)

## x = mastens läge i bilden (0 akter, 1 bogsprötets spets), h = höjd (andel av längden),
## sails = segel nedifrån och upp, gaff = gaffelseglets längd akterut (andel av längden).
const RIGS := {
	"slup": {"masts": [{"x": 0.42, "h": 0.92, "sails": ["gaff"], "gaff": 0.4}], "jib": 0.97},
	"skonare": {"masts": [{"x": 0.31, "h": 0.84, "sails": ["gaff"], "gaff": 0.24}, {"x": 0.55, "h": 0.8, "sails": ["gaff"], "gaff": 0.22}], "jib": 0.97},
	"handelsfartyg": {"masts": [{"x": 0.37, "h": 0.8, "sails": ["course", "topsail"]}, {"x": 0.66, "h": 0.72, "sails": ["course", "topsail"]}], "jib": 0.97},
	"brigg": {"masts": [{"x": 0.30, "h": 0.8, "sails": ["course", "topsail", "topgallant"]}, {"x": 0.59, "h": 0.74, "sails": ["course", "topsail", "topgallant"]}], "jib": 0.97},
	"galeon": {"masts": [{"x": 0.16, "h": 0.6, "sails": ["gaff", "topsail"], "gaff": 0.2}, {"x": 0.33, "h": 0.82, "sails": ["course", "topsail"]}, {"x": 0.57, "h": 0.74, "sails": ["course", "topsail"]}], "jib": 0.97},
	"fregatt": {"masts": [{"x": 0.17, "h": 0.62, "sails": ["gaff", "topsail"], "gaff": 0.2}, {"x": 0.37, "h": 0.86, "sails": ["course", "topsail", "topgallant"]}, {"x": 0.62, "h": 0.78, "sails": ["course", "topsail", "topgallant"]}], "jib": 0.97},
	"linjeskepp": {"masts": [{"x": 0.19, "h": 0.62, "sails": ["gaff", "topsail"], "gaff": 0.2}, {"x": 0.39, "h": 0.86, "sails": ["course", "topsail", "topgallant"]}, {"x": 0.62, "h": 0.8, "sails": ["course", "topsail", "topgallant"]}], "jib": 0.97},
	"spokskepp": {"masts": [{"x": 0.18, "h": 0.6, "sails": ["gaff", "topsail"], "gaff": 0.2}, {"x": 0.37, "h": 0.84, "sails": ["course", "topsail", "topgallant"]}, {"x": 0.60, "h": 0.76, "sails": ["course", "topsail"]}], "jib": 0.97},
	"armadaskepp": {"masts": [{"x": 0.19, "h": 0.62, "sails": ["gaff", "topsail"], "gaff": 0.2}, {"x": 0.39, "h": 0.86, "sails": ["course", "topsail", "topgallant"]}, {"x": 0.64, "h": 0.8, "sails": ["course", "topsail", "topgallant"]}], "jib": 0.97},
	"kristallskepp": {"masts": [{"x": 0.36, "h": 0.86, "sails": ["course", "topsail", "topgallant"]}, {"x": 0.59, "h": 0.78, "sails": ["course", "topsail"]}], "jib": 0.97},
}
## Skepp utan egen skrovbild använder ett annat skrov med egen färgton.
const HULL_ALIAS := {"kultskepp": ["brigg", Color(0.62, 0.5, 0.66)]}
## Råseglens höjd på masten (andel av masthöjden) och bredd (gånger skrovets bredd).
const SQUARE := {"course": [0.2, 0.48, 2.2], "topsail": [0.5, 0.73, 1.8], "topgallant": [0.75, 0.9, 1.3]}

# Sammanhang för pågående ritning (sätts i draw, används av projektionen)
static var _o := Vector2.ZERO
static var _lean := Vector2.ZERO
static var _depth := 0.0
static var _idx_cache := {}


static func tex(path: String) -> Texture2D:
	return Art.tex("res://assets/" + path + ".png")


static func hull_tex(type: String) -> Texture2D:
	var name: String = HULL_ALIAS[type][0] if HULL_ALIAS.has(type) else type
	return tex("ships/hull/" + name)


static func _fwd(screen_angle: float) -> Vector2:
	return Vector2(cos(screen_angle), sin(screen_angle) / Y_SQUASH).normalized()


static func _sq(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * Y_SQUASH)


## Från skeppets 3D-rum (x, y på havet, z höjd) till skärmen.
static func _p(p: Vector3) -> Vector2:
	var he := maxf(p.z - _depth, 0.0)
	return _o + Vector2(p.x + _lean.x * p.z, (p.y + _lean.y * p.z) * Y_SQUASH - he * H_K)


## Skuggan av en punkt, kastad på havsytan.
static func _ps(p: Vector3) -> Vector2:
	var he := maxf(p.z - _depth, 0.0)
	var g := Vector2(p.x + _lean.x * p.z, p.y + _lean.y * p.z) + SUN * he
	return _o + Vector2(g.x, g.y * Y_SQUASH)


static func _indices(nx: int, ny: int) -> PackedInt32Array:
	var key := nx * 100 + ny
	if _idx_cache.has(key):
		return _idx_cache[key]
	var out := PackedInt32Array()
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			out.append_array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1])
	_idx_cache[key] = out
	return out


## Seglens utseende per ägare: [rå-/gaffelsegel, färg].
static func _style(s) -> Array:
	match s.owner_id:
		"svartarevet", "vildpirater":
			return ["patched", Color(0.36, 0.33, 0.32)]
		"djupkulten":
			return ["patched", Color(0.5, 0.32, 0.56)]
		"armadan":
			return ["", Color(1.0, 0.62, 0.5)]
		"spokflottan":
			return ["tattered", Color(0.62, 1.0, 0.8, 0.78)]
		"vaktarna":
			return ["", Color(0.68, 0.95, 1.0, 0.86)]
		"solmar":
			return ["", Color(1.0, 0.94, 0.84)]
		"kaluma":
			return ["", Color(0.98, 0.9, 0.76)]
		"valdoria":
			return ["", Color(1.04, 1.04, 1.06)]
	return ["", Color(1, 1, 1)]


# ------------------------------------------------------------------ Tillstånd
## Uppdaterar seglens fyllnad, rår, bom, krängning och revning (verklig tid, mjukt).
static func update(s, delta: float) -> void:
	var real := delta / maxf(0.001, Engine.time_scale)
	if real <= 0.0:
		return
	var f := _fwd(s.heading)
	var r := Vector2(-f.y, f.x)
	var w := _fwd(Game.wind_angle)
	var rel := angle_difference(f.angle(), w.angle())
	var ghost: bool = s.def.get("ghost", false)
	# Vinden fyller seglen utom när skeppet går rakt mot vinden
	var fill: float = (1.0 - smoothstep(1.85, 2.7, absf(rel))) * clampf(0.35 + s.speed / 110.0, 0.35, 1.0) * clampf(Game.wind_strength, 0.45, 1.5)
	if ghost:
		fill = 0.9
	s.art_fill = lerpf(s.art_fill, fill, clampf(real * 1.8, 0.0, 1.0))
	# Seglen revas när skeppet ligger still
	var still: bool = s.speed < 10.0 and s.order == "idle" and s.sinking <= 0.0
	s.art_furl = move_toward(s.art_furl, 1.0 if still else 0.0, real * 0.6)
	# Rårna brassas efter vinden, gaffelbommen går över till läsidan
	s.art_brace = lerpf(s.art_brace, clampf(rel * 0.5, -0.62, 0.62), clampf(real * 0.9, 0.0, 1.0))
	var cross := w.dot(r)
	s.art_side = move_toward(s.art_side, 1.0 if cross >= 0.0 else -1.0, real * 1.2)
	s.art_rel = rel
	# Krängning: vinden trycker i seglen, och skeppet lutar utåt i svängar
	var turn: float = angle_difference(s.art_last_heading, s.heading) / maxf(delta, 0.0001)
	s.art_last_heading = s.heading
	var heel: float = cross * s.art_fill * 0.085 * (1.0 + Game.storm * 1.5)
	heel += clampf(-turn * 0.06, -0.05, 0.05) * clampf(s.speed / 100.0, 0.0, 1.0)
	s.art_heel = lerpf(s.art_heel, heel, clampf(real * 1.6, 0.0, 1.0))
	s.art_kick = move_toward(s.art_kick, 0.0, real * 0.25)


# ------------------------------------------------------------------ Ritning
static func draw(s, ci: CanvasItem, lod: int) -> void:
	var L: float = s._hull_len()
	var hull := hull_tex(s.type)
	if hull == null:
		return
	var rig: Dictionary = RIGS.get(HULL_ALIAS[s.type][0] if HULL_ALIAS.has(s.type) else s.type, RIGS["brigg"])
	var sink: float = clampf(s.sinking / 4.0, 0.0, 1.0)
	var t: float = s._t
	var f := _fwd(s.heading)
	var r := Vector2(-f.y, f.x)
	var storm: float = Game.storm
	var heel: float = s.art_heel + s.art_kick + sink * 0.5 * s.art_sink_side
	var pitch: float = sin(t * 1.7 + s.position.x * 0.01) * 0.022 * (1.0 + storm * 2.0) + sink * 0.12
	_lean = r * sin(heel) + f * sin(pitch)
	_o = Vector2(0, sin(t * 1.8 + s.position.x * 0.013) * 1.1 * (1.0 + storm))
	_depth = sink * sink * L * 0.95
	var deck := L * DECK
	var tw := float(hull.get_width())
	var th := float(hull.get_height())
	var beam := L * th / tw * 0.78
	var ghost: bool = s.def.get("ghost", false)
	var crystal: bool = s.def.get("crystal", false)
	var alpha := 1.0 - pow(sink, 1.4) * 0.9
	if ghost:
		alpha *= 0.78 + 0.14 * sin(t * 2.0)
	# Glöd på vattnet runt spök- och kristallskepp
	if ghost or crystal:
		var gc := Color(0.45, 1.0, 0.75, 0.18 * alpha) if ghost else Color(0.5, 0.9, 1.0, 0.18 * alpha)
		_ellipse(ci, Vector2.ZERO, f, r, L * 0.62 + sin(t * 3.0) * 3.0, beam * 1.4, gc)
	# Vattnet: kölvatten, bogvåg och skum runt skrovet
	if lod > 0:
		_wake(s, ci, f, L, alpha)
	_bow_wave(s, ci, f, r, L, beam, alpha)
	# Skrov: skugga, mörk skrovsida och däck
	var sc := L / tw
	var xa := _sq(f) * sc
	var ya := _sq(r) * sc * cos(heel)
	var half := Vector2(tw, th) * 0.5
	var hmod := Color(1, 1, 1).lerp(Color(0.25, 0.5, 0.62), sink * 0.85)
	if HULL_ALIAS.has(s.type):
		hmod *= HULL_ALIAS[s.type][1]
	hmod.a = alpha
	ci.draw_set_transform_matrix(Transform2D(xa * 1.02, ya * 1.06, _o + _sq(SUN * deck * 1.6) + Vector2(3, 4)))
	ci.draw_texture(hull, -half, Color(0.0, 0.05, 0.1, 0.28 * alpha))
	ci.draw_set_transform_matrix(Transform2D(xa, ya, _o + _sq(r * sin(heel) * deck * 0.3)))
	ci.draw_texture(hull, -half, Color(hmod.r * 0.42, hmod.g * 0.3, hmod.b * 0.22, alpha))
	var deck_o := _p(Vector3(0, 0, deck)) + _sq(r * sin(heel) * deck * 0.5)
	ci.draw_set_transform_matrix(Transform2D(xa, ya, deck_o))
	ci.draw_texture(hull, -half, hmod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Riggen
	var style := _style(s)
	var scol: Color = style[1]
	scol.a *= alpha
	var parts: Array = []   # [djup, sort, data]
	var masts: Array = rig["masts"]
	var tops: Array = []
	var main_top := Vector3.ZERO
	var main_h := 0.0
	for m in masts:
		var gx: float = (float(m["x"]) - 0.5) * L
		var base := Vector3(f.x * gx, f.y * gx, deck)
		var mh: float = float(m["h"]) * L
		var top := Vector3(base.x, base.y, deck + mh)
		tops.append(top)
		if mh > main_h:
			main_h = mh
			main_top = top
		parts.append([base.y, "mast", [base, top, L]])
		for sn in m["sails"]:
			var sail: Dictionary = _make_sail(s, sn, m, base, mh, f, r, beam, L, t, style)
			if not sail.is_empty():
				parts.append([base.y + (0.5 if sail["front"] else -0.5), "sail", sail])
	# Klyvare från bogspröt till förmasten
	var fore: Vector3 = tops[tops.size() - 1]
	var tip_x: float = (float(rig["jib"]) - 0.5) * L
	var tip := Vector3(f.x * tip_x, f.y * tip_x, deck + L * 0.06)
	var jib := _make_jib(s, fore, tip, f, r, L, t, style)
	if not jib.is_empty():
		parts.append([(fore.y + tip.y) * 0.5 + 0.2, "sail", jib])
	# Skuggor från master och segel på däck och vatten
	if lod > 1:
		var shc := Color(0.0, 0.04, 0.08, 0.16 * alpha)
		for p in parts:
			if p[1] == "mast":
				var d: Array = p[2]
				ci.draw_line(_ps(d[0]), _ps(d[1]), shc, maxf(1.0, L * 0.016))
			else:
				_draw_cloth(ci, p[2], true, shc)
	# Brand på däck
	if s.hp < s.max_hp * 0.5 and sink <= 0.0:
		_fires(s, ci, f, r, L, deck, t)
	# Master, segel och klyvare bakifrån och framåt
	parts.sort_custom(func(a, b): return a[0] < b[0])
	for p in parts:
		if p[1] == "mast":
			var d: Array = p[2]
			_mast(ci, d[0], d[1], L, alpha)
		else:
			_draw_cloth(ci, p[2], false, scol)
	# Rigg: vant från masttopparna till relingen och stag mot bogsprötet
	if lod > 1 and alpha > 0.2:
		var rc := Color(ROPE_COL, ROPE_COL.a * alpha)
		for i in tops.size():
			var tp: Vector3 = tops[i]
			var at := Vector3(tp.x, tp.y, lerpf(deck, tp.z, 0.82))
			for sgn in [1.0, -1.0]:
				var foot := Vector3(tp.x + r.x * beam * 0.5 * sgn, tp.y + r.y * beam * 0.5 * sgn, deck)
				ci.draw_line(_p(at), _p(foot), rc, -1.0)
			if i + 1 < tops.size():
				var nt: Vector3 = tops[i + 1]
				ci.draw_line(_p(tp), _p(Vector3(nt.x, nt.y, lerpf(deck, nt.z, 0.6))), rc, -1.0)
		ci.draw_line(_p(fore), _p(tip), rc, -1.0)
	# Flagga i stormastens topp och vimplar på de andra
	if sink < 0.6:
		_flag(s, ci, main_top, L, t, alpha, true)
		if lod > 1:
			for tp in tops:
				if tp != main_top:
					_flag(s, ci, tp, L * 0.7, t + float(tp.x), alpha, false)


## Ett segel som ett nät av punkter i 3D: hörn, bukt, fladder, ljus och textur.
static func _make_sail(s, sn: String, m: Dictionary, base: Vector3, mh: float, f: Vector2, r: Vector2, beam: float, L: float, t: float, style: Array) -> Dictionary:
	var fill: float = s.art_fill
	var furl: float = s.art_furl
	var flut: float = (1.0 - fill) * 0.03 * L + Game.storm * 0.012 * L
	if sn == "gaff":
		# Gaffelsegel längs skeppet, bommen svänger ut åt läsidan
		var glen: float = float(m.get("gaff", 0.25)) * L
		var side: float = s.art_side
		var rel: float = s.art_rel
		var swing: float = lerpf(0.18, 1.15, (1.0 + cos(rel)) * 0.5) * side
		var a := (-f) * cos(swing) + r * sin(swing)
		var n := Vector2(-a.y, a.x)
		if n.dot(r * side) < 0.0:
			n = -n
		var lo: float = base.z + mh * 0.1
		var hi: float = base.z + mh * (0.55 if m["sails"].size() > 1 else 0.88)
		hi = lerpf(hi, lo + mh * 0.08, furl)
		var peak_h := hi + mh * 0.12 * (1.0 - furl)
		var tl := Vector3(base.x + a.x * glen, base.y + a.y * glen, peak_h)
		var tr := Vector3(base.x, base.y, hi)
		var bl := Vector3(base.x + a.x * glen, base.y + a.y * glen, lo)
		var br := Vector3(base.x, base.y, lo)
		var txn: String = style[0] if style[0] != "" else "gaff"
		return _cloth("ships/sails/" + txn, tl, tr, bl, br, Vector3(n.x, n.y, 0), (0.015 + 0.09 * fill) * L * (1.0 - furl * 0.8), flut, t, "gaff", 1.0 - furl * 0.7, n.y > 0.0)
	if not SQUARE.has(sn):
		return {}
	var d: Array = SQUARE[sn]
	var y0: float = d[0]
	var y1: float = d[1]
	if sn == "topsail" and m["sails"].size() == 2:
		y0 = 0.58 if m["sails"][0] == "gaff" else 0.5
		y1 = 0.86 if m["sails"][0] == "gaff" else 0.8
	var top_h: float = base.z + mh * y1
	var bot_h: float = base.z + mh * y0
	bot_h = lerpf(bot_h, top_h - mh * 0.03, furl)
	var width: float = beam * float(d[2]) * clampf(mh / (L * 0.82), 0.75, 1.1)
	var brace: float = s.art_brace
	var nf := f.rotated(brace)
	var yard := Vector2(-nf.y, nf.x)
	var hw := width * 0.5
	var hwb := hw * 1.06
	var tl := Vector3(base.x - yard.x * hw, base.y - yard.y * hw, top_h)
	var tr := Vector3(base.x + yard.x * hw, base.y + yard.y * hw, top_h)
	var bl := Vector3(base.x - yard.x * hwb, base.y - yard.y * hwb, bot_h)
	var br := Vector3(base.x + yard.x * hwb, base.y + yard.y * hwb, bot_h)
	var tname: String = sn
	if style[0] != "" and sn == "course":
		tname = style[0]
	var sail := _cloth("ships/sails/" + tname, tl, tr, bl, br, Vector3(nf.x, nf.y, 0), (0.02 + 0.1 * fill) * L * (1.0 - furl), flut * (1.0 - furl), t, "square", 1.0 - furl * 0.9, nf.y > 0.0)
	if furl > 0.05:
		sail["furled"] = [tl, tr, furl]
	return sail


## Klyvaren: trekantigt segel från förmasten ned till bogsprötets spets.
static func _make_jib(s, fore: Vector3, tip: Vector3, f: Vector2, r: Vector2, L: float, t: float, style: Array) -> Dictionary:
	var furl: float = s.art_furl
	if furl > 0.97:
		return {}
	var side: float = s.art_side
	var head := Vector3(fore.x + f.x * L * 0.02, fore.y + f.y * L * 0.02, lerpf(tip.z, fore.z, 0.78))
	var clew_g := Vector2(fore.x, fore.y) + f * L * 0.07 + r * side * L * 0.05
	var clew := Vector3(clew_g.x, clew_g.y, tip.z + L * 0.02)
	# Revad klyvare: dras ihop mot staget
	clew = clew.lerp((head + tip) * 0.5, furl)
	var tr := head.lerp(tip, 0.03)
	var n := r * side
	var txn := "jib" if style[0] != "tattered" else "staysail"
	return _cloth("ships/sails/" + txn, head, tr, clew, tip, Vector3(n.x, n.y, 0), (0.015 + 0.06 * s.art_fill) * L, (1.0 - s.art_fill) * 0.02 * L, t, "jib", 1.0 - furl, n.y > 0.0)


static func _cloth(texname: String, tl: Vector3, tr: Vector3, bl: Vector3, br: Vector3, n: Vector3, billow: float, flut: float, t: float, kind: String, vis: float, front: bool) -> Dictionary:
	return {"tex": texname, "c": [tl, tr, bl, br], "n": n, "b": billow, "fl": flut, "t": t, "kind": kind, "vis": vis, "front": front}


## Ritar en duk (eller dess skugga) som ett nät av trianglar med målad textur.
static func _draw_cloth(ci: CanvasItem, c: Dictionary, shadow: bool, col: Color) -> void:
	var vis: float = c["vis"]
	if vis <= 0.02 and not c.has("furled"):
		return
	var corners: Array = c["c"]
	var tl: Vector3 = corners[0]
	var tr: Vector3 = corners[1]
	var bl: Vector3 = corners[2]
	var br: Vector3 = corners[3]
	var n: Vector3 = c["n"]
	var billow: float = c["b"]
	var flut: float = c["fl"]
	var t: float = c["t"]
	var kind: String = c["kind"]
	var nx := 4
	var ny := 3
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var sun_side := clampf(n.x * -0.6 + n.y * 0.5, -1.0, 1.0)
	for j in ny + 1:
		var v := float(j) / ny
		for i in nx + 1:
			var u := float(i) / nx
			var p: Vector3 = tl.lerp(tr, u).lerp(bl.lerp(br, u), v)
			var shape := sin(PI * u)
			match kind:
				"square":
					shape *= 0.35 + 0.65 * sin(PI * minf(v * 0.85 + 0.15, 1.0))
				"gaff":
					shape = sin(PI * u) * sin(PI * clampf(v * 0.9 + 0.1, 0.0, 1.0))
				_:
					shape = sin(PI * u) * sin(PI * v)
			var ripple := sin(t * 7.5 + u * 6.0 + v * 4.0) * flut * sin(PI * u)
			p += n * (billow * shape + ripple)
			if shadow:
				pts.append(_ps(p))
				cols.append(col)
			else:
				pts.append(_p(p))
				var k := (0.8 + 0.2 * shape) * (0.95 + 0.1 * sun_side * shape)
				cols.append(Color(col.r * k, col.g * k, col.b * k, col.a * vis))
			uvs.append(Vector2(u, v))
	var rid := RID()
	if not shadow:
		var tx := tex(c["tex"])
		if tx != null:
			rid = tx.get_rid()
	if (shadow and vis > 0.1) or (not shadow and vis > 0.02):
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _indices(nx, ny), pts, cols, PackedVector2Array() if shadow else uvs, PackedInt32Array(), PackedFloat32Array(), rid)
	# Revat segel: en hoprullad duk längs rån
	if c.has("furled") and not shadow:
		var fd: Array = c["furled"]
		var a: Vector3 = fd[0]
		var b: Vector3 = fd[1]
		var k: float = fd[2]
		var ftx := tex("ships/sails/furled")
		if ftx != null:
			var h := (a.distance_to(b)) * 0.09
			var q := PackedVector2Array([_p(a + Vector3(0, 0, h)), _p(b + Vector3(0, 0, h)), _p(b - Vector3(0, 0, h)), _p(a - Vector3(0, 0, h))])
			var cc := Color(col.r, col.g, col.b, col.a * k)
			ci.draw_polygon(q, PackedColorArray([cc, cc, cc, cc]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), ftx)


static func _mast(ci: CanvasItem, base: Vector3, top: Vector3, L: float, alpha: float) -> void:
	var a := _p(base)
	var b := _p(top)
	if a.distance_to(b) < 0.5:
		return
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var w0 := maxf(1.2, L * 0.012)
	var w1 := maxf(0.8, L * 0.006)
	var col := Color(MAST_COL, alpha)
	ci.draw_colored_polygon(PackedVector2Array([a - nrm * w0, a + nrm * w0, b + nrm * w1, b - nrm * w1]), col)
	ci.draw_line(a - nrm * w0 * 0.3, b - nrm * w1 * 0.3, Color(0.55, 0.4, 0.26, alpha * 0.8), maxf(0.6, w1 * 0.6))
	# Mastkorg
	var nest := _p(base.lerp(top, 0.66))
	ci.draw_set_transform(nest, 0.0, Vector2(1.0, 0.55))
	ci.draw_circle(Vector2.ZERO, L * 0.026, Color(0.27, 0.18, 0.1, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _flag(s, ci: CanvasItem, top: Vector3, L: float, t: float, alpha: float, big: bool) -> void:
	var p := _p(top)
	var w := _fwd(Game.wind_angle)
	var dir := _sq(w).normalized()
	var flen := L * (0.16 if big else 0.13)
	var h := L * (0.085 if big else 0.025) * H_K
	var nat := Data.nation_color(s.owner_id)
	var acc := Data.nation_accent(s.owner_id)
	var n := 6
	var up := PackedVector2Array()
	var down := PackedVector2Array()
	var amp := L * 0.012 * (0.6 + Game.wind_strength * 0.6)
	for i in n + 1:
		var k := float(i) / n
		var wave := sin(t * 8.0 - k * 6.0) * amp * k
		var taper := 1.0 if big else (1.0 - k * 0.85)
		var q := p + dir * flen * k + Vector2(0, wave)
		up.append(q - Vector2(0, h * 0.5 * taper))
		down.append(q + Vector2(0, h * 0.5 * taper))
	for i in n:
		var shade := 0.88 + 0.12 * sin(t * 8.0 - float(i) / n * 6.0 + 1.2)
		var c := Color(nat.r * shade, nat.g * shade, nat.b * shade, alpha)
		ci.draw_colored_polygon(PackedVector2Array([up[i], up[i + 1], down[i + 1], down[i]]), c)
		if big:
			var m0 := up[i].lerp(down[i], 0.38)
			var m1 := up[i + 1].lerp(down[i + 1], 0.38)
			var m2 := up[i + 1].lerp(down[i + 1], 0.62)
			var m3 := up[i].lerp(down[i], 0.62)
			ci.draw_colored_polygon(PackedVector2Array([m0, m1, m2, m3]), Color(acc.r * shade, acc.g * shade, acc.b * shade, alpha))
	ci.draw_line(p, p - Vector2(0, L * 0.03), Color(MAST_COL, alpha), maxf(1.0, L * 0.006))


## Eld som flammar på däck när skeppet är svårt skadat.
static func _fires(s, ci: CanvasItem, f: Vector2, r: Vector2, L: float, deck: float, t: float) -> void:
	var spots := [f * (-0.18 * L) + r * (0.05 * L), f * (0.1 * L) - r * (0.06 * L), f * (0.28 * L) + r * (0.02 * L)]
	var n := 1
	if s.hp < s.max_hp * 0.3:
		n = 2
	if s.hp < s.max_hp * 0.15:
		n = 3
	for i in n:
		var g: Vector2 = spots[i]
		var p := _p(Vector3(g.x, g.y, deck))
		var frame := int(t * 11.0 + i * 1.7) % 4
		var ft := tex("fx/fire%d" % (frame + 1))
		if ft == null:
			continue
		var hgt := L * (0.15 + 0.03 * sin(t * 5.0 + i))
		var wdt := hgt * ft.get_width() / ft.get_height()
		ci.draw_texture_rect(ft, Rect2(p - Vector2(wdt * 0.5, hgt * 0.92), Vector2(wdt, hgt)), false)


## Kölvatten: ett målat skumband som vidgas och bleknar bakom skeppet.
static func _wake(s, ci: CanvasItem, f: Vector2, L: float, alpha: float) -> void:
	var pts_w: Array = s._wake
	if pts_w.size() < 2:
		return
	var wt := tex("fx/wake")
	if wt == null:
		return
	var stern := -_sq(f) * L * 0.42
	var line: Array = [stern]
	for q in pts_w:
		line.append(q - s.position)
	var n := line.size()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var sp := clampf(s.speed / 110.0, 0.0, 1.0)
	for i in n:
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, n - 1)]
		var dg := Vector2(b.x - a.x, (b.y - a.y) / Y_SQUASH)
		if dg.length() < 0.001:
			dg = -f
		var nrm := Vector2(-dg.y, dg.x).normalized()
		var k := float(i) / (n - 1)
		var wdt := L * (0.1 + k * 0.32)
		var c: Vector2 = line[i]
		pts.append(c + _sq(nrm * wdt))
		pts.append(c - _sq(nrm * wdt))
		var u := 0.78 - k * 0.72
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		var al := (1.0 - k) * (0.35 + 0.55 * sp) * alpha
		cols.append(Color(1, 1, 1, al))
		cols.append(Color(1, 1, 1, al))
	var idx := PackedInt32Array()
	for i in n - 1:
		var a := i * 2
		idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), wt.get_rid())


## Bogvåg: ett V av skum vid fören som växer med farten.
static func _bow_wave(s, ci: CanvasItem, f: Vector2, r: Vector2, L: float, beam: float, alpha: float) -> void:
	var sp := clampf((s.speed - 8.0) / 110.0, 0.0, 1.0)
	if sp <= 0.01:
		return
	var bt := tex("fx/bowwave")
	if bt == null:
		return
	var t: float = s._t
	var bow := f * L * 0.33
	var w := beam * (1.3 + sp * 0.9)
	var h := L * (0.18 + sp * 0.22) * (1.0 + 0.06 * sin(t * 9.0))
	var sx := w / bt.get_width()
	var sy := h / bt.get_height()
	var xa := _sq(r) * sx
	var ya := _sq(-f) * sy
	ci.draw_set_transform_matrix(Transform2D(xa, ya, _o + _sq(bow)))
	ci.draw_texture(bt, Vector2(-bt.get_width() * 0.5, -bt.get_height() * 0.95), Color(1, 1, 1, (0.45 + 0.4 * sp) * alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _ellipse(ci: CanvasItem, c: Vector2, f: Vector2, r: Vector2, a: float, b: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		pts.append(c + _sq(f * cos(ang) * a + r * sin(ang) * b))
	ci.draw_colored_polygon(pts, col)


## Var en kanon på skeppets sida sitter (för mynningsflammor och rök), i världens koordinater.
static func cannon_port(s, side: int, t: float) -> Vector2:
	var L: float = s._hull_len()
	var f := _fwd(s.heading)
	var r := Vector2(-f.y, f.x)
	var hull := hull_tex(s.type)
	var beam := L * 0.25
	if hull != null:
		beam = L * float(hull.get_height()) / hull.get_width() * 0.78
	var g := f * t * L * 0.55 + r * side * beam * 0.5
	return s.position + _sq(g) - Vector2(0, L * DECK * H_K * 0.6)


## Riktningen ut från skeppets sida på skärmen.
static func side_dir(s, side: int) -> Vector2:
	var f := _fwd(s.heading)
	var r := Vector2(-f.y, f.x) * side
	return _sq(r).normalized()
