extends Control
## Huvudmeny med levande hav i bakgrunden.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

var main = null
var _t := 0.0
var _deco: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	var sea := ColorRect.new()
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("size", Vector2(2400, 1400))
	sea.material = mat
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sea)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var title := UITheme.label("Ö-KOLONIN", 64, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	vb.add_child(title)
	var sub := UITheme.label("Segel, socker och krut i %s" % Data.SEA_NAME, 20, UITheme.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(HSeparator.new())
	for b in [["Nytt spel", _new_game], ["Hjälp", _help], ["Avsluta", func(): get_tree().quit()]]:
		var btn := UITheme.button(b[0], b[1], 22)
		btn.custom_minimum_size = Vector2(0, 52)
		vb.add_child(btn)
	var ver := UITheme.label("Pilotversion 0.1 – gjord i Godot", 13, UITheme.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ver)


func _process(delta: float) -> void:
	_t += delta
	_deco.queue_redraw()


func _new_game() -> void:
	main.show_select()


func _help() -> void:
	var d := AcceptDialog.new()
	d.title = "Om spelet"
	d.dialog_text = "Du strandar i Smaragdhavet år 1680 som ledare för en av fyra nationer.\nBygg upp din ö, forska fram nya byggnader, perks och skeppsmodeller,\nkolonisera nya öar och strid till sjöss med segelskepp.\n\nDet finns inget slut – det är en sandlåda. Slå på endgame-kriser\nom du vill ha ett hot som enar (eller krossar) alla nationer.\n\nTryck F1 i spelet för alla kontroller."
	add_child(d)
	d.popup_centered()


func _draw_deco() -> void:
	var s := _deco.size
	# En ö i nedre vänstra hörnet och ett skepp vid horisonten.
	var ic := Vector2(s.x * 0.16, s.y * 0.86)
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var r := 220.0 * (1.0 + 0.1 * sin(a * 3.0 + 1.0) + 0.06 * sin(a * 7.0))
		pts.append(ic + Vector2(cos(a) * r, sin(a) * r * 0.45))
	var shallow := PackedVector2Array()
	for p in pts:
		shallow.append(ic + (p - ic) * 1.25)
	_deco.draw_colored_polygon(shallow, Color(0.45, 0.92, 0.88, 0.3))
	var side := PackedVector2Array()
	for p in pts:
		side.append(p + Vector2(0, 14))
	_deco.draw_colored_polygon(side, Color(0.78, 0.64, 0.42))
	_deco.draw_colored_polygon(pts, Color(0.97, 0.9, 0.7))
	var grass := PackedVector2Array()
	for p in pts:
		grass.append(ic + (p - ic) * 0.78)
	_deco.draw_colored_polygon(grass, Color(0.36, 0.67, 0.3))
	for k in 6:
		var base := ic + Vector2(-120 + k * 48, -10 + (k % 2) * 30)
		var top := base + Vector2(sin(_t * 0.8 + k) * 4.0 + 10, -80)
		_deco.draw_line(base, top, Color(0.55, 0.4, 0.25), 7.0)
		for j in 7:
			var a := -PI * 0.5 + (j - 3) * 0.55
			_deco.draw_line(top, top + Vector2(cos(a), sin(a) * 0.6 + 0.35) * 46.0, Color(0.2, 0.6, 0.25), 6.0)
	# Skepp
	var sp := Vector2(s.x * 0.8 + sin(_t * 0.1) * 30.0, s.y * 0.72 + sin(_t * 1.2) * 3.0)
	_deco.draw_colored_polygon(PackedVector2Array([sp + Vector2(-80, 0), sp + Vector2(80, 0), sp + Vector2(60, 26), sp + Vector2(-64, 26)]), Color(0.35, 0.22, 0.12))
	for m in 3:
		var mx := sp + Vector2(-44 + m * 44, 0)
		_deco.draw_line(mx, mx + Vector2(0, -130 + abs(m - 1) * 20), Color(0.3, 0.2, 0.12), 4.0)
		for k in 2:
			var y0 := -40.0 - k * 46.0
			var w := 34.0 - k * 6.0
			_deco.draw_colored_polygon(PackedVector2Array([mx + Vector2(-w, y0 - 38), mx + Vector2(w, y0 - 38), mx + Vector2(w + 6, y0), mx + Vector2(-w + 6, y0)]), Color(0.97, 0.95, 0.88))
	_deco.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -132), sp + Vector2(26, -126), sp + Vector2(0, -120)]), Color(0.85, 0.2, 0.2))
