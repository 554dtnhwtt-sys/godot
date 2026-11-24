extends Node2D
## Spelvärlden: öar, skepp, ekonomi (dag för dag), synfält, order och AI.

const IslandScript = preload("res://scripts/world/island.gd")
const ShipScript = preload("res://scripts/world/ship.gd")
const FxScript = preload("res://scripts/world/fx.gd")
const FogScript = preload("res://scripts/world/fog.gd")
const CameraScript = preload("res://scripts/world/camera.gd")
const OverlayScript = preload("res://scripts/world/overlay.gd")
const AIScript = preload("res://scripts/world/ai.gd")
const EventsScript = preload("res://scripts/world/events.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const AmbientScript = preload("res://scripts/world/ambient.gd")
const GovernorScript = preload("res://scripts/world/governor.gd")
const Governor = GovernorScript

## Flottans formation när skepp får en förflyttningsorder: linje, kil, spridd.
const FORMATIONS := {"linje": "Linje", "kil": "Kil", "spridd": "Spridd"}

signal selection_changed
signal ended(winner: String)

var islands: Array = []
var ships: Array = []
var selected_ships: Array = []
var selected_island = null
var fx = null
var fog = null
var cam: Camera2D = null
var hud = null
var events = null
var overlay = null
var objects: Node2D = null
var ais := {}
var markers: Array = []
var dragging := false
var drag_from := Vector2.ZERO
var drag_to := Vector2.ZERO
var _last_day := -1
var _vision_t := 0.0
var _wind_target := 0.0
var _player_dead_announced := false
var formation := "linje"


func _ready() -> void:
	Game.world = self
	_wind_target = Game.wind_angle
	var ocean := ColorRect.new()
	ocean.position = Vector2(-1000, -1000)
	ocean.size = Data.WORLD_SIZE + Vector2(2000, 2000)
	ocean.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var omat := ShaderMaterial.new()
	omat.shader = load("res://shaders/ocean.gdshader")
	omat.set_shader_parameter("size", ocean.size)
	ocean.material = omat
	ocean.z_index = -20
	add_child(ocean)
	var ground := Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	objects = Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	add_child(objects)
	fx = FxScript.new()
	fx.world = self
	fx.z_index = 5
	add_child(fx)
	var amb := AmbientScript.new()
	amb.world = self
	add_child(amb)
	fog = FogScript.new()
	add_child(fog)
	fog.setup()
	overlay = OverlayScript.new()
	overlay.world = self
	overlay.z_index = 30
	add_child(overlay)
	for def in Data.ISLANDS:
		var isl := IslandScript.new()
		ground.add_child(isl)
		isl.setup(def, self, objects)
		islands.append(isl)
	_setup_nations()
	cam = CameraScript.new()
	add_child(cam)
	cam.make_current()
	var home = island_by_id(Data.NATIONS[Game.player]["home"])
	cam.focus(home.position + Vector2(0, 60))
	for n in Game.nations:
		if Game.nations[n]["ai"]:
			var ai := AIScript.new()
			ai.setup(n, self)
			ais[n] = ai
	events = EventsScript.new()
	events.world = self
	add_child(events)
	hud = HudScript.new()
	hud.world = self
	add_child(hud)
	_update_vision()
	Game.set_speed(0)
	Game.say("Välkommen till %s, %s. Året är %d." % [Data.SEA_NAME, Data.NATIONS[Game.player]["leader"], Data.START_YEAR], Data.nation_accent(Game.player))


func _setup_nations() -> void:
	for n in Game.nations:
		var def: Dictionary = Data.NATIONS[n]
		var isl = island_by_id(def["home"])
		isl.set_owner_id(n)
		isl.add_building("radhus", true)
		isl.add_building("skeppsvarv", true)
		isl.add_building("skogshuggare", true)
		isl.add_building("kokosodling", true)
		isl.add_building("bosattning", true)
		isl.garrison = isl.max_garrison()
		isl.store = {"tra": 160.0, "mat": 140.0, "sten": 40.0}
		isl.population = 26.0
		var i := 0
		for st in def["start_ships"]:
			var p: Vector2 = isl.coast_point_towards(Data.WORLD_SIZE * 0.5 + Vector2(i * 40, i * 30), 50.0)
			spawn_ship(st, n, p + Vector2(i * 50, i * 20))
			i += 1
	# Väktarna finns från start om krisen är påslagen.
	var sol = island_by_id("solstenson")
	if Game.settings["crises"].get("vaktarna", false):
		sol.set_owner_id("vaktarna")
		sol.add_building("radhus", true)
		sol.add_building("kanonbatteri", true)
		sol.add_building("kanonbatteri", true)
		sol.add_building("akademi", true)
		sol.garrison = sol.max_garrison()
		for k in 3:
			var s = spawn_ship("kristallskepp", "vaktarna", sol.coast_point_towards(sol.position + Vector2.from_angle(k * TAU / 3.0) * 500.0, 60.0))
			s.ai_role = "guard"


# ------------------------------------------------------------------ Uppslag
func island_by_id(id: String):
	for isl in islands:
		if isl.id == id:
			return isl
	return null


func islands_of(nation: String) -> Array:
	var out: Array = []
	for isl in islands:
		if isl.owner_id == nation:
			out.append(isl)
	return out


func ships_of(nation: String) -> Array:
	var out: Array = []
	for s in ships:
		if s.owner_id == nation and s.is_alive():
			out.append(s)
	return out


func count_buildings(nation: String, type: String) -> int:
	var c := 0
	for isl in islands:
		if isl.owner_id != nation:
			continue
		for b in isl.buildings:
			if b.type == type:
				c += 1
	return c


func nation_strength(nation: String) -> float:
	var s := 0.0
	for sh in ships:
		if sh.owner_id == nation and sh.is_alive():
			s += sh.hp * (1.0 + sh.def["cannons"] * 0.12)
	for isl in islands:
		if isl.owner_id == nation:
			s += 150.0 + isl.garrison * 2.0
			for b in isl.buildings:
				if b.is_active() and Data.BUILDINGS[b.type].has("fort"):
					s += 80.0
	return s


func nearest_hostile_ship(owner: String, pos: Vector2, max_dist: float, _exclude = null):
	var best = null
	var bd := max_dist
	for s in ships:
		if not s.is_alive() or s.owner_id == owner:
			continue
		if not Game.at_war(owner, s.owner_id):
			continue
		var d: float = s.position.distance_to(pos)
		if d < bd:
			bd = d
			best = s
	return best


func nearest_own_island(owner: String, pos: Vector2, margin: float):
	for isl in islands:
		if isl.owner_id == owner and pos.distance_to(isl.position) < isl.radius + margin:
			return isl
	return null


func island_fort_target(isl, from: Vector2):
	var best = null
	var bd := INF
	for b in isl.buildings:
		if b.is_active() and Data.BUILDINGS[b.type].has("fort"):
			var d: float = b.global_position.distance_to(from)
			if d < bd:
				bd = d
				best = b
	return best


func island_at(p: Vector2):
	for isl in islands:
		if isl.contains_world_point(p):
			return isl
	return null


func ship_at(p: Vector2, only_visible: bool = true):
	var best = null
	var bd := 38.0
	for s in ships:
		if not s.is_alive() or (only_visible and not s.visible):
			continue
		var d: float = (s.position + Vector2(0, -16 * s.size_f)).distance_to(p)
		if d < bd * s.size_f:
			bd = d / s.size_f
			best = s
	return best


# ------------------------------------------------------------------ Handlingar
func spawn_ship(type: String, owner: String, pos: Vector2):
	var s := ShipScript.new()
	s.setup(type, owner, pos, self)
	objects.add_child(s)
	ships.append(s)
	return s


func remove_ship(s) -> void:
	ships.erase(s)
	selected_ships.erase(s)
	s.queue_free()


func build(nation: String, isl, type: String) -> bool:
	if isl.owner_id != nation or not Game.building_unlocked(nation, type) or not isl.can_build_type(type):
		return false
	var cost := Game.building_cost(nation, type)
	if not Game.pay_at(nation, isl, cost):
		return false
	isl.add_building(type)
	return true


func queue_ship(nation: String, isl, type: String) -> bool:
	if isl.owner_id != nation or not isl.has_shipyard() or not Game.ship_unlocked(nation, type):
		return false
	if isl.ship_queue.size() >= 5:
		return false
	if not Game.pay_at(nation, isl, Game.ship_cost(nation, type)):
		return false
	isl.ship_queue.append({"type": type, "left": float(Data.SHIPS[type]["time"])})
	return true


func try_colonize(ship, isl) -> void:
	var n: String = ship.owner_id
	if not Game.is_playable(n) or isl.owner_id != "neutral":
		return
	if isl.guardians:
		return
	var cost := Game.colonize_cost(n)
	if not Game.pay_at(n, home_island(n), cost):
		if n == Game.player:
			Game.say("Inte råd att kolonisera %s (kräver %s)." % [isl.display_name, Data.cost_text(cost)], Color(1, 0.6, 0.5))
		return
	isl.set_owner_id(n)
	isl.add_building("radhus", true)
	isl.garrison = isl.max_garrison() * 0.5
	# Nybyggarna tar med sig förnödenheter från skeppet.
	isl.population = 6.0
	isl.store = {"tra": 50.0, "mat": 50.0}
	for g in ship.cargo:
		isl.add_good(g, ship.cargo[g])
	ship.cargo = {}
	fx.text(isl.position, "Koloniserad!", Data.nation_color(n).lightened(0.4))
	if n == Game.player:
		Game.say("%s är nu din koloni! Bygg en handelsrutt dit för full produktion." % isl.display_name, Color(0.6, 1, 0.7))
	else:
		Game.say("%s har koloniserat %s." % [Data.nation_short(n), isl.display_name], Color(0.8, 0.8, 0.75))
	# Väktarna ogillar nybyggare nära Solstensön.
	var sol = island_by_id("solstenson")
	if sol != null and sol.owner_id == "vaktarna" and isl.position.distance_to(sol.position) < 1000.0:
		Game.vaktarna_angry[n] = true
		Game.say("De Sovande Väktarna har märkt att %s byggt nära Solstensön. De är nu fientliga mot dem!" % Data.nation_short(n), Data.HOSTILE_FACTIONS["vaktarna"]["color"])


func land_troops(ship, isl) -> void:
	if ship.troops < 1.0:
		return
	var power: float = ship.troops * ship.fleet_mod("troops")
	ship.troops = 0.0
	isl.last_attacked = Game.time
	fx.text(isl.coast_point_towards(ship.position, -40.0), "Landstigning!", Color(1, 0.85, 0.5))
	if power > isl.garrison:
		capture_island(isl, ship.owner_id, power - isl.garrison)
	else:
		isl.garrison -= power


func capture_island(isl, new_owner: String, garrison: float) -> void:
	var old: String = isl.owner_id
	isl.set_owner_id(new_owner)
	isl.garrison = garrison
	isl.ship_queue.clear()
	isl.trade_until = -1.0
	for b in isl.buildings:
		if b.built:
			b.hp = maxf(b.hp, b.max_hp * 0.3)
	if new_owner == Game.player:
		Game.say("Du har erövrat %s från %s!" % [isl.display_name, Data.nation_short(old)], Color(0.6, 1, 0.6))
	elif old == Game.player:
		Game.say("%s har erövrat %s från dig!" % [Data.nation_short(new_owner), isl.display_name], Color(1, 0.45, 0.4))
	else:
		Game.say("%s har erövrat %s från %s." % [Data.nation_short(new_owner), isl.display_name, Data.nation_short(old)], Color(0.85, 0.8, 0.7))
	if Game.is_playable(old) and Game.is_playable(new_owner):
		Game.change_relation(old, new_owner, -20.0)
	if old == "vaktarna":
		Game.say("Solstensöns uråldriga kristaller tillhör nu %s." % Data.nation_short(new_owner), Data.HOSTILE_FACTIONS["vaktarna"]["color"])
	_check_elimination()


# ------------------------------------------------------------------ Handel och frakt
## Startar en handelsrutt: lastar direkt i startön och seglar mot målet.
func start_trade(ship, a, b) -> void:
	ship.order_trade(a, b)
	_load_cargo(ship, a, b)


func trade_arrival(ship, isl) -> void:
	var n: String = ship.owner_id
	var delivered := 0.0
	for g in ship.cargo.keys():
		delivered += isl.add_good(g, ship.cargo[g])
	ship.cargo = {}
	var other = ship.trade_a if isl == ship.trade_b else ship.trade_b
	if other != null:
		_load_cargo(ship, isl, other)
	var was: bool = isl.trade_connected()
	isl.trade_until = Game.time + 60.0
	var gold := 4.0 * Game.mod(n, "trade")
	Game.add_res(n, "guld", gold)
	if n == Game.player:
		if delivered >= 1.0:
			fx.text(isl.position + Vector2(0, -40), "+%d varor levererade" % int(delivered), Color(1, 0.9, 0.6))
		if not was and isl.home_of != n:
			Game.say("Handelsrutten till %s är igång." % isl.display_name, Color(1, 0.85, 0.4))


## Hur mycket en ö vill behålla av en vara innan den skickar bort överskott.
func _reserve(isl, g: String) -> float:
	var home: bool = isl.home_of != "" and isl.home_of == isl.owner_id
	if g == "mat":
		return maxf(30.0, isl.population * Data.FOOD_PER_POP * 30.0) + (60.0 if home else 0.0)
	if g in ["tra", "sten", "sand"]:
		return 100.0 if home else 40.0
	if g == "socker" and Governor.count_on(isl, "romdestilleri") > 0:
		return 40.0
	return 0.0


## Automatisk lastning: överskott skickas till hemön, kolonier får byggvaror och mat de behöver.
func _load_cargo(ship, from, to) -> void:
	var space: float = ship.cargo_cap() - ship.cargo_total()
	if space <= 1.0:
		return
	var to_home: bool = to.home_of != "" and to.home_of == to.owner_id
	var wants: Array = []
	for g in Data.GOODS:
		var surplus: float = from.good(g) - _reserve(from, g)
		if surplus < 1.0:
			continue
		var amount := surplus
		if not to_home:
			var target := 160.0 if g in ["tra", "sten", "mat", "sand"] else 0.0
			if g == "mat" and to.starving:
				target = 250.0
			amount = minf(surplus, maxf(0.0, target - to.good(g)))
		if amount >= 1.0:
			wants.append([g, amount])
	wants.sort_custom(func(x, y): return x[1] > y[1])
	for w in wants:
		if space < 1.0:
			break
		var take: float = minf(w[1], space)
		from.add_good(w[0], -take)
		ship.cargo[w[0]] = ship.cargo.get(w[0], 0.0) + take
		space -= take


func on_ship_sunk(ship, attacker: String, src = null) -> void:
	selected_ships.erase(ship)
	fx.splash(ship.position, 2.0)
	var plunder := attacker != "" and Game.mod(attacker, "plunder") > 0.0
	if src != null and is_instance_valid(src) and src._fleet_mods.has("plunder"):
		plunder = true
	if plunder:
		var loot: float = 25.0 + ship.max_hp * 0.15
		Game.add_res(attacker, "guld", loot)
		var got := 0.0
		if src != null and is_instance_valid(src):
			for g in ship.cargo:
				var take: float = minf(ship.cargo[g], src.cargo_cap() - src.cargo_total())
				if take > 0.0:
					src.cargo[g] = src.cargo.get(g, 0.0) + take
					got += take
		if attacker == Game.player:
			fx.text(ship.position, "+%d guld (plundring)%s" % [int(loot), (" +%d last" % int(got)) if got >= 1.0 else ""], Data.RESOURCE_COLORS["guld"])
	if ship.admiral != null:
		_admiral_lost(ship)
	if ship.owner_id == Game.player:
		Game.say("Din %s har sjunkit!" % ship.display_name().to_lower(), Color(1, 0.5, 0.45))
	elif attacker == Game.player:
		Game.say("Ni sänkte %ss %s." % [Data.nation_short(ship.owner_id), ship.display_name().to_lower()], Color(0.7, 1, 0.7))
	if events:
		events.on_ship_sunk(ship)
	selection_changed.emit()
	_check_elimination()


# ------------------------------------------------------------------ Amiraler och uppgraderingar
func admiral_cost(nation: String) -> float:
	if not Game.is_playable(nation):
		return 0.0
	return Data.ADMIRAL_COST * (1.0 + Game.nations[nation]["admirals"].size() * 0.5)


func free_admirals(nation: String) -> Array:
	var out: Array = []
	if Game.is_playable(nation):
		for a in Game.nations[nation]["admirals"]:
			if not a.get("assigned", false):
				out.append(a)
	return out


func recruit_admiral(ship) -> bool:
	var n: String = ship.owner_id
	if ship.admiral != null or not Game.is_playable(n):
		return false
	var cost := admiral_cost(n)
	if Game.res(n, "guld") < cost:
		return false
	Game.add_res(n, "guld", -cost)
	var used: Array = []
	for a in Game.nations[n]["admirals"]:
		used.append(a["name"])
	var names: Array = Data.ADMIRAL_NAMES.get(n, ["Kapten Okänd"]).duplicate()
	names.shuffle()
	var name: String = names[0]
	for nm in names:
		if not nm in used:
			name = nm
			break
	var traits: Array = Data.ADMIRAL_TRAITS.keys()
	traits.shuffle()
	var adm := {"name": name, "traits": traits.slice(0, 1 + (randi() % 2)), "assigned": false}
	Game.nations[n]["admirals"].append(adm)
	assign_admiral(ship, adm)
	if n == Game.player:
		var tn: Array = []
		for t in adm["traits"]:
			tn.append(Data.ADMIRAL_TRAITS[t]["name"])
		Game.say("%s (%s) tar befälet över flottan." % [name, ", ".join(tn)], Color(1, 0.9, 0.6))
	Game.resources_changed.emit()
	return true


func assign_admiral(ship, adm: Dictionary) -> void:
	if ship.admiral != null:
		ship.admiral["assigned"] = false
	adm["assigned"] = true
	ship.admiral = adm
	ship._fleet_t = 0.0


func _admiral_lost(ship) -> void:
	var adm: Dictionary = ship.admiral
	ship.admiral = null
	if not Game.is_playable(ship.owner_id):
		return
	if randf() < 0.6:
		adm["assigned"] = false
		if ship.owner_id == Game.player:
			Game.say("%s räddade sig i en jolle och väntar på ett nytt skepp." % adm["name"], Color(1, 0.85, 0.6))
	else:
		Game.nations[ship.owner_id]["admirals"].erase(adm)
		if ship.owner_id == Game.player:
			Game.say("%s gick under med sitt skepp." % adm["name"], Color(1, 0.5, 0.45))


## Ön med skeppsvarv där skeppet kan uppgraderas (måste ligga nära), annars null.
func upgrade_island(ship):
	for isl in islands:
		if isl.owner_id == ship.owner_id and isl.has_shipyard() and ship.position.distance_to(isl.position) < isl.radius + 280.0:
			return isl
	return null


func upgrade_ship(ship, key: String) -> bool:
	if ship.upgrades.has(key):
		return false
	var isl = upgrade_island(ship)
	if isl == null:
		return false
	if not Game.pay_at(ship.owner_id, isl, Data.UPGRADES[key]["cost"]):
		return false
	ship.apply_upgrade(key)
	if ship.owner_id == Game.player:
		Game.say("%s: %s på %s." % [Data.UPGRADES[key]["name"], ship.display_name().to_lower(), isl.display_name], Color(0.7, 0.9, 1))
	return true


func on_war_declared(_a: String, _b: String) -> void:
	if hud:
		hud.refresh_panels()


func _check_elimination() -> void:
	for n in Game.nations:
		var st: Dictionary = Game.nations[n]
		if not st["alive"]:
			continue
		if islands_of(n).size() == 0:
			st["alive"] = false
			for s in ships_of(n):
				s.take_damage(99999.0, "")
			if n == Game.player:
				Game.say("Din nation har fallit. Du kan fortsätta titta på eller starta ett nytt spel.", Color(1, 0.4, 0.4))
				if hud:
					hud.show_message_popup("Nationen har fallit", "Alla dina öar är förlorade. %s är inte längre en makt i Smaragdhavet." % Data.nation_name(Game.player))
			else:
				Game.say("%s har fallit och är inte längre en makt i Smaragdhavet." % Data.nation_name(n), Color(1, 0.8, 0.4))


# ------------------------------------------------------------------ Uppdatering
func _process(delta: float) -> void:
	Game.time += delta / Data.DAY_SECONDS
	var d := Game.day()
	if d != _last_day:
		_last_day = d
		_day_tick()
	_vision_t -= delta
	if _vision_t <= 0.0:
		_vision_t = 0.25
		_update_vision()
	_update_wind(delta)
	var i := 0
	while i < markers.size():
		markers[i]["t"] -= delta / maxf(0.001, Engine.time_scale)
		if markers[i]["t"] <= 0.0:
			markers.remove_at(i)
		else:
			i += 1


func _update_wind(delta: float) -> void:
	var days := delta / Data.DAY_SECONDS
	Game.wind_angle = rotate_toward(Game.wind_angle, _wind_target, 0.02 * days)
	if Game.storm > 0.0:
		Game.wind_strength = lerpf(Game.wind_strength, 1.4 + Game.storm * 0.6, 0.02)


func _day_tick() -> void:
	if Game.day() % 25 == 0:
		_wind_target = Game.wind_angle + randf_range(-1.2, 1.2)
		if Game.storm <= 0.0:
			Game.wind_strength = randf_range(0.6, 1.4)
	_economy_day()
	for n in ais:
		if Game.nations[n]["alive"]:
			ais[n].day_tick()
	if Game.day() % 15 == 0:
		Game.diplomacy_tick()
	events.day_tick()


func _economy_day() -> void:
	var rates := {}
	for n in Game.nations:
		rates[n] = {}
	for isl in islands:
		var n: String = isl.owner_id
		if not Game.is_playable(n):
			if isl.owner_id != "neutral":
				isl.garrison = move_toward(isl.garrison, isl.max_garrison(), 1.0)
			continue
		var r: Dictionary = rates[n]
		var ir := {}
		# Befolkningen äter, betalar skatt och växer eller krymper.
		var food_need: float = isl.population * Data.FOOD_PER_POP
		var food_have: float = isl.good("mat")
		var housing: float = isl.housing()
		if food_have >= food_need:
			isl.add_good("mat", -food_need)
			ir["mat"] = -food_need
			if isl.population < housing:
				isl.population = minf(housing, isl.population + maxf(0.4, housing * 0.025))
			if isl.starving and n == Game.player:
				Game.say("Invånarna på %s har mat igen." % isl.display_name, Color(0.7, 1, 0.7))
			isl.starving = false
		else:
			isl.add_good("mat", -food_have)
			ir["mat"] = -food_have
			isl.population = maxf(0.0, isl.population - maxf(0.5, isl.population * 0.03))
			if not isl.starving and n == Game.player:
				Game.say("Svält på %s! Invånarna flyttar. Bygg kokosodlingar eller fiskehyddor, eller frakta dit mat." % isl.display_name, Color(1, 0.55, 0.45))
			isl.starving = true
		if isl.population > housing:
			isl.population = maxf(housing, isl.population - 1.0)
		var tax: float = isl.population * Data.TAX_PER_POP * Game.prod_mod(n, "guld")
		Game.add_res(n, "guld", tax)
		ir["guld"] = tax
		# Byggnaderna producerar efter hur många arbetare som finns.
		var eff: float = isl.work_efficiency()
		for b in isl.buildings:
			if not b.is_active():
				continue
			var bd: Dictionary = Data.BUILDINGS[b.type]
			var cons: Dictionary = bd.get("consumes", {})
			var ok := true
			for c in cons:
				if isl.good(c) < cons[c] * eff:
					ok = false
			if not ok:
				continue
			for c in cons:
				isl.add_good(c, -cons[c] * eff)
				ir[c] = ir.get(c, 0.0) - cons[c] * eff
			for pr in bd["prod"]:
				var amount: float = bd["prod"][pr] * Game.prod_mod(n, pr) * eff
				if pr == "guld" and bd.get("market", false):
					amount *= Game.mod(n, "trade")
				if Game.is_national(pr):
					Game.add_res(n, pr, amount)
				else:
					amount = isl.add_good(pr, amount)
				ir[pr] = ir.get(pr, 0.0) + amount
			if bd.get("market", false):
				for lux in Data.LUXURY_PRICES:
					var have: float = isl.good(lux)
					if have > Data.LUXURY_RESERVE:
						var sell: float = minf(0.5 * eff, have - Data.LUXURY_RESERVE)
						var gold: float = sell * Data.LUXURY_PRICES[lux] * Game.mod(n, "trade")
						isl.add_good(lux, -sell)
						Game.add_res(n, "guld", gold)
						ir[lux] = ir.get(lux, 0.0) - sell
						ir["guld"] = ir.get("guld", 0.0) + gold
		isl.rates = ir
		for k in ir:
			r[k] = r.get(k, 0.0) + ir[k]
		isl.garrison = move_toward(isl.garrison, isl.max_garrison(), 0.5 + isl.max_garrison() * 0.01)
		# Skeppsvarvets kö
		if isl.ship_queue.size() > 0 and isl.has_shipyard():
			var q: Dictionary = isl.ship_queue[0]
			q["left"] -= 1.0
			if q["left"] <= 0.0:
				isl.ship_queue.pop_front()
				var yard = isl.shipyard_building()
				var at: Vector2 = isl.coast_point_towards(yard.global_position + (yard.global_position - isl.position) * 2.0, 40.0)
				var s = spawn_ship(q["type"], n, at)
				if n == Game.player:
					Game.say("En ny %s har sjösatts på %s." % [s.display_name().to_lower(), isl.display_name], Color(0.6, 0.85, 1))
				elif ais.has(n):
					ais[n].on_ship_built(s)
		# Guvernören bygger på spelarens öar
		if n == Game.player and isl.governor and Game.day() % 3 == 0:
			var t: String = GovernorScript.choose(n, isl, self, isl.governor_focus, 120.0)
			if t != "" and build(n, isl, t):
				Game.say("Guvernören på %s bygger %s." % [isl.display_name, Data.BUILDINGS[t]["name"].to_lower()], Color(0.8, 0.85, 0.75))
	# Handelsavtal mellan nationer
	for k in Game.relations:
		var rel: Dictionary = Game.relations[k]
		if rel["status"] == "handel" or rel["status"] == "allians":
			for n in k.split("|"):
				if Game.nations[n]["alive"]:
					var g := 1.5 * Game.mod(n, "trade")
					Game.add_res(n, "guld", g)
					rates[n]["guld"] = rates[n].get("guld", 0.0) + g
	# Underhåll: skeppen äter mat från närmaste egna ö (annars hemön)
	for s in ships:
		if s.is_alive() and Game.is_playable(s.owner_id):
			var food: float = 0.08 * s.size_f
			var src = nearest_own_island(s.owner_id, s.position, 600.0)
			if src == null:
				src = home_island(s.owner_id)
			if src == null or src.good("mat") < food:
				s.hp = maxf(1.0, s.hp - s.max_hp * 0.01)
			else:
				src.add_good("mat", -food)
				rates[s.owner_id]["mat"] = rates[s.owner_id].get("mat", 0.0) - food
	for n in Game.nations:
		if Game.nations[n]["alive"]:
			Game.tick_research(n)
	Game.rates = rates
	Game.resources_changed.emit()


func home_island(nation: String):
	var first = null
	for isl in islands:
		if isl.owner_id == nation:
			if isl.home_of == nation:
				return isl
			if first == null:
				first = isl
	return first


func total_population(nation: String) -> float:
	var p := 0.0
	for isl in islands:
		if isl.owner_id == nation:
			p += isl.population
	return p


func _update_vision() -> void:
	var p := Game.player
	var vm := Game.mod(p, "vision")
	var sources: Array = []
	for s in ships:
		if s.owner_id == p and s.is_alive():
			sources.append([s.position, 520.0 * vm])
	for isl in islands:
		if isl.owner_id == p or (Game.is_playable(isl.owner_id) and Game.status(p, isl.owner_id) == "allians"):
			sources.append([isl.position, (isl.radius + 420.0) * vm])
			for b in isl.buildings:
				if b.is_active() and Data.BUILDINGS[b.type].has("vision"):
					sources.append([b.global_position, Data.BUILDINGS[b.type]["vision"] * vm])
	for s in ships:
		if s.is_alive() and s.owner_id != p and Game.is_playable(s.owner_id) and Game.status(p, s.owner_id) == "allians":
			sources.append([s.position, 450.0])
	for src in sources:
		fog.reveal(src[0], src[1])
	fog.commit()
	for s in ships:
		if s.owner_id == p:
			s.visible = true
			continue
		var seen := false
		for src in sources:
			if s.position.distance_to(src[0]) < src[1] * 0.92:
				seen = true
				break
		s.visible = seen


# ------------------------------------------------------------------ Inmatning
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var wp := get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				drag_from = wp
				drag_to = wp
			elif dragging:
				dragging = false
				drag_to = wp
				if drag_from.distance_to(drag_to) < 10.0 / cam.zoom.x:
					_click_select(wp, mb.shift_pressed)
				else:
					_box_select(Rect2(drag_from, Vector2.ZERO).expand(drag_to), mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_right_click(wp)
	elif event is InputEventMouseMotion and dragging:
		drag_to = get_global_mouse_position()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_SPACE:
				Game.toggle_pause()
			KEY_1:
				Game.set_speed(0)
			KEY_2:
				Game.set_speed(1)
			KEY_3:
				Game.set_speed(2)
			KEY_4:
				Game.set_speed(3)
			KEY_H:
				var home = island_by_id(Data.NATIONS[Game.player]["home"])
				cam.focus(home.position)
			KEY_ESCAPE:
				if selected_ships.size() > 0 or selected_island != null:
					clear_selection()
				else:
					hud.toggle_menu()
			KEY_A:
				if k.ctrl_pressed:
					clear_selection()
					for s in ships_of(Game.player):
						s.selected = true
						selected_ships.append(s)
					selection_changed.emit()


func clear_selection() -> void:
	for s in selected_ships:
		if is_instance_valid(s):
			s.selected = false
	selected_ships.clear()
	if selected_island != null:
		selected_island.selected = false
	selected_island = null
	selection_changed.emit()


func select_island(isl) -> void:
	clear_selection()
	selected_island = isl
	isl.selected = true
	selection_changed.emit()


func _click_select(wp: Vector2, add: bool) -> void:
	var s = ship_at(wp)
	if s != null and s.owner_id == Game.player:
		if not add:
			clear_selection()
		if s in selected_ships and add:
			s.selected = false
			selected_ships.erase(s)
		else:
			s.selected = true
			selected_ships.append(s)
		selection_changed.emit()
		return
	var isl = island_at(wp)
	if isl != null and fog.is_explored(isl.position):
		select_island(isl)
		return
	if s != null:
		clear_selection()
		hud.show_ship_info(s)
		return
	clear_selection()


func _box_select(r: Rect2, add: bool) -> void:
	if not add:
		clear_selection()
	for s in ships_of(Game.player):
		if r.has_point(s.position) and not s in selected_ships:
			s.selected = true
			selected_ships.append(s)
	selection_changed.emit()


func _right_click(wp: Vector2) -> void:
	if selected_ships.is_empty():
		return
	var p := Game.player
	var target = ship_at(wp)
	if target != null and target.owner_id != p:
		if Game.at_war(p, target.owner_id):
			for s in selected_ships:
				s.order_attack(target)
			_marker(target.position, Color(1, 0.3, 0.25))
		elif target.owner_id == "vaktarna":
			_provoke_vaktarna(p)
			for s in selected_ships:
				s.order_attack(target)
			_marker(target.position, Color(1, 0.3, 0.25))
		else:
			Game.say("Ni är inte i krig med %s. Förklara krig i Diplomati-fönstret (D)." % Data.nation_short(target.owner_id), Color(1, 0.8, 0.5))
		return
	var isl = island_at(wp)
	if isl != null:
		if isl.owner_id == p:
			_order_own_island(isl)
		elif isl.owner_id == "neutral":
			if isl.guardians:
				Game.say("Solstensön är helig mark. Ingen kan kolonisera den.", Color(1, 0.8, 0.5))
				return
			var cs = _best_colonizer()
			cs.order_colonize(isl)
			for s in selected_ships:
				if s != cs:
					s.order_move(isl.coast_point_towards(s.position, 120.0))
			Game.say("Skickar %s för att kolonisera %s (kostar %s)." % [cs.display_name().to_lower(), isl.display_name, Data.cost_text(Game.colonize_cost(p))], Color(0.8, 0.95, 0.8))
			_marker(isl.position, Color(0.5, 1, 0.6))
		elif isl.owner_id == "vaktarna" and not Game.at_war(p, "vaktarna"):
			_provoke_vaktarna(p)
			for s in selected_ships:
				s.order_attack_island(isl)
			_marker(isl.position, Color(1, 0.3, 0.25))
		elif Game.at_war(p, isl.owner_id):
			for s in selected_ships:
				s.order_attack_island(isl)
			_marker(isl.position, Color(1, 0.3, 0.25))
			Game.say("Anfall mot %s! Skeppen skjuter sönder försvaret och landstiger sedan." % isl.display_name, Color(1, 0.75, 0.5))
		else:
			for s in selected_ships:
				s.order_move(isl.coast_point_towards(s.position, 120.0))
			Game.say("Ni är inte i krig med %s." % Data.nation_short(isl.owner_id), Color(1, 0.8, 0.5))
		return
	# Vatten: förflyttning i formation
	order_formation_move(selected_ships, wp)
	_marker(wp, Color(0.6, 1, 0.6))


## Flyttar en grupp skepp i vald formation. Flottan håller ihop genom att alla
## seglar i det långsammaste skeppets fart.
func order_formation_move(group: Array, wp: Vector2) -> void:
	var n := group.size()
	if n == 0:
		return
	var center := Vector2.ZERO
	var slowest := INF
	for s in group:
		center += s.position
		slowest = minf(slowest, s.def["speed"])
	center /= n
	var dir := (wp - center)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	var side := dir.orthogonal()
	# Skeppet närmast målet leder.
	var ordered := group.duplicate()
	ordered.sort_custom(func(a, b): return a.position.distance_to(wp) < b.position.distance_to(wp))
	var cols := int(ceilf(sqrt(float(n))))
	for i in n:
		var s = ordered[i]
		var off := Vector2.ZERO
		match formation:
			"linje":
				off = -dir * i * 100.0
			"kil":
				var k := (i + 1) / 2
				var sgn := 1.0 if i % 2 == 1 else -1.0
				off = -dir * k * 85.0 + side * sgn * k * 80.0
			"spridd":
				var row := i / cols
				var col := i % cols
				off = side * (col - (cols - 1) * 0.5) * 150.0 - dir * row * 150.0
		s.order_move(wp + off)
		s.speed_cap = clampf(slowest / s.def["speed"], 0.3, 1.0) if n > 1 else 1.0


func _order_own_island(isl) -> void:
	for s in selected_ships:
		if s.def.get("trade", false):
			var start = nearest_own_island(Game.player, s.position, 500.0)
			if start != null and start != isl:
				start_trade(s, start, isl)
				Game.say("Handelsrutt: %s ⇄ %s" % [start.display_name, isl.display_name], Color(1, 0.85, 0.4))
				continue
		s.order_move(isl.coast_point_towards(s.position, 90.0))
	_marker(isl.position, Color(0.6, 0.85, 1))


func _best_colonizer():
	var best = selected_ships[0]
	for s in selected_ships:
		if s.def["speed"] > best.def["speed"]:
			best = s
	return best


func _provoke_vaktarna(p: String) -> void:
	if not Game.vaktarna_angry.has(p):
		Game.vaktarna_angry[p] = true
		Game.say("Du har väckt De Sovande Väktarnas vrede!", Data.HOSTILE_FACTIONS["vaktarna"]["color"])


func _marker(p: Vector2, c: Color) -> void:
	markers.append({"p": p, "t": 0.8, "c": c})
