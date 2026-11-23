extends Control
## Nationsval i Total War-stil: karta med startpunkter, lore, styrkor/svagheter
## och inställningar (AI-tempo, kriser).

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const Emblem = preload("res://scripts/ui/emblem.gd")

var main = null
var selected := "valdoria"
var _t := 0.0
var _map: Control
var _detail: VBoxContainer
var _cards := {}
var _tempo: OptionButton
var _timing: OptionButton
var _crisis_checks := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("size", Vector2(2400, 1400))
	bg.material = mat
	bg.modulate = Color(0.45, 0.45, 0.5)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := UITheme.label("Välj din nation", 38, UITheme.GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(title)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 16)
	root.add_child(mid)
	# Vänster: karta + inställningar
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	mid.add_child(left)
	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(map_panel)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(760, 420)
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_map_input)
	map_panel.add_child(_map)
	left.add_child(_settings_box())
	# Höger: detaljer
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(560, 0)
	mid.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	scroll.add_child(_detail)
	# Nederkant: nationskort + knappar
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	for n in Data.PLAYABLE:
		bottom.add_child(_card(n))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var back := UITheme.button("Tillbaka", func(): main.show_menu(), 18)
	back.custom_minimum_size = Vector2(130, 90)
	bottom.add_child(back)
	var start := UITheme.button("Börja spela", _start, 24)
	start.custom_minimum_size = Vector2(220, 90)
	bottom.add_child(start)
	_select(selected)


func _card(n: String) -> Button:
	var def: Dictionary = Data.NATIONS[n]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 90)
	b.pressed.connect(_select.bind(n))
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_top = 6
	hb.add_theme_constant_override("separation", 10)
	b.add_child(hb)
	var em := Emblem.new(n, 62.0)
	hb.add_child(em)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(UITheme.label(def["short"], 19, Data.nation_color(n).lightened(0.45)))
	vb.add_child(UITheme.label(def["type"], 14, UITheme.DIM))
	var stars := ""
	for i in 3:
		stars += "★" if i <= def["difficulty"] else "☆"
	var diff_names := ["Lätt", "Medel", "Svår"]
	vb.add_child(UITheme.label("%s  %s" % [stars, diff_names[def["difficulty"]]], 14, UITheme.GOLD))
	hb.add_child(vb)
	_cards[n] = b
	return b


func _settings_box() -> Control:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Inställningar", 19, UITheme.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UITheme.label("AI-tempo:", 15))
	_tempo = OptionButton.new()
	_tempo.focus_mode = Control.FOCUS_NONE
	for k in Data.AI_TEMPO:
		_tempo.add_item(Data.AI_TEMPO[k]["name"])
		_tempo.set_item_metadata(_tempo.item_count - 1, k)
	_tempo.select(1)
	_tempo.tooltip_text = "Fredlig: ingen förklarar krig de första åren. Normal: efter ca ett år. Aggressiv: från start."
	row.add_child(_tempo)
	row.add_child(UITheme.label("   Kriser börjar:", 15))
	_timing = OptionButton.new()
	_timing.focus_mode = Control.FOCUS_NONE
	for k in Data.CRISIS_TIMING:
		_timing.add_item(Data.CRISIS_TIMING[k]["name"])
		_timing.set_item_metadata(_timing.item_count - 1, k)
	_timing.select(1)
	row.add_child(_timing)
	vb.add_child(row)
	vb.add_child(UITheme.label("Endgame-kriser (flera kan pågå samtidigt):", 15))
	var grid := GridContainer.new()
	grid.columns = 2
	vb.add_child(grid)
	for c in Data.CRISES:
		var def: Dictionary = Data.CRISES[c]
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		var name: String = def["name"]
		if def.get("from_start", false):
			name += " (finns från start)"
		if not def.get("pilot", false):
			name += " – kommer i betan"
			cb.disabled = true
			cb.button_pressed = false
		else:
			cb.button_pressed = true
		cb.text = name
		cb.tooltip_text = def["desc"]
		cb.add_theme_font_size_override("font_size", 14)
		grid.add_child(cb)
		_crisis_checks[c] = cb
	return panel


