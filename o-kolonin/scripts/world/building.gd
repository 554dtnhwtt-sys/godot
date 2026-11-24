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
var concealed := false       # stadsbyggnader finns i staden och ritas inte separat
var upgrading := false
var up_progress := 0.0
var up_time := 10.0
var _pending_variant := ""
var _pending_delay := 0.0
var _pop := 0.0
var _prev_variant := ""  # förra stadsmodellen, tonas ut när staden växer
var _fade := 0.0
var _t := 0.0
var _seed := 0.0

const WIDTH := {"radhus": 150.0}
const RESOURCE_WIDTH := 96.0
const VARIANT_WIDTH := {"town1": 150.0, "town2": 178.0, "town3": 206.0, "town4": 234.0, "town5": 262.0, "town_ancient": 232.0}
## Rök från staden: punkter i bilden (andel av bredd/höjd från övre vänstra hörnet).
const TOWN_SMOKE := {
	"town1": [Vector2(0.42, 0.55)],
	"town2": [Vector2(0.3, 0.3), Vector2(0.62, 0.22)],
	"town3": [Vector2(0.25, 0.3), Vector2(0.55, 0.18), Vector2(0.78, 0.38)],
	"town4": [Vector2(0.3, 0.3), Vector2(0.52, 0.2), Vector2(0.72, 0.34)],
	"town5": [Vector2(0.28, 0.35), Vector2(0.45, 0.22), Vector2(0.66, 0.3), Vector2(0.8, 0.45)],
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
	_fade = maxf(0.0, _fade - delta / maxf(0.001, Engine.time_scale) * 0.6)
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
					_prev_variant = variant
					_fade = 1.0
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
	var w: float = VARIANT_WIDTH.get(variant, WIDTH.get(type, RESOURCE_WIDTH))
	var h := w * tex.get_height() / tex.get_width()
	return Rect2(Vector2(-w * 0.5, -h * 0.66), Vector2(w, h))


## Hur högt över marken byggnadens topp är (för skylten över staden).
func top_height() -> float:
	if _three_d() and type == "radhus":
		return Game.world.view3d.town_top(island)
	var tex := _tex()
	if tex == null:
		return 80.0
	return _rect(tex).size.y * 0.72


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


func _bar(y: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(-24, y, 48, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-24, y, 48 * frac, 6), col)


func _three_d() -> bool:
	return Game.world != null and Game.world.view3d != null


## Med 3D-lagret ritas bara mätare, nivåmarkering och brand här (ovanför modellerna).
func _draw_3d_marks() -> void:
	if not built:
		_bar(16, clampf(progress, 0.0, 1.0), Color(0.95, 0.8, 0.3))
		return
	if upgrading and type != "radhus" and _pending_delay <= 0.0:
		_bar(16, up_progress, Color(0.6, 0.85, 1.0))
		if randf() < 0.05 and Game.world:
			Game.world.fx.dust(global_position + Vector2(randf_range(-30, 30), -4))
	if level >= 2:
		for i in level:
			var x := -6.0 * (level - 1) + i * 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 24), Vector2(x + 4, 28), Vector2(x, 32), Vector2(x - 4, 28)]), Color(1, 0.85, 0.3))
	if ruined:
		var h := 40.0 if type == "radhus" else 18.0
		_smoke(Vector2(0, -h), Color(0.25, 0.25, 0.25))
		draw_circle(Vector2(-6, -h * 0.6), 6 + sin(_t * 9.0) * 1.5, Color(1, 0.5, 0.1, 0.85))
		draw_circle(Vector2(8, -h * 0.4), 4 + sin(_t * 7.0) * 1.5, Color(1, 0.7, 0.2, 0.8))
	if hp < max_hp - 1.0:
		_bar(18, hp / max_hp, Color(0.9, 0.3, 0.25))


func _draw() -> void:
	if delay > 0.0 or concealed:
		return
	if _three_d():
		if z_index != 6:
			z_index = 6
		_draw_3d_marks()
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
		_scaffold(r, 0.6)
		_bar(12, p, Color(0.95, 0.8, 0.3))
		return
	# Studs när bygget blir klart
	var sq := sin(_pop * PI * 3.0) * _pop * 0.14
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + sq, 1.0 - sq))
	var mod := Color(0.55, 0.5, 0.48) if ruined else Color(1, 1, 1)
	# Mjuk övergång från förra stadsmodellen
	if _fade > 0.0 and _prev_variant != "":
		var old: Texture2D = Art.building(_prev_variant)
		if old != null:
			var ow: float = VARIANT_WIDTH.get(_prev_variant, r.size.x)
			var oh := ow * old.get_height() / old.get_width()
			draw_texture_rect(old, Rect2(Vector2(-ow * 0.5, -oh * 0.66), Vector2(ow, oh)), false, Color(1, 1, 1, _fade))
		mod.a = 1.0 - _fade
	draw_texture_rect(tex, r, false, mod)
	draw_set_transform(Vector2.ZERO)
	if TOWN_SMOKE.has(variant) and not ruined:
		for sp in TOWN_SMOKE[variant]:
			_smoke(r.position + Vector2(r.size.x * sp.x, r.size.y * sp.y))
	if not ruined and is_active():
		_work_anim(r)
	if upgrading:
		_scaffold(r, 0.4)
		if randf() < 0.05 and Game.world:
			Game.world.fx.dust(global_position + Vector2(randf_range(-r.size.x * 0.3, r.size.x * 0.3), -4))
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


## Diskreta animationer som visar att platsen arbetar.
func _work_anim(r: Rect2) -> void:
	var ph := fmod(_t + _seed, 1000.0)
	match type:
		"fiskehydda", "parldykare":
			_boat(r)
		"skogshuggare", "stenbrott", "sandtakt", "guldgruva":
			var k := fmod(ph * 0.3, 1.0)
			var col := Color(0.8, 0.78, 0.74) if type != "sandtakt" else Color(1.0, 0.93, 0.72)
			draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.4) + Vector2(k * 8.0, -k * 26.0), 3.0 + k * 7.0, Color(col, 0.4 * (1.0 - k)))
		"sockerplantage":
			skew = sin(_t * 1.2 + _seed) * 0.025
		"kristallgruva":
			draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.45), r.size.x * 0.3, Color(0.5, 0.95, 1.0, 0.08 + 0.06 * sin(_t * 2.2)))


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
