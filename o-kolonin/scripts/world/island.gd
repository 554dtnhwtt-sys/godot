extends Node2D
## En ö: form, karibiskt utseende, ägare, garnison, byggplatser och byggnader.
## Världen är sedd snett uppifrån, därför är öarna tillplattade på höjden.

const BuildingScript = preload("res://scripts/world/building.gd")
const PalmScript = preload("res://scripts/world/palm.gd")
const Y_SQUASH := 0.72

var id := ""
var display_name := ""
var radius := 200.0
var deposits: Array = []
var owner_id := "neutral"
var home_of := ""
var garrison := 0.0
var volcano := false
var dark := false
var guardians := false
var trade_until := -1.0
var ship_queue: Array = []  # [{"type", "left"}] på skeppsvarvet
var store := {}            # öns eget lager: vara -> mängd
var rates := {}            # förändring per dag (för gränssnittet)
var population := 0.0
var governor := false      # guvernören bygger automatiskt
var governor_focus := "balans"
var starving := false
var famine_warned := -999.0
var last_attacked := -999.0
var selected := false
var world = null
var objects_layer: Node2D = null

var poly_side := PackedVector2Array()
var grass_side := PackedVector2Array()
var wet := PackedVector2Array()
var foam_rings: Array = []  # förberäknade skumlinjer för vågornas animation
var poly := PackedVector2Array()
var block_poly := PackedVector2Array()
var grass := PackedVector2Array()
var shallow1 := PackedVector2Array()
var shallow2 := PackedVector2Array()
var foam := PackedVector2Array()
# Färdigplanerad stad och resursplatser (lokala koordinater)
var town_center := Vector2.ZERO
var harbor_dir := Vector2.RIGHT
var town_level := 0
var town_upgrade_left := 0.0
var plots: Array = []   # {"kind": typ eller "house"/"hall"/"plaza"/"tower", "pos": Vector2, "b": byggnad}
var sites: Array = []   # {"res": resurs, "pos": Vector2, "b": byggnad}
var hover_site := -1
var buildings: Array = []
var palms: Array = []
var decos: Array = []
var patches: Array = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(def: Dictionary, p_world, p_objects: Node2D) -> void:
	world = p_world
	objects_layer = p_objects
	id = def["id"]
	display_name = def["name"]
	radius = def["r"]
	deposits = def["deposits"].duplicate()
	position = def["pos"]
	volcano = def.get("volcano", false)
	dark = def.get("dark", false)
	guardians = def.get("guardians", false)
	home_of = def.get("home", "")
	_rng.seed = hash(id)
	_build_shape()
	_build_layout()
	_build_decor()
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for p in polys:
		var a := _area(p)
		if a > best_area:
			best_area = a
			best = p
	return best


func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return absf(a) * 0.5


