extends Node2D
## En byggnad på en ö, ritad snett uppifrån. Den reser sig ur en byggställning,
## studsar till när den är klar, kan uppgraderas i nivåer och har egna
## arbetsanimationer. Kanonbatterier skjuter på fiender.

var type := ""
var variant := ""          # annan bild än typen (rådhusets nivåer, hustyper, torg, torn)
var island = null
var owner_id := ""
var site_index := -1
var level := 1
var progress := 0.0
var built := false
var delay := 0.0           # dagar innan bygget börjar (staden växer ett hus i taget)
var hp := 150.0
var max_hp := 150.0
var reload := 0.0
var ruined := false
var upgrading := false
var up_progress := 0.0
var up_time := 10.0
var _pending_variant := ""
var _pending_delay := 0.0
var _pop := 0.0
var _t := 0.0
var _seed := 0.0

const WIDTH := {
	"radhus": 104.0, "akademi": 104.0, "fyrtorn": 66.0, "kanonbatteri": 96.0, "marknad": 100.0,
	"skeppsvarv": 108.0, "sandtakt": 90.0, "glasbruk": 80.0, "sockerplantage": 96.0, "kokosodling": 96.0,
	"lagerhus": 92.0, "hus": 66.0,
}
const VARIANT_WIDTH := {"hall1": 86.0, "hall2": 96.0, "hall3": 106.0, "hall4": 122.0, "hall5": 136.0, "plaza": 104.0, "tower": 64.0, "chapel": 72.0, "mansion": 74.0, "townhouse": 70.0}
## Var skorstenar sitter i bilden (andel av bredd/höjd från övre vänstra hörnet).
const SMOKE := {"romdestilleri": Vector2(0.44, 0.05), "glasbruk": Vector2(0.43, 0.03), "townhouse": Vector2(0.5, 0.06), "hall1": Vector2(0.48, 0.55)}
## Extra dekoration vid resursbyggnader på nivå 2 och 3.
const LEVEL_DECO := {
	"skogshuggare": "palm2", "kokosodling": "palm1", "stenbrott": "sten", "sandtakt": "sand", "sockerplantage": "socker",
	"kryddgard": "kryddor", "parldykare": "parlor", "kristallgruva": "kristaller", "guldgruva": "guld", "fiskehydda": "parlor",
}


func _ready() -> void:
	max_hp = 400.0 if type == "radhus" else (260.0 if type == "kanonbatteri" else 150.0)
	hp = max_hp
	_seed = randf() * 10.0


func def() -> Dictionary:
	return Data.BUILDINGS[type]


func is_active() -> bool:
	return built and not ruined and delay <= 0.0


func display_name() -> String:
	return def()["name"]


## Byter utseende (t.ex. nytt rådhus eller finare hus) med en byggställning.
func change_variant(v: String, instant: bool, wait: float = 0.0) -> void:
	if instant:
		variant = v
		return
	_pending_variant = v
	_pending_delay = wait
	upgrading = true
	up_progress = 0.0
	up_time = 6.0


## Uppgradering av resursbyggnad eller rådhus: byggställning medan arbetet pågår.
func begin_upgrade(days: float) -> void:
	upgrading = true
	up_progress = 0.0
	up_time = maxf(1.0, days)


func _process(delta: float) -> void:
	_t += delta
	var days := delta / Data.DAY_SECONDS
	_pop = maxf(0.0, _pop - delta * 1.6)
	if delay > 0.0:
		delay -= days
		queue_redraw()
		return
	if not built:
		progress += days / maxf(0.5, def().get("time", 6.0))
		if randf() < delta * 3.0 and Game.world:
			Game.world.fx.dust(global_position + Vector2(randf_range(-20, 20), -4))
		if progress >= 1.0:
			_finish_build()
	elif upgrading:
		if _pending_delay > 0.0:
			_pending_delay -= days
		else:
			up_progress += days / up_time
			if up_progress >= 1.0:
				upgrading = false
				up_progress = 0.0
				if _pending_variant != "":
					variant = _pending_variant
					_pending_variant = ""
				elif type != "radhus":
					level = mini(level + 1, 3)
					if owner_id == Game.player:
						Game.say("%s on %s upgraded to level %d." % [display_name(), island.display_name, level], Color(0.7, 0.95, 0.7))
				_pop = 1.0
				_burst()
	elif ruined:
		if Game.time - island.last_attacked > 20.0:
			hp += max_hp * 0.02 * days
			if hp >= max_hp * 0.5:
				ruined = false
	elif hp < max_hp and Game.time - island.last_attacked > 10.0:
		hp = minf(max_hp, hp + max_hp * 0.01 * days)
	if is_active() and def().has("fort"):
		_fort_logic(delta)
	queue_redraw()


