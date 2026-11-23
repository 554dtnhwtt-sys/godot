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
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1080, 600)
	position = Vector2(-540, -300)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	add_child(_content)


func rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_rows.clear()
	var head := HBoxContainer.new()
	head.add_child(UITheme.label("Diplomati", 26, UITheme.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.button("Stäng (P)", func(): visible = false, 15))
	_content.add_child(head)
	_result = UITheme.wrap_label("Välj en åtgärd. Relationen avgör vad de andra nationerna går med på – handel och allianser kräver förtroende, tribut kräver att du är mycket starkare.", 14, UITheme.DIM)
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
	hb.add_child(Emblem.new(n, 56.0))
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
		["krig", "Förklara krig"], ["fred", "Föreslå fred"], ["handel", "Handelsavtal"], ["allians", "Allians"],
		["bryt", "Bryt avtal"], ["gava", "Gåva (100 guld)"], ["lyxgava", "Lyxgåva"], ["tribut", "Kräv tribut"],
	]
	for a in actions:
		var b := UITheme.button(a[1], _act.bind(a[0], n), 14)
		b.custom_minimum_size = Vector2(150, 32)
		grid.add_child(b)
		buttons[a[0]] = b
	buttons["lyxgava"].tooltip_text = "20 kryddor och 10 pärlor – ger mycket bättre relation än guld."
	buttons["tribut"].tooltip_text = "Kräv 30 % av deras guld. Kräver att du är minst 60 % starkare."
	var jw := HBoxContainer.new()
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(150, 32)
	for m in Data.PLAYABLE:
		if m != p and m != n:
			ob.add_item(Data.nation_short(m))
			ob.set_item_metadata(ob.item_count - 1, m)
	_war_targets[n] = ob
	var jb := UITheme.button("Gemensamt krig mot", _joint_war.bind(n), 14)
	jb.custom_minimum_size = Vector2(170, 32)
	jb.tooltip_text = "Be en allierad att förklara krig mot en annan nation."
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
	vb.add_child(UITheme.label("Andra makter", 18, UITheme.GOLD))
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
		row["status"].text = ("%s   Relation: %d" % [Game.STATUS_NAMES[st], int(rel["value"])]) if alive else "Har fallit"
		row["status"].add_theme_color_override("font_color", Game.STATUS_COLORS[st] if alive else UITheme.DIM)
		row["bar"].value = rel["value"]
		var fill_col := UITheme.GOOD if rel["value"] >= 0 else UITheme.BAD
		row["bar"].add_theme_stylebox_override("fill", UITheme.box(fill_col, Color(0, 0, 0, 0), 0, 3, 0.0))
		var their := Game.nation_strength(n)
		var ratio := my_str / maxf(1.0, their)
		var cmp := "jämnstarka"
		if ratio > 1.6:
			cmp = "du är mycket starkare"
		elif ratio > 1.15:
			cmp = "du är starkare"
		elif ratio < 0.6:
			cmp = "de är mycket starkare"
		elif ratio < 0.87:
			cmp = "de är starkare"
		row["strength"].text = "Styrka: %d mot din %d (%s).  Öar: %d" % [int(their), int(my_str), cmp, Game.world.islands_of(n).size()]
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
				lines.append("%s: fiender till alla. Dyker upp som händelser." % name)
			"spokflottan":
				if not Game.settings["crises"].get("spokflottan", false):
					continue
				var state := "aktiv – alla är i fara!" if Game.active_crises.has("spokflottan") else "vilar i djupet ... än så länge"
				lines.append("%s: %s" % [name, state])
			"vaktarna":
				if not Game.settings["crises"].get("vaktarna", false):
					continue
				var state := "vakna och fientliga mot alla!" if Game.vaktarna_awake else ("fientliga mot dig" if Game.vaktarna_angry.has(p) else "sover på Solstensön. Kom inte för nära.")
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