func _build_shape() -> void:
	var n := 56
	var ph := [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	for i in n:
		var a := TAU * i / n
		var rr: float = radius * (1.0 + 0.13 * sin(2.0 * a + ph[0]) + 0.08 * sin(3.0 * a + ph[1]) + 0.05 * sin(5.0 * a + ph[2]) + 0.03 * sin(9.0 * a + ph[3]) + _rng.randf_range(-0.015, 0.015))
		poly.append(Vector2(cos(a) * rr, sin(a) * rr * Y_SQUASH))
	grass = _largest(Geometry2D.offset_polygon(poly, -30.0))
	shallow1 = _largest(Geometry2D.offset_polygon(poly, 55.0))
	shallow2 = _largest(Geometry2D.offset_polygon(poly, 120.0))
	foam = _largest(Geometry2D.offset_polygon(poly, 12.0))
	foam.append(foam[0])
	block_poly = _largest(Geometry2D.offset_polygon(poly, 34.0))
	wet = _largest(Geometry2D.offset_polygon(poly, 6.0))
	for k in 12:
		var ring := _largest(Geometry2D.offset_polygon(poly, 26.0 - k * 1.5))
		if ring.size() > 2:
			ring.append(ring[0])
		foam_rings.append(ring)
	for p in poly:
		poly_side.append(p + Vector2(0, 18))
	for p in grass:
		grass_side.append(p + Vector2(0, 6))


func _sq(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * Y_SQUASH)


func _volcano_center() -> Vector2:
	return Vector2(radius * 0.05, -radius * 0.12)


func _inside(p: Vector2, area: PackedVector2Array) -> Vector2:
	var q := p
	for i in 30:
		if Geometry2D.is_point_in_polygon(q, area):
			return q
		q = q * 0.9
	return q


## Punkt på kusten i en viss riktning, flyttad lite inåt land.
func _coast_at(dir: Vector2, inset: float) -> Vector2:
	var best := poly[0]
	var bd := -INF
	for p in poly:
		var d := Vector2(p.x, p.y / Y_SQUASH).normalized().dot(dir)
		if d > bd:
			bd = d
			best = p
	return best.move_toward(Vector2.ZERO, inset)


func _free_spot(p: Vector2, min_d: float) -> bool:
	for pl in plots:
		if pl["pos"].distance_to(p) < min_d:
			return false
	return true


## Stadsplan: rådhus i mitten, hamn mot havet, särskilda platser och hus i ringar.
func _build_layout() -> void:
	var to_center := Data.WORLD_SIZE * 0.5 - position
	harbor_dir = to_center.normalized() if to_center.length() > 50.0 else Vector2(1, 0.3).normalized()
	var inner := _largest(Geometry2D.offset_polygon(poly, -62.0))
	var c := _inside(_sq(harbor_dir) * radius * 0.26, inner)
	if volcano and c.distance_to(_volcano_center()) < radius * 0.5:
		c = _inside(_volcano_center() + _sq(harbor_dir) * radius * 0.55, inner)
	town_center = c
	var side := harbor_dir.orthogonal()
	var harbor := _coast_at(harbor_dir, 28.0)
	plots.append({"kind": "hall", "pos": c, "b": null})
	plots.append({"kind": "skeppsvarv", "pos": harbor, "b": null})
	plots.append({"kind": "lagerhus", "pos": _inside(c.lerp(harbor, 0.55) + _sq(side) * 62.0, inner), "b": null})
	plots.append({"kind": "marknad", "pos": _inside(c + _sq(side * 100.0 + harbor_dir * 25.0), inner), "b": null})
	plots.append({"kind": "akademi", "pos": _inside(c + _sq(-side * 105.0 - harbor_dir * 10.0), inner), "b": null})
	plots.append({"kind": "plaza", "pos": _inside(c + _sq(harbor_dir * 72.0 - side * 18.0), inner), "b": null})
	plots.append({"kind": "romdestilleri", "pos": _inside(c + _sq(harbor_dir.rotated(2.1) * 180.0), inner), "b": null})
	plots.append({"kind": "glasbruk", "pos": _inside(c + _sq(harbor_dir.rotated(-2.1) * 180.0), inner), "b": null})
	plots.append({"kind": "kanonbatteri", "pos": _coast_at(harbor_dir.rotated(0.75), 26.0), "b": null})
	plots.append({"kind": "kanonbatteri", "pos": _coast_at(harbor_dir.rotated(-0.75), 26.0), "b": null})
	# Fyren på udden längst bort från staden
	var far := poly[0]
	for p in poly:
		if p.distance_to(c) > far.distance_to(c):
			far = p
	plots.append({"kind": "fyrtorn", "pos": far.move_toward(Vector2.ZERO, 24.0), "b": null})
	plots.append({"kind": "tower", "pos": _inside(c + _sq(side * 210.0 - harbor_dir * 40.0), inner), "b": null})
	plots.append({"kind": "tower", "pos": _inside(c + _sq(-side * 210.0 - harbor_dir * 40.0), inner), "b": null})
	_build_sites(inner)
	# Hus i ringar runt rådhuset
	var houses := 0
	for ring in [78.0, 124.0, 170.0, 216.0, 262.0]:
		var n := int(TAU * ring / 66.0)
		var off := _rng.randf() * TAU
		for k in n:
			if houses >= 22:
				break
			var a := off + TAU * k / n
			var p := c + _sq(Vector2.from_angle(a) * ring)
			if not Geometry2D.is_point_in_polygon(p, inner):
				continue
			if volcano and p.distance_to(_volcano_center()) < radius * 0.42:
				continue
			if not _free_spot(p, 54.0):
				continue
			var near_site := false
			for st in sites:
				if st["pos"].distance_to(p) < 72.0:
					near_site = true
			if near_site:
				continue
			plots.append({"kind": "house", "pos": p, "b": null})
			houses += 1


## Resursplatser: skog, kokospalmer, fiskevatten och öns fyndigheter.
func _build_sites(inner: PackedVector2Array) -> void:
	var want: Array = []
	for d in deposits:
		var n := 1
		if d == "tra":
			n = 3 if radius > 300.0 else 2
		elif d == "mat":
			n = 2
		elif d == "sten" and radius > 300.0:
			n = 2
		for i in n:
			want.append(d)
	want.append("fisk")
	if radius > 280.0:
		want.append("fisk")
	var area := _largest(Geometry2D.offset_polygon(poly, -48.0))
	for res in want:
		var coastal: bool = res in ["fisk", "parlor"]
		for attempt in 160:
			# Lätta på kraven om ön är trång
			var k := 1.0 - 0.45 * (attempt / 160.0)
			var p := _random_beach_point() if coastal else _random_point_in(area)
			if p.distance_to(town_center) < (140.0 if coastal else 165.0) * k:
				continue
			if not _free_spot(p, 70.0 * k):
				continue
			var clash := false
			for st in sites:
				if st["pos"].distance_to(p) < 100.0 * k:
					clash = true
			if clash:
				continue
			if volcano and p.distance_to(_volcano_center()) < radius * 0.42:
				continue
			sites.append({"res": res, "pos": p, "b": null})
			break


func _build_decor() -> void:
	# Gräsfläckar för variation
	for i in int(radius / 12):
		var p := _random_point_in(grass)
		patches.append({"p": p, "r": _rng.randf_range(14, 34), "c": _rng.randf_range(-0.06, 0.06)})
	# Resursplatsernas utseende: skogsdungar, palmlundar och fyndigheter
	for st in sites:
		var res: String = st["res"]
		var sp: Vector2 = st["pos"]
		if res == "tra" or res == "mat":
			for k in 4:
				var a := TAU * k / 4.0 + _rng.randf() * 0.6
				_add_palm(sp + _sq(Vector2.from_angle(a) * _rng.randf_range(34, 54)), 1 if res == "mat" else 0)
		elif res != "fisk":
			for k in 2:
				var a := (PI * 0.2 if k == 0 else PI * 1.1) + _rng.randf() * 0.5
				decos.append({"type": res, "p": sp + _sq(Vector2.from_angle(a) * 38.0), "s": _rng.randf_range(0.75, 1.0)})
	# Palmer utanför staden och resursplatserna
	var tries := int(radius * 0.22)
	for i in tries:
		var p := _random_point_in(grass)
		if _rng.randf() < 0.4:
			p = _random_beach_point()
		if p.distance_to(town_center) < 230.0 or not _free_spot(p, 60.0):
			continue
		var near := false
		for st in sites:
			if st["pos"].distance_to(p) < 70.0:
				near = true
		if near:
			continue
		_add_palm(p, 0)


func _add_palm(p: Vector2, variant: int) -> void:
	var palm := PalmScript.new()
	palm.position = position + p
	palm.seed_value = _rng.randi()
	palm.dark = dark
	if variant > 0:
		palm.force_variant = variant
	objects_layer.add_child(palm)
	palms.append(palm)


func _random_point_in(p: PackedVector2Array) -> Vector2:
	for i in 40:
		var v := Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * Y_SQUASH)
		if Geometry2D.is_point_in_polygon(v, p):
			return v
	return Vector2.ZERO


