extends PanelContainer
## Forskningsfönster med tre grenar: Byggnader, Perks och Skeppsmodeller.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

var hud = null
var _content: VBoxContainer
var _progress: ProgressBar
var _progress_label: Label
var _queue_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1120, 640)
	position = Vector2(-560, -320)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	add_child(_content)


func rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var p := Game.player
	var head := HBoxContainer.new()
	head.add_child(UITheme.label("Forskning", 26, UITheme.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.button("Stäng (F)", func(): visible = false, 15))
	_content.add_child(head)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	_progress_label = UITheme.label("", 15)
	_progress_label.custom_minimum_size.x = 380
	info.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(300, 18)
	_progress.show_percentage = false
	info.add_child(_progress)
	_queue_label = UITheme.label("", 14, UITheme.DIM)
	info.add_child(_queue_label)
	_content.add_child(info)
	_content.add_child(UITheme.wrap_label("Klicka på ett projekt för att forska (eller köa det). Klicka igen för att avbryta. Akademier ger mer forskning.", 13, UITheme.DIM))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(cols)
	for tree in Data.RESEARCH_TREES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		col.add_child(UITheme.label(Data.RESEARCH_TREES[tree], 20, UITheme.GOLD))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(340, 460)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 5)
		scroll.add_child(list)
		var ids: Array = []
		for rid in Data.RESEARCH:
			if Data.RESEARCH[rid]["tree"] == tree:
				ids.append(rid)
		ids.sort_custom(func(a, b): return Data.RESEARCH[a]["cost"] < Data.RESEARCH[b]["cost"])
		for rid in ids:
			list.add_child(_card(p, rid))
		cols.add_child(col)
	update_progress()


func _card(p: String, rid: String) -> Button:
	var r: Dictionary = Data.RESEARCH[rid]
	var st: Dictionary = Game.nations[p]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := ""
	var col := Color(1, 1, 1)
	if Game.has_research(p, rid):
		state = "KLAR"
		col = Color(0.6, 1.0, 0.6)
	elif st["current_research"] == rid:
		state = "PÅGÅR"
		col = Color(0.85, 0.75, 1.3)
	elif rid in st["research_queue"]:
		state = "I KÖ (%d)" % (st["research_queue"].find(rid) + 1)
		col = Color(0.7, 0.9, 1.2)
	elif Game.research_available(p, rid):
		state = "%d poäng" % int(Data.research_cost(rid))
	else:
		state = "LÅST"
		col = Color(0.55, 0.55, 0.55)
	b.text = "%s  –  %s\n%s" % [r["name"], state, r["desc"]]
	b.add_theme_font_size_override("font_size", 14)
	b.modulate = col
	var tip := "%s\n%s\nKostnad: %d forskningspoäng" % [r["name"], r["desc"], int(Data.research_cost(rid))]
	if r["req"].size() > 0:
		var names: Array = []
		for q in r["req"]:
			names.append(Data.RESEARCH[q]["name"] + (" ✓" if Game.has_research(p, q) else ""))
		tip += "\nKräver: " + ", ".join(names)
	b.tooltip_text = tip
	b.pressed.connect(_on_click.bind(rid))
	return b


func _on_click(rid: String) -> void:
	var p := Game.player
	var st: Dictionary = Game.nations[p]
	if Game.has_research(p, rid):
		return
	if st["current_research"] == rid or rid in st["research_queue"]:
		Game.cancel_research(p, rid)
	elif Game.research_available(p, rid):
		Game.queue_research(p, rid)
	else:
		# Köa förkunskaperna först, sedan projektet.
		for q in _missing_chain(p, rid):
			Game.nations[p]["research_queue"].erase(q)
			Game.queue_research(p, q)
		Game.nations[p]["research_queue"].append(rid)
		Game.research_changed.emit()
	rebuild()


func _missing_chain(p: String, rid: String) -> Array:
	var out: Array = []
	for q in Data.RESEARCH[rid]["req"]:
		if not Game.has_research(p, q):
			for x in _missing_chain(p, q):
				if not x in out:
					out.append(x)
			if not q in out:
				out.append(q)
	return out


func update_progress() -> void:
	if _progress == null:
		return
	var p := Game.player
	var st: Dictionary = Game.nations[p]
	var rate: float = Game.rates.get(p, {}).get("forskning", 0.0)
	if st["current_research"] != "":
		var rid: String = st["current_research"]
		_progress.max_value = Data.research_cost(rid)
		_progress.value = st["research_progress"]
		var left := (Data.research_cost(rid) - st["research_progress"]) / max(0.01, rate)
		_progress_label.text = "Pågår: %s   (%.1f poäng/dag, ca %d dagar kvar)" % [Data.RESEARCH[rid]["name"], rate, int(left)]
	else:
		_progress.value = 0
		_progress_label.text = "Ingen forskning pågår. (%.1f poäng/dag, %d sparade)" % [rate, int(Game.res(p, "forskning"))]
	var names: Array = []
	for q in st["research_queue"]:
		names.append(Data.RESEARCH[q]["name"])
	_queue_label.text = ("Kö: " + ", ".join(names)) if names.size() > 0 else ""
