extends Node3D
## 3D-modell av ett segelfartyg, byggd i kod: skrov med kanonportar och kanoner,
## akter- och förkastell, master, rår, segel som buktar i vinden, bogspröt och flagga.
## Skeppet krängar i vinden, gungar i sjön och sjunker under vattenytan.

const Kit = preload("res://scripts/world3d/kit.gd")
const SOLID = preload("res://shaders/solid3d.gdshader")
const SAIL = preload("res://shaders/sail3d.gdshader")
const FLAG = preload("res://shaders/flag3d.gdshader")
const Y_SQUASH := 0.72

## Riggning per skeppstyp.
const SPEC := {
	"handelsfartyg": {"rig": "square", "castle": 0.5, "decks": 0, "beam": 0.32, "masts": 2},
	"slup": {"rig": "fore_aft", "castle": 0.0, "decks": 1, "beam": 0.27, "masts": 1},
	"skonare": {"rig": "fore_aft", "castle": 0.0, "decks": 1, "beam": 0.25, "masts": 2},
	"brigg": {"rig": "square", "castle": 0.35, "decks": 1, "beam": 0.28, "masts": 2},
	"galeon": {"rig": "square", "castle": 1.2, "decks": 1, "beam": 0.32, "masts": 3},
	"fregatt": {"rig": "square", "castle": 0.55, "decks": 1, "beam": 0.27, "masts": 3},
	"linjeskepp": {"rig": "square", "castle": 0.9, "decks": 3, "beam": 0.3, "masts": 3},
	"spokskepp": {"rig": "square", "castle": 1.0, "decks": 1, "beam": 0.3, "masts": 3},
	"armadaskepp": {"rig": "square", "castle": 1.0, "decks": 2, "beam": 0.3, "masts": 3},
	"kristallskepp": {"rig": "square", "castle": 0.5, "decks": 1, "beam": 0.26, "masts": 2},
	"kultskepp": {"rig": "square", "castle": 0.4, "decks": 1, "beam": 0.28, "masts": 2},
}

static var _hull_cache := {}
static var _sail_cache := {}
static var _solid_mat: ShaderMaterial = null
static var _flag_mats := {}

var ship = null
var _hull: MeshInstance3D
var _sails: MeshInstance3D
var _flag: MeshInstance3D
var _sail_mat: ShaderMaterial
var _flag_top := Vector3.ZERO
var _t := 0.0
var _heel := 0.0
var _L := 86.0


static func solid_material() -> ShaderMaterial:
	if _solid_mat == null:
		_solid_mat = ShaderMaterial.new()
		_solid_mat.shader = SOLID
	return _solid_mat


func setup(s) -> void:
	ship = s
	_t = randf() * 10.0
	var type: String = s.type
	var spec: Dictionary = SPEC.get(type, SPEC["brigg"])
	_L = 86.0 * s.size_f
	var key := "%s|%s" % [type, s.owner_id]
	if not _hull_cache.has(key):
		_hull_cache[key] = _build_hull(type, spec, s.owner_id, s.cannons)
	_hull = MeshInstance3D.new()
	_hull.mesh = _hull_cache[key][0]
	_flag_top = _hull_cache[key][1]
	var mat := solid_material()
	if s.def.get("ghost", false):
		mat = ShaderMaterial.new()
		mat.shader = SOLID
		mat.set_shader_parameter("tint", Color(0.55, 0.9, 0.75))
		mat.set_shader_parameter("glow", 0.25)
	elif s.def.get("crystal", false):
		mat = ShaderMaterial.new()
		mat.shader = SOLID
		mat.set_shader_parameter("tint", Color(0.75, 0.92, 1.1))
		mat.set_shader_parameter("glow", 0.2)
	_hull.material_override = mat
	add_child(_hull)
	if not _sail_cache.has(type):
		_sail_cache[type] = _build_sails(type, spec)
	_sails = MeshInstance3D.new()
	_sails.mesh = _sail_cache[type]
	_sail_mat = ShaderMaterial.new()
	_sail_mat.shader = SAIL
	_sail_mat.set_shader_parameter("sail_color", _sail_color(s))
	if s.def.get("ghost", false):
		_sail_mat.set_shader_parameter("glow", 0.55)
	elif s.def.get("crystal", false):
		_sail_mat.set_shader_parameter("glow", 0.45)
	_sails.material_override = _sail_mat
	_sails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_sails)
	_flag = MeshInstance3D.new()
	_flag.mesh = _flag_mesh()
	_flag.material_override = _flag_material(s.owner_id)
	_flag.position = _flag_top
	add_child(_flag)