func _finish_build() -> void:
	progress = 1.0
	built = true
	_pop = 1.0
	_burst()
	if owner_id == Game.player and Game.world and type != "hus" and type != "dekor":
		Game.say("%s completed on %s." % [display_name(), island.display_name], Color(0.7, 0.95, 0.7))


func _burst() -> void:
	if Game.world == null:
		return
	for i in 4:
		Game.world.fx.dust(global_position + Vector2(randf_range(-26, 26), randf_range(-6, 4)))


func _fort_logic(delta: float) -> void:
	reload -= delta
	if reload > 0.0 or Game.world == null:
		return
	var f: Dictionary = def()["fort"]
	var target = Game.world.nearest_hostile_ship(owner_id, global_position, f["range"])
	if target == null:
		reload = 0.5
		return
	var dmg: float = f["damage"] * Game.mod(owner_id, "fort")
	Game.world.fx.fire_cannonball(global_position + Vector2(0, -24), target, dmg, owner_id, null)
	Game.world.fx.smoke(global_position + Vector2(0, -24), 2)
	reload = f["reload"] * randf_range(0.85, 1.15)


func take_damage(amount: float) -> void:
	if not built:
		progress = maxf(0.0, progress - amount / 100.0)
		return
	hp -= amount
	island.last_attacked = Game.time
	if hp <= 0.0:
		hp = 0.0
		ruined = true


# ------------------------------------------------------------------ Rita
func _tex() -> Texture2D:
	return Art.building(variant if variant != "" else type)


func _rect(tex: Texture2D) -> Rect2:
	var w: float = VARIANT_WIDTH.get(variant, WIDTH.get(type, 88.0))
	if type == "hus" and not VARIANT_WIDTH.has(variant):
		w = WIDTH["hus"]
	var h := w * tex.get_height() / tex.get_width()
	return Rect2(Vector2(-w * 0.5, -h * 0.72), Vector2(w, h))


func _flag(p: Vector2, h: float) -> void:
	draw_line(p, p + Vector2(0, -h), Color(0.35, 0.25, 0.15), 2.0)
	var wave := sin(_t * 4.0 + _seed) * 2.0
	var top := p + Vector2(0, -h)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(16, 2 + wave), top + Vector2(16, 11 + wave), top + Vector2(0, 9)]), Data.nation_color(owner_id))
	draw_line(top + Vector2(2, 5), top + Vector2(14, 6 + wave), Data.nation_accent(owner_id), 2.0)


func _smoke(p: Vector2, col := Color(0.75, 0.75, 0.75)) -> void:
	for i in 4:
		var k := fmod(_t * 0.35 + i / 4.0 + _seed, 1.0)
		var drift := Vector2.from_angle(Game.wind_angle) * k * 26.0
		draw_circle(p + drift + Vector2(sin(_t + i) * 3.0, -k * 46.0), 4.0 + k * 9.0, Color(col, 0.45 * (1.0 - k)))


func _scaffold(r: Rect2, frac: float) -> void:
	var sc: Texture2D = Art.deco("scaffold")
	if sc == null:
		return
	var sw := r.size.x * frac
	var sh := sw * sc.get_height() / sc.get_width()
	draw_texture_rect(sc, Rect2(Vector2(-sw * 0.5, -sh * 0.85), Vector2(sw, sh)), false)


func _worker(p: Vector2, phase: float) -> void:
	var hit := absf(sin(_t * 6.0 + phase))
	draw_rect(Rect2(p + Vector2(-2, -8), Vector2(4, 7)), Color(0.75, 0.45, 0.25))
	draw_circle(p + Vector2(0, -10), 2.2, Color(0.55, 0.38, 0.26))
	draw_line(p + Vector2(2, -7), p + Vector2(6, -11 + hit * 6.0), Color(0.35, 0.25, 0.15), 1.5)


func _bar(y: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(-24, y, 48, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-24, y, 48 * frac, 6), col)


