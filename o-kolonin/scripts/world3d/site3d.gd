extends Node3D
## Resursbyggnader och skeppsvarv i 3D. Modellen reser sig medan den byggs, får
## fler delar på nivå 2 och 3, och har en egen arbetsanimation: väderkvarnens
## vingar snurrar, kranar svänger, båtar ror ut och tillbaka, kristaller glöder.

const Kit = preload("res://scripts/world3d/kit.gd")
const Ship3D = preload("res://scripts/world3d/ship3d.gd")
const Y_SQUASH := 0.72
const S := 1.5

static var _cache := {}
static var _glow_mat: ShaderMaterial = null
static var _ruin_mat: ShaderMaterial = null

var b = null                 # byggnaden i 2D-världen
var _body: MeshInstance3D
var _parts: Array = []       # animerade delar: {"n": nod, "kind": ...}
var _built_level := -1
var _t := 0.0
var _seed := 0.0
var _out := Vector3.RIGHT    # riktning ut mot havet (båtar)
var _was_ruined := false


static func glow_material() -> ShaderMaterial:
	if _glow_mat == null:
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = Ship3D.SOLID
		_glow_mat.set_shader_parameter("glow", 0.9)
	return _glow_mat


static func ruin_material() -> ShaderMaterial:
	if _ruin_mat == null:
		_ruin_mat = ShaderMaterial.new()
		_ruin_mat.shader = Ship3D.SOLID
		_ruin_mat.set_shader_parameter("tint", Color(0.42, 0.38, 0.36))
	return _ruin_mat


func setup(p_b) -> void:
	b = p_b
	_seed = randf() * 100.0
	position = Ship3D.to3d(b.global_position)
	var isl = b.island
	if isl != null:
		var o: Vector2 = b.global_position - isl.position
		_out = Vector3(o.x, 0, o.y / Y_SQUASH).normalized()
		if b.type == "skeppsvarv":
			var ho: Vector2 = isl.harbor_out
			_out = Vector3(ho.x, 0, ho.y / Y_SQUASH).normalized()
	# Varvets slip pekar ut mot havet; övriga platser vänds lätt mot havet men
	# visar mest framsidan mot betraktaren.
	if b.type == "skeppsvarv":
		rotation.y = atan2(-_out.z, _out.x)
	else:
		rotation.y = atan2(_out.x, _out.z) * 0.3
	_body = MeshInstance3D.new()
	_body.material_override = Ship3D.solid_material()
	add_child(_body)


func sync(delta: float) -> void:
	var real := delta / maxf(0.001, Engine.time_scale)
	_t += real
	if b == null or not is_instance_valid(b):
		return
	visible = b.delay <= 0.0
	if not visible:
		return
	if _built_level != b.level:
		_rebuild(b.level)
	# Reser sig ur marken medan den byggs
	var rise := 1.0
	if not b.built:
		rise = maxf(0.04, clampf(b.progress, 0.0, 1.0))
	var pop: float = sin(b._pop * PI * 3.0) * b._pop * 0.12
	scale = Vector3(1.0 + pop, rise * (1.0 - pop), 1.0 + pop) * S
	if b.ruined != _was_ruined:
		_was_ruined = b.ruined
		_body.material_override = ruin_material() if b.ruined else Ship3D.solid_material()
	if b.built and not b.ruined:
		_animate(delta)


func _rebuild(level: int) -> void:
	_built_level = level
	for p in _parts:
		if is_instance_valid(p["n"]):
			p["n"].queue_free()
	_parts.clear()
	var key := "%s|%d" % [b.type, level]
	if not _cache.has(key):
		_cache[key] = _make_body(b.type, level)
	_body.mesh = _cache[key]
	_make_parts(b.type, level)


func _part(mesh: ArrayMesh, at: Vector3, kind: String, mat: Material = null) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat != null else Ship3D.solid_material()
	mi.position = at
	add_child(mi)
	_parts.append({"n": mi, "kind": kind, "base": at})
	return mi


