extends Sprite2D
## 3D-lagret: skepp, städer, resursbyggnader och palmer renderas i 3D i en egen
## SubViewport med genomskinlig bakgrund och läggs över den målade 2D-världen.
## En ortografisk kamera tittar snett ned (asin 0.72 ≈ 46°) så att 3D-marken
## hamnar exakt där 2D-världen är: 2D (x, y) motsvarar 3D (x, 0, y / 0.72).

const Ship3D = preload("res://scripts/world3d/ship3d.gd")
const Town3D = preload("res://scripts/world3d/town3d.gd")
const Site3D = preload("res://scripts/world3d/site3d.gd")
const Kit = preload("res://scripts/world3d/kit.gd")
const SOLID = preload("res://shaders/solid3d.gdshader")
const CATCHER = preload("res://shaders/shadow_catcher.gdshader")
const Y_SQUASH := 0.72
const AMBIENT := Color(0.66, 0.7, 0.78)
const AMBIENT_ENERGY := 0.7

var world = null
var vp: SubViewport
var cam3: Camera3D
var sun: DirectionalLight3D
var root3: Node3D
var _catcher: MeshInstance3D
var _ships := {}      # instance_id -> [skepp, modell]
var _towns := {}      # ö -> modell
var _sites := {}      # instance_id -> [byggnad, modell]
var _palms := {}      # instance_id -> [palm, modell]
var _palm_mat: ShaderMaterial
var _palm_meshes: Array = []
var _scan_t := 0.0
var _volcanoes: Array = []   # [ö, kraterns topp i 3D]
var _volcano_t := 0.0


func setup(p_world) -> void:
	world = p_world
	z_index = 4
	centered = true
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = cm
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = _phys_size()
	add_child(vp)
	texture = vp.get_texture()
	root3 = Node3D.new()
	vp.add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	# Solen: snett framifrån och från vänster, så att sidorna mot betraktaren är
	# upplysta och skuggorna faller åt höger och bakåt
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.8, -0.45), Vector3.UP)
	cam3 = Camera3D.new()
	cam3.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam3.keep_aspect = Camera3D.KEEP_HEIGHT
	cam3.rotation = Vector3(-asin(Y_SQUASH), 0, 0)
	vp.add_child(cam3)
	cam3.make_current()
	# Skuggfångare över hela havet och alla öar
	var plane := PlaneMesh.new()
	plane.size = Vector2(Data.WORLD_SIZE.x + 6000.0, Data.WORLD_SIZE.y / Y_SQUASH + 6000.0)
	_catcher = MeshInstance3D.new()
	_catcher.mesh = plane
	var cmat := ShaderMaterial.new()
	cmat.shader = CATCHER
	var amb := AMBIENT.srgb_to_linear()
	cmat.set_shader_parameter("ambient_linear", Vector3(amb.r, amb.g, amb.b) * AMBIENT_ENERGY)
	_catcher.material_override = cmat
	_catcher.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_catcher.position = Vector3(Data.WORLD_SIZE.x * 0.5, 0.05, Data.WORLD_SIZE.y * 0.5 / Y_SQUASH)
	root3.add_child(_catcher)
	_palm_mat = ShaderMaterial.new()
	_palm_mat.shader = SOLID
	_palm_mat.set_shader_parameter("sway", 0.05)
	for i in 4:
		var k := Kit.new()
		Site3D.palm(k, Vector3.ZERO, 30.0 + i * 3.0, 100 + i * 17)
		_palm_meshes.append(k.commit())
	process_priority = 100
	# Kameran ska följa med även när spelet är pausat
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan(true)


func _phys_size() -> Vector2i:
	var s := get_window().size if is_inside_tree() else Vector2i(1600, 900)
	return Vector2i(maxi(64, s.x), maxi(64, s.y))