func _random_beach_point() -> Vector2:
	var i := _rng.randi() % poly.size()
	return poly[i].lerp(Vector2.ZERO, _rng.randf_range(0.1, 0.2))


# ------------------------------------------------------------------ Logik
func contains_world_point(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p - position, poly)


func blocks(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p - position, block_poly)


func coast_point_towards(from: Vector2, extra: float = 70.0) -> Vector2:
	var dir := (from - position)
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var r := radius
	var p := position + Vector2(dir.x * r, dir.y * r * Y_SQUASH)
	return p + dir * (extra + 30.0)


func approach_radius() -> float:
	return radius + 110.0


func max_garrison() -> float:
	if owner_id == "neutral":
		return 0.0
	var g := 10.0
	if town_level > 0:
		g = Data.TOWN_LEVELS[town_level - 1]["garrison"]
	for b in buildings:
		if b.built:
			g += Data.BUILDINGS[b.type].get("garrison", 0)
	if owner_id == "vaktarna":
		g += 80.0
	return g * Game.mod(owner_id, "garrison")


func has_shipyard() -> bool:
	for b in buildings:
		if b.built and Data.BUILDINGS[b.type].get("shipyard", false):
			return true
	return false


func shipyard_building():
	for b in buildings:
		if b.built and Data.BUILDINGS[b.type].get("shipyard", false):
			return b
	return null