func _draw() -> void:
	if delay > 0.0:
		return
	var tex := _tex()
	if tex == null:
		return
	var r := _rect(tex)
	# Skugga under byggnaden
	draw_set_transform(Vector2(6, 2), 0.0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, r.size.x * 0.42, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	if not built:
		# Byggnaden reser sig nerifrån och upp bakom byggställningen
		var p := clampf(progress, 0.0, 1.0)
		var ts := tex.get_size()
		var src := Rect2(0, ts.y * (1.0 - p), ts.x, ts.y * p)
		var dst := Rect2(r.position.x, r.position.y + r.size.y * (1.0 - p), r.size.x, r.size.y * p)
		draw_texture_rect_region(tex, dst, src, Color(1, 1, 1, 0.9))
		_scaffold(r, 0.72)
		_worker(Vector2(-r.size.x * 0.3, 2), 0.0)
		_worker(Vector2(r.size.x * 0.32, 4), 1.7)
		_bar(12, p, Color(0.95, 0.8, 0.3))
		return
	# Studs när bygget blir klart
	var sq := sin(_pop * PI * 3.0) * _pop * 0.14
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + sq, 1.0 - sq))
	if level >= 2 and LEVEL_DECO.has(type):
		_level_deco(r)
	var mod := Color(0.55, 0.5, 0.48) if ruined else Color(1, 1, 1)
	draw_texture_rect(tex, r, false, mod)
	draw_set_transform(Vector2.ZERO)
	var key := variant if variant != "" else type
	if SMOKE.has(key) and not ruined:
		var sp: Vector2 = SMOKE[key]
		_smoke(r.position + Vector2(r.size.x * sp.x, r.size.y * sp.y))
	if not ruined and is_active():
		_work_anim(r)
	if upgrading:
		_scaffold(r, 0.5)
		_worker(Vector2(r.size.x * 0.34, 4), 0.6)
		if _pending_delay <= 0.0:
			_bar(12, up_progress, Color(0.6, 0.85, 1.0))
	if level >= 2:
		for i in level:
			var x := -6.0 * (level - 1) + i * 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 14), Vector2(x + 4, 18), Vector2(x, 22), Vector2(x - 4, 18)]), Color(1, 0.85, 0.3))
	if ruined:
		_smoke(Vector2(0, -r.size.y * 0.3), Color(0.25, 0.25, 0.25))
		draw_circle(Vector2(-6, -r.size.y * 0.2), 6 + sin(_t * 9.0) * 1.5, Color(1, 0.5, 0.1, 0.85))
		draw_circle(Vector2(8, -r.size.y * 0.15), 4 + sin(_t * 7.0) * 1.5, Color(1, 0.7, 0.2, 0.8))
	if hp < max_hp - 1.0:
		_bar(14, hp / max_hp, Color(0.9, 0.3, 0.25))


func _level_deco(r: Rect2) -> void:
	var dt: Texture2D = Art.deco(LEVEL_DECO[type])
	if dt == null:
		return
	var w := r.size.x * 0.42
	var h := w * dt.get_height() / dt.get_width()
	draw_texture_rect(dt, Rect2(Vector2(r.size.x * 0.28, -h * 0.85 + 6), Vector2(w, h)), false)
	if level >= 3:
		draw_texture_rect(dt, Rect2(Vector2(-r.size.x * 0.28 - w, -h * 0.85 + 8), Vector2(w, h)), false)


