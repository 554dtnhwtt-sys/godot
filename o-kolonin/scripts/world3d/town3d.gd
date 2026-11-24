extends Node3D
## En stad i 3D. Husen ligger i kvarter med gator emellan och växer fram ett i taget
## när staden uppgraderas. Varje nivå har sina landmärken: palissad och tält,
## kapell, kyrka, katedral med murar och bastioner, palats med kupol och stjärnfort.

const Kit = preload("res://scripts/world3d/kit.gd")
const Ship3D = preload("res://scripts/world3d/ship3d.gd")
const Site3D = preload("res://scripts/world3d/site3d.gd")
const HOUSES := [0, 10, 20, 32, 44]
## Hela staden skalas upp så att den fyller sin provins.
const S := 1.45
## Hur högt över stadens mitt skylten ska sitta (skärmpixlar), per nivå.
const TOP := [34.0, 40.0, 46.0, 56.0, 58.0]
const Y_SQUASH := 0.72
const INNER := 44.0
const PLAZA := Vector3(-62, 0, 34)

static var _house_cache := {}

var island = null
var level := 0
var _spots: Array = []
var _houses: Array = []
var _house_style: Array = []
var _landmarks: Array = []
var _rises: Array = []        # [nod, tid]
var _angle := 0.0
var _rng := RandomNumberGenerator.new()
var _smoke_t := 0.0
var _ruined := false


func setup(isl) -> void:
	island = isl
	_rng.seed = hash(isl.id) + 77
	_angle = _rng.randf_range(-0.5, 0.5)
	position = Ship3D.to3d(isl.position + isl.town_center)
	scale = Vector3(S, S, S)
	_plan()


func _local2d(p: Vector3) -> Vector2:
	return island.town_center + Vector2(p.x, p.z * Y_SQUASH) * S


func _on_land(p: Vector3, margin_poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(_local2d(p), margin_poly)


## Husplatser i kvarter med gator emellan, närmast mitten först. Platser i havet,
## på vulkanen, vid varvet eller vid resursplatserna hoppas över.
func _plan() -> void:
	var b := Basis(Vector3.UP, _angle)
	var plaza := b * PLAZA
	var yard: Vector2 = island.harbor_pos - island.harbor_out * 26.0
	for gx in range(-7, 8):
		for gz in range(-7, 8):
			if gx % 3 == 0 or gz % 3 == 0:
				continue  # gator
			var p := b * Vector3(gx * 21.0 + _rng.randf_range(-2, 2), 0, gz * 19.0 + _rng.randf_range(-2, 2))
			var r := p.length()
			if r < INNER or r > 124.0 or p.distance_to(plaza) < 30.0:
				continue
			if not _on_land(p, island.grass):
				continue
			var lp := _local2d(p)
			if lp.distance_to(yard) < 70.0:
				continue
			if island.volcano and lp.distance_to(island._volcano_center()) < island.radius * 0.45:
				continue
			var near := false
			for st in island.sites:
				if st["pos"].distance_to(lp) < 70.0:
					near = true
			if near:
				continue
			_spots.append(p)
	_spots.sort_custom(func(x, y): return x.length() < y.length())


func _style_for(lv: int) -> int:
	if island.guardians:
		return 3
	if lv <= 2:
		return 0
	if lv == 3:
		return 1
	return 2


func top_height() -> float:
	return TOP[clampi(level, 1, 5) - 1] * S


## Ett hus (cachat per stil och variant).
static func house_mesh(style: int, variant: int) -> ArrayMesh:
	var key := "%d|%d" % [style, variant]
	if _house_cache.has(key):
		return _house_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = style * 31 + variant * 7 + 3
	var k := Kit.new()
	var w := rng.randf_range(15, 19)
	var d := rng.randf_range(11, 13)
	var h := rng.randf_range(8, 10)
	var wall := Color(0.55, 0.4, 0.26)
	var roof := Color(0.76, 0.64, 0.36)
	match style:
		1:
			wall = [Color(0.93, 0.9, 0.84), Color(0.95, 0.88, 0.72), Color(0.88, 0.86, 0.8)][variant % 3]
			roof = Color(0.72, 0.34, 0.2).darkened(rng.randf_range(0.0, 0.15))
			h += 1.0
		2:
			h = rng.randf_range(13, 17)
			wall = [Color(0.92, 0.88, 0.8), Color(0.86, 0.75, 0.55), Color(0.8, 0.85, 0.88), Color(0.95, 0.9, 0.8)][variant % 4]
			roof = Color(0.66, 0.3, 0.18).darkened(rng.randf_range(0.0, 0.15))
		3:
			var stone := Color(0.86, 0.84, 0.76).darkened(rng.randf_range(0.0, 0.1))
			k.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), stone)
			k.box(Vector3(0, h + 2.0, 0), Vector3(w * 0.6, 4.0, d * 0.6), stone.lightened(0.05))
			k.cone(Vector3(w * 0.3, h, d * 0.3), 1.2, 6.0, Color(0.4, 0.95, 1.0), 4)
			var m3 := k.commit()
			_house_cache[key] = m3
			return m3
	k.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	k.gable(Vector3(0, h, 0), w, d, 7.0 if style == 0 else 6.0, roof, 1.6)
	# Dörr och fönster mot gatan
	var fz := d * 0.5 + 0.2
	k.quad(Vector3(-1.5, 0, fz), Vector3(1.5, 0, fz), Vector3(1.5, 5, fz), Vector3(-1.5, 5, fz), Color(0.3, 0.2, 0.12), Vector3(0, 3, 0))
	if style > 0:
		for wx in [-w * 0.3, w * 0.3]:
			k.quad(Vector3(wx - 1.2, h * 0.5, fz), Vector3(wx + 1.2, h * 0.5, fz), Vector3(wx + 1.2, h * 0.5 + 2.6, fz), Vector3(wx - 1.2, h * 0.5 + 2.6, fz), Color(0.25, 0.33, 0.42), Vector3(0, h * 0.5, 0))
	if variant % 2 == 0:
		k.box(Vector3(w * 0.25, h + 4.5, -d * 0.15), Vector3(2.2, 5.0, 2.2), Color(0.6, 0.5, 0.42))
	var m := k.commit()
	_house_cache[key] = m
	return m