# ------------------------------------------------------------------ Stad och resursplatser
static func is_resource_type(type: String) -> bool:
	for k in Data.SITES:
		if Data.SITES[k]["building"] == type:
			return true
	return false


static func site_res_for(type: String) -> String:
	for k in Data.SITES:
		if Data.SITES[k]["building"] == type:
			return k
	return ""


func free_site(res: String) -> int:
	for i in sites.size():
		if sites[i]["res"] == res and sites[i]["b"] == null:
			return i
	return -1


func free_plot(kind: String) -> int:
	for i in plots.size():
		if plots[i]["kind"] == kind and plots[i]["b"] == null:
			return i
	return -1


func free_slot_count() -> int:
	var n := 0
	for st in sites:
		if st["b"] == null:
			n += 1
	return n


func can_build_type(type: String) -> bool:
	if is_resource_type(type):
		return free_site(site_res_for(type)) >= 0
	if not Data.TOWN_REQ.has(type):
		return false
	return town_level >= Data.TOWN_REQ[type] and free_plot(type) >= 0


func _spawn(type: String, local_pos: Vector2, instant: bool, variant: String = "", delay: float = 0.0):
	var b := BuildingScript.new()
	b.type = type
	b.variant = variant
	b.island = self
	b.owner_id = owner_id
	b.position = position + local_pos
	b.delay = delay
	if instant:
		b.progress = 1.0
		b.built = true
	buildings.append(b)
	objects_layer.add_child(b)
	# Rensa palmer som står i vägen
	var clear := 30.0 if type == "skogshuggare" or type == "kokosodling" else 46.0
	for palm in palms.duplicate():
		if is_instance_valid(palm) and palm.position.distance_to(b.position) < clear:
			palms.erase(palm)
			palm.queue_free()
	return b


## Bygger en byggnad: resursbyggnader på en ledig resursplats, stadsbyggnader på sin plats i staden.
func add_building(type: String, instant: bool = false):
	if is_resource_type(type):
		var i := free_site(site_res_for(type))
		return build_site(i, instant) if i >= 0 else null
	var pi := free_plot(type)
	if pi < 0:
		return null
	var b = _spawn(type, plots[pi]["pos"], instant)
	plots[pi]["b"] = b
	return b


func build_site(i: int, instant: bool = false):
	if i < 0 or i >= sites.size() or sites[i]["b"] != null:
		return null
	var type: String = Data.SITES[sites[i]["res"]]["building"]
	var b = _spawn(type, sites[i]["pos"], instant)
	b.site_index = i
	sites[i]["b"] = b
	return b


func hall():
	for pl in plots:
		if pl["kind"] == "hall" and pl["b"] != null:
			return pl["b"]
	return null


## Sätter stadens nivå. Staden växer av sig själv: nytt rådhus, fler hus, torg och torn.
func set_town_level(lv: int, instant: bool) -> void:
	town_level = clampi(lv, 0, Data.TOWN_LEVELS.size())
	if town_level == 0:
		return
	var td: Dictionary = Data.TOWN_LEVELS[town_level - 1]
	var h = hall()
	if h == null:
		var pi := free_plot("hall")
		h = _spawn("radhus", plots[pi]["pos"], instant, td["hall"])
		plots[pi]["b"] = h
	elif h.variant != td["hall"]:
		h.change_variant(td["hall"], instant)
	# Nya hus byggs ett i taget, inifrån och ut
	var tiers: Array = Data.HOUSE_TIERS[td["tier"]]
	var have := 0
	for pl in plots:
		if pl["kind"] == "house" and pl["b"] != null:
			have += 1
	var k := 0
	for pl in plots:
		if have >= td["houses"]:
			break
		if pl["kind"] == "house" and pl["b"] == null:
			pl["b"] = _spawn("hus", pl["pos"], instant, tiers[_rng.randi() % tiers.size()], 0.0 if instant else k * 1.6)
			have += 1
			k += 1
	# Gamla hus byggs om i finare stil
	if not instant:
		for pl in plots:
			var b = pl["b"]
			if pl["kind"] == "house" and b != null and not b.variant in tiers and _rng.randf() < 0.45:
				b.change_variant(tiers[_rng.randi() % tiers.size()], false, k * 1.2)
				k += 1
	if town_level >= 3:
		var pi := free_plot("plaza")
		if pi >= 0:
			plots[pi]["b"] = _spawn("dekor", plots[pi]["pos"], instant, "plaza")
	if town_level >= 4:
		for n in 2:
			var pi := free_plot("tower")
			if pi >= 0:
				plots[pi]["b"] = _spawn("dekor", plots[pi]["pos"], instant, "tower", 0.0 if instant else 2.0 + n)


