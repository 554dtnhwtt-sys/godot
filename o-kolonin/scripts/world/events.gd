extends Node
## Slumpade händelser (storm, pirater, handelsman) och endgame-kriser.
## Styr även de fientliga fraktionernas skepp (pirater, Spökflottan, Väktarna).

var world = null
var next_event := 70
var storm_left := 0
var ghost_waves_sent := 0
var ghost_next := -1
var ghost_done := false
var vaktarna_next := -1
const GHOST_WAVES := 6


func day_tick() -> void:
	var d := Game.day()
	_storm_tick()
	if d >= next_event:
		next_event = d + randi_range(60, 120)
		_random_event()
	_crises(d)
	if d % 3 == 0:
		_hostile_ships()


# ------------------------------------------------------------------ Storm
func _storm_tick() -> void:
	if storm_left > 0:
		storm_left -= 1
		Game.storm = minf(1.0, Game.storm + 0.2)
		if storm_left == 0:
			Game.say("The storm has passed.", Color(0.8, 0.9, 1))
	else:
		Game.storm = maxf(0.0, Game.storm - 0.15)


func start_storm(days: int) -> void:
	storm_left = days
	Game.say("A storm is sweeping over the Emerald Sea! Ships at sea take damage – seek shelter at your own islands.", Color(0.7, 0.8, 1))


# ------------------------------------------------------------------ Händelser
func _random_event() -> void:
	var pool := ["storm", "handelsman", "handelsman", "fiske", "skeppsbrutna"]
	if Game.time > 90.0:
		pool.append("pirater")
		pool.append("pirater")
	match pool[randi() % pool.size()]:
		"storm":
			start_storm(randi_range(10, 22))
		"pirater":
			_pirate_raid()
		"handelsman":
			_merchant()
		"fiske":
			var amount := 60.0 + Game.time * 0.1
			Game.add_res(Game.player, "mat", amount)
			Game.say("The fish shoals are unusually large this year. +%d food." % int(amount), Data.RESOURCE_COLORS["mat"])
		"skeppsbrutna":
			var gold := 50.0 + randi() % 80
			Game.add_res(Game.player, "guld", gold)
			Game.say("Your fishermen rescue shipwrecked sailors. They pay with %d gold from a salvaged chest." % int(gold), Data.RESOURCE_COLORS["guld"])


func _pirate_raid() -> void:
	var targets: Array = []
	for n in Game.nations:
		if Game.nations[n]["alive"] and n != "svartarevet":
			targets.append(n)
			if n == Game.player:
				targets.append(n)
	if targets.is_empty():
		return
	var tn: String = targets[randi() % targets.size()]
	var isls: Array = world.islands_of(tn)
	if isls.is_empty():
		return
	var target = isls[randi() % isls.size()]
	var count := mini(2 + int(Game.time / 400.0), 6)
	var spawn := _edge_point_near(target.position)
	for i in count:
		var t := "slup"
		var r := randf()
		if Game.time > 500.0 and r < 0.3:
			t = "brigg"
		elif Game.time > 200.0 and r < 0.6:
			t = "skonare"
		var s = world.spawn_ship(t, "vildpirater", spawn + Vector2(i * 60, (i % 2) * 50))
		s.order_attack_island(target)
	if tn == Game.player:
		Game.say("Pirates sighted! %d ships are sailing towards %s." % [count, target.display_name], Color(1, 0.5, 0.4))
		if world.hud:
			world.hud.show_message_popup("Pirates!", "The lookout shouts from the masthead: black sails on the horizon! %d pirate ships are heading for %s.\n\nGather your ships and build cannon batteries." % [count, target.display_name])
	else:
		Game.say("Pirates are raiding around %s (%s)." % [target.display_name, Data.nation_short(tn)], Color(0.85, 0.75, 0.65))


func _edge_point_near(p: Vector2) -> Vector2:
	var w := Data.WORLD_SIZE
	var options := [Vector2(80, p.y), Vector2(w.x - 80, p.y), Vector2(p.x, 80), Vector2(p.x, w.y - 80)]
	var best: Vector2 = options[0]
	for o in options:
		if o.distance_to(p) < best.distance_to(p):
			best = o
	# Inte för nära: minst 900 px bort
	var dir := (best - p).normalized()
	if best.distance_to(p) < 900.0:
		best = p + dir * 900.0
	best.x = clampf(best.x, 60.0, w.x - 60.0)
	best.y = clampf(best.y, 60.0, w.y - 60.0)
	return best


