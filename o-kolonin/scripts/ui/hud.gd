extends CanvasLayer
## Spelets gränssnitt: resursrad, datum och tidskontroller, vind, meddelanden,
## info om markerade öar/skepp, minikarta, popup-fönster och paneler.

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const ResIcon = preload("res://scripts/ui/res_icon.gd")
const Emblem = preload("res://scripts/ui/emblem.gd")
const ResearchPanel = preload("res://scripts/ui/research_panel.gd")
const DiplomacyPanel = preload("res://scripts/ui/diplomacy_panel.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")

const TOP_RES := ["guld", "tra", "mat", "sten", "sand", "kristaller", "socker", "rom", "kryddor", "parlor", "forskning"]
const SPEED_LABELS := ["||", ">", ">>", ">>>", ">>>>"]

var world = null
var root: Control
var res_labels := {}
var res_chips := {}
var date_label: Label
var speed_buttons: Array = []
var wind_ctl: Control
var log_box: VBoxContainer
var info_panel: PanelContainer
var info_box: VBoxContainer
var research_panel = null
var diplomacy_panel = null
var minimap = null
var popup_layer: Control
var popup_queue: Array = []
var popup_open := false
var _pause_before_popup := false
var _refresh_t := 0.0
var _dynamic: Array = []
var _info_ship = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)
	_build_top_bar()
	_build_side_buttons()
	_build_log()
	_build_info_panel()
	minimap = Minimap.new()
	minimap.world = world
	root.add_child(minimap)
	research_panel = ResearchPanel.new()
	research_panel.hud = self
	root.add_child(research_panel)
	research_panel.visible = false
	diplomacy_panel = DiplomacyPanel.new()
	diplomacy_panel.hud = self
	root.add_child(diplomacy_panel)
	diplomacy_panel.visible = false
	_build_popup_layer()
	Game.notify.connect(_on_notify)
	Game.popup_requested.connect(_on_ai_popup)
	Game.resources_changed.connect(_update_resources)
	Game.research_changed.connect(refresh_panels)
	Game.diplomacy_changed.connect(_on_diplomacy_changed)
	world.selection_changed.connect(_rebuild_info)
	_update_resources()
	_rebuild_info()


# ------------------------------------------------------------------ Övre raden
func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.06, 0.05, 0.92), UITheme.BORDER, 0, 0, 6.0))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	bar.add_child(hb)
	var em := Emblem.new(Game.player, 26.0)
	hb.add_child(em)
	for r in TOP_RES:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.add_child(ResIcon.new(r, 20.0))
		var l := UITheme.label("0", 15)
		l.custom_minimum_size.x = 44
		chip.add_child(l)
		hb.add_child(chip)
		res_labels[r] = l
		res_chips[r] = chip
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	wind_ctl = Control.new()
	wind_ctl.custom_minimum_size = Vector2(34, 34)
	wind_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	wind_ctl.draw.connect(_draw_wind)
	hb.add_child(wind_ctl)
	date_label = UITheme.label("", 17, UITheme.GOLD)
	date_label.custom_minimum_size.x = 170
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(date_label)
	for i in SPEED_LABELS.size():
		var b := UITheme.button(SPEED_LABELS[i], _on_speed.bind(i), 14)
		b.custom_minimum_size = Vector2(40, 30)
		b.tooltip_text = "Paus (mellanslag)" if i == 0 else "Hastighet %dx (tangent %d)" % [int(Data.SPEEDS[i - 1]), i]
		hb.add_child(b)
		speed_buttons.append(b)


func _on_speed(i: int) -> void:
	if i == 0:
		Game.toggle_pause()
	else:
		Game.set_speed(i - 1)


