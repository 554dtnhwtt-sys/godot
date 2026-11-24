extends Node2D
## Ett segelskepp (eller ett sjöodjur). Seglar efter order, påverkas av vinden
## och manövrerar själv för att skjuta bredsidor mot fiender.

const Y_SQUASH := 0.72

var type := "slup"
var def: Dictionary = {}
var owner_id := ""
var hp := 100.0
var max_hp := 100.0
var heading := 0.0
var speed := 0.0
var velocity := Vector2.ZERO
var troops := 0.0
var max_troops := 0.0
var order := "idle"   # idle, move, attack, attack_island, colonize, trade
var target_pos := Vector2.ZERO
var target_ship = null
var target_island = null
var trade_a = null
var trade_b = null
var trade_leg := 0
var reload_l := 0.0
var reload_r := 0.0
var selected := false
var sinking := 0.0
var shown := true
var size_f := 1.0
var ai_role := ""
var speed_cap := 1.0  # sätts av formationer så att flottan håller ihop
var last_hit := -999.0
var world = null
var _wake: Array = []
var _wake_timer := 0.0
var _t := 0.0
var _auto_target = null
var _retarget := 0.0
var _flash_l := 0.0
var _flash_r := 0.0


func setup(p_type: String, p_owner: String, pos: Vector2, p_world) -> void:
	type = p_type
	def = Data.SHIPS[type]
	owner_id = p_owner
	position = pos
	world = p_world
	max_hp = def["hp"] * Game.mod(owner_id, "ship_hp")
	hp = max_hp
	max_troops = def["troops"] * Game.mod(owner_id, "troops")
	troops = max_troops
	size_f = def["size"]
	heading = randf() * TAU
	_t = randf() * 10.0
	add_to_group("ships")


func is_alive() -> bool:
	return sinking <= 0.0 and hp > 0.0


func is_monster() -> bool:
	return def.get("monster", false)


func display_name() -> String:
	return def["name"]


# ------------------------------------------------------------------ Order
func order_move(p: Vector2) -> void:
	order = "move"
	target_pos = p
	target_ship = null
	target_island = null


func order_attack(s) -> void:
	order = "attack"
	target_ship = s
	target_island = null


func order_attack_island(isl) -> void:
	order = "attack_island"
	target_island = isl
	target_ship = null


func order_colonize(isl) -> void:
	order = "colonize"
	target_island = isl
	target_ship = null


func order_trade(a, b) -> void:
	order = "trade"
	trade_a = a
	trade_b = b
	trade_leg = 1
	target_ship = null
	target_island = null


func stop() -> void:
	order = "idle"
	target_ship = null
	target_island = null


# ------------------------------------------------------------------ Fart & vind
func wind_factor(h: float) -> float:
	var d := cos(angle_difference(h, Game.wind_angle))  # 1 = medvind, -1 = motvind
	var f := 1.0 - 0.15 * d if d >= 0.0 else 1.0 + 0.62 * d
	return f * lerpf(0.85, 1.15, clampf(Game.wind_strength - 0.5, 0.0, 1.0))


func max_speed() -> float:
	var s: float = def["speed"] * Game.mod(owner_id, "ship_speed")
	if def.get("ghost", false) or is_monster():
		return s
	s *= wind_factor(heading)
	s *= 1.0 - Game.storm * 0.3
	if hp < max_hp * 0.3:
		s *= 0.75
	if order == "move":
		s *= speed_cap
	return s


# ------------------------------------------------------------------ Uppdatering
func _process(delta: float) -> void:
	_t += delta
	_flash_l = maxf(0.0, _flash_l - delta)
	_flash_r = maxf(0.0, _flash_r - delta)
	if sinking > 0.0:
		sinking += delta
		if sinking > 4.0:
			world.remove_ship(self)
		queue_redraw()
		return
	var days := delta / Data.DAY_SECONDS
	var goal := _think(delta)
	_combat(delta)
	_move(delta, goal)
	_upkeep(days)
	_wake_timer -= delta
	if _wake_timer <= 0.0:
		_wake_timer = 0.12
		if speed > 15.0:
			_wake.push_front(position + Vector2.from_angle(heading + PI) * 20.0 * size_f)
		elif _wake.size() > 0:
			_wake.pop_back()
		if _wake.size() > 14:
			_wake.pop_back()
	queue_redraw()