func _merchant() -> void:
	var p := Game.player
	var offers := [
		{"text": "Buy 25 crystals for 220 gold", "cost": {"guld": 220.0}, "gain": {"kristaller": 25.0}},
		{"text": "Sell 20 spices for 220 gold", "cost": {"kryddor": 20.0}, "gain": {"guld": 220.0}},
		{"text": "Sell 10 pearls for 240 gold", "cost": {"parlor": 10.0}, "gain": {"guld": 240.0}},
		{"text": "Buy 30 rum for 120 gold", "cost": {"guld": 120.0}, "gain": {"rom": 30.0}},
		{"text": "Buy 150 wood and 80 stone for 180 gold", "cost": {"guld": 180.0}, "gain": {"tra": 150.0, "sten": 80.0}},
		{"text": "Buy blueprints: finish your current research (300 gold)", "cost": {"guld": 300.0}, "gain": {}, "research": true},
		{"text": "Buy a sea chart that clears the fog (150 gold)", "cost": {"guld": 150.0}, "gain": {}, "map": true},
	]
	offers.shuffle()
	var buttons: Array = []
	for i in 3:
		var o: Dictionary = offers[i]
		var ok := Game.can_afford(p, o["cost"])
		if o.get("research", false) and Game.nations[p]["current_research"] == "":
			ok = false
		buttons.append({"text": o["text"], "disabled": not ok, "cb": _merchant_buy.bind(o)})
	buttons.append({"text": "No thanks", "cb": Callable()})
	if world.hud:
		world.hud.show_popup({
			"title": "A merchant arrives",
			"text": "A foreign merchant ship with silk sails drops anchor in your harbour. The captain, a sunburnt man with gold teeth, offers his wares:\n\n\"Today only, my friend – and only for you!\"",
			"buttons": buttons,
		})


func _merchant_buy(o: Dictionary) -> void:
	var p := Game.player
	if not Game.pay(p, o["cost"]):
		return
	for r in o["gain"]:
		Game.add_res(p, r, o["gain"][r])
	if o.get("research", false):
		var st: Dictionary = Game.nations[p]
		if st["current_research"] != "":
			st["research_progress"] = Data.research_cost(st["current_research"])
			Game.tick_research(p)
	if o.get("map", false):
		for isl in world.islands:
			if not world.fog.is_explored(isl.position):
				world.fog.reveal(isl.position, isl.radius + 400.0)
				Game.say("The sea chart reveals the way to %s." % isl.display_name, Color(0.8, 0.9, 1))
				break
		world.fog.commit()
	Game.resources_changed.emit()
	Game.say("The deal is done.", Color(1, 0.85, 0.4))


# ------------------------------------------------------------------ Kriser
func _crisis_time() -> float:
	return Data.CRISIS_TIMING[Game.settings["crisis_timing"]]["time"]