func _draw_wind() -> void:
	var c := wind_ctl.size * 0.5
	var r: float = minf(c.x, c.y) - 2.0
	wind_ctl.draw_circle(c, r, Color(0.15, 0.25, 0.3, 0.9))
	wind_ctl.draw_arc(c, r, 0, TAU, 24, UITheme.BORDER, 1.5)
	var dir := Vector2.from_angle(Game.wind_angle)
	dir.y *= 0.72
	dir = dir.normalized()
	var len := r * (0.5 + 0.35 * clampf(Game.wind_strength - 0.6, 0.0, 1.0))
	var tip := c + dir * len
	var tail := c - dir * len
	var col := Color(0.8, 0.95, 1.0) if Game.storm < 0.3 else Color(1, 0.5, 0.4)
	wind_ctl.draw_line(tail, tip, col, 2.5)
	wind_ctl.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 7 + dir.orthogonal() * 5, tip - dir * 7 - dir.orthogonal() * 5]), col)


func _update_resources() -> void:
	var p := Game.player
	var rates: Dictionary = Game.rates.get(p, {})
	for r in TOP_RES:
		var v := Game.res(p, r)
		res_labels[r].text = _fmt(v)
		var rate: float = rates.get(r, 0.0)
		var tip := "%s: %d" % [Data.RESOURCE_NAMES[r], int(v)]
		if r == "forskning":
			var st: Dictionary = Game.nations[p]
			tip = "Forskning: %+.1f per dag" % rate
			if st["current_research"] != "":
				tip += "\nPågår: %s (%d/%d)" % [Data.RESEARCH[st["current_research"]]["name"], int(st["research_progress"]), int(Data.research_cost(st["current_research"]))]
			else:
				tip += "\nIngen forskning pågår – öppna Forskning (F)."
			res_labels[r].text = "%+.1f" % rate
		else:
			tip += "\n%+.1f per dag" % rate
			if r in Data.LUXURY_PRICES:
				tip += "\nLyxvara – marknader säljer överskott över %d." % int(Data.LUXURY_RESERVE)
			if r == "rom":
				tip += "\nRom i lager: skeppen laddar 12 % snabbare och träffar 10 % hårdare."
		res_chips[r].tooltip_text = tip
		res_labels[r].add_theme_color_override("font_color", UITheme.TEXT if rate >= -0.01 or v > 5.0 else UITheme.BAD)


func _fmt(v: float) -> String:
	if v >= 100000.0:
		return "%dk" % int(v / 1000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(v))


# ------------------------------------------------------------------ Knappar till höger
func _build_side_buttons() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	vb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vb.offset_left = -190
	vb.offset_right = -14
	vb.offset_top = 56
	vb.custom_minimum_size = Vector2(176, 0)
	vb.add_theme_constant_override("separation", 6)
	root.add_child(vb)
	var b1 := UITheme.button("Forskning  (F)", toggle_research, 16)
	var b2 := UITheme.button("Diplomati  (P)", toggle_diplomacy, 16)
	var b3 := UITheme.button("Meny  (Esc)", toggle_menu, 16)
	var b4 := UITheme.button("Hjälp  (F1)", show_help, 16)
	for b in [b1, b2, b4, b3]:
		b.custom_minimum_size = Vector2(176, 36)
		vb.add_child(b)


func toggle_research() -> void:
	diplomacy_panel.visible = false
	research_panel.visible = not research_panel.visible
	if research_panel.visible:
		research_panel.rebuild()


func toggle_diplomacy() -> void:
	research_panel.visible = false
	diplomacy_panel.visible = not diplomacy_panel.visible
	if diplomacy_panel.visible:
		diplomacy_panel.rebuild()


func refresh_panels() -> void:
	if research_panel and research_panel.visible:
		research_panel.rebuild()
	if diplomacy_panel and diplomacy_panel.visible:
		diplomacy_panel.rebuild()
	_rebuild_info()


func _on_diplomacy_changed() -> void:
	if diplomacy_panel and diplomacy_panel.visible:
		diplomacy_panel.update_values()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				toggle_research()
				get_viewport().set_input_as_handled()
			KEY_P:
				toggle_diplomacy()
				get_viewport().set_input_as_handled()
			KEY_F1:
				show_help()
				get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Meddelanden
func _build_log() -> void:
	log_box = VBoxContainer.new()
	log_box.position = Vector2(14, 58)
	log_box.custom_minimum_size = Vector2(560, 0)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_theme_constant_override("separation", 2)
	root.add_child(log_box)


