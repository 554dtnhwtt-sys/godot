extends PanelContainer
## Diplomati: relationer, krig, fred, handelsavtal, allianser, tribut, gåvor
## och gemensamma krig. Visar också kriserna och fientliga fraktioner.

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const Emblem = preload("res://scripts/ui/emblem.gd")

var hud = null
var _content: VBoxContainer
var _result: Label
var _rows := {}
var _war_targets := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1080, 600)
	offset_left = -540
	offset_right = 540
	offset_top = -300
	offset_bottom = 300
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	add_child(_content)


func rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_rows.clear()
	var head := HBoxContainer.new()
	head.add_child(UITheme.label("Diplomacy", 26, UITheme.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.button("Close (P)", func(): visible = false, 15))
	_content.add_child(head)
	_result = UITheme.wrap_label("Choose an action. Relations decide what the other nations will agree to – trade and alliances require trust, tribute requires you to be much stronger.", 14, UITheme.DIM)
	_content.add_child(_result)
	var p := Game.player
	for n in Data.PLAYABLE:
		if n == p:
			continue
		_content.add_child(_nation_row(n))
		_content.add_child(HSeparator.new())
	_content.add_child(_crisis_row())
	update_values()


func _nation_row(n: String) -> Control:
	var p := Game.player
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.5), Data.nation_accent(n), 2, 5, 2.0))
	var portrait := TextureRect.new()
	portrait.texture = Art.portrait(n)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2(84, 84)
	frame.add_child(portrait)
	hb.add_child(frame)
	hb.add_child(Emblem.new(n, 46.0))
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 330
	info.add_child(UITheme.label(Data.NATIONS[n]["name"], 19, Data.nation_color(n).lightened(0.4)))
	info.add_child(UITheme.label(Data.NATIONS[n]["leader"] + " – " + Data.NATIONS[n]["type"], 13, UITheme.DIM))
	var status := UITheme.label("", 15)
	info.add_child(status)
	var bar := ProgressBar.new()
	bar.min_value = -100
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 12)
	info.add_child(bar)
	var strength := UITheme.label("", 13, UITheme.DIM)
	info.add_child(strength)
	hb.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var buttons := {}
	var actions := [
		["krig", "Declare war"], ["fred", "Propose peace"], ["handel", "Trade agreement"], ["allians", "Alliance"],
		["bryt", "Break agreement"], ["gava", "Gift (100 gold)"], ["lyxgava", "Luxury gift"], ["tribut", "Demand tribute"],
	]
	for a in actions:
		var b := UITheme.button(a[1], _act.bind(a[0], n), 14)
		b.custom_minimum_size = Vector2(150, 32)
		grid.add_child(b)
		buttons[a[0]] = b
	buttons["lyxgava"].tooltip_text = "20 spices and 10 pearls – improves relations far more than gold."
	buttons["tribut"].tooltip_text = "Demand 30% of their gold. Requires you to be at least 60% stronger."
	var jw := HBoxContainer.new()
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(150, 32)
	for m in Data.PLAYABLE:
		if m != p and m != n:
			ob.add_item(Data.nation_short(m))
			ob.set_item_metadata(ob.item_count - 1, m)
	_war_targets[n] = ob
	var jb := UITheme.button("Joint war against", _joint_war.bind(n), 14)
	jb.custom_minimum_size = Vector2(170, 32)
	jb.tooltip_text = "Ask an ally to declare war on another nation."
	jw.add_child(jb)
	jw.add_child(ob)
	buttons["gemensamt_krig"] = jb
	var right := VBoxContainer.new()
	right.add_child(grid)
	right.add_child(jw)
	hb.add_child(right)
	_rows[n] = {"status": status, "bar": bar, "strength": strength, "buttons": buttons}
	return hb


func _crisis_row() -> Control:
	var vb := VBoxContainer.new()
	vb.add_child(UITheme.label("Other powers", 18, UITheme.GOLD))
	var l := UITheme.wrap_label("", 14)
	vb.add_child(l)
	_rows["_crisis"] = {"label": l}
	return vb


