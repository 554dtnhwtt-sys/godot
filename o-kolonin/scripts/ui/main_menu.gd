extends Control
## Huvudmeny: målad karibisk vik som sakta zoomar, med menyn till vänster.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

var main = null
var _t := 0.0
var _bg: TextureRect
var _shine: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	clip_contents = true
	_bg = TextureRect.new()
	_bg.texture = Art.ui("menu_bg.jpg")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# Mörk toning bakom menyn så texten syns
	_shine = Control.new()
	_shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.draw.connect(_draw_overlay)
	add_child(_shine)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.05, 0.04, 0.82), UITheme.BORDER, 2, 10, 22.0))
	panel.custom_minimum_size = Vector2(460, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 90
	panel.offset_right = 550
	panel.offset_top = -230
	panel.offset_bottom = 230
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var title := UITheme.label("ISLAND COLONY", 66, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.02))
	title.add_theme_constant_override("outline_size", 6)
	vb.add_child(title)
	var sub := UITheme.label("Sails, sugar and gunpowder in %s" % Data.SEA_NAME, 19, UITheme.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(HSeparator.new())
	for b in [["New game", _new_game], ["Help", _help], ["Quit", func(): get_tree().quit()]]:
		var btn := UITheme.button(b[0], b[1], 22)
		btn.custom_minimum_size = Vector2(0, 54)
		vb.add_child(btn)
	var ver := UITheme.label("Pilot version 0.5", 13, UITheme.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ver)


func _process(delta: float) -> void:
	_t += delta
	# Långsam zoom och panorering över målningen
	var k := 1.06 + 0.04 * sin(_t * 0.05)
	_bg.pivot_offset = _bg.size * 0.5
	_bg.scale = Vector2(k, k)
	_bg.position = Vector2(sin(_t * 0.035) * 30.0, cos(_t * 0.03) * 12.0)
	_shine.queue_redraw()


func _draw_overlay() -> void:
	var s := _shine.size
	# Mörkare åt vänster där menyn står
	var dark := Color(0.02, 0.02, 0.05, 0.6)
	var clear := Color(0.02, 0.02, 0.05, 0.0)
	_shine.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x * 0.55, 0), Vector2(s.x * 0.55, s.y), Vector2(0, s.y)]), PackedColorArray([dark, clear, clear, dark]))
	# Solglitter på vattnet
	for i in 18:
		var ph := fmod(_t * 0.3 + i * 0.137, 1.0)
		var p := Vector2(s.x * (0.52 + 0.3 * fmod(i * 0.618, 1.0)), s.y * (0.6 + 0.12 * fmod(i * 0.414, 1.0)))
		_shine.draw_circle(p, 2.0 + 2.0 * sin(ph * PI), Color(1, 0.95, 0.75, 0.6 * sin(ph * PI)))


func _new_game() -> void:
	main.show_select()


func _help() -> void:
	var d := AcceptDialog.new()
	d.title = "About the game"
	d.dialog_text = "You arrive in the Emerald Sea in the year 1680 as the leader of one of four nations.\nBuild up your island, research new buildings, perks and ship designs,\ncolonize new islands and fight at sea with sailing ships.\n\nThere is no ending – it is a sandbox. Turn on the endgame crises\nif you want a threat that unites (or crushes) every nation.\n\nPress F1 in the game for all controls."
	add_child(d)
	d.popup_centered()
