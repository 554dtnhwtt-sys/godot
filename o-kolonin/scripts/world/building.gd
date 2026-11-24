extends Node2D
## En byggnad på en ö, ritad snett uppifrån. Bygger sig själv, producerar
## (via World) och kanonbatterier skjuter på fiender.

var type := ""
var island = null
var owner_id := ""
var slot_index := -1
var progress := 0.0
var built := false
var hp := 150.0
var max_hp := 150.0
var reload := 0.0
var ruined := false
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	max_hp = 400.0 if type == "radhus" else (260.0 if type == "kanonbatteri" else 150.0)
	hp = max_hp
	_seed = randf() * 10.0


func def() -> Dictionary:
	return Data.BUILDINGS[type]


func is_active() -> bool:
	return built and not ruined


func _process(delta: float) -> void:
	_t += delta
	var days := delta / Data.DAY_SECONDS
	if not built:
		progress += days / maxf(0.5, def().get("time", 6.0))
		if progress >= 1.0:
			progress = 1.0
			built = true
			if owner_id == Game.player and Game.world:
				Game.say("%s är färdigbyggd på %s." % [def()["name"], island.display_name], Color(0.7, 0.95, 0.7))
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
const WIDTH := {
	"radhus": 118.0, "akademi": 104.0, "fyrtorn": 66.0, "kanonbatteri": 96.0, "marknad": 100.0,
	"skeppsvarv": 108.0, "sandtakt": 90.0, "glasbruk": 80.0, "sockerplantage": 96.0, "kokosodling": 96.0,
}
## Var skorstenar och lampor sitter i bilden (andel av bredd/höjd från övre vänstra hörnet).
const SMOKE := {"romdestilleri": Vector2(0.44, 0.05), "glasbruk": Vector2(0.43, 0.03)}


func _rect(tex: Texture2D) -> Rect2:
	var w: float = WIDTH.get(type, 88.0)
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


func _draw() -> void:
	var tex: Texture2D = Art.building(type)
	if tex == null:
		return
	var r := _rect(tex)
	# Skugga under byggnaden
	draw_set_transform(Vector2(6, 2), 0.0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, r.size.x * 0.42, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	if not built:
		draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.15 + progress * 0.45))
		var sc: Texture2D = Art.deco("scaffold")
		if sc != null:
			var sw := r.size.x * 0.7
			var sh := sw * sc.get_height() / sc.get_width()
			draw_texture_rect(sc, Rect2(Vector2(-sw * 0.5, -sh * 0.85), Vector2(sw, sh)), false)
		draw_rect(Rect2(-24, 10, 48, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-24, 10, 48 * progress, 6), Color(0.95, 0.8, 0.3))
		return
	var mod := Color(0.55, 0.5, 0.48) if ruined else Color(1, 1, 1)
	draw_texture_rect(tex, r, false, mod)
	if SMOKE.has(type) and not ruined:
		var sp: Vector2 = SMOKE[type]
		_smoke(r.position + Vector2(r.size.x * sp.x, r.size.y * sp.y))
	match type:
		"radhus", "kanonbatteri", "skeppsvarv":
			_flag(r.position + Vector2(r.size.x * 0.86, r.size.y * 0.3), 26.0)
		"fyrtorn":
			var lamp := r.position + Vector2(r.size.x * 0.48, r.size.y * 0.13)
			var glow := 0.55 + 0.25 * sin(_t * 3.0)
			draw_circle(lamp, 10.0, Color(1, 0.95, 0.6, 0.35 * glow))
			var beam_a := _t * 1.1
			var beam := Vector2(cos(beam_a), sin(beam_a) * 0.4) * 140.0
			draw_colored_polygon(PackedVector2Array([lamp, lamp + beam + beam.orthogonal() * 0.12, lamp + beam - beam.orthogonal() * 0.12]), Color(1, 0.95, 0.6, 0.14))
		"kristallgruva":
			var g := 0.5 + 0.5 * sin(_t * 2.2 + _seed)
			draw_circle(r.position + Vector2(r.size.x * 0.55, r.size.y * 0.45), 18.0, Color(0.5, 0.95, 1.0, 0.12 * g))
	if ruined:
		_smoke(Vector2(0, -r.size.y * 0.3), Color(0.25, 0.25, 0.25))
		draw_circle(Vector2(-6, -r.size.y * 0.2), 6 + sin(_t * 9.0) * 1.5, Color(1, 0.5, 0.1, 0.85))
		draw_circle(Vector2(8, -r.size.y * 0.15), 4 + sin(_t * 7.0) * 1.5, Color(1, 0.7, 0.2, 0.8))
	if hp < max_hp - 1.0:
		draw_rect(Rect2(-22, 12, 44, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-22, 12, 44 * hp / max_hp, 5), Color(0.9, 0.3, 0.25))