func _on_notify(text: String, color: Color) -> void:
	var l := UITheme.wrap_label(text, 15, color)
	l.custom_minimum_size.x = 560
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("born", Time.get_ticks_msec())
	log_box.add_child(l)
	while log_box.get_child_count() > 8:
		var c := log_box.get_child(0)
		log_box.remove_child(c)
		c.queue_free()


func _fade_log() -> void:
	var now := Time.get_ticks_msec()
	for c in log_box.get_children():
		var age: float = (now - int(c.get_meta("born"))) / 1000.0
		if age > 14.0:
			c.queue_free()
		elif age > 10.0:
			c.modulate.a = 1.0 - (age - 10.0) / 4.0


# ------------------------------------------------------------------ Infopanel
func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_panel.offset_left = 12
	info_panel.offset_top = -12
	info_panel.offset_bottom = -12
	info_panel.custom_minimum_size = Vector2(600, 0)
	root.add_child(info_panel)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_box)


func _clear_info() -> void:
	_dynamic.clear()
	for c in info_box.get_children():
		info_box.remove_child(c)
		c.queue_free()


func show_ship_info(s) -> void:
	_info_ship = s
	_rebuild_info()


func _rebuild_info() -> void:
	_clear_info()
	if world == null:
		return
	if world.selected_ships.size() > 0:
		_info_ship = null
		_build_ship_info()
	elif world.selected_island != null:
		_info_ship = null
		_build_island_info(world.selected_island)
	elif _info_ship != null and is_instance_valid(_info_ship) and _info_ship.is_alive():
		_build_foreign_ship(_info_ship)
	else:
		info_panel.visible = false
		return
	info_panel.visible = true
	info_panel.reset_size()
	_refresh_dynamic()


func _title_row(text: String, color: Color, nation: String = "") -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	if nation != "" and Data.NATIONS.has(nation):
		hb.add_child(Emblem.new(nation, 30.0))
	hb.add_child(UITheme.label(text, 21, color))
	info_box.add_child(hb)


func _build_ship_info() -> void:
	var sel: Array = world.selected_ships
	var counts := {}
	for s in sel:
		counts[s.type] = counts.get(s.type, 0) + 1
	if sel.size() == 1:
		var s = sel[0]
		_title_row(s.def["name"], UITheme.GOLD, Game.player)
		info_box.add_child(UITheme.wrap_label(s.def["desc"], 14, UITheme.DIM))
	else:
		_title_row("Flotta – %d skepp" % sel.size(), UITheme.GOLD, Game.player)
		var parts: Array = []
		for t in counts:
			parts.append("%d %s" % [counts[t], Data.SHIPS[t]["name"].to_lower()])
		info_box.add_child(UITheme.wrap_label(", ".join(parts), 15))
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(560, 16)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("fill", UITheme.box(Color(0.4, 0.85, 0.4), Color(0, 0, 0, 0), 0, 3, 0.0))
	info_box.add_child(hp_bar)
	var stats := UITheme.label("", 14)
	info_box.add_child(stats)
	var _upd1 := func():
		var hp := 0.0
		var mhp := 0.0
		var tr := 0.0
		var cannons := 0
		var order_txt := ""
		for s in world.selected_ships:
			if not is_instance_valid(s):
				continue
			hp += s.hp
			mhp += s.max_hp
			tr += s.troops
			cannons += s.def["cannons"]
			order_txt = _order_text(s)
		hp_bar.max_value = maxf(1.0, mhp)
		hp_bar.value = hp
		var spd := ""
		if world.selected_ships.size() > 0 and is_instance_valid(world.selected_ships[0]):
			var s0 = world.selected_ships[0]
			spd = "   Fart: %d%% (vind)" % int(s0.wind_factor(s0.heading) * 100.0)
		stats.text = "Skrov %d/%d   Kanoner %d   Soldater %d%s\n%s" % [int(hp), int(mhp), cannons, int(tr), spd, order_txt]
	_dynamic.append(_upd1)
	var hb := HBoxContainer.new()
	hb.add_child(UITheme.button("Stoppa", _stop_selected, 14))
	hb.add_child(UITheme.button("Till hemön", _send_home, 14))
	info_box.add_child(hb)
	if sel.size() > 1:
		var fb := HBoxContainer.new()
		fb.add_theme_constant_override("separation", 6)
		fb.add_child(UITheme.label("Formation:", 14, UITheme.DIM))
		var tips := {"linje": "Linje: skeppen seglar efter varandra – bra för bredsidor.", "kil": "Kil: spjutspets med ledaren längst fram.", "spridd": "Spridd: stort avstånd mellan skeppen – svårare att träffa."}
		for f in world.FORMATIONS:
			var b := UITheme.button(world.FORMATIONS[f], _set_formation.bind(f), 14)
			b.modulate = Color(1.0, 0.85, 0.4) if world.formation == f else Color(1, 1, 1)
			b.tooltip_text = tips[f]
			fb.add_child(b)
		info_box.add_child(fb)
	var hint := "Högerklick: segla, anfall skepp/ö, kolonisera obebodd ö."
	for s in sel:
		if s.def.get("trade", false):
			hint += "\nHandelsfartyg: lägg dig vid en egen ö och högerklicka på en annan egen ö för att starta en handelsrutt."
			break
	info_box.add_child(UITheme.wrap_label(hint, 13, UITheme.DIM))