## Bestämmer vart skeppet vill. Returnerar {"pos": Vector2, "speed": float, "face": float eller null}.
func _think(delta: float) -> Dictionary:
	var stop_goal := {"pos": position, "speed": 0.0}
	match order:
		"move":
			if position.distance_to(target_pos) < 30.0 * size_f:
				order = "idle"
				return stop_goal
			return {"pos": target_pos, "speed": max_speed()}
		"attack":
			if target_ship == null or not is_instance_valid(target_ship) or not target_ship.is_alive() or not Game.at_war(owner_id, target_ship.owner_id):
				stop()
				return stop_goal
			return _fight_goal(target_ship.position)
		"attack_island":
			var isl = target_island
			if isl == null or not Game.at_war(owner_id, isl.owner_id) or isl.owner_id == "neutral":
				stop()
				return stop_goal
			var fort = world.island_fort_target(isl, position)
			if fort != null:
				return _fight_goal(fort.global_position)
			# Inga försvar kvar: gå in och landstig eller bombardera.
			var coast: Vector2 = isl.coast_point_towards(position, 20.0)
			if position.distance_to(coast) < 70.0 * size_f:
				if troops >= 1.0:
					world.land_troops(self, isl)
				return {"pos": coast, "speed": 0.0}
			return {"pos": coast, "speed": max_speed()}
		"colonize":
			var isl = target_island
			if isl == null or isl.owner_id != "neutral":
				stop()
				return stop_goal
			var coast: Vector2 = isl.coast_point_towards(position, 20.0)
			if position.distance_to(coast) < 70.0 * size_f:
				world.try_colonize(self, isl)
				stop()
				return stop_goal
			return {"pos": coast, "speed": max_speed()}
		"trade":
			if trade_a == null or trade_b == null or trade_a.owner_id != owner_id or trade_b.owner_id != owner_id:
				stop()
				return stop_goal
			var dest = trade_b if trade_leg == 1 else trade_a
			var coast: Vector2 = dest.coast_point_towards(position, 20.0)
			if position.distance_to(coast) < 70.0 * size_f:
				world.trade_arrival(self, dest)
				trade_leg = 1 - trade_leg
			return {"pos": coast, "speed": max_speed()}
	# idle: strid om fiender är nära, annars ligg still.
	if _auto_target != null and is_instance_valid(_auto_target) and _auto_target.is_alive():
		if position.distance_to(_auto_target.position) < _range() * 1.8:
			return _fight_goal(_auto_target.position)
	return stop_goal


func _range() -> float:
	return def["range"]


## Strid: närma dig, vänd sedan bredsidan mot målet.
func _fight_goal(tp: Vector2) -> Dictionary:
	var to := tp - position
	var dist := to.length()
	var r := _range()
	if is_monster():
		return {"pos": tp, "speed": max_speed() * (0.3 if dist < r * 0.6 else 1.0)}
	if def["cannons"] == 0:
		# Obeväpnat: fly bort.
		return {"pos": position - to.normalized() * 300.0, "speed": max_speed()}
	if dist > r * 0.9:
		return {"pos": tp, "speed": max_speed()}
	var a := to.angle()
	var opt1 := a + PI * 0.5
	var opt2 := a - PI * 0.5
	var face := opt1 if absf(angle_difference(heading, opt1)) < absf(angle_difference(heading, opt2)) else opt2
	# Håll avståndet: luta in eller ut lite.
	if dist > r * 0.7:
		face = lerp_angle(face, a, 0.3)
	elif dist < r * 0.4:
		face = lerp_angle(face, a + PI, 0.3)
	return {"pos": position + Vector2.from_angle(face) * 200.0, "speed": max_speed() * 0.65}