# ------------------------------------------------------------------ Gemensamma delar
static func hut(k, c: Vector3, w: float, d: float, h: float, wall: Color, roof: Color, yaw := 0.0) -> void:
	k.xform = Transform3D(Basis(Vector3.UP, yaw), c)
	k.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	k.gable(Vector3(0, h, 0), w, d, h * 0.6, roof, 1.4)
	k.quad(Vector3(-1.4, 0, d * 0.5 + 0.2), Vector3(1.4, 0, d * 0.5 + 0.2), Vector3(1.4, 4.5, d * 0.5 + 0.2), Vector3(-1.4, 4.5, d * 0.5 + 0.2), Color(0.25, 0.17, 0.1), Vector3(0, 2, 0))
	k.xform = Transform3D.IDENTITY


static func tree(k, at: Vector3, h: float, col: Color, seed_v: int) -> void:
	k.cylinder(at, at + Vector3(0, h * 0.45, 0), h * 0.06, Color(0.4, 0.28, 0.17), 5, h * 0.04)
	k.dome(at + Vector3(0, h * 0.55, 0), h * 0.32, col, 7, 3, true, 0.85, 0.18, seed_v)
	k.dome(at + Vector3(h * 0.12, h * 0.78, -h * 0.05), h * 0.22, col.lightened(0.08), 6, 2, true, 0.9, 0.2, seed_v + 1)