## Den logiska skärmstorleken (efter canvas_items-skalningen).
func _vis_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	if world == null:
		return
	_follow_camera()
	if get_tree().paused:
		return
	_scan_t -= delta / maxf(0.001, Engine.time_scale)
	if _scan_t <= 0.0:
		_scan_t = 0.4
		_scan(false)
	_sync_ships(delta)
	for isl in _towns:
		_towns[isl].sync(delta)
	for id in _sites:
		var e: Array = _sites[id]
		e[1].sync(delta)
	_volcano_t -= delta / maxf(0.001, Engine.time_scale)
	if _volcano_t <= 0.0:
		_volcano_t = 0.35
		for v in _volcanoes:
			var top: Vector3 = v[1]
			world.fx.smoke(Vector2(top.x, top.z * Y_SQUASH - top.y * 0.694) + Vector2(randf_range(-6, 6), 0), 1)
	var wd := Vector2.from_angle(Game.wind_angle)
	_palm_mat.set_shader_parameter("wind", Vector2(wd.x, wd.y / Y_SQUASH).normalized() * Game.wind_strength * (1.0 + Game.storm * 2.0))


## 3D-kameran följer 2D-kameran exakt: samma mittpunkt och samma skala.
func _follow_camera() -> void:
	var phys := _phys_size()
	if vp.size != phys:
		vp.size = phys
	var ct := get_viewport().get_canvas_transform()
	var vis := _vis_size()
	var center: Vector2 = ct.affine_inverse() * (vis * 0.5)
	var zoom: float = ct.get_scale().x
	position = center
	scale = Vector2(vis.x / phys.x, vis.y / phys.y) / zoom
	var view_h := vis.y / zoom
	cam3.size = view_h
	# Kameran står så nära att skuggkartan bara täcker det som syns (skarpare skuggor)
	var dist := view_h * 0.55 + 500.0
	var fwd := -cam3.global_transform.basis.z
	var target := Vector3(center.x, 0, center.y / Y_SQUASH)
	cam3.position = target - fwd * dist
	cam3.near = 1.0
	cam3.far = dist + view_h * 0.6 + 600.0
	sun.directional_shadow_max_distance = cam3.far


func _scan(_initial: bool) -> void:
	# Städer (och vulkaner)
	for isl in world.islands:
		if not _towns.has(isl):
			var t := Town3D.new()
			root3.add_child(t)
			t.setup(isl)
			_towns[isl] = t
			if isl.volcano:
				_make_volcano(isl)
	# Resursbyggnader och varv (stadens byggnader finns i stadsmodellen)
	var seen := {}
	for isl in world.islands:
		for b in isl.buildings:
			if b.concealed or b.type == "radhus":
				continue
			var id: int = b.get_instance_id()
			seen[id] = true
			if not _sites.has(id):
				var s := Site3D.new()
				root3.add_child(s)
				s.setup(b)
				_sites[id] = [b, s]
	for id in _sites.keys():
		if not seen.has(id):
			_sites[id][1].queue_free()
			_sites.erase(id)
	# Palmer
	var pseen := {}
	for isl in world.islands:
		for palm in isl.palms:
			if not is_instance_valid(palm):
				continue
			var id: int = palm.get_instance_id()
			pseen[id] = true
			if not _palms.has(id):
				var mi := MeshInstance3D.new()
				mi.mesh = _palm_meshes[palm.seed_value % _palm_meshes.size()]
				mi.material_override = _palm_mat
				root3.add_child(mi)
				mi.position = Ship3D.to3d(palm.position)
				mi.rotation.y = float(palm.seed_value % 628) * 0.01
				var sc: float = 1.15 + float(palm.seed_value % 30) * 0.01
				mi.scale = Vector3(sc, sc, sc)
				if palm.dark:
					var dm := ShaderMaterial.new()
					dm.shader = SOLID
					dm.set_shader_parameter("tint", Color(0.55, 0.6, 0.55))
					mi.material_override = dm
				_palms[id] = [palm, mi]
	for id in _palms.keys():
		if not pseen.has(id):
			_palms[id][1].queue_free()
			_palms.erase(id)