func _combat(delta: float) -> void:
	reload_l -= delta
	reload_r -= delta
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.5 + randf() * 0.3
		_auto_target = world.nearest_hostile_ship(owner_id, position, _range() * 1.6, self)
	if is_monster():
		_monster_attack()
		return
	if def["cannons"] == 0:
		return
	var tgt = null
	var tpos := Vector2.ZERO
	var bld = null
	if order == "attack" and target_ship != null and is_instance_valid(target_ship) and target_ship.is_alive():
		tgt = target_ship
	elif order == "attack_island" and target_island != null:
		bld = world.island_fort_target(target_island, position)
		if bld != null:
			tpos = bld.global_position + Vector2(0, -10)
		elif _auto_target != null and is_instance_valid(_auto_target):
			tgt = _auto_target
	if tgt == null and bld == null and _auto_target != null and is_instance_valid(_auto_target) and _auto_target.is_alive():
		tgt = _auto_target
	if tgt != null:
		tpos = tgt.position
	elif bld == null:
		return
	var to := tpos - position
	var dist := to.length()
	if dist > _range():
		return
	var a := to.angle()
	for side in [-1, 1]:
		var normal: float = heading + side * PI * 0.5
		if absf(angle_difference(normal, a)) < 0.45:
			if side == -1 and reload_l <= 0.0:
				_broadside(side, tgt, tpos, bld)
				reload_l = _reload_time()
			elif side == 1 and reload_r <= 0.0:
				_broadside(side, tgt, tpos, bld)
				reload_r = _reload_time()


func _reload_time() -> float:
	var r: float = def["reload"] * Game.mod(owner_id, "reload")
	if Game.is_playable(owner_id) and Game.res(owner_id, "rom") > 1.0:
		r *= 0.88  # rom på skeppen ger bättre moral
	return r * randf_range(0.9, 1.1)


func _broadside(side: int, tgt, tpos: Vector2, bld) -> void:
	var n: int = def["cannons"]
	var length := _hull_len()
	var dmg: float = def["damage"] * Game.mod(owner_id, "cannon_dmg")
	if Game.is_playable(owner_id) and Game.res(owner_id, "rom") > 1.0:
		dmg *= 1.1
		Game.add_res(owner_id, "rom", -0.02 * n)
	var fwd := Vector2.from_angle(heading)
	var nrm := Vector2.from_angle(heading + side * PI * 0.5)
	for i in n:
		var t := (float(i) / maxf(1, n - 1)) - 0.5 if n > 1 else 0.0
		var from := position + fwd * t * length * 0.6 + nrm * 9.0 * size_f
		var target = tgt if tgt != null else tpos
		world.fx.fire_cannonball(from, target, dmg, owner_id, bld, i * 0.07)
		world.fx.smoke(from + nrm * 10.0, 1)
	if side == -1:
		_flash_l = 0.15
	else:
		_flash_r = 0.15


func _monster_attack() -> void:
	var tgt = _auto_target
	if order == "attack" and target_ship != null and is_instance_valid(target_ship):
		tgt = target_ship
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	if position.distance_to(tgt.position) < _range() and reload_l <= 0.0:
		reload_l = def["reload"]
		tgt.take_damage(def["damage"], owner_id)
		world.fx.splash(tgt.position, 2.0)