## Palm: böjd stam i segment och nedhängande blad.
static func palm(k, at: Vector3, h: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * h * 0.22
	var prev := at
	var segs := 5
	for i in segs:
		var t := float(i + 1) / segs
		var p := at + Vector3(0, h * t, 0) + lean * t * t
		k.cylinder(prev, p, h * 0.035 * (1.0 - t * 0.35), Color(0.55, 0.42, 0.28).darkened(0.08 * (i % 2)), 5)
		prev = p
	var top := prev
	var leaf := Color(0.25, 0.55, 0.2)
	var n := 7
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var mid := top + dir * h * 0.25 + Vector3(0, h * 0.06, 0)
		var tip := top + dir * h * 0.48 - Vector3(0, h * 0.16, 0)
		var lc := leaf.lightened(rng.randf_range(-0.08, 0.12))
		k.plane_tri(top, mid + side * h * 0.07, mid - side * h * 0.07, lc, Vector3.UP)
		k.plane_tri(mid + side * h * 0.07, tip, mid - side * h * 0.07, lc.darkened(0.08), Vector3.UP)
	k.dome(top - Vector3(0, h * 0.02, 0), h * 0.05, Color(0.45, 0.33, 0.15), 5, 2, true)


static func rock(k, at: Vector3, r: float, col: Color, seed_v: int) -> void:
	k.dome(at, r, col, 7, 3, false, 0.7, 0.25, seed_v)


static func crate(k, at: Vector3, s: float) -> void:
	k.box(at + Vector3(0, s * 0.5, 0), Vector3(s, s, s), Color(0.6, 0.45, 0.27))


static func boat_mesh() -> ArrayMesh:
	if _cache.has("boat"):
		return _cache["boat"]
	var k := Kit.new()
	var w := Color(0.45, 0.3, 0.18)
	k.quad(Vector3(-8, 2, -3), Vector3(7, 2, -2), Vector3(5, -1, -1), Vector3(-7, -1, -2), w, Vector3(0, 1, 0))
	k.quad(Vector3(-8, 2, 3), Vector3(7, 2, 2), Vector3(5, -1, 1), Vector3(-7, -1, 2), w, Vector3(0, 1, 0))
	k.tri(Vector3(7, 2, -2), Vector3(7, 2, 2), Vector3(11, 2.5, 0), w, Vector3(0, 1, 0))
	k.quad(Vector3(-8, 2, -3), Vector3(7, 2, -2), Vector3(7, 2, 2), Vector3(-8, 2, 3), Color(0.6, 0.45, 0.28), Vector3(0, -5, 0))
	k.cylinder(Vector3(1, 2, 0), Vector3(1, 15, 0), 0.4, Color(0.35, 0.24, 0.14), 4)
	k.plane_tri(Vector3(1.2, 14, 0), Vector3(1.2, 3, 0), Vector3(8, 3.5, 0), Color(0.97, 0.94, 0.86), Vector3(0, 0, 1))
	var m := k.commit()
	_cache["boat"] = m
	return m


# ------------------------------------------------------------------ Modeller per typ
func _make_body(type: String, level: int) -> ArrayMesh:
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(type) + level
	var wood := Color(0.52, 0.37, 0.22)
	var thatch := Color(0.78, 0.66, 0.38)
	var plank := Color(0.62, 0.47, 0.3)
	match type:
		"skogshuggare":
			hut(k, Vector3(-6, 0, 4), 18, 13, 9, wood, thatch)
			for i in 3:
				k.cylinder(Vector3(10, 1.8 + i * 3.2, -6 + i * 0.3), Vector3(10, 1.8 + i * 3.2, 8 - i * 0.3), 1.8, Color(0.55, 0.38, 0.22), 6)
				if i < 2:
					k.cylinder(Vector3(14, 1.8 + i * 3.2, -6), Vector3(14, 1.8 + i * 3.2, 8), 1.8, Color(0.5, 0.35, 0.2), 6)
			k.cylinder(Vector3(18, 0, 14), Vector3(18, 3, 14), 3.0, Color(0.5, 0.36, 0.22), 7)  # stubbe
			var trees := [Vector3(-28, 0, -18), Vector3(-14, 0, -26), Vector3(4, 0, -28), Vector3(24, 0, -20), Vector3(-30, 0, 6)]
			if level >= 2:
				trees += [Vector3(30, 0, -4), Vector3(-22, 0, 22)]
				hut(k, Vector3(-4, 0, -12), 10, 8, 6, wood.darkened(0.1), thatch.darkened(0.1))
			if level >= 3:
				trees += [Vector3(14, 0, -36), Vector3(-36, 0, -8)]
				k.box(Vector3(26, 4, 10), Vector3(10, 8, 14), wood)
				k.gable(Vector3(26, 8, 10), 10, 14, 4, thatch, 1.0)
			for i in trees.size():
				tree(k, trees[i], rng.randf_range(26, 34), Color(0.2, 0.42, 0.18).lightened(rng.randf_range(-0.05, 0.1)), i * 13 + 5)
		"kokosodling":
			hut(k, Vector3(16, 0, 14), 14, 11, 7, wood, thatch)
			var rows := 2 + level
			for r in rows:
				for c in 3:
					var p := Vector3(-26 + c * 16 + (r % 2) * 7, 0, -26 + r * 13)
					palm(k, p, rng.randf_range(26, 32), r * 7 + c)
			for i in level + 1:
				k.dome(Vector3(4 + i * 5, 0, 22), 2.6, Color(0.42, 0.3, 0.15), 5, 2)
			if level >= 3:
				k.box(Vector3(-20, 3, 22), Vector3(14, 6, 8), plank)
		"fiskehydda":
			# Hydda på pålar vid strandkanten, torkställningar
			for p in [Vector3(-6, 0, -5), Vector3(6, 0, -5), Vector3(6, 0, 5), Vector3(-6, 0, 5)]:
				k.cylinder(p, p + Vector3(0, 4, 0), 0.8, wood.darkened(0.2), 4)
			k.box(Vector3(0, 4.5, 0), Vector3(16, 1, 14), plank)
			hut(k, Vector3(0, 5, 0), 13, 10, 7, wood, thatch)
			for i in 2 + level:
				var x := -18.0 + i * 7.0
				k.cylinder(Vector3(x, 0, 14), Vector3(x, 8, 14), 0.5, wood, 4)
				k.cylinder(Vector3(x, 8, 14), Vector3(x + 7, 8, 14), 0.4, wood, 4)
				for f in 2:
					k.box(Vector3(x + 2 + f * 2.5, 6.5, 14), Vector3(1, 3, 0.6), Color(0.72, 0.76, 0.8))
			if level >= 2:
				hut(k, Vector3(-18, 0, -6), 10, 8, 6, wood, thatch, 0.4)
			if level >= 3:
				for i in 3:
					k.box(Vector3(14 + i * 3.0, 1.5, -12), Vector3(2.4, 3, 2.4), Color(0.5, 0.36, 0.2))
		"stenbrott":
			var stone := Color(0.66, 0.64, 0.6)
			rock(k, Vector3(-10, 0, -14), 22, stone, 3)
			rock(k, Vector3(14, 0, -18), 16, stone.darkened(0.06), 7)
			rock(k, Vector3(-26, 0, 2), 12, stone.lightened(0.04), 11)
			for i in 3 + level * 2:
				var p := Vector3(rng.randf_range(-6, 22), 0, rng.randf_range(4, 20))
				k.box(p + Vector3(0, 2.2, 0), Vector3(6, 4.4, 5), Color(0.8, 0.78, 0.72).darkened(rng.randf() * 0.1))
			hut(k, Vector3(24, 0, 10), 12, 10, 7, wood, thatch, -0.3)
			# Kranens fot
			k.cylinder(Vector3(4, 0, -2), Vector3(4, 18, -2), 1.2, wood, 5)
			if level >= 3:
				k.box(Vector3(-12, 3, 18), Vector3(16, 6, 10), stone.lightened(0.1))
		"sandtakt":
			var sand := Color(0.95, 0.88, 0.68)
			k.dome(Vector3(-12, 0, -8), 15, sand, 8, 3, false, 0.45)
			k.dome(Vector3(10, 0, -14), 11, sand.darkened(0.04), 8, 3, false, 0.5)
			if level >= 2:
				k.dome(Vector3(-22, 0, 12), 10, sand.lightened(0.03), 8, 3, false, 0.5)
			# Såll på bockar
			for p in [Vector3(6, 0, 6), Vector3(16, 0, 6), Vector3(6, 0, 12), Vector3(16, 0, 12)]:
				k.cylinder(p, p + Vector3(0, 6, 0), 0.6, wood, 4)
			k.box(Vector3(11, 6.5, 9), Vector3(13, 0.8, 9), wood.lightened(0.1))
			hut(k, Vector3(22, 0, -8), 11, 9, 6, wood, thatch)
			# Skottkärra
			k.box(Vector3(-2, 3, 14), Vector3(6, 3, 4), plank)
			k.cylinder(Vector3(1, 1.5, 12), Vector3(1, 1.5, 16), 1.5, Color(0.3, 0.2, 0.12), 6)
			if level >= 3:
				k.box(Vector3(-4, 2, -22), Vector3(14, 4, 6), Color(0.75, 0.88, 0.85))
		"sockerplantage":
			# Fält med sockerrör i rader
			var cane := Color(0.45, 0.66, 0.28)
			var rows := 4 + level * 2
			for r in rows:
				for c in 6:
					var p := Vector3(-34 + c * 6.5 + rng.randf_range(-1, 1), 0, -30 + r * 5.0)
					var h := rng.randf_range(8, 12)
					k.cylinder(p, p + Vector3(rng.randf_range(-1, 1), h, 0), 0.7, cane.darkened(rng.randf() * 0.15), 3)
					k.cone(p + Vector3(0, h * 0.8, 0), 2.2, h * 0.5, cane.lightened(0.1), 4)
			# Kvarnens torn (vingarna är en egen del som snurrar)
			k.cylinder(Vector3(18, 0, 8), Vector3(18, 26, 8), 7.0, Color(0.88, 0.84, 0.76), 8, 5.0)
			k.cone(Vector3(18, 26, 8), 6.5, 9, Color(0.6, 0.32, 0.2), 8)
			hut(k, Vector3(4, 0, 22), 14, 10, 7, Color(0.88, 0.84, 0.76), Color(0.62, 0.32, 0.2))
			if level >= 3:
				hut(k, Vector3(-16, 0, 24), 12, 9, 6, wood, thatch)
		"kryddgard":
			var bush := [Color(0.3, 0.52, 0.22), Color(0.42, 0.55, 0.2), Color(0.55, 0.42, 0.2), Color(0.62, 0.3, 0.22)]
			var rows := 3 + level
			for r in rows:
				for c in 5:
					var p := Vector3(-30 + c * 9.0, 0, -26 + r * 8.0)
					k.dome(p, rng.randf_range(3.0, 4.2), bush[(r + c) % 4], 6, 2, false, 0.9, 0.2, r * 5 + c)
			hut(k, Vector3(20, 0, 8), 14, 11, 8, Color(0.86, 0.8, 0.66), Color(0.6, 0.33, 0.2))
			# Torkställning med lövtak
			for p in [Vector3(10, 0, 22), Vector3(26, 0, 22), Vector3(10, 0, 30), Vector3(26, 0, 30)]:
				k.cylinder(p, p + Vector3(0, 7, 0), 0.6, wood, 4)
			k.box(Vector3(18, 7.3, 26), Vector3(18, 0.6, 10), Color(0.7, 0.58, 0.32))
			if level >= 3:
				k.cylinder(Vector3(-24, 0, 22), Vector3(-24, 14, 22), 4.0, Color(0.86, 0.8, 0.66), 7)
				k.cone(Vector3(-24, 14, 22), 5.0, 7, Color(0.6, 0.33, 0.2), 7)
		"parldykare":
			for p in [Vector3(-6, 0, -5), Vector3(6, 0, -5), Vector3(6, 0, 5), Vector3(-6, 0, 5)]:
				k.cylinder(p, p + Vector3(0, 4, 0), 0.8, wood.darkened(0.2), 4)
			k.box(Vector3(0, 4.5, 0), Vector3(16, 1, 14), plank)
			hut(k, Vector3(0, 5, 0), 12, 10, 7, Color(0.85, 0.8, 0.7), thatch)
			for i in 2 + level:
				k.dome(Vector3(-16 + i * 6.0, 0, 14), 2.4, Color(0.95, 0.93, 0.88), 6, 2, false, 0.6)
			k.box(Vector3(14, 2.5, 8), Vector3(8, 5, 6), Color(0.55, 0.4, 0.25))
			if level >= 2:
				hut(k, Vector3(-18, 0, -8), 10, 8, 6, wood, thatch)
		"kristallgruva", "guldgruva":
			var crystal: bool = type == "kristallgruva"
			var stone := Color(0.55, 0.5, 0.46) if not crystal else Color(0.45, 0.45, 0.52)
			rock(k, Vector3(-4, 0, -14), 24, stone, 5)
			rock(k, Vector3(-24, 0, -4), 14, stone.darkened(0.05), 9)
			# Gruvöppning med timmerram
			k.box(Vector3(-4, 6, 6), Vector3(12, 12, 3), Color(0.12, 0.1, 0.1))
			k.cylinder(Vector3(-11, 0, 8), Vector3(-11, 13, 8), 1.2, wood, 5)
			k.cylinder(Vector3(3, 0, 8), Vector3(3, 13, 8), 1.2, wood, 5)
			k.cylinder(Vector3(-12, 13, 8), Vector3(4, 13, 8), 1.3, wood, 5)
			# Räls och vagn
			for x in [-6.0, -2.0]:
				k.box(Vector3(x, 0.3, 18), Vector3(0.8, 0.6, 20), Color(0.35, 0.3, 0.28))
			k.box(Vector3(-4, 3, 20), Vector3(7, 4, 6), Color(0.4, 0.3, 0.2))
			k.dome(Vector3(-4, 5, 20), 2.8, Color(0.85, 0.7, 0.25) if not crystal else Color(0.4, 0.95, 1.0), 5, 2, false, 0.7)
			hut(k, Vector3(18, 0, 10), 13, 10, 7, wood, thatch, -0.4)
			if not crystal:
				# Lyftverk (hjulet snurrar)
				for p in [Vector3(12, 0, -8), Vector3(22, 0, -8)]:
					k.cylinder(p, p + Vector3(0, 22, 0), 1.0, wood, 4)
				k.cylinder(Vector3(11, 22, -8), Vector3(23, 22, -8), 1.0, wood, 4)
			if level >= 2:
				hut(k, Vector3(20, 0, 28), 10, 8, 6, wood.darkened(0.1), thatch)
			if level >= 3:
				k.box(Vector3(-24, 4, 22), Vector3(12, 8, 10), wood)
				k.gable(Vector3(-24, 8, 22), 12, 10, 5, Color(0.5, 0.5, 0.55), 1.0)
		"skeppsvarv":
			# Slip med ett skepp under byggnad (spant), lagerhus och kran
			k.box(Vector3(0, 1.0, 0), Vector3(70, 2, 26), plank.darkened(0.1))
			for i in 9:
				var x := -26.0 + i * 6.0
				var hw := 9.0 * sin(PI * (i + 0.5) / 9.0) + 2.0
				k.cylinder(Vector3(x, 2, -hw), Vector3(x, 12, -hw * 1.15), 0.7, wood.lightened(0.1), 4)
				k.cylinder(Vector3(x, 2, hw), Vector3(x, 12, hw * 1.15), 0.7, wood.lightened(0.1), 4)
			k.cylinder(Vector3(-30, 2.5, 0), Vector3(30, 3.5, 0), 1.3, wood, 5)  # köl
			k.box(Vector3(-46, 9, -20), Vector3(22, 18, 16), Color(0.85, 0.8, 0.7))
			k.gable(Vector3(-46, 18, -20), 22, 16, 8, Color(0.62, 0.3, 0.18), 1.2)
			for i in 4:
				k.box(Vector3(-40 + i * 5.0, 2, 22), Vector3(4, 4, 4), Color(0.6, 0.45, 0.27))
			k.cylinder(Vector3(36, 0, -16), Vector3(36, 26, -16), 1.4, wood, 5)  # kranens mast
			if level >= 2:
				k.box(Vector3(-46, 7, 12), Vector3(18, 14, 12), wood)
				k.gable(Vector3(-46, 14, 12), 18, 12, 6, thatch, 1.0)
			if level >= 3:
				for i in 6:
					k.cylinder(Vector3(-20 + i * 9.0, 0, -22), Vector3(-20 + i * 9.0, 2, -22), 1.6, Color(0.15, 0.15, 0.16), 6)
	if k.is_empty():
		k.box(Vector3(0, 5, 0), Vector3(14, 10, 14), wood)
	return k.commit()


## Rörliga delar: vingar, kranarmar, hjul, båtar, kristaller.
func _make_parts(type: String, level: int) -> void:
	match type:
		"sockerplantage":
			var k := Kit.new()
			k.cylinder(Vector3(0, 0, -1), Vector3(0, 0, 2), 1.2, Color(0.35, 0.24, 0.14), 5)
			for i in 4:
				var a := TAU * i / 4.0
				var d := Vector3(cos(a), sin(a), 0)
				var s := Vector3(-d.y, d.x, 0)
				k.cylinder(Vector3.ZERO, d * 22.0, 0.6, Color(0.4, 0.28, 0.16), 4)
				k.plane_tri(d * 4.0, d * 21.0, d * 21.0 + s * 5.0, Color(0.95, 0.92, 0.84), Vector3(0, 0, 1))
				k.plane_tri(d * 4.0, d * 21.0 + s * 5.0, d * 4.0 + s * 5.0, Color(0.92, 0.89, 0.8), Vector3(0, 0, 1))
			_part(k.commit(), Vector3(18, 26, 15.5), "spin")
		"stenbrott":
			var k := Kit.new()
			k.cylinder(Vector3(0, 0, 0), Vector3(20, 4, 0), 0.9, Color(0.45, 0.32, 0.2), 4)
			k.cylinder(Vector3(18, 4, 0), Vector3(18, -6, 0), 0.25, Color(0.3, 0.28, 0.25), 3)
			k.box(Vector3(18, -8, 0), Vector3(4, 3, 3), Color(0.8, 0.78, 0.72))
			_part(k.commit(), Vector3(4, 18, -2), "swing")
		"skeppsvarv":
			var k := Kit.new()
			k.cylinder(Vector3(0, 0, 0), Vector3(-34, 6, 0), 1.0, Color(0.45, 0.32, 0.2), 4)
			k.cylinder(Vector3(-30, 6, 0), Vector3(-30, -8, 0), 0.25, Color(0.3, 0.28, 0.25), 3)
			k.box(Vector3(-30, -10, 0), Vector3(4, 4, 4), Color(0.6, 0.45, 0.27))
			_part(k.commit(), Vector3(36, 24, -16), "swing")
		"guldgruva":
			var k := Kit.new()
			for i in 6:
				var a := TAU * i / 6.0
				k.cylinder(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 6.0, 0.5, Color(0.35, 0.24, 0.14), 3)
			_part(k.commit(), Vector3(17, 22, -8), "wheel")
		"kristallgruva":
			var k := Kit.new()
			var crystal := Color(0.45, 0.95, 1.0)
			for c in [Vector3(-14, 0, -4), Vector3(8, 0, -2), Vector3(-22, 0, 10), Vector3(10, 0, 18)]:
				for j in 2 + level:
					k.cone(c + Vector3(j * 2.5 - 2.5, 0, (j % 2) * 2.5), 2.2, 8.0 + j * 3.5, crystal, 4)
			_part(k.commit(), Vector3.ZERO, "glow", glow_material())
	if type in ["fiskehydda", "parldykare", "skeppsvarv"]:
		var boat := MeshInstance3D.new()
		boat.mesh = boat_mesh()
		boat.material_override = Ship3D.solid_material()
		add_child(boat)
		_parts.append({"n": boat, "kind": "boat", "base": Vector3.ZERO})


func _animate(_delta: float) -> void:
	var w := Game.wind_strength * (1.0 + Game.storm)
	for p in _parts:
		var n: Node3D = p["n"]
		match p["kind"]:
			"spin":
				n.rotation.z = _t * 1.4 * w + _seed
			"swing":
				n.rotation.y = sin(_t * 0.45 + _seed) * 1.1
			"wheel":
				n.rotation.z = _t * 2.0
			"glow":
				var m: ShaderMaterial = n.material_override
				m.set_shader_parameter("glow", 0.6 + 0.35 * sin(Time.get_ticks_msec() * 0.002))
			"boat":
				# Ut och tillbaka till stranden, i världens koordinater
				var k := fmod((_t + _seed * 3.0) / 14.0, 1.0)
				var tt := k * 2.0 if k < 0.5 else 2.0 - k * 2.0
				var side := Vector3(-_out.z, 0, _out.x)
				var wp := Ship3D.to3d(b.global_position) + _out * (60.0 + tt * 100.0) + side * sin(_t * 0.7 + _seed) * 10.0
				var dir := _out if k < 0.5 else -_out
				n.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)).scaled(Vector3(1.4, 1.4, 1.4)), wp + Vector3(0, sin(_t * 2.0 + _seed) * 0.5, 0))
