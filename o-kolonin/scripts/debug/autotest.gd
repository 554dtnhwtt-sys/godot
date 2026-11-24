extends Node
## Testläge för utveckling. Aktiveras med argument efter "--" på kommandoraden:
##   --autostart=<nation>   starta direkt med nationen
##   --autoplay             låt AI:n styra även spelarens nation
##   --speed=<0-3>          tidshastighet
##   --quit-days=<n>        avsluta efter n speldagar och skriv en rapport
##   --shots=<mapp>         spara skärmdumpar
##   --screen=<menu|select> ta en skärmdump av huvudmenyn eller nationsvalet
##   --crises=tidig         kriserna startar tidigt

const AIScript = preload("res://scripts/world/ai.gd")

var main = null
var args := {}
var _shot_days := [2, 60, 300, 700, 1100, 1500]
var _shot_i := 0
var _reported := false
var _frames := 0


func parse() -> void:
	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"


func active() -> bool:
	return args.has("autostart") or args.has("screen")


func run() -> void:
	if args.has("screen"):
		if args["screen"] == "select":
			main.show_select()
		else:
			main.show_menu()
		await _wait_frames(30)
		_save_shot("screen_" + args["screen"])
		get_tree().quit()
		return
	var crises := {"spokflottan": true, "armadan": false, "djupkulten": false, "vaktarna": true}
	main.start_game({
		"nation": args.get("autostart", "valdoria"),
		"ai_tempo": args.get("tempo", "normal"),
		"crisis_timing": args.get("crises", "normal"),
		"crises": crises,
	})
	await get_tree().process_frame
	if args.has("autoplay"):
		var ai := AIScript.new()
		ai.setup(Game.player, Game.world)
		Game.world.ais[Game.player] = ai
	if args.has("zoom"):
		var z := float(args["zoom"])
		Game.world.cam.zoom = Vector2(z, z)
	if args.has("town"):
		# Visa en stad på en viss nivå och en flotta med alla skeppstyper (för skärmdumpar)
		var home = Game.world.home_island(Game.player)
		home.set_town_level(int(args["town"]), true)
		home.add_building("skeppsvarv", true)
		for st in home.sites:
			if st["b"] == null:
				var b = home.build_site(home.sites.find(st), true)
				if b != null:
					b.level = int(args.get("site-level", "1"))
	if args.has("showcase"):
		var home = Game.world.home_island(Game.player)
		var types := ["handelsfartyg", "slup", "skonare", "brigg", "galeon", "fregatt", "linjeskepp", "spokskepp", "armadaskepp", "kristallskepp", "kultskepp"]
		var base: Vector2 = home.coast_point_towards(home.position + Vector2(600, 260), 120.0)
		for i in types.size():
			var owner := Game.player
			if types[i] in ["spokskepp", "armadaskepp", "kristallskepp", "kultskepp"]:
				owner = {"spokskepp": "spokflottan", "armadaskepp": "armadan", "kristallskepp": "vaktarna", "kultskepp": "djupkulten"}[types[i]]
			var s = Game.world.spawn_ship(types[i], owner, base + Vector2((i % 4) * 190, (i / 4) * 150))
			s.heading = -0.4 + (i % 3) * 0.9
		Game.world.cam.focus(base + Vector2(280, 120))
	if args.has("reveal"):
		Game.world.fog.reveal_all()
		Game.world.fog.commit()
	Game.set_speed(int(args.get("speed", "3")))
	Game.world.hud.popup_queue.clear()
	if args.has("shots"):
		_shot_days = []
		for d in args.get("shot-days", "2,60,300,700,1100,1500").split(","):
			_shot_days.append(int(d))