## Små animationer som visar att byggnaden arbetar.
func _work_anim(r: Rect2) -> void:
	var ph := fmod(_t + _seed, 1000.0)
	match key_type():
		"radhus":
			_flag(r.position + Vector2(r.size.x * 0.86, r.size.y * 0.3), 26.0)
		"kanonbatteri", "skeppsvarv":
			_flag(r.position + Vector2(r.size.x * 0.86, r.size.y * 0.3), 26.0)
			if type == "skeppsvarv":
				# Gnistor från hammarslag på skrovet
				var k := fmod(ph * 1.3, 1.0)
				if k < 0.3:
					for i in 4:
						var a := -PI * 0.5 + (i - 1.5) * 0.5
						draw_line(Vector2(-6, -18), Vector2(-6, -18) + Vector2.from_angle(a) * (4.0 + k * 22.0), Color(1, 0.85, 0.3, 1.0 - k / 0.3), 1.5)
		"skogshuggare":
			var k := fmod(ph * 0.6, 1.0)
			if k < 0.4:
				for i in 5:
					var a := -PI * 0.5 + (i - 2) * 0.6
					var d := k * 40.0
					draw_rect(Rect2(Vector2(r.size.x * 0.18, -10) + Vector2.from_angle(a) * d + Vector2(0, k * k * 60.0), Vector2(3, 2)), Color(0.75, 0.55, 0.3, 1.0 - k / 0.4))
			_worker(Vector2(r.size.x * 0.12, 6), 0.0)
		"kokosodling":
			for i in 2:
				var k := fmod(ph * 0.35 + i * 0.5, 1.0)
				var x := -r.size.x * 0.25 + i * r.size.x * 0.4
				draw_circle(Vector2(x, -r.size.y * 0.45 + k * k * r.size.y * 0.45), 3.0, Color(0.45, 0.3, 0.15, 1.0 - maxf(0.0, k - 0.85) * 6.0))
		"fiskehydda", "parldykare":
			_boat(r)
		"stenbrott", "sandtakt":
			var k := fmod(ph * 0.5, 1.0)
			var col := Color(0.8, 0.8, 0.78) if type == "stenbrott" else Color(1.0, 0.93, 0.72)
			draw_circle(Vector2(sin(_seed) * 14.0, -10 - k * 22.0), 5.0 + k * 10.0, Color(col, 0.5 * (1.0 - k)))
			_worker(Vector2(-r.size.x * 0.2, 4), 1.0)
		"sockerplantage":
			skew = sin(_t * 1.4 + _seed) * 0.035
		"kryddgard", "kristallgruva":
			var col := Color(1, 0.55, 0.2) if type == "kryddgard" else Color(0.55, 0.95, 1.0)
			for i in 3:
				var k := fmod(ph * 0.7 + i * 0.33, 1.0)
				var p := Vector2(sin(i * 2.3 + _seed) * r.size.x * 0.3, -10 - k * 30.0)
				draw_circle(p, 2.0 * (1.0 - k) + 0.5, Color(col, 1.0 - k))
			if type == "kristallgruva":
				draw_circle(r.position + Vector2(r.size.x * 0.55, r.size.y * 0.45), 18.0, Color(0.5, 0.95, 1.0, 0.1 + 0.08 * sin(_t * 2.2)))
		"guldgruva":
			var x := sin(ph * 0.8) * r.size.x * 0.25
			draw_rect(Rect2(Vector2(x - 7, -6), Vector2(14, 7)), Color(0.4, 0.3, 0.2))
			draw_circle(Vector2(x - 4, 2), 2.5, Color(0.2, 0.2, 0.2))
			draw_circle(Vector2(x + 4, 2), 2.5, Color(0.2, 0.2, 0.2))
			draw_circle(Vector2(x, -8), 3.5, Color(1, 0.84, 0.3))
		"marknad":
			for i in 4:
				var x := sin(ph * (0.4 + i * 0.1) + i * 1.7) * r.size.x * 0.32
				var cloth: Color = [Color(0.85, 0.3, 0.25), Color(0.25, 0.45, 0.8), Color(0.95, 0.85, 0.6), Color(0.35, 0.6, 0.3)][i]
				draw_rect(Rect2(Vector2(x - 2, 2 - 8), Vector2(4, 7)), cloth)
				draw_circle(Vector2(x, 2 - 10), 2.2, Color(0.55, 0.38, 0.26))
		"lagerhus":
			var k := fmod(ph * 0.3, 1.0)
			var x := lerpf(-r.size.x * 0.35, r.size.x * 0.1, k)
			draw_rect(Rect2(Vector2(x - 5, -4), Vector2(10, 8)), Color(0.6, 0.42, 0.22))
			_worker(Vector2(x - 9, 6), 0.0)
		"fyrtorn":
			var lamp := r.position + Vector2(r.size.x * 0.48, r.size.y * 0.13)
			draw_circle(lamp, 10.0, Color(1, 0.95, 0.6, 0.35 * (0.55 + 0.25 * sin(_t * 3.0))))
			var beam := Vector2(cos(_t * 1.1), sin(_t * 1.1) * 0.4) * 140.0
			draw_colored_polygon(PackedVector2Array([lamp, lamp + beam + beam.orthogonal() * 0.12, lamp + beam - beam.orthogonal() * 0.12]), Color(1, 0.95, 0.6, 0.14))
		"akademi":
			draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.55), 10.0, Color(1, 0.95, 0.7, 0.08 + 0.06 * sin(_t * 1.5)))


func key_type() -> String:
	return type


## En liten båt som ror ut och tillbaka (fiskare och pärldykare).
func _boat(r: Rect2) -> void:
	if island == null:
		return
	var out: Vector2 = global_position - island.position
	out.y /= 0.72
	out = out.normalized()
	out.y *= 0.72
	var k := fmod((_t + _seed * 3.0) / 14.0, 1.0)
	var t := k * 2.0 if k < 0.5 else 2.0 - k * 2.0
	var p := out * (36.0 + t * 90.0) + out.orthogonal() * sin(_t * 0.7 + _seed) * 8.0
	var dirx := out if k < 0.5 else -out
	var n := dirx.orthogonal()
	draw_colored_polygon(PackedVector2Array([p + dirx * 9.0, p + n * 4.0 - dirx * 7.0, p - n * 4.0 - dirx * 7.0]), Color(0.45, 0.3, 0.18))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2), p + Vector2(0, -14), p + Vector2(7, -4)]), Color(0.97, 0.95, 0.88))
	if type == "parldykare" and fmod(_t + _seed, 3.0) < 1.0:
		draw_arc(p + out * 10.0, 4.0 + fmod(_t, 1.0) * 8.0, 0, TAU, 12, Color(1, 1, 1, 0.6), 1.5)