func _sail_color(s) -> Color:
	match s.owner_id:
		"svartarevet", "vildpirater":
			return Color(0.22, 0.2, 0.2)
		"djupkulten":
			return Color(0.32, 0.18, 0.4)
		"armadan":
			return Color(0.95, 0.82, 0.45)
		"spokflottan":
			return Color(0.6, 1.0, 0.82)
		"vaktarna":
			return Color(0.6, 0.92, 1.0)
		"solmar":
			return Color(1.0, 0.92, 0.78)
		"valdoria":
			return Color(0.95, 0.95, 0.98)
	return Color(0.95, 0.91, 0.8)


static func _flag_material(owner: String) -> ShaderMaterial:
	if not _flag_mats.has(owner):
		var m := ShaderMaterial.new()
		m.shader = FLAG
		m.set_shader_parameter("color_a", Data.nation_color(owner))
		m.set_shader_parameter("color_b", Data.nation_accent(owner))
		_flag_mats[owner] = m
	return _flag_mats[owner]


func _flag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 14.0 * clampf(_L / 86.0, 1.0, 1.6)
	var h := 9.0 * clampf(_L / 86.0, 1.0, 1.6)
	var n := 6
	for i in n:
		var x0 := w * i / n
		var x1 := w * (i + 1) / n
		var pts := [Vector3(x0, 0, 0), Vector3(x1, 0, 0), Vector3(x1, -h, 0), Vector3(x0, -h, 0)]
		var uvs := [Vector2(float(i) / n, 0), Vector2(float(i + 1) / n, 0), Vector2(float(i + 1) / n, 1), Vector2(float(i) / n, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])
	return st.commit()


# ------------------------------------------------------------------ Skrov
static func _beam_shape(t: float) -> float:
	if t < 0.15:
		return lerpf(0.78, 0.95, t / 0.15)
	if t < 0.55:
		return lerpf(0.95, 1.0, (t - 0.15) / 0.4)
	return pow(cos((t - 0.55) / 0.45 * PI * 0.5), 0.75)