func _move(delta: float, goal: Dictionary) -> void:
	var gp: Vector2 = goal["pos"]
	var want: float = goal["speed"]
	var to := gp - position
	var desired := heading
	if to.length() > 4.0:
		desired = to.angle()
	# Undvik öar: titta framåt och sväng längs kusten.
	var look := 70.0 + speed * 0.9
	var ahead := position + Vector2.from_angle(heading) * look
	var ahead2 := position + Vector2.from_angle(desired) * look
	for isl in world.islands:
		if position.distance_to(isl.position) > isl.radius + 260.0:
			continue
		if isl.blocks(ahead) or isl.blocks(ahead2):
			var away: Vector2 = position - isl.position
			away.y /= Y_SQUASH
			var tangent := away.orthogonal().normalized()
			if tangent.dot(Vector2.from_angle(desired)) < 0.0:
				tangent = -tangent
			# Om målet ligger på ön (landstigning): stanna närmare.
			if isl.blocks(gp) and position.distance_to(gp) < 120.0:
				want = minf(want, 20.0)
			desired = (tangent + away.normalized() * 0.35).angle()
			break
	var turn := (1.3 if not is_monster() else 1.8) / size_f
	heading = rotate_toward(heading, desired, turn * delta)
	speed = move_toward(speed, want, 45.0 * delta)
	velocity = Vector2.from_angle(heading) * speed
	var np := position + velocity * delta
	var blocked := false
	for isl in world.islands:
		if position.distance_to(isl.position) > isl.radius + 120.0:
			continue
		if isl.contains_world_point(np):
			blocked = true
			var push: Vector2 = position - isl.position
			position += push.normalized() * 30.0 * delta
			speed *= 0.5
			break
	if not blocked:
		position = np
	# Håll avstånd till egna skepp
	for other in world.ships:
		if other == self or other.owner_id != owner_id or not other.is_alive():
			continue
		var d: Vector2 = position - other.position
		var min_d: float = 58.0 * (size_f + other.size_f) * 0.5
		if d.length() < min_d and d.length() > 0.01:
			position += d.normalized() * (min_d - d.length()) * 2.0 * delta
	position.x = clampf(position.x, 40.0, Data.WORLD_SIZE.x - 40.0)
	position.y = clampf(position.y, 40.0, Data.WORLD_SIZE.y - 40.0)


func _upkeep(days: float) -> void:
	if not Game.is_playable(owner_id):
		return
	var home = world.nearest_own_island(owner_id, position, 260.0)
	if home != null and Game.time - last_hit > 8.0:
		hp = minf(max_hp, hp + max_hp * 0.03 * days)
		troops = minf(max_troops, troops + max_troops * 0.05 * days)
	elif Game.storm > 0.4 and not def.get("ghost", false):
		hp -= max_hp * 0.006 * days * Game.storm
		if hp <= 0.0:
			hp = 1.0
			take_damage(5.0, "")


func take_damage(amount: float, attacker: String) -> void:
	if not is_alive():
		return
	hp -= amount
	last_hit = Game.time
	world.fx.splinters(position)
	if hp <= 0.0:
		hp = 0.0
		sinking = 0.001
		selected = false
		world.on_ship_sunk(self, attacker)


# ------------------------------------------------------------------ Rita
const SHIP_SHADER = preload("res://shaders/ship.gdshader")


func _hull_len() -> float:
	return 86.0 * size_f


func _ensure_material() -> void:
	if material != null:
		return
	var m := ShaderMaterial.new()
	m.shader = SHIP_SHADER
	var sail := Color(1, 1, 1)
	var strength := 0.0
	match owner_id:
		"svartarevet", "vildpirater":
			sail = Color(0.24, 0.22, 0.22)
			strength = 1.0
		"djupkulten":
			sail = Color(0.35, 0.18, 0.42)
			strength = 1.0
		"valdoria":
			sail = Color(0.92, 0.94, 1.0)
			strength = 0.5
		"solmar":
			sail = Color(1.0, 0.9, 0.75)
			strength = 0.6
		"kaluma":
			sail = Color(0.95, 0.88, 0.72)
			strength = 0.5
	m.set_shader_parameter("sail_color", sail)
	m.set_shader_parameter("tint_strength", strength)
	material = m