func _select(n: String) -> void:
	selected = n
	for k in _cards:
		_cards[k].modulate = Color(1, 1, 1) if k == n else Color(0.7, 0.7, 0.7)
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var def: Dictionary = Data.NATIONS[n]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(Emblem.new(n, 96.0))
	var hv := VBoxContainer.new()
	hv.add_child(UITheme.label(def["name"], 26, Data.nation_color(n).lightened(0.45)))
	hv.add_child(UITheme.label(def["type"], 16, UITheme.DIM))
	hv.add_child(UITheme.label(def["leader"], 16, UITheme.GOLD))
	hv.add_child(UITheme.label("Hemö: " + Data.island_def(def["home"])["name"], 15, UITheme.DIM))
	head.add_child(hv)
	_detail.add_child(head)
	_detail.add_child(HSeparator.new())
	var lore := UITheme.wrap_label(def["lore"], 16)
	lore.custom_minimum_size.x = 520
	_detail.add_child(lore)
	_detail.add_child(HSeparator.new())
	_detail.add_child(UITheme.label("Styrkor", 18, UITheme.GOOD))
	for s in def["strengths"]:
		_detail.add_child(UITheme.wrap_label("+  " + s, 15, UITheme.GOOD))
	_detail.add_child(UITheme.label("Svagheter", 18, UITheme.BAD))
	for s in def["weaknesses"]:
		_detail.add_child(UITheme.wrap_label("–  " + s, 15, UITheme.BAD))
	var ships: Array = []
	for s in def["start_ships"]:
		ships.append(Data.SHIPS[s]["name"])
	_detail.add_child(UITheme.wrap_label("Startflotta: " + ", ".join(ships), 15, UITheme.DIM))
	_map.queue_redraw()


func _start() -> void:
	var crises := {}
	for c in _crisis_checks:
		crises[c] = _crisis_checks[c].button_pressed
	main.start_game({
		"nation": selected,
		"ai_tempo": _tempo.get_item_metadata(_tempo.selected),
		"crisis_timing": _timing.get_item_metadata(_timing.selected),
		"crises": crises,
	})


func _process(delta: float) -> void:
	_t += delta
	_map.queue_redraw()


func _map_scale() -> float:
	return min(_map.size.x / Data.WORLD_SIZE.x, _map.size.y / Data.WORLD_SIZE.y)


func _map_offset() -> Vector2:
	return (_map.size - Data.WORLD_SIZE * _map_scale()) * 0.5


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var wp: Vector2 = (event.position - _map_offset()) / _map_scale()
		for d in Data.ISLANDS:
			if d.has("home") and wp.distance_to(d["pos"]) < d["r"] * 1.3:
				_select(d["home"])


func _draw_map() -> void:
	var sc := _map_scale()
	var off := _map_offset()
	_map.draw_rect(Rect2(off, Data.WORLD_SIZE * sc), Color(0.04, 0.4, 0.52))
	var font := ThemeDB.fallback_font
	for d in Data.ISLANDS:
		var c: Vector2 = off + d["pos"] * sc
		var r: float = d["r"] * sc
		_ellipse(c, r * 1.5, r * 1.1, Color(0.4, 0.9, 0.88, 0.25))
		var col := Color(0.95, 0.88, 0.66)
		if d.has("home"):
			col = Data.nation_color(d["home"]).lightened(0.2)
		if d.get("guardians", false):
			col = Color(0.6, 0.85, 1.0)
		_ellipse(c, r, r * 0.72, col)
		if d.has("home"):
			var n: String = d["home"]
			if n == selected:
				var pulse := 1.0 + 0.15 * sin(_t * 4.0)
				_map.draw_arc(c, r * 1.6 * pulse, 0, TAU, 32, Data.nation_accent(n), 3.0)
			var label: String = Data.NATIONS[n]["short"]
			_map.draw_string(font, c + Vector2(-60, -r - 10), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1, 1, 1))
		elif d.get("guardians", false):
			_map.draw_string(font, c + Vector2(-60, -r - 8), "?", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.8, 0.95, 1))
	_map.draw_string(font, off + Vector2(12, 24), Data.SEA_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.7))
	_map.draw_string(font, off + Vector2(12, Data.WORLD_SIZE.y * sc - 12), "Dimman döljer allt utom din hemö när spelet börjar.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_map.draw_colored_polygon(pts, col)