## Returnerar [mesh, flaggans position].
func _build_hull(type: String, spec: Dictionary, owner: String, cannons: int) -> Array:
	var k := Kit.new()
	var L := _L
	var W: float = L * spec["beam"]
	var decks: int = spec["decks"]
	var Hd: float = L * (0.1 + 0.035 * maxi(0, decks - 1))
	var D := L * 0.1
	var castle: float = spec["castle"]
	var nat := Data.nation_color(owner)
	var acc := Data.nation_accent(owner)
	var wood := Color(0.36, 0.23, 0.13)
	var dark := Color(0.2, 0.14, 0.09)
	var deck := Color(0.66, 0.51, 0.33)
	var stripe := nat.lerp(Color(0.85, 0.7, 0.35), 0.35) if owner != "armadan" else Color(0.9, 0.72, 0.25)
	if owner in ["svartarevet", "vildpirater"]:
		wood = Color(0.16, 0.13, 0.12)
		deck = Color(0.38, 0.3, 0.22)
	var N := 12
	var secs: Array = []
	for i in N + 1:
		var t := float(i) / N
		var x := -L * 0.5 + t * L
		var half: float = W * 0.5 * _beam_shape(t)
		var top: float = Hd * (1.0 + 0.45 * pow(1.0 - t, 4.0) + 0.25 * pow(t, 5.0))
		var keel: float = -D * (0.5 + 0.5 * sin(t * PI))
		var prof := [Vector2(half, top), Vector2(half * 1.03, top * 0.5), Vector2(half * 0.97, 0.0), Vector2(half * 0.7, keel * 0.6), Vector2(0.0, keel)]
		secs.append({"x": x, "p": prof, "top": top, "keel": keel})
	var band_cols := [stripe, wood, dark, dark]
	for i in N:
		var a: Dictionary = secs[i]
		var b: Dictionary = secs[i + 1]
		var xm: float = (a["x"] + b["x"]) * 0.5
		for j in 4:
			for sgn in [1.0, -1.0]:
				var p0: Vector2 = a["p"][j]
				var p1: Vector2 = a["p"][j + 1]
				var q0: Vector2 = b["p"][j]
				var q1: Vector2 = b["p"][j + 1]
				var inside := Vector3(xm, 0.0, 0.0)
				k.quad(Vector3(a["x"], p0.y, p0.x * sgn), Vector3(b["x"], q0.y, q0.x * sgn), Vector3(b["x"], q1.y, q1.x * sgn), Vector3(a["x"], p1.y, p1.x * sgn), band_cols[j], inside)
		# Däck
		var at: Vector2 = a["p"][0]
		var bt: Vector2 = b["p"][0]
		k.quad(Vector3(a["x"], at.y, at.x), Vector3(b["x"], bt.y, bt.x), Vector3(b["x"], bt.y, -bt.x), Vector3(a["x"], at.y, -at.x), deck, Vector3(xm, at.y - 20.0, 0))
		# Reling
		for sgn in [1.0, -1.0]:
			k.quad(Vector3(a["x"], at.y, at.x * sgn), Vector3(b["x"], bt.y, bt.x * sgn), Vector3(b["x"], bt.y + 2.2, bt.x * sgn * 0.98), Vector3(a["x"], at.y + 2.2, at.x * sgn * 0.98), stripe.darkened(0.2), Vector3(xm, at.y, 0))
	# Akterspegel
	var s0: Dictionary = secs[0]
	var sp: Array = s0["p"]
	for j in 4:
		for sgn in [1.0, -1.0]:
			k.tri(Vector3(s0["x"], 0.0, 0.0), Vector3(s0["x"], sp[j].y, sp[j].x * sgn), Vector3(s0["x"], sp[j + 1].y, sp[j + 1].x * sgn), wood.darkened(0.1), Vector3(s0["x"] + 10.0, 0, 0))
		k.tri(Vector3(s0["x"], sp[0].y, 0.0), Vector3(s0["x"], sp[0].y, sp[0].x), Vector3(s0["x"], sp[0].y, -sp[0].x), wood, Vector3(s0["x"] + 10.0, 0, 0))
	# Kanonportar och kanoner
	var per_side := maxi(0, cannons)
	var rows := maxi(1, decks)
	var per_row := int(ceil(float(per_side) / rows))
	for r in rows:
		for c in per_row:
			if r * per_row + c >= per_side:
				break
			var t: float = lerpf(0.2, 0.78, (c + 0.5) / per_row)
			var x := -L * 0.5 + t * L
			var half: float = W * 0.5 * _beam_shape(t) * 1.03
			var y: float = Hd * (0.62 - r * 0.28)
			for sgn in [1.0, -1.0]:
				var z: float = (half + 0.4) * sgn
				k.quad(Vector3(x - 1.8, y - 1.4, z), Vector3(x + 1.8, y - 1.4, z), Vector3(x + 1.8, y + 1.4, z), Vector3(x - 1.8, y + 1.4, z), Color(0.08, 0.06, 0.05), Vector3(x, y, 0))
				k.cylinder(Vector3(x, y, z), Vector3(x, y, z + 3.2 * sgn), 0.75, Color(0.12, 0.12, 0.13), 5)
	# Akterkastell med fönster
	var top0: float = secs[0]["top"]
	if castle > 0.0:
		var cl: float = L * 0.2
		var ch: float = Hd * 0.55 * castle
		var cw: float = W * 0.82
		var cx: float = -L * 0.5 + cl * 0.5 + 1.0
		var cy: float = Hd * 1.15
		k.box(Vector3(cx, cy + ch * 0.5, 0), Vector3(cl, ch, cw), wood.lightened(0.08), deck)
		k.box(Vector3(cx, cy + ch + 1.0, 0), Vector3(cl, 2.0, cw + 1.0), stripe)
		for wi in 3:
			var wz := (wi - 1) * cw * 0.28
			k.quad(Vector3(cx - cl * 0.5 - 0.3, cy + ch * 0.35, wz - 2), Vector3(cx - cl * 0.5 - 0.3, cy + ch * 0.35, wz + 2), Vector3(cx - cl * 0.5 - 0.3, cy + ch * 0.7, wz + 2), Vector3(cx - cl * 0.5 - 0.3, cy + ch * 0.7, wz - 2), Color(0.95, 0.82, 0.45), Vector3(cx, cy + ch * 0.5, 0))
		if castle >= 0.9:
			# Förkastell
			k.box(Vector3(L * 0.3, Hd * 1.05 + ch * 0.25, 0), Vector3(L * 0.12, ch * 0.5, W * 0.55), wood.lightened(0.08), deck)
	# Bogspröt
	var bow := Vector3(L * 0.5, Hd * 1.2, 0)
	k.cylinder(bow, bow + Vector3(L * 0.22, L * 0.07, 0), L * 0.008, Color(0.3, 0.2, 0.12), 5)
	# Master och rår
	var masts := _mast_positions(spec)
	var flag_top := Vector3.ZERO
	for mi in masts.size():
		var m: Dictionary = masts[mi]
		var mx: float = m["x"]
		var mh: float = m["h"]
		var base := Vector3(mx, Hd * 0.9, 0)
		k.cylinder(base, base + Vector3(0, mh, 0), L * 0.012, Color(0.32, 0.21, 0.12), 6, L * 0.007)
		# Mastkorg
		k.cylinder(base + Vector3(0, mh * 0.62, 0), base + Vector3(0, mh * 0.64, 0), L * 0.035, Color(0.3, 0.2, 0.12), 6)
		if spec["rig"] == "square":
			for sail in _square_sails(mh, mi, masts.size()):
				var yy: float = Hd * 0.9 + sail["y1"]
				var hw: float = W * sail["w"] * 0.5 + 2.0
				k.cylinder(Vector3(mx + 1.0, yy, -hw), Vector3(mx + 1.0, yy, hw), L * 0.006, Color(0.3, 0.2, 0.12), 4)
		else:
			k.cylinder(Vector3(mx, Hd * 0.9 + 5.0, 0), Vector3(mx - L * 0.38, Hd * 0.9 + 4.0, 0), L * 0.007, Color(0.3, 0.2, 0.12), 4)
		if m.get("main", false):
			flag_top = base + Vector3(0, mh, 0)
	if flag_top == Vector3.ZERO:
		flag_top = Vector3(masts[0]["x"], Hd * 0.9 + masts[0]["h"], 0)
	return [k.commit(), flag_top]