func _draw() -> void:
	if is_monster():
		_draw_kraken()
		return
	_ensure_material()
	var sink_k: float = clampf(sinking / 4.0, 0.0, 1.0)
	var L := _hull_len()
	var fwd := Vector2.from_angle(heading)
	var right := fwd.orthogonal()
	var ghost: bool = def.get("ghost", false)
	var crystal: bool = def.get("crystal", false)
	var alpha := 1.0 - sink_k * 0.85
	if ghost:
		alpha *= 0.72 + 0.18 * sin(_t * 2.0)
	_draw_wake(fwd, right, L, alpha)
	var tex: Texture2D = Art.ship(type)
	if tex == null:
		return
	var sc := L / tex.get_width()
	var half := tex.get_size() * 0.5
	var bob := sin(_t * 1.7 + position.x * 0.013)
	var roll := sin(_t * 1.25 + position.y * 0.011) * 0.025 + sink_k * 0.4
	var lean := clampf(angle_difference(heading, Game.wind_angle), -1.0, 1.0) * 0.04
	# Glöd för spök- och kristallskepp
	if ghost or crystal:
		var gc := Color(0.45, 1.0, 0.75, 0.16 * alpha) if ghost else Color(0.5, 0.9, 1.0, 0.16 * alpha)
		draw_set_transform(Vector2.ZERO, heading, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, L * 0.62 + sin(_t * 3.0) * 3.0, gc)
	# Skugga på vattnet
	draw_set_transform(Vector2(6, 8), heading + roll, Vector2(sc, sc * 0.9))
	draw_texture(tex, -half, Color(0.0, 0.06, 0.12, 0.3 * alpha))
	# Skrov och segel – gungar med vågorna och lutar i vinden
	draw_set_transform(Vector2(0, bob * 1.3), heading + roll + lean, Vector2(sc * (1.0 + bob * 0.012), sc * (1.0 - sink_k * 0.45)))
	draw_texture(tex, -half, Color(1, 1, 1, alpha))
	# Mynningsflammor
	if _flash_l > 0.0 or _flash_r > 0.0:
		var side := -1.0 if _flash_l > 0.0 else 1.0
		var k := (_flash_l if _flash_l > 0.0 else _flash_r) / 0.15
		for i in 4:
			var t := (i - 1.5) / 4.0
			var fp := Vector2(t * tex.get_width() * 0.6, side * tex.get_height() * 0.42)
			draw_circle(fp, 22.0 * k, Color(1, 0.8, 0.3, 0.85 * k))
	draw_set_transform(Vector2.ZERO)
	# Flagga i toppen av stormasten
	if sinking <= 0.0:
		var top := fwd * L * 0.04 + Vector2(0, bob * 1.3 - 2.0)
		var wdir := Vector2.from_angle(Game.wind_angle)
		var wn := wdir.orthogonal()
		var wave := sin(_t * 7.0) * 2.0
		var fl := 14.0 * clampf(size_f, 1.0, 1.6)
		var nat := Data.nation_color(owner_id)
		var acc := Data.nation_accent(owner_id)
		draw_colored_polygon(PackedVector2Array([top, top + wdir * fl + wn * wave, top + wdir * fl + wn * (6.0 + wave), top + wn * 6.0]), Color(nat, alpha))
		draw_line(top + wn * 3.0, top + wdir * fl + wn * (3.0 + wave), Color(acc, alpha), 1.5)
	# Markering
	if selected:
		var ring := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			ring.append(fwd * cos(a) * L * 0.6 + right * sin(a) * L * 0.26)
		draw_polyline(ring, Color(0.6, 1.0, 0.6, 0.55 + 0.25 * sin(_t * 4.0)), 2.0, true)
	if sinking <= 0.0 and (selected or hp < max_hp - 0.5):
		var bw := 40.0 * clampf(size_f, 1.0, 1.6)
		var by := -L * 0.38 - 16.0
		draw_rect(Rect2(-bw * 0.5 - 1, by - 1, bw + 2, 7), Color(0, 0, 0, 0.6))
		var hc := Color(0.4, 0.9, 0.4) if hp > max_hp * 0.5 else (Color(0.95, 0.8, 0.3) if hp > max_hp * 0.25 else Color(0.95, 0.3, 0.25))
		draw_rect(Rect2(-bw * 0.5, by, bw * hp / max_hp, 5), hc)
		if selected and max_troops > 0.0:
			draw_rect(Rect2(-bw * 0.5, by + 6, bw * troops / max_troops, 3), Color(0.85, 0.85, 1.0))
	if hp < max_hp * 0.5 and sinking <= 0.0:
		# Brand och rök när skeppet är svårt skadat
		for i in 3:
			var k := fmod(_t * 0.8 + i / 3.0, 1.0)
			draw_circle(-fwd * L * 0.15 + Vector2(sin(i * 2.1) * 6.0 + k * 10.0, -k * 34.0), 4.0 + k * 9.0, Color(0.3, 0.3, 0.3, 0.45 * (1.0 - k)))
		draw_circle(-fwd * L * 0.15, 4.0 + sin(_t * 11.0) * 1.5, Color(1, 0.55, 0.15, 0.85))
	if sinking > 0.0:
		for i in 5:
			var k := fmod(_t * 1.5 + i * 0.2, 1.0)
			draw_circle(Vector2(sin(i * 2.3) * 16.0, -k * 18.0 + 8.0), 2.5 + k * 3.0, Color(1, 1, 1, 0.55 * (1.0 - k)))
		draw_arc(Vector2.ZERO, L * 0.3 + sink_k * L * 0.4, 0, TAU, 28, Color(1, 1, 1, 0.5 * (1.0 - sink_k)), 2.0)


