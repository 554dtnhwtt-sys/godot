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
		Game.storm = min(1.0, Game.storm + 0.2)
		if storm_left == 0:
			Game.say("Stormen har bedarrat.", Color(0.8, 0.9, 1))
	else:
		Game.storm = max(0.0, Game.storm - 0.15)


func start_storm(days: int) -> void:
	storm_left = days
	Game.say("En storm drar in över Smaragdhavet! Skepp till sjöss tar skada – sök skydd vid egna öar.", Color(0.7, 0.8, 1))


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
			Game.say("Fiskestimmarna är ovanligt stora i år. +%d mat." % int(amount), Data.RESOURCE_COLORS["mat"])
		"skeppsbrutna":
			var gold := 50.0 + randi() % 80
			Game.add_res(Game.player, "guld", gold)
			Game.say("Skeppsbrutna sjömän räddas av dina fiskare. De betalar med %d guld ur en räddad kista." % int(gold), Data.RESOURCE_COLORS["guld"])


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
		Game.say("Pirater har siktats! %d skepp seglar mot %s." % [count, target.display_name], Color(1, 0.5, 0.4))
		if world.hud:
			world.hud.show_message_popup("Pirater!", "Utkiken ropar från masttoppen: svarta segel vid horisonten! %d piratskepp är på väg mot %s.\n\nSamla dina skepp och bygg kanonbatterier." % [count, target.display_name])
	else:
		Game.say("Pirater härjar kring %s (%s)." % [target.display_name, Data.nation_short(tn)], Color(0.85, 0.75, 0.65))


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
	best.x = clamp(best.x, 60.0, w.x - 60.0)
	best.y = clamp(best.y, 60.0, w.y - 60.0)
	return best


func _merchant() -> void:
	var p := Game.player
	var offers := [
		{"text": "Köp 25 kristaller för 220 guld", "cost": {"guld": 220.0}, "gain": {"kristaller": 25.0}},
		{"text": "Sälj 20 kryddor för 220 guld", "cost": {"kryddor": 20.0}, "gain": {"guld": 220.0}},
		{"text": "Sälj 10 pärlor för 240 guld", "cost": {"parlor": 10.0}, "gain": {"guld": 240.0}},
		{"text": "Köp 30 rom för 120 guld", "cost": {"guld": 120.0}, "gain": {"rom": 30.0}},
		{"text": "Köp 150 trä och 80 sten för 180 guld", "cost": {"guld": 180.0}, "gain": {"tra": 150.0, "sten": 80.0}},
		{"text": "Köp ritningar: slutför din pågående forskning (300 guld)", "cost": {"guld": 300.0}, "gain": {}, "research": true},
		{"text": "Köp en sjökarta som skingrar dimman (150 guld)", "cost": {"guld": 150.0}, "gain": {}, "map": true},
	]
	offers.shuffle()
	var buttons: Array = []
	for i in 3:
		var o: Dictionary = offers[i]
		var ok := Game.can_afford(p, o["cost"])
		if o.get("research", false) and Game.nations[p]["current_research"] == "":
			ok = false
		buttons.append({"text": o["text"], "disabled": not ok, "cb": _merchant_buy.bind(o)})
	buttons.append({"text": "Nej tack", "cb": Callable()})
	if world.hud:
		world.hud.show_popup({
			"title": "En handelsman anländer",
			"text": "Ett främmande handelsfartyg med silkessegel ankrar vid din hamn. Kaptenen, en solbränd man med guldtänder, bjuder ut sina varor:\n\n\"Bara idag, min vän – och bara för dig!\"",
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
				Game.say("Sjökartan visar vägen till %s." % isl.display_name, Color(0.8, 0.9, 1))
				break
		world.fog.commit()
	Game.resources_changed.emit()
	Game.say("Affären är klar.", Color(1, 0.85, 0.4))


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
			Game.say("Dimman tätnar och havet blir kallt. Spökflottan har vaknat!", Data.HOSTILE_FACTIONS["spokflottan"]["color"])
			if world.hud:
				world.hud.show_message_popup("Spökflottan", Data.CRISES["spokflottan"]["desc"] + "\n\nSpökflottan anfaller i %d vågor. Alla nationer är i fara – kanske är det dags att glömma gamla fejder?" % GHOST_WAVES)
		if Game.active_crises.has("spokflottan") and ghost_next >= 0 and d >= ghost_next:
			if ghost_waves_sent < GHOST_WAVES:
				_ghost_wave()
				ghost_waves_sent += 1
				ghost_next = d + 55
			elif world.ships_of("spokflottan").is_empty():
				ghost_done = true
				ghost_next = -1
				Game.say("Den sista spökbesättningen har fått ro. Spökflottan är besegrad!", Color(1, 0.9, 0.6))
				if world.hud:
					world.hud.show_message_popup("Spökflottan är besegrad", "Dimman lättar och solen bryter igenom. De döda sjömännen har äntligen fått ro, och Smaragdhavet andas ut.")
	# De Sovande Väktarna vaknar
	if crises.get("vaktarna", false) and not Game.vaktarna_awake:
		var sol = world.island_by_id("solstenson")
		if sol != null and sol.owner_id == "vaktarna" and Game.time >= start * 1.2:
			Game.vaktarna_awake = true
			vaktarna_next = d + 5
			Game.say("Solstensön lyser upp natthimlen. De Sovande Väktarna har vaknat!", Data.HOSTILE_FACTIONS["vaktarna"]["color"])
			if world.hud:
				world.hud.show_message_popup("Väktarna vaknar", "Ett skarpt ljus stiger ur Solstensöns kristaller. De uråldriga Väktarna har vaknat ur sin sömn och ser alla främlingar som inkräktare.\n\nErövra Solstensön för att stoppa dem.")
	if Game.vaktarna_awake and vaktarna_next >= 0 and d >= vaktarna_next:
		var sol = world.island_by_id("solstenson")
		if sol == null or sol.owner_id != "vaktarna":
			vaktarna_next = -1
			Game.say("Väktarnas kristaller har slocknat. Hotet från Solstensön är över.", Color(1, 0.9, 0.6))
		else:
			vaktarna_next = d + 70
			if world.ships_of("vaktarna").size() < 8:
				for k in 2:
					world.spawn_ship("kristallskepp", "vaktarna", sol.coast_point_towards(sol.position + Vector2.from_angle(randf() * TAU) * 400.0, 60.0))


func _ghost_wave() -> void:
	var count := 3 + ghost_waves_sent
	var w := Data.WORLD_SIZE
	var edges := [Vector2(randf_range(400, w.x - 400), 80), Vector2(randf_range(400, w.x - 400), w.y - 80), Vector2(80, randf_range(400, w.y - 400)), Vector2(w.x - 80, randf_range(400, w.y - 400))]
	var spawn: Vector2 = edges[randi() % edges.size()]
	for i in count:
		world.spawn_ship("spokskepp", "spokflottan", spawn + Vector2((i % 3) * 70, (i / 3) * 70))
	Game.say("Spökflottans våg %d/%d (%d skepp) stiger ur dimman!" % [ghost_waves_sent + 1, GHOST_WAVES, count], Data.HOSTILE_FACTIONS["spokflottan"]["color"])


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