func _mast_positions(spec: Dictionary) -> Array:
	var L := _L
	var n: int = spec["masts"]
	match n:
		1:
			return [{"x": L * 0.08, "h": L * 0.88, "main": true}]
		2:
			return [{"x": -L * 0.14, "h": L * 0.82, "main": true}, {"x": L * 0.2, "h": L * 0.72}]
	return [{"x": -L * 0.24, "h": L * 0.62}, {"x": 0.0, "h": L * 0.9, "main": true}, {"x": L * 0.24, "h": L * 0.78}]


## Råsegel per mast: höjder (från däck) och bredd i förhållande till skrovbredden.
func _square_sails(mh: float, mi: int, count: int) -> Array:
	var out := [
		{"y0": mh * 0.2, "y1": mh * 0.5, "w": 1.55},
		{"y0": mh * 0.53, "y1": mh * 0.76, "w": 1.2},
	]
	if count >= 3:
		out.append({"y0": mh * 0.79, "y1": mh * 0.93, "w": 0.85})
	return out


# ------------------------------------------------------------------ Segel
func _sail_quad(st: SurfaceTool, corners: Array, normal: Vector3, nx := 4, ny := 3) -> void:
	# corners: [övre vänster, övre höger, nedre höger, nedre vänster]
	var tl: Vector3 = corners[0]
	var tr: Vector3 = corners[1]
	var br: Vector3 = corners[2]
	var bl: Vector3 = corners[3]
	for j in ny:
		for i in nx:
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var v0 := float(j) / ny
			var v1 := float(j + 1) / ny
			var p := func(u: float, v: float) -> Vector3: return tl.lerp(tr, u).lerp(bl.lerp(br, u), v)
			var pts := [p.call(u0, v0), p.call(u1, v0), p.call(u1, v1), p.call(u0, v1)]
			var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(normal)
				st.set_uv(uvs[idx])
				st.add_vertex(pts[idx])


