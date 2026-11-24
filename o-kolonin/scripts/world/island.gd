extends Node2D
## En ö: form, karibiskt utseende, ägare, garnison, byggplatser och byggnader.
## Världen är sedd snett uppifrån, därför är öarna tillplattade på höjden.

const BuildingScript = preload("res://scripts/world/building.gd")
const PalmScript = preload("res://scripts/world/palm.gd")
const Y_SQUASH := 0.72
const SLOT_SPACING := 72.0

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
var slots: Array = []        # lokala positioner (Vector2)
var slot_coastal: Array = []  # bool per plats
var slot_used: Array = []     # byggnad eller null
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
	_build_slots()
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


func _build_slots() -> void:
	var inner := _largest(Geometry2D.offset_polygon(poly, -48.0))
	var coast_near := _largest(Geometry2D.offset_polygon(poly, -105.0))
	var x := -radius
	while x <= radius:
		var y := -radius
		while y <= radius:
			var p := Vector2(x, y * Y_SQUASH * 0.95)
			if Geometry2D.is_point_in_polygon(p, inner):
				if volcano and p.distance_to(Vector2(radius * 0.05, -radius * 0.12)) < radius * 0.38:
					y += SLOT_SPACING
					continue
				slots.append(p)
				slot_coastal.append(not Geometry2D.is_point_in_polygon(p, coast_near))
				slot_used.append(null)
			y += SLOT_SPACING
		x += SLOT_SPACING


func _build_decor() -> void:
	# Gräsfläckar för variation
	for i in int(radius / 12):
		var p := _random_point_in(grass)
		patches.append({"p": p, "r": _rng.randf_range(14, 34), "c": _rng.randf_range(-0.06, 0.06)})
	# Resursdekorationer
	for d in deposits:
		if d in ["tra", "mat"]:
			continue
		var count := 3 if d != "kristaller" else 4
		for i in count:
			var p := _random_point_in(grass)
			if d == "parlor":
				p = _random_beach_point()
			var ok := true
			for s in slots:
				if s.distance_to(p) < 26:
					ok = false
			if ok:
				decos.append({"type": d, "p": p, "s": _rng.randf_range(0.8, 1.25)})
	# Palmer – inte på byggplatserna
	var tries := int(radius * 0.2)
	for i in tries:
		var p := _random_point_in(grass)
		if _rng.randf() < 0.35:
			p = _random_beach_point()
		var near := false
		for s in slots:
			if s.distance_to(p) < 40:
				near = true
				break
		if near and _rng.randf() < 0.9:
			continue
		var palm := PalmScript.new()
		palm.position = position + p
		palm.seed_value = _rng.randi()
		palm.dark = dark
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
	var g := 0.0
	for b in buildings:
		if b.built:
			g += Data.BUILDINGS[b.type].get("garrison", 0)
	if owner_id == "vaktarna":
		g += 80.0
	g += 10.0
	return g * Game.mod(owner_id, "garrison")


func free_slot_count() -> int:
	var n := 0
	for s in slot_used:
		if s == null:
			n += 1
	return n


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


func can_build_type(type: String) -> bool:
	var def: Dictionary = Data.BUILDINGS[type]
	if def.has("deposit") and not deposits.has(def["deposit"]):
		return false
	return _pick_slot(type) >= 0


func _pick_slot(type: String) -> int:
	var def: Dictionary = Data.BUILDINGS[type]
	var coastal: bool = def.get("coastal", false)
	var best := -1
	var best_score := INF
	for i in slots.size():
		if slot_used[i] != null:
			continue
		var s: Vector2 = slots[i]
		var score := s.length()
		if coastal:
			if not slot_coastal[i]:
				continue
			score = -s.length()
		score += _rng.randf() * 30.0
		if score < best_score:
			best_score = score
			best = i
	return best


func add_building(type: String, instant: bool = false):
	var i := _pick_slot(type)
	if i < 0:
		return null
	var b := BuildingScript.new()
	b.type = type
	b.island = self
	b.owner_id = owner_id
	b.slot_index = i
	b.position = position + slots[i]
	if instant:
		b.progress = 1.0
		b.built = true
	slot_used[i] = b
	buildings.append(b)
	objects_layer.add_child(b)
	# Rensa palmer som står i vägen
	for palm in palms.duplicate():
		if is_instance_valid(palm) and palm.position.distance_to(b.position) < 58.0:
			palms.erase(palm)
			palm.queue_free()
	return b


func remove_building(b) -> void:
	buildings.erase(b)
	if b.slot_index >= 0 and b.slot_index < slot_used.size():
		slot_used[b.slot_index] = null
	if is_instance_valid(b):
		b.queue_free()


func set_owner_id(new_owner: String) -> void:
	owner_id = new_owner
	for b in buildings:
		b.owner_id = new_owner
		b.queue_redraw()
	queue_redraw()


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