func _mi(mesh: ArrayMesh, at: Vector3, yaw: float, rise: bool, delay := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Site3D.ruin_material() if _ruined else Ship3D.solid_material()
	mi.position = at
	mi.rotation = Vector3(0, yaw, 0)
	add_child(mi)
	if rise:
		mi.scale = Vector3(1, 0.01, 1)
		_rises.append([mi, -delay])
	return mi


func sync(delta: float) -> void:
	var real := delta / maxf(0.001, Engine.time_scale)
	visible = island.town_level > 0
	# Husen reser sig mjukt ur marken
	var i := 0
	while i < _rises.size():
		var r: Array = _rises[i]
		r[1] += real
		var node = r[0]
		if not is_instance_valid(node):
			_rises.remove_at(i)
			continue
		var k := clampf(r[1] / 0.9, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		node.scale = Vector3(1, maxf(0.01, e + sin(k * PI) * 0.12), 1)
		if k >= 1.0:
			node.scale = Vector3.ONE
			_rises.remove_at(i)
		else:
			i += 1
	if not visible:
		return
	if island.town_level != level:
		_set_level(island.town_level, level == 0)
	# Under uppgraderingen växer nya hus fram i takt med arbetet
	var want: int = HOUSES[level - 1]
	if island.town_upgrade_left > 0.0 and level < HOUSES.size():
		var total: float = Data.TOWN_LEVELS[level]["time"]
		var p: float = 1.0 - island.town_upgrade_left / total
		want = int(lerpf(HOUSES[level - 1], HOUSES[level], clampf(p, 0.0, 1.0)))
	while _houses.size() < mini(want, _spots.size()):
		_add_house(_style_for(maxi(level, 2)), true)
	# Förstörd stad: mörkare modeller
	var h = island.hall()
	var ruined: bool = h != null and h.ruined
	if ruined != _ruined:
		_ruined = ruined
		var mat: Material = Site3D.ruin_material() if ruined else Ship3D.solid_material()
		for n in _houses + _landmarks:
			if is_instance_valid(n):
				n.material_override = mat
	# Rök från några skorstenar
	_smoke_t -= real
	if _smoke_t <= 0.0 and Game.world and not ruined:
		_smoke_t = randf_range(0.6, 1.3) / (1.0 + level * 0.25)
		var src := Vector3(0, 24, 0)
		if _houses.size() > 0:
			var hn: Node3D = _houses[randi() % _houses.size()]
			src = hn.position + Vector3(0, 16, 0)
		var wp: Vector3 = position + src * S
		Game.world.fx.smoke(Vector2(wp.x, wp.z * Y_SQUASH - wp.y * 0.69), 1)


func _add_house(style: int, rise: bool) -> void:
	var idx := _houses.size()
	var spot: Vector3 = _spots[idx]
	var yaw := _angle + (PI * 0.5 if _rng.randf() < 0.25 else 0.0) + _rng.randf_range(-0.06, 0.06)
	var mi := _mi(house_mesh(style, _rng.randi() % 6), spot, yaw, rise, (idx % 4) * 0.15)
	_houses.append(mi)
	_house_style.append(style)


func _set_level(lv: int, instant: bool) -> void:
	var grew := lv > level
	level = lv
	for n in _landmarks:
		if is_instance_valid(n):
			n.queue_free()
	_landmarks.clear()
	var style := _style_for(lv)
	# Staden krympte (erövrad eller skadad): ta bort hus
	while _houses.size() > HOUSES[lv - 1]:
		var last: Node3D = _houses.pop_back()
		_house_style.pop_back()
		last.queue_free()
	# Äldre hus byggs om i stadens nya stil
	if grew and not instant:
		for idx in _houses.size():
			if _house_style[idx] < style and _rng.randf() < 0.6:
				var old: MeshInstance3D = _houses[idx]
				old.mesh = house_mesh(style, _rng.randi() % 6)
				old.scale = Vector3(1, 0.01, 1)
				_rises.append([old, -0.1 * (idx % 5)])
				_house_style[idx] = style
	while _houses.size() < mini(HOUSES[lv - 1], _spots.size()):
		_add_house(style if lv >= 2 else _style_for(2), not instant)
	if island.guardians:
		_landmarks.append(_mi(_ancient_mesh(), Vector3.ZERO, _angle, not instant))
		return
	var plaza := Basis(Vector3.UP, _angle) * PLAZA
	match lv:
		1:
			_landmarks.append(_mi(_outpost_mesh(), Vector3.ZERO, _angle, not instant))
		2:
			_landmarks.append(_mi(_church_mesh(0), Vector3.ZERO, _angle, not instant))
		3:
			_landmarks.append(_mi(_church_mesh(1), Vector3.ZERO, _angle, not instant))
			_landmarks.append(_mi(_well_mesh(), plaza, _angle, not instant, 0.2))
		4:
			_landmarks.append(_mi(_church_mesh(2), Vector3.ZERO, _angle, not instant))
			_landmarks.append(_mi(_well_mesh(), plaza, _angle, not instant, 0.2))
			_landmarks.append(_mi(_walls_mesh(136.0, 8, false), Vector3.ZERO, _angle, not instant, 0.3))
		5:
			_landmarks.append(_mi(_palace_mesh(), Vector3.ZERO, _angle, not instant))
			_landmarks.append(_mi(_church_mesh(1), plaza, _angle, not instant, 0.2))
			_landmarks.append(_mi(_walls_mesh(146.0, 6, true), Vector3.ZERO, _angle, not instant, 0.4))


# ------------------------------------------------------------------ Landmärken
func _outpost_mesh() -> ArrayMesh:
	var k := Kit.new()
	var logc := Color(0.45, 0.32, 0.2)
	var n := 40
	for i in n:
		var a := TAU * i / n
		if absf(angle_difference(a, PI * 0.5)) < 0.25:
			continue  # porten mot betraktaren
		var p := Vector3(cos(a) * 40.0, 0, sin(a) * 40.0)
		var rp := Basis(Vector3.UP, _angle) * p
		if not _on_land(rp, island.poly) or _local2d(rp).distance_to(island.harbor_pos - island.harbor_out * 26.0) < 62.0:
			continue
		k.cylinder(p, p + Vector3(0, 11.0 + (i % 3), 0), 2.4, logc.darkened(0.08 * (i % 2)), 5, 1.5)
	var canvas := Color(0.9, 0.86, 0.74)
	for t in [Vector3(-14, 0, -8), Vector3(10, 0, -14), Vector3(12, 0, 10)]:
		k.gable(t, 11, 9, 8.0, canvas, 0.4)
	k.cylinder(Vector3(-4, 0, 6), Vector3(-4, 1.5, 6), 3.0, Color(0.3, 0.28, 0.26), 7)  # eldstad
	# Utkikstorn
	var tw := Vector3(-20, 0, 16)
	for c in [Vector3(-3.5, 0, -3.5), Vector3(3.5, 0, -3.5), Vector3(3.5, 0, 3.5), Vector3(-3.5, 0, 3.5)]:
		k.cylinder(tw + c, tw + c + Vector3(0, 26, 0), 0.9, logc, 4)
	k.box(tw + Vector3(0, 26, 0), Vector3(11, 2, 11), logc.lightened(0.1))
	k.pyramid(tw + Vector3(0, 27, 0), 12, 12, 6, Color(0.7, 0.6, 0.35))
	return k.commit()


func _church_mesh(kind: int) -> ArrayMesh:
	var k := Kit.new()
	var wall := Color(0.62, 0.47, 0.3) if kind == 0 else Color(0.94, 0.92, 0.86)
	var roof := Color(0.74, 0.62, 0.34) if kind == 0 else Color(0.66, 0.3, 0.18)
	var s: float = [1.0, 1.3, 1.6][kind]
	var w := 26.0 * s
	var d := 14.0 * s
	var h := 12.0 * s
	k.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	k.gable(Vector3(0, h, 0), w, d, 8.0 * s, roof, 1.5)
	# Portal mot betraktaren
	k.quad(Vector3(-2.5 * s, 0, d * 0.5 + 0.2), Vector3(2.5 * s, 0, d * 0.5 + 0.2), Vector3(2.5 * s, 7 * s, d * 0.5 + 0.2), Vector3(-2.5 * s, 7 * s, d * 0.5 + 0.2), Color(0.3, 0.2, 0.12), Vector3(0, h * 0.5, 0))
	var towers := 2 if kind == 2 else 1
	for ti in towers:
		var tx := -w * 0.5 - 3.5 * s
		var tz := 0.0 if towers == 1 else (ti - 0.5) * d * 0.9
		var th := h * 2.1
		k.box(Vector3(tx, th * 0.5, tz), Vector3(7.0 * s, th, 7.0 * s), wall.darkened(0.03))
		k.pyramid(Vector3(tx, th, tz), 8.0 * s, 8.0 * s, 9.0 * s, roof.darkened(0.1))
	if kind == 2:
		k.dome(Vector3(w * 0.25, h + 2.0, 0), 6.0 * s, Color(0.35, 0.6, 0.6), 8, 3)
	return k.commit()


func _well_mesh() -> ArrayMesh:
	var k := Kit.new()
	k.cylinder(Vector3.ZERO, Vector3(0, 3, 0), 4.5, Color(0.75, 0.72, 0.66), 8)
	k.cylinder(Vector3(0, 3, 0), Vector3(0, 3.2, 0), 3.6, Color(0.35, 0.6, 0.7), 8)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		k.dome(Vector3(cos(a) * 12.0, 0, sin(a) * 12.0), 3.4, Color(0.3, 0.55, 0.22), 6, 2, true, 0.9, 0.15, i)
	return k.commit()


func _palace_mesh() -> ArrayMesh:
	var k := Kit.new()
	var wall := Color(0.93, 0.9, 0.82)
	var teal := Color(0.32, 0.6, 0.6)
	k.box(Vector3(0, 10, 0), Vector3(50, 20, 34), wall)
	k.box(Vector3(0, 20.5, 0), Vector3(52, 1.6, 36), Color(0.8, 0.76, 0.68))
	k.dome(Vector3(0, 21, 0), 11.0, teal, 10, 4)
	k.cylinder(Vector3(0, 32, 0), Vector3(0, 37, 0), 1.0, Color(0.85, 0.7, 0.3), 5)
	for c in [Vector3(-25, 0, -17), Vector3(25, 0, -17), Vector3(25, 0, 17), Vector3(-25, 0, 17)]:
		k.box(c + Vector3(0, 13, 0), Vector3(8, 26, 8), wall.darkened(0.05))
		k.dome(c + Vector3(0, 26, 0), 4.5, teal, 8, 3)
	# Pelargång mot betraktaren
	for i in 6:
		var x := -15.0 + i * 6.0
		k.cylinder(Vector3(x, 0, 19), Vector3(x, 14, 19), 1.0, Color(0.97, 0.95, 0.9), 6)
	k.box(Vector3(0, 14.5, 19), Vector3(34, 1.4, 4), wall)
	return k.commit()


## Stenmur runt staden med bastioner i hörnen (stjärnfort på högsta nivån).
## Murbitar som skulle hamna i havet hoppas över.
func _walls_mesh(r: float, corners: int, star: bool) -> ArrayMesh:
	var k := Kit.new()
	var stone := Color(0.74, 0.7, 0.62)
	var rot := Basis(Vector3.UP, _angle)
	var pts: Array = []
	for i in corners:
		var a := TAU * i / corners + PI / corners
		pts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for i in corners:
		var a: Vector3 = pts[i]
		var bpt: Vector3 = pts[(i + 1) % corners]
		var mid := (a + bpt) * 0.5
		if not _on_land(rot * a, island.poly) or not _on_land(rot * bpt, island.poly) or not _on_land(rot * mid, island.poly):
			continue
		var dir := bpt - a
		var seg_len := dir.length()
		k.xform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), mid)
		if absf(angle_difference(atan2(mid.z, mid.x), PI * 0.5)) < PI / corners + 0.01:
			# Port mot betraktaren
			k.box(Vector3(-seg_len * 0.3, 5, 0), Vector3(seg_len * 0.4, 10, 5), stone)
			k.box(Vector3(seg_len * 0.3, 5, 0), Vector3(seg_len * 0.4, 10, 5), stone)
			k.box(Vector3(-seg_len * 0.1 - 2.0, 7, 0), Vector3(4, 14, 7), stone.darkened(0.08))
			k.box(Vector3(seg_len * 0.1 + 2.0, 7, 0), Vector3(4, 14, 7), stone.darkened(0.08))
		else:
			k.box(Vector3(0, 5, 0), Vector3(seg_len, 10, 5), stone)
		k.xform = Transform3D.IDENTITY
	for p in pts:
		if not _on_land(rot * p, island.poly):
			continue
		var bs := 15.0 if star else 11.0
		var out: Vector3 = p.normalized() * (bs * 0.55 if star else 0.0)
		k.xform = Transform3D(Basis(Vector3.UP, atan2(-p.z, p.x) + PI * 0.25), p + out)
		k.box(Vector3(0, 6, 0), Vector3(bs, 12, bs), stone.darkened(0.05))
		k.xform = Transform3D.IDENTITY
	return k.commit()


func _ancient_mesh() -> ArrayMesh:
	var k := Kit.new()
	var stone := Color(0.86, 0.84, 0.76)
	for pyr in [[Vector3(0, 0, 0), 56.0], [Vector3(-52, 0, 28), 32.0], [Vector3(48, 0, 32), 28.0]]:
		var c: Vector3 = pyr[0]
		var s: float = pyr[1]
		var y := 0.0
		for tier in 4:
			var w := s * (1.0 - tier * 0.22)
			k.box(c + Vector3(0, y + s * 0.08, 0), Vector3(w, s * 0.16, w), stone.darkened(0.04 * tier))
			y += s * 0.16
		k.box(c + Vector3(0, y + s * 0.06, 0), Vector3(s * 0.25, s * 0.12, s * 0.25), stone.lightened(0.05))
	var crystal := Color(0.4, 0.95, 1.0)
	for cp in [Vector3(-20, 0, -30), Vector3(25, 0, -28), Vector3(-30, 0, 5), Vector3(32, 0, 0)]:
		for j in 3:
			k.cone(cp + Vector3(j * 3.0 - 3.0, 0, (j % 2) * 3.0), 2.5, 10.0 + j * 4.0, crystal, 4)
	return k.commit()