func _set_formation(f: String) -> void:
	world.formation = f
	_rebuild_info()


func _stop_selected() -> void:
	for s in world.selected_ships:
		s.stop()


func _send_home() -> void:
	var home = world.island_by_id(Data.NATIONS[Game.player]["home"])
	if home.owner_id == Game.player:
		for s in world.selected_ships:
			s.order_move(home.coast_point_towards(s.position, 90.0))


func _order_text(s) -> String:
	match s.order:
		"move":
			return "Order: segla"
		"attack":
			return "Order: anfall %s" % (s.target_ship.display_name().to_lower() if s.target_ship != null and is_instance_valid(s.target_ship) else "")
		"attack_island":
			return "Order: anfall %s" % (s.target_island.display_name if s.target_island != null else "")
		"colonize":
			return "Order: kolonisera %s" % (s.target_island.display_name if s.target_island != null else "")
		"trade":
			return "Handelsrutt: %s – %s" % [s.trade_a.display_name, s.trade_b.display_name] if s.trade_a != null and s.trade_b != null else "Handelsrutt"
	return "Order: ligger för ankar"


func _build_foreign_ship(s) -> void:
	_title_row("%s – %s" % [s.def["name"], Data.nation_short(s.owner_id)], Data.nation_color(s.owner_id).lightened(0.3), s.owner_id)
	var st := "I krig" if Game.at_war(Game.player, s.owner_id) else "Inte i krig"
	var l := UITheme.label("", 15)
	info_box.add_child(l)
	var _upd2 := func():
		if is_instance_valid(s):
			l.text = "Skrov %d/%d   Kanoner %d   %s" % [int(s.hp), int(s.max_hp), s.def["cannons"], st]
	_dynamic.append(_upd2)