func _draw_wake(fwd: Vector2, right: Vector2, L: float, alpha: float) -> void:
	if _wake.size() > 1:
		for i in range(_wake.size() - 1):
			var a: Vector2 = _wake[i] - position
			var b: Vector2 = _wake[i + 1] - position
			var k := 1.0 - float(i) / _wake.size()
			var spread := (1.0 - k) * 10.0 * size_f + 4.0
			draw_line(a + right * spread, b + right * (spread + 2.0), Color(1, 1, 1, 0.32 * k * alpha), 2.5 * k + 1.0)
			draw_line(a - right * spread, b - right * (spread + 2.0), Color(1, 1, 1, 0.32 * k * alpha), 2.5 * k + 1.0)
			draw_line(a, b, Color(0.85, 0.97, 1.0, 0.18 * k * alpha), 6.0 * k * size_f)
	if speed > 25.0:
		var bow := fwd * L * 0.5
		var s := clampf(speed / 140.0, 0.2, 1.0)
		draw_arc(bow - fwd * 4.0, 7.0 * size_f, heading - 1.3, heading + 1.3, 10, Color(1, 1, 1, 0.45 * s * alpha), 2.0)


func _draw_kraken() -> void:
	var sink_k: float = clampf(sinking / 4.0, 0.0, 1.0)
	var a := 1.0 - sink_k
	var body := Color(0.45, 0.15, 0.35, a)
	var R := 34.0 * size_f
	draw_circle(Vector2(8, 10), R * 1.1, Color(0, 0.05, 0.1, 0.25 * a))
	for i in 8:
		var ang := TAU * i / 8.0 + sin(_t * 0.7 + i) * 0.3
		var prev := Vector2.ZERO
		for s in range(1, 8):
			var k := s / 7.0
			var p := Vector2.from_angle(ang + sin(_t * 2.0 + i + s * 0.6) * 0.35 * k) * R * (0.6 + k * 1.9)
			p.y *= Y_SQUASH
			p.y -= sin(k * PI) * 26.0
			draw_line(prev, p, body.lightened(0.1 * (s % 2)), (14.0 - s * 1.6) * size_f * 0.5, true)
			prev = p
	draw_circle(Vector2(0, -12), R * 0.7, body)
	draw_circle(Vector2(-10, -18), 5, Color(1, 0.9, 0.3, a))
	draw_circle(Vector2(10, -18), 5, Color(1, 0.9, 0.3, a))
	draw_circle(Vector2(-10, -18), 2, Color(0, 0, 0, a))
	draw_circle(Vector2(10, -18), 2, Color(0, 0, 0, a))
	if sinking <= 0.0 and hp < max_hp - 0.5:
		draw_rect(Rect2(-40, -70, 80, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-40, -70, 80 * hp / max_hp, 6), Color(0.85, 0.3, 0.6))