func upgrade_cost(nation: String) -> Dictionary:
	if town_level <= 0 or town_level >= Data.TOWN_LEVELS.size():
		return {}
	var base: Dictionary = Data.TOWN_LEVELS[town_level]["cost"]
	var out := {}
	for r in base:
		out[r] = ceilf(base[r] * Game.mod(nation, "build_cost"))
	return out


func start_town_upgrade() -> void:
	town_upgrade_left = Data.TOWN_LEVELS[town_level]["time"]
	var h = hall()
	if h != null:
		h.begin_upgrade(town_upgrade_left)


func site_at(world_pos: Vector2) -> int:
	var lp := world_pos - position
	for i in sites.size():
		if (sites[i]["pos"] + Vector2(0, -14)).distance_to(lp) < 42.0:
			return i
	return -1


func remove_building(b) -> void:
	buildings.erase(b)
	for pl in plots:
		if pl["b"] == b:
			pl["b"] = null
	for st in sites:
		if st["b"] == b:
			st["b"] = null
	if is_instance_valid(b):
		b.queue_free()


func set_owner_id(new_owner: String) -> void:
	owner_id = new_owner
	population *= 0.5
	governor = false
	for b in buildings:
		b.owner_id = new_owner
		b.queue_redraw()
	queue_redraw()


# ------------------------------------------------------------------ Lager och befolkning
func capacity() -> float:
	var c := Data.STORAGE_HOME if home_of != "" and home_of == owner_id else Data.STORAGE_BASE
	if town_level > 0:
		c += Data.TOWN_LEVELS[town_level - 1]["storage"]
	for b in buildings:
		if b.is_active():
			c += Data.BUILDINGS[b.type].get("storage", 0.0)
	return c


## Lägger till (eller drar av) en vara. Returnerar hur mycket som faktiskt ändrades.
func add_good(r: String, amount: float) -> float:
	var cur: float = store.get(r, 0.0)
	var nv := clampf(cur + amount, 0.0, maxf(capacity(), cur))
	store[r] = nv
	return nv - cur


func good(r: String) -> float:
	return store.get(r, 0.0)


func housing() -> float:
	if town_level <= 0:
		return 0.0
	return Data.TOWN_LEVELS[town_level - 1]["housing"]


func workers_needed() -> float:
	var w := 0.0
	for b in buildings:
		if b.is_active():
			w += Data.BUILDINGS[b.type].get("workers", 0.0) * Data.RES_LEVEL_WORKERS[b.level - 1]
	return w


func work_efficiency() -> float:
	var need := workers_needed()
	if need <= 0.0:
		return 1.0
	return clampf(population / need, 0.0, 1.0)


func trade_connected() -> bool:
	return Game.time < trade_until