func _crises(d: int) -> void:
	var crises: Dictionary = Game.settings["crises"]
	var start := _crisis_time()
	# Spökflottan
	if crises.get("spokflottan", false) and not ghost_done:
		if not Game.active_crises.has("spokflottan") and Game.time >= start:
			Game.active_crises["spokflottan"] = true
			ghost_next = d + 10
			Game.say("The fog thickens and the sea turns cold. The Ghost Fleet has awoken!", Data.HOSTILE_FACTIONS["spokflottan"]["color"])
			if world.hud:
				world.hud.show_message_popup("The Ghost Fleet", Data.CRISES["spokflottan"]["desc"] + "\n\nThe Ghost Fleet attacks in %d waves. Every nation is in danger – perhaps it is time to forget old feuds?" % GHOST_WAVES)
		if Game.active_crises.has("spokflottan") and ghost_next >= 0 and d >= ghost_next:
			if ghost_waves_sent < GHOST_WAVES:
				_ghost_wave()
				ghost_waves_sent += 1
				ghost_next = d + 55
			elif world.ships_of("spokflottan").is_empty():
				ghost_done = true
				ghost_next = -1
				Game.say("The last ghostly crew has found peace. The Ghost Fleet is defeated!", Color(1, 0.9, 0.6))
				if world.hud:
					world.hud.show_message_popup("The Ghost Fleet is defeated", "The fog lifts and the sun breaks through. The dead sailors have finally found peace, and the Emerald Sea breathes again.")
	# De Sovande Väktarna vaknar
	if crises.get("vaktarna", false) and not Game.vaktarna_awake:
		var sol = world.island_by_id("solstenson")
		if sol != null and sol.owner_id == "vaktarna" and Game.time >= start * 1.2:
			Game.vaktarna_awake = true
			vaktarna_next = d + 5
			Game.say("Sunstone Isle lights up the night sky. The Sleeping Wardens have awoken!", Data.HOSTILE_FACTIONS["vaktarna"]["color"])
			if world.hud:
				world.hud.show_message_popup("The Wardens awaken", "A piercing light rises from the crystals of Sunstone Isle. The ancient Wardens have woken from their slumber and see all strangers as intruders.\n\nConquer Sunstone Isle to stop them.")
	if Game.vaktarna_awake and vaktarna_next >= 0 and d >= vaktarna_next:
		var sol = world.island_by_id("solstenson")
		if sol == null or sol.owner_id != "vaktarna":
			vaktarna_next = -1
			Game.say("The Wardens' crystals have gone dark. The threat from Sunstone Isle is over.", Color(1, 0.9, 0.6))
		else:
			vaktarna_next = d + 70
			if world.ships_of("vaktarna").size() < 8:
				for k in 2:
					world.spawn_ship("kristallskepp", "vaktarna", sol.coast_point_towards(sol.position + Vector2.from_angle(randf() * TAU) * 400.0, 60.0))


func _ghost_wave() -> void:
	var count := 2 + ghost_waves_sent
	var w := Data.WORLD_SIZE
	var edges := [Vector2(randf_range(400, w.x - 400), 80), Vector2(randf_range(400, w.x - 400), w.y - 80), Vector2(80, randf_range(400, w.y - 400)), Vector2(w.x - 80, randf_range(400, w.y - 400))]
	var spawn: Vector2 = edges[randi() % edges.size()]
	for i in count:
		world.spawn_ship("spokskepp", "spokflottan", spawn + Vector2((i % 3) * 70, (i / 3) * 70))
	Game.say("Ghost Fleet wave %d/%d (%d ships) rises from the fog!" % [ghost_waves_sent + 1, GHOST_WAVES, count], Data.HOSTILE_FACTIONS["spokflottan"]["color"])


func on_ship_sunk(_ship) -> void:
	pass


# ------------------------------------------------------------------ Fientliga skepp
func _hostile_ships() -> void:
	var sol = world.island_by_id("solstenson")
	for s in world.ships:
		if not s.is_alive() or s.order != "idle":
			continue
		match s.owner_id:
			"vildpirater", "spokflottan", "armadan", "djupkulten":
				var t = _nearest_target_island(s.owner_id, s.position)
				if t != null:
					s.order_attack_island(t)
			"vaktarna":
				if Game.vaktarna_awake:
					var t = _nearest_target_island("vaktarna", s.position)
					if t != null:
						s.order_attack_island(t)
				elif sol != null:
					# Patrullera runt Solstensön och jaga bort provokatörer.
					var intruder = world.nearest_hostile_ship("vaktarna", sol.position, 1100.0)
					if intruder != null:
						s.order_attack(intruder)
					else:
						s.order_move(sol.position + Vector2.from_angle(randf() * TAU) * (sol.radius + 220.0))


func _nearest_target_island(owner: String, p: Vector2):
	var best = null
	var bd := INF
	for isl in world.islands:
		if isl.owner_id == "neutral" or isl.owner_id == owner or not Game.at_war(owner, isl.owner_id):
			continue
		var d: float = isl.position.distance_to(p)
		if d < bd:
			bd = d
			best = isl
	return best