func _build_sails(type: String, spec: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L := _L
	var W: float = L * spec["beam"]
	var decks: int = spec["decks"]
	var Hd: float = L * (0.1 + 0.035 * maxi(0, decks - 1))
	var masts := _mast_positions(spec)
	for mi in masts.size():
		var m: Dictionary = masts[mi]
		var mx: float = m["x"]
		var mh: float = m["h"]
		var y_base: float = Hd * 0.9
		if spec["rig"] == "square":
			for sail in _square_sails(mh, mi, masts.size()):
				var hw: float = W * sail["w"] * 0.5
				var hw_bot: float = hw * 1.08
				var y0: float = y_base + sail["y0"]
				var y1: float = y_base + sail["y1"]
				_sail_quad(st, [Vector3(mx + 1.5, y1, -hw), Vector3(mx + 1.5, y1, hw), Vector3(mx + 1.5, y0, hw_bot), Vector3(mx + 1.5, y0, -hw_bot)], Vector3(1, 0, 0))
		else:
			# Gaffelsegel längs skeppet
			var glen := L * 0.38 if masts.size() == 1 else L * 0.3
			_sail_quad(st, [Vector3(mx - 1, y_base + mh * 0.92, 0), Vector3(mx - glen, y_base + mh * 0.68, 0), Vector3(mx - glen, y_base + 6.0, 0), Vector3(mx - 1, y_base + 6.0, 0)], Vector3(0, 0, 1))
	# Klyvare från bogspröt till förmasten
	var fore: Dictionary = masts[masts.size() - 1]
	var tip := Vector3(L * 0.5 + L * 0.2, Hd * 1.2 + L * 0.06, 0)
	var top := Vector3(fore["x"] + 2.0, Hd * 0.9 + fore["h"] * 0.85, 0)
	var low := Vector3(fore["x"] + 4.0, Hd * 1.0 + 4.0, 0)
	_sail_quad(st, [top, top.lerp(tip, 0.02), tip, low], Vector3(0, 0, 1), 3, 3)
	return st.commit()


# ------------------------------------------------------------------ Uppdatering
static func to3d(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x, h, p.y / Y_SQUASH)


func sync(delta: float) -> void:
	_t += delta
	var s = ship
	var sink: float = clampf(s.sinking / 4.0, 0.0, 1.0)
	visible = s.visible
	if not visible:
		return
	var dir2 := Vector2.from_angle(s.heading)
	var d3 := Vector3(dir2.x, 0, dir2.y / Y_SQUASH).normalized()
	var yaw := atan2(-d3.z, d3.x)
	# Krängning i vinden och gungning i sjön
	var wind_side := sin(angle_difference(s.heading, Game.wind_angle))
	var target_heel := clampf(wind_side, -1.0, 1.0) * 0.09 * clampf(s.speed / 100.0, 0.0, 1.0) * Game.wind_strength
	_heel = lerpf(_heel, target_heel, clampf(delta * 1.5, 0.0, 1.0))
	var roll := _heel + sin(_t * 1.3 + s.position.y * 0.01) * 0.03 * (1.0 + Game.storm * 2.0) + sink * 0.55
	var pitch := sin(_t * 1.7 + s.position.x * 0.01) * 0.025 * (1.0 + Game.storm * 2.0) + sink * 0.25
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, roll) * Basis(Vector3.BACK, pitch)
	var bob := sin(_t * 1.8 + s.position.x * 0.013) * 1.2 - sink * _L * 0.45
	transform = Transform3D(b, to3d(s.position, bob))
	# Segel: buktar mer i fart, gaffelsegel byter sida efter vinden
	_sail_mat.set_shader_parameter("billow", 2.0 + 7.0 * clampf(s.speed / 120.0, 0.0, 1.0) * Game.wind_strength)
	_sail_mat.set_shader_parameter("side", -1.0 if wind_side > 0.0 else 1.0)
	# Flaggan pekar med vinden
	var wd := Vector2.from_angle(Game.wind_angle)
	var w3 := Vector3(wd.x, 0, wd.y / Y_SQUASH).normalized()
	var wyaw := atan2(-w3.z, w3.x) - yaw
	_flag.rotation = Vector3(0, wyaw, 0)