# ------------------------------------------------------------------ Rita
func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _uvs(pts: PackedVector2Array, scale_f: float = 1.0 / 260.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append((p + Vector2(radius, radius)) * scale_f)
	return out


func _tex_poly(pts: PackedVector2Array, tex: Texture2D, col: Color) -> void:
	if tex == null:
		draw_colored_polygon(pts, col)
		return
	draw_polygon(pts, PackedColorArray([col]), _uvs(pts), tex)


func _draw() -> void:
	var shallow_c := Color(0.45, 0.93, 0.88) if not dark else Color(0.3, 0.6, 0.62)
	draw_colored_polygon(shallow2, Color(shallow_c, 0.14))
	draw_colored_polygon(shallow1, Color(shallow_c.lightened(0.2), 0.28))
	draw_colored_polygon(wet, Color(0.85, 0.8, 0.62, 0.55) if not dark else Color(0.3, 0.3, 0.3, 0.5))
	# Skum som rullar in mot stranden
	for k in 2:
		var ph := fmod(_t * 0.25 + k * 0.5 + radius * 0.001, 1.0)
		var ring: PackedVector2Array = foam_rings[mini(int(ph * foam_rings.size()), foam_rings.size() - 1)]
		if ring.size() > 2:
			draw_polyline(ring, Color(1, 1, 1, 0.42 * sin(ph * PI)), 2.5, true)
	var sand: Texture2D = Art.texture("sand")
	var grass_t: Texture2D = Art.texture("grass")
	var tint := Color(1, 1, 1) if not dark else Color(0.42, 0.4, 0.42)
	_tex_poly(poly_side, sand, Color(tint.r * 0.72, tint.g * 0.62, tint.b * 0.5))
	_tex_poly(poly, sand, tint)
	var gtint := Color(1, 1, 1) if not dark else Color(0.5, 0.58, 0.5)
	_tex_poly(grass_side, grass_t, Color(gtint.r * 0.55, gtint.g * 0.6, gtint.b * 0.5))
	_tex_poly(grass, grass_t, gtint)
	var edge := grass.duplicate()
	edge.append(grass[0])
	draw_polyline(edge, Color(0.75, 0.72, 0.45, 0.35) if not dark else Color(0.3, 0.3, 0.3, 0.3), 5.0, true)
	for pt in patches:
		var c := Color(1, 1, 0.8, 0.07) if pt["c"] > 0 else Color(0, 0.15, 0, 0.08)
		_draw_ellipse(pt["p"], pt["r"], pt["r"] * 0.6, c)
	_draw_town_ground()
	if volcano:
		_draw_volcano()
	for d in decos:
		_draw_deposit(d)
	# Ägarens gräns
	if owner_id != "neutral":
		var col := Data.nation_color(owner_id)
		col.a = 0.85
		var acc := Data.nation_accent(owner_id)
		for i in poly.size():
			if i % 2 == 0:
				var j := (i + 1) % poly.size()
				draw_line(poly[i] + Vector2(0, -2), poly[j] + Vector2(0, -2), col, 5.0, true)
				draw_line(poly[i] + Vector2(0, -2), poly[j] + Vector2(0, -2), Color(acc, 0.5), 1.5)
	if selected:
		var sel := poly.duplicate()
		sel.append(poly[0])
		draw_polyline(sel, Color(1, 0.95, 0.5, 0.6 + 0.3 * sin(_t * 5.0)), 3.0, true)
	_draw_label()


## Vägar från torget till byggnaderna, torgets stenläggning och invånare som går omkring.
func _path_pts(a: Vector2, b: Vector2) -> PackedVector2Array:
	var mid := (a + b) * 0.5
	var n := (b - a).orthogonal().normalized() * (b - a).length() * 0.12 * (1.0 if int(b.x) % 2 == 0 else -1.0)
	var out := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		out.append(a.lerp(mid + n, t).lerp((mid + n).lerp(b, t), t))
	return out


func _draw_town_ground() -> void:
	if town_level <= 0:
		return
	var dests: Array = []
	for b in buildings:
		if b.type == "hus" or b.type == "radhus" or b.type == "dekor" or b.delay > 0.0:
			continue
		dests.append(b.position - position)
	var road := Color(0.8, 0.68, 0.45, 0.55) if not dark else Color(0.35, 0.32, 0.3, 0.55)
	for d in dests:
		var pts := _path_pts(town_center, d)
		draw_polyline(pts, road, 10.0, true)
		draw_polyline(pts, road.lightened(0.18), 5.0, true)
	# Torget växer med staden
	var pr := 34.0 + town_level * 12.0
	_draw_ellipse(town_center + Vector2(0, 6), pr, pr * 0.55, Color(0.78, 0.74, 0.66, 0.55))
	_draw_ellipse(town_center + Vector2(0, 6), pr * 0.8, pr * 0.44, Color(0.86, 0.82, 0.74, 0.4))
	# Invånare som går mellan torget och byggnaderna
	if dests.is_empty() or owner_id == "neutral":
		return
	var n := clampi(int(population / 7.0), 1, 16)
	for i in n:
		var d: Vector2 = dests[i % dests.size()]
		var ph := fmod(_t * (0.05 + (i % 5) * 0.012) + i * 0.37, 2.0)
		var t := ph if ph < 1.0 else 2.0 - ph
		var pts := _path_pts(town_center, d)
		var f := t * 10.0
		var k := mini(int(f), 9)
		var pos: Vector2 = pts[k].lerp(pts[k + 1], f - k)
		var bob := absf(sin(_t * 8.0 + i)) * 1.5
		var cloth: Color = [Color(0.85, 0.3, 0.25), Color(0.25, 0.45, 0.8), Color(0.95, 0.85, 0.6), Color(0.35, 0.6, 0.3), Color(0.9, 0.9, 0.88)][i % 5]
		_draw_ellipse(pos + Vector2(2, 1), 3.5, 1.5, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(pos + Vector2(-2, -8 - bob), Vector2(4, 7)), cloth)
		draw_circle(pos + Vector2(0, -10 - bob), 2.2, Color(0.55, 0.38, 0.26))


func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	var top := -radius * Y_SQUASH - 58.0
	var fs := 22
	var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(-w * 0.5, top)
	if owner_id != "neutral":
		var col := Data.nation_color(owner_id)
		var rect := Rect2(pos + Vector2(-26, -22), Vector2(w + 36, 30))
		draw_rect(rect, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(rect.position, Vector2(16, rect.size.y)), col)
		draw_rect(Rect2(rect.position + Vector2(4, 6), Vector2(8, 8)), Data.nation_accent(owner_id))
		# Garnison: litet svärd + antal soldater
		var sp := pos + Vector2(4, 20)
		draw_line(sp + Vector2(0, 0), sp + Vector2(9, -9), Color(0.9, 0.9, 0.95), 2.0)
		draw_line(sp + Vector2(1, -5), sp + Vector2(5, -1), Color(0.8, 0.6, 0.3), 2.0)
		draw_string(font, pos + Vector2(16, 24), "%d" % int(garrison), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
		if trade_connected():
			var tp := pos + Vector2(w - 14, 18)
			draw_circle(tp, 6.0, Color(1, 0.85, 0.4))
			draw_circle(tp, 3.0, Color(0.6, 0.45, 0.15))
	draw_string(font, pos + Vector2(2, 2), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.98, 0.9))


func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_volcano() -> void:
	var c := Vector2(radius * 0.05, -radius * 0.12)
	var w := radius * 0.42
	var h := radius * 0.55
	var base_l := c + Vector2(-w, h * 0.35)
	var base_r := c + Vector2(w, h * 0.35)
	var top_l := c + Vector2(-w * 0.22, -h * 0.55)
	var top_r := c + Vector2(w * 0.22, -h * 0.55)
	draw_colored_polygon(PackedVector2Array([base_l, top_l, top_r, base_r]), Color(0.38, 0.3, 0.27))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, h * 0.35), top_r, base_r]), Color(0.3, 0.23, 0.21))
	_draw_ellipse(c + Vector2(0, -h * 0.55), w * 0.22, w * 0.07, Color(0.95, 0.4 + 0.15 * sin(_t * 2.0), 0.1))
	for i in 3:
		var k := fmod(_t * 0.25 + i / 3.0, 1.0)
		_draw_ellipse(c + Vector2(sin(_t + i) * 10.0 + k * 30.0, -h * 0.6 - k * 120.0), 14.0 + k * 30.0, 10.0 + k * 20.0, Color(0.5, 0.48, 0.48, 0.45 * (1.0 - k)))


func _draw_deposit(d: Dictionary) -> void:
	var p: Vector2 = d["p"]
	var s: float = d["s"]
	var tex: Texture2D = Art.deco(d["type"])
	if tex == null:
		return
	var w := 46.0 * s
	if d["type"] == "parlor":
		w = 34.0 * s
	var h := w * tex.get_height() / tex.get_width()
	draw_set_transform(p + Vector2(4, 2), 0.0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, w * 0.42, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO)
	if d["type"] == "kristaller":
		draw_circle(p + Vector2(0, -h * 0.4), w * 0.6, Color(0.5, 0.95, 1.0, 0.1 + 0.06 * sin(_t * 2.0 + p.x)))
	draw_texture_rect(tex, Rect2(p + Vector2(-w * 0.5, -h * 0.9), Vector2(w, h)), false)