func update_values() -> void:
	if _content == null or _rows.is_empty():
		return
	var p := Game.player
	var my_str := Game.nation_strength(p)
	for n in _rows:
		if n == "_crisis":
			continue
		var row: Dictionary = _rows[n]
		var rel := Game.get_rel(p, n)
		var st: String = rel["status"]
		var alive: bool = Game.nations[n]["alive"]
		row["status"].text = ("%s   Relation: %d" % [Game.STATUS_NAMES[st], int(rel["value"])]) if alive else "Has fallen"
		row["status"].add_theme_color_override("font_color", Game.STATUS_COLORS[st] if alive else UITheme.DIM)
		row["bar"].value = rel["value"]
		var fill_col := UITheme.GOOD if rel["value"] >= 0 else UITheme.BAD
		row["bar"].add_theme_stylebox_override("fill", UITheme.box(fill_col, Color(0, 0, 0, 0), 0, 3, 0.0))
		var their := Game.nation_strength(n)
		var ratio := my_str / maxf(1.0, their)
		var cmp := "evenly matched"
		if ratio > 1.6:
			cmp = "you are much stronger"
		elif ratio > 1.15:
			cmp = "you are stronger"
		elif ratio < 0.6:
			cmp = "they are much stronger"
		elif ratio < 0.87:
			cmp = "they are stronger"
		row["strength"].text = "Strength: %d against your %d (%s).  Islands: %d" % [int(their), int(my_str), cmp, Game.world.islands_of(n).size()]
		var b: Dictionary = row["buttons"]
		b["krig"].disabled = not alive or st == "krig"
		b["fred"].disabled = not alive or st != "krig"
		b["handel"].disabled = not alive or st != "fred"
		b["allians"].disabled = not alive or st != "handel"
		b["bryt"].disabled = not alive or not (st == "handel" or st == "allians")
		b["gava"].disabled = not alive or Game.res(p, "guld") < 100.0
		b["lyxgava"].disabled = not alive or not Game.can_afford(p, {"kryddor": 20.0, "parlor": 10.0})
		b["tribut"].disabled = not alive or st == "krig"
		b["gemensamt_krig"].disabled = not alive or st != "allians"
	var lines: Array = []
	for f in ["vildpirater", "spokflottan", "vaktarna"]:
		var name: String = Data.HOSTILE_FACTIONS[f]["name"]
		match f:
			"vildpirater":
				lines.append("%s: enemies of everyone. They appear as events." % name)
			"spokflottan":
				if not Game.settings["crises"].get("spokflottan", false):
					continue
				var state := "active – everyone is in danger!" if Game.active_crises.has("spokflottan") else "resting in the deep ... for now"
				lines.append("%s: %s" % [name, state])
			"vaktarna":
				if not Game.settings["crises"].get("vaktarna", false):
					continue
				var state := "awake and hostile to everyone!" if Game.vaktarna_awake else ("hostile to you" if Game.vaktarna_angry.has(p) else "asleep on Sunstone Isle. Do not come too close.")
				lines.append("%s: %s" % [name, state])
	_rows["_crisis"]["label"].text = "\n".join(lines)


func _act(action: String, n: String) -> void:
	var r := Game.player_proposal(action, n)
	_result.text = r["text"]
	_result.add_theme_color_override("font_color", UITheme.GOOD if r["ok"] else UITheme.BAD)
	update_values()


func _joint_war(n: String) -> void:
	var ob: OptionButton = _war_targets[n]
	if ob.selected < 0:
		return
	var target: String = ob.get_item_metadata(ob.selected)
	var r := Game.player_proposal("gemensamt_krig", n, target)
	_result.text = r["text"]
	_result.add_theme_color_override("font_color", UITheme.GOOD if r["ok"] else UITheme.BAD)
	update_values()