func _build_island_info(isl) -> void:
	var p := Game.player
	var owner: String = isl.owner_id
	var owner_txt := "Obebodd" if owner == "neutral" else Data.nation_name(owner)
	_title_row(isl.display_name, UITheme.GOLD, owner)
	var sub := UITheme.label(owner_txt, 15, Data.nation_color(owner).lightened(0.35) if owner != "neutral" else UITheme.DIM)
	info_box.add_child(sub)
	# Fyndigheter
	var dep := HBoxContainer.new()
	dep.add_child(UITheme.label("Resurser:", 14, UITheme.DIM))
	for d in isl.deposits:
		var chip := HBoxContainer.new()
		chip.add_child(ResIcon.new(d, 18.0))
		chip.add_child(UITheme.label(Data.RESOURCE_NAMES[d], 14))
		dep.add_child(chip)
	info_box.add_child(dep)
	if owner == "neutral":
		if isl.guardians:
			info_box.add_child(UITheme.wrap_label("Helig mark. Ingen kan kolonisera Solstensön.", 14, UITheme.DIM))
		else:
			info_box.add_child(UITheme.wrap_label("Markera ett skepp och högerklicka på ön för att kolonisera den.\nKostnad: %s" % Data.cost_text(Game.colonize_cost(p)), 14))
		return
	var status := UITheme.label("", 14)
	info_box.add_child(status)
	var _upd3 := func():
		var t := "Garnison: %d / %d" % [int(isl.garrison), int(isl.max_garrison())]
		if owner == p:
			if isl.home_of == p:
				t += "   Hemö: full produktion"
			elif isl.trade_connected():
				t += "   Handelsrutt aktiv: full produktion"
			else:
				t += "   Ingen handelsrutt: 60 % produktion"
			t += "   Lediga platser: %d" % isl.free_slot_count()
		elif Game.is_playable(owner):
			t += "   Relation: %s (%d)" % [Game.STATUS_NAMES[Game.status(p, owner)], int(Game.get_rel(p, owner)["value"])]
		status.text = t
	_dynamic.append(_upd3)
	if owner != p:
		if Game.is_playable(owner) and not Game.at_war(p, owner):
			info_box.add_child(UITheme.wrap_label("Ni är inte i krig. Öppna Diplomati (P) för att förhandla eller förklara krig.", 13, UITheme.DIM))
		else:
			info_box.add_child(UITheme.wrap_label("Fiende. Markera skepp och högerklicka på ön för att anfalla. Skjut sönder kanonbatterierna – sedan landstiger soldaterna.", 13, UITheme.DIM))
		return
	# Byggmeny
	info_box.add_child(UITheme.label("Bygg", 17, UITheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	info_box.add_child(grid)
	for type in Data.BUILD_ORDER:
		var def: Dictionary = Data.BUILDINGS[type]
		if def.has("deposit") and not isl.deposits.has(def["deposit"]):
			continue
		var b := UITheme.button(def["name"], _on_build.bind(isl, type), 13)
		b.custom_minimum_size = Vector2(144, 30)
		grid.add_child(b)
		var _upd4 := func():
			var unlocked := Game.building_unlocked(p, type)
			var cost := Game.building_cost(p, type)
			var tip := "%s\n%s\n\nKostnad: %s" % [def["name"], def["desc"], Data.cost_text(cost)]
			var prod: Dictionary = def["prod"]
			if prod.size() > 0:
				var parts: Array = []
				for r in prod:
					parts.append("+%.1f %s" % [prod[r] * Game.prod_mod(p, r), Data.RESOURCE_NAMES[r].to_lower()])
				tip += "\nProducerar: %s per dag" % ", ".join(parts)
			if def.has("consumes"):
				tip += "\nFörbrukar: %s per dag" % Data.cost_text(def["consumes"])
			if not unlocked:
				tip += "\n\nKräver forskning: %s" % Data.RESEARCH[def["research"]]["name"]
			elif not isl.can_build_type(type):
				tip += "\n\nIngen ledig plats" + (" vid kusten." if def.get("coastal", false) else ".")
			b.tooltip_text = tip
			b.disabled = not unlocked or not isl.can_build_type(type) or not Game.can_afford(p, cost)
			b.modulate = Color(1, 1, 1) if unlocked else Color(0.6, 0.6, 0.6)
		_dynamic.append(_upd4)
	# Byggnader på ön
	var counts := {}
	for bld in isl.buildings:
		counts[bld.type] = counts.get(bld.type, 0) + 1
	var parts: Array = []
	for t in counts:
		parts.append("%s ×%d" % [Data.BUILDINGS[t]["name"], counts[t]] if counts[t] > 1 else Data.BUILDINGS[t]["name"])
	info_box.add_child(UITheme.wrap_label("På ön: " + ", ".join(parts), 13, UITheme.DIM))
	# Skeppsvarv
	if isl.has_shipyard():
		info_box.add_child(UITheme.label("Skeppsvarv", 17, UITheme.GOLD))
		var sg := GridContainer.new()
		sg.columns = 4
		sg.add_theme_constant_override("h_separation", 4)
		sg.add_theme_constant_override("v_separation", 4)
		info_box.add_child(sg)
		for t in Data.SHIP_ORDER:
			var sd: Dictionary = Data.SHIPS[t]
			var b := UITheme.button(sd["name"], _on_ship.bind(isl, t), 13)
			b.custom_minimum_size = Vector2(144, 30)
			sg.add_child(b)
			var _upd5 := func():
				var unlocked := Game.ship_unlocked(p, t)
				var cost := Game.ship_cost(p, t)
				var tip := "%s\n%s\n\nSkrov %d  Kanoner %d  Fart %d  Soldater %d\nByggtid: %d dagar\nKostnad: %s" % [sd["name"], sd["desc"], int(sd["hp"] * Game.mod(p, "ship_hp")), sd["cannons"], int(sd["speed"] * Game.mod(p, "ship_speed")), int(sd["troops"] * Game.mod(p, "troops")), int(sd["time"]), Data.cost_text(cost)]
				if not unlocked:
					tip += "\n\nKräver forskning: %s" % Data.RESEARCH[Data.SHIP_RESEARCH[t]]["name"]
				b.tooltip_text = tip
				b.disabled = not unlocked or not Game.can_afford(p, cost) or isl.ship_queue.size() >= 5
				b.modulate = Color(1, 1, 1) if unlocked else Color(0.6, 0.6, 0.6)
			_dynamic.append(_upd5)
		var q := UITheme.label("", 14)
		info_box.add_child(q)
		var _upd6 := func():
			if isl.ship_queue.is_empty():
				q.text = "Kö: tom"
			else:
				var names: Array = []
				for e in isl.ship_queue:
					names.append(Data.SHIPS[e["type"]]["name"])
				q.text = "Kö: %s  (nästa klar om %d dagar)" % [", ".join(names), int(ceilf(isl.ship_queue[0]["left"]))]
		_dynamic.append(_upd6)
func _on_build(isl, type: String) -> void:
	if world.build(Game.player, isl, type):
		Game.say("Bygger %s på %s." % [Data.BUILDINGS[type]["name"].to_lower(), isl.display_name], Color(0.85, 0.85, 0.75))
		_rebuild_info()


func _on_ship(isl, type: String) -> void:
	if world.queue_ship(Game.player, isl, type):
		Game.say("%s beställd på %s." % [Data.SHIPS[type]["name"], isl.display_name], Color(0.6, 0.85, 1))
	_refresh_dynamic()


func _refresh_dynamic() -> void:
	for f in _dynamic:
		f.call()


# ------------------------------------------------------------------ Uppdatering
func _process(delta: float) -> void:
	var real := delta / maxf(0.001, Engine.time_scale)
	_refresh_t -= real
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		_refresh_dynamic()
		_fade_log()
		date_label.text = Game.date_text()
		for i in speed_buttons.size():
			var active := (i == 0 and Game.paused) or (i > 0 and not Game.paused and Game.speed_index == i - 1)
			speed_buttons[i].modulate = Color(1.0, 0.85, 0.4) if active else Color(1, 1, 1)
		wind_ctl.tooltip_text = "Vind: %s%s\nMedvind ger full fart, motvind halverar farten." % ["stark" if Game.wind_strength > 1.15 else ("svag" if Game.wind_strength < 0.85 else "måttlig"), " – STORM" if Game.storm > 0.3 else ""]
		wind_ctl.queue_redraw()
		if research_panel.visible:
			research_panel.update_progress()


# ------------------------------------------------------------------ Popup
func _build_popup_layer() -> void:
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_layer.visible = false
	root.add_child(popup_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)


## data: {"title", "text", "buttons": [{"text", "cb": Callable, "disabled": bool}]}
func show_popup(data: Dictionary) -> void:
	popup_queue.append(data)
	if not popup_open:
		_next_popup()


func show_message_popup(title: String, text: String) -> void:
	show_popup({"title": title, "text": text, "buttons": [{"text": "OK", "cb": Callable()}]})


func _next_popup() -> void:
	for c in popup_layer.get_children():
		if c is PanelContainer:
			popup_layer.remove_child(c)
			c.queue_free()
	if popup_queue.is_empty():
		popup_open = false
		popup_layer.visible = false
		if not _pause_before_popup and Game.paused:
			Game.toggle_pause()
		return
	if not popup_open:
		_pause_before_popup = Game.paused
		if not Game.paused:
			Game.toggle_pause()
	popup_open = true
	var data: Dictionary = popup_queue.pop_front()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	popup_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	if data.has("portrait"):
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.5), Data.nation_accent(data["portrait"]), 2, 5, 2.0))
		var pt := TextureRect.new()
		pt.texture = Art.portrait(data["portrait"])
		pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pt.custom_minimum_size = Vector2(96, 96)
		frame.add_child(pt)
		th.add_child(frame)
	var tl := UITheme.wrap_label(data.get("title", ""), 24, UITheme.GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tl)
	vb.add_child(th)
	vb.add_child(HSeparator.new())
	var txt := UITheme.wrap_label(data.get("text", ""), 16)
	txt.custom_minimum_size.x = 540
	vb.add_child(txt)
	var bb := VBoxContainer.new()
	bb.add_theme_constant_override("separation", 6)
	vb.add_child(bb)
	for bd in data.get("buttons", []):
		var cb: Callable = bd.get("cb", Callable())
		var b := UITheme.button(bd["text"], _popup_choice.bind(cb), 16)
		b.custom_minimum_size = Vector2(0, 36)
		b.disabled = bd.get("disabled", false)
		bb.add_child(b)
	panel.reset_size()
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.position = (root.size - panel.size) * 0.5