func _process(_delta: float) -> void:
	if not active() or Game.world == null or not is_instance_valid(Game.world):
		return
	_frames += 1
	# Popup-fönster pausar spelet; i testläget stänger vi dem direkt.
	var hud = Game.world.hud
	if hud and hud.popup_open:
		print("[POPUP] ", hud.popup_layer.get_child_count())
		hud.popup_queue.clear()
		hud._next_popup()
	if Game.paused:
		Game.set_speed(int(args.get("speed", "3")))
	if args.has("shots") and _shot_i < _shot_days.size() and Game.day() >= _shot_days[_shot_i]:
		_shot_i += 1
		_delayed_shot("day_%04d" % Game.day())
	var quit := int(args.get("quit-days", "0"))
	if quit > 0 and Game.day() >= quit and not _reported and _shot_i >= (_shot_days.size() if args.has("shots") else 0):
		_reported = true
		_report()
		get_tree().quit()


func _delayed_shot(name: String) -> void:
	_focus_action()
	await _wait_frames(6)
	if args.has("debug-ui"):
		var hud = Game.world.hud
		print("[UI] panel visible=", hud.info_panel.visible, " size=", hud.info_panel.size, " pos=", hud.info_panel.position, " children=", hud.info_box.get_child_count())
		for c in hud.info_box.get_children():
			print("[UI]   ", c.get_class(), " ", c.size, " vis=", c.visible, " min=", c.get_combined_minimum_size())
	_save_shot(name)


func _focus_action() -> void:
	var w = Game.world
	if args.has("showcase") or args.has("keep-cam"):
		return
	if args.has("select") and args["select"] == "home":
		var home = w.home_island(Game.player)
		w.select_island(home)
		w.cam.focus(home.position + Vector2(0, 120))
		return
	if args.has("select") and args["select"] == "ship":
		w.clear_selection()
		var best = null
		for s in w.ships_of(Game.player):
			if best == null or s.max_hp > best.max_hp:
				best = s
		if best != null:
			best.selected = true
			w.selected_ships.append(best)
			w.selection_changed.emit()
			w.cam.focus(best.position)
		return
	if args.has("focus"):
		var isl = w.island_by_id(args["focus"])
		if isl:
			w.cam.focus(isl.position)
			return
	# Titta där det händer mest: helst en strid, annars spelarens hemö.
	for s in w.ships:
		if s.is_alive() and s.owner_id == Game.player and s._auto_target != null:
			w.cam.focus(s.position)
			return
	var home = w.island_by_id(Data.NATIONS[Game.player]["home"])
	w.cam.focus(home.position)


func _save_shot(name: String) -> void:
	if not args.has("shots"):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path: String = args["shots"].path_join(name + ".png")
	img.save_png(path)
	print("[SHOT] ", path)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _report() -> void:
	var w = Game.world
	print("=== RAPPORT dag %d (%s) ===" % [Game.day(), Game.date_text()])
	for n in Game.nations:
		var st: Dictionary = Game.nations[n]
		var res_txt: Array = []
		for r in ["guld", "tra", "mat", "sten", "sand", "kristaller", "socker", "rom", "kryddor", "parlor", "forskning"]:
			res_txt.append("%s=%d" % [r, int(Game.res(n, r))])
		var b := 0
		for isl in w.islands_of(n):
			b += isl.buildings.size()
		var vets := 0
		var cargo := 0.0
		for s in w.ships_of(n):
			if s.level() > 0:
				vets += 1
			cargo += s.cargo_total()
		print("%s alive=%s öar=%d byggnader=%d skepp=%d forskning=%d styrka=%d befolkning=%d amiraler=%d veteraner=%d last=%d" % [n, st["alive"], w.islands_of(n).size(), b, w.ships_of(n).size(), st["research"].size(), int(w.nation_strength(n)), int(w.total_population(n)), st["admirals"].size(), vets, int(cargo)])
		print("   ", " ".join(res_txt))
	for k in Game.relations:
		print("rel ", k, " ", Game.relations[k]["status"], " ", int(Game.relations[k]["value"]))
	var owners := {}
	for isl in w.islands:
		owners[isl.owner_id] = owners.get(isl.owner_id, 0) + 1
	print("ägare: ", owners)
	var hostile := {}
	for s in w.ships:
		if s.is_alive() and not Game.is_playable(s.owner_id):
			hostile[s.owner_id] = hostile.get(s.owner_id, 0) + 1
	print("fientliga skepp: ", hostile, "  kriser: ", Game.active_crises, " väktare vakna: ", Game.vaktarna_awake)