## Vulkan: en kon i två färger med glödande lava i kratern. Röken kommer från fx.
func _make_volcano(isl) -> void:
	var R: float = isl.radius * 0.36
	var H: float = isl.radius * 0.66
	var k := Kit.new()
	var base := Ship3D.to3d(isl.position + isl._volcano_center())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(isl.id)
	var seg := 14
	var rings := [[0.0, 1.0, Color(0.55, 0.58, 0.4)], [0.3, 0.68, Color(0.58, 0.5, 0.42)], [0.72, 0.38, Color(0.52, 0.46, 0.42)], [1.0, 0.22, Color(0.44, 0.38, 0.36)]]
	var pts: Array = []
	for r in rings:
		var ring: Array = []
		for i in seg:
			var a := TAU * i / seg
			var j := rng.randf_range(0.9, 1.1)
			ring.append(Vector3(cos(a) * R * r[1] * j, H * r[0] * rng.randf_range(0.97, 1.0), sin(a) * R * r[1] * j))
		pts.append(ring)
	for ri in rings.size() - 1:
		for i in seg:
			var i2 := (i + 1) % seg
			var col: Color = rings[ri][2].lerp(rings[ri + 1][2], 0.5).darkened(0.07 * (i % 3))
			k.quad(pts[ri][i], pts[ri][i2], pts[ri + 1][i2], pts[ri + 1][i], col, Vector3(0, H * 0.4, 0))
	# Lavaströmmar längs sidorna
	for i in 3:
		var a := rng.randf_range(0.3, 2.8)
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x)
		var top := d * R * 0.22 + Vector3(0, H * 0.99, 0)
		var mid := d * R * 0.55 + Vector3(0, H * 0.55, 0)
		k.quad(top + side * 2.0 + d * 0.6, top - side * 2.0 + d * 0.6, mid - side * 3.5 + d * 1.0, mid + side * 3.5 + d * 1.0, Color(1.0, 0.45, 0.12), Vector3(0, H * 0.4, 0))
	var body := MeshInstance3D.new()
	body.mesh = k.commit()
	body.material_override = Ship3D.solid_material()
	body.position = base
	root3.add_child(body)
	var lava := Kit.new()
	for i in seg:
		var i2 := (i + 1) % seg
		var p1: Vector3 = pts[3][i] * Vector3(0.85, 1, 0.85)
		var p2: Vector3 = pts[3][i2] * Vector3(0.85, 1, 0.85)
		lava.tri(Vector3(0, H * 0.97, 0), p1 - Vector3(0, H * 0.02, 0), p2 - Vector3(0, H * 0.02, 0), Color(1.0, 0.5, 0.15), Vector3(0, 0, 0))
	var glow := MeshInstance3D.new()
	glow.mesh = lava.commit()
	var gm := ShaderMaterial.new()
	gm.shader = SOLID
	gm.set_shader_parameter("glow", 0.6)
	glow.material_override = gm
	glow.position = base
	root3.add_child(glow)
	_volcanoes.append([isl, base + Vector3(0, H, 0)])


func _sync_ships(delta: float) -> void:
	var seen := {}
	for s in world.ships:
		if not is_instance_valid(s) or s.is_monster():
			continue
		var id: int = s.get_instance_id()
		seen[id] = true
		var e = _ships.get(id)
		if e == null:
			var m := Ship3D.new()
			root3.add_child(m)
			m.setup(s)
			e = [s, m]
			_ships[id] = e
		e[1].sync(delta)
	for id in _ships.keys():
		if not seen.has(id):
			_ships[id][1].queue_free()
			_ships.erase(id)


func town_top(isl) -> float:
	var t = _towns.get(isl)
	return t.top_height() if t != null else 40.0