func _popup_choice(cb: Callable) -> void:
	if cb.is_valid():
		cb.call()
	_next_popup()


func _on_ai_popup(data: Dictionary) -> void:
	var from: String = data["from"]
	show_popup({
		"portrait": from,
		"title": "Sändebud från %s" % Data.nation_name(from),
		"text": data["text"] + "\n\nRelation just nu: %d" % int(Game.get_rel(Game.player, from)["value"]),
		"buttons": [
			{"text": "Acceptera", "cb": func(): Game.answer_ai_proposal(data, true)},
			{"text": "Avböj", "cb": func(): Game.answer_ai_proposal(data, false)},
		],
	})


func toggle_menu() -> void:
	if popup_open:
		return
	show_popup({
		"title": "Ö-kolonin – meny",
		"text": "%s\n%s\nPilotversion 0.1" % [Data.nation_name(Game.player), Game.date_text()],
		"buttons": [
			{"text": "Fortsätt", "cb": Callable()},
			{"text": "Hjälp och kontroller", "cb": show_help},
			{"text": "Avsluta till huvudmenyn", "cb": func(): world.ended.emit("menu")},
			{"text": "Avsluta spelet", "cb": func(): get_tree().quit()},
		],
	})


func show_help() -> void:
	show_message_popup("Hjälp och kontroller", "KAMERA\nWASD / pilar: flytta kameran. Scrollhjul: zooma. Mellanknapp: dra kartan. H: hemön. Klicka på minikartan för att hoppa dit.\n\nTID\nMellanslag: paus. 1–4: hastighet (1x, 2x, 4x, 8x). Tiden går dag för dag.\n\nSKEPP\nVänsterklick / dra en ruta: markera skepp. Ctrl+A: alla skepp.\nHögerklick på vatten: segla dit. På fiendeskepp: anfall. På fiendeö: anfall – skeppen skjuter sönder kanonbatterier och landstiger sedan. På obebodd ö: kolonisera.\nSkeppen vänder själva bredsidan mot fienden. Medvind ger full fart, motvind halverar den.\n\nÖAR\nKlicka på en egen ö för att bygga. Kolonier utan handelsrutt producerar 60 %. Skicka ett handelsfartyg mellan hemön och kolonin.\n\nPANELER\nF: Forskning (byggnader, perks, skeppsmodeller). P: Diplomati (krig, fred, handel, allians, tribut, gåvor, gemensamma krig). Esc: meny.")
