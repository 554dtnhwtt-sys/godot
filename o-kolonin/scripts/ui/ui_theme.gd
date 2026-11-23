extends RefCounted
## Spelets tema: mörkt trä, mässingskanter och pergament – karibisk sjöfartskänsla.

const BG := Color(0.1, 0.08, 0.06, 0.94)
const BORDER := Color(0.78, 0.62, 0.36)
const TEXT := Color(0.97, 0.93, 0.83)
const DIM := Color(0.75, 0.7, 0.6)
const GOOD := Color(0.55, 0.92, 0.55)
const BAD := Color(1.0, 0.5, 0.45)
const GOLD := Color(1.0, 0.82, 0.35)


static func box(bg: Color, border: Color, bw: int = 2, radius: int = 6, margin: float = 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	var panel := box(BG, BORDER, 2, 8, 12.0)
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 6
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var normal := box(Color(0.33, 0.22, 0.12), Color(0.72, 0.55, 0.3), 1, 5, 6.0)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := box(Color(0.45, 0.31, 0.17), Color(0.95, 0.78, 0.45), 1, 5, 6.0)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	var pressed := box(Color(0.22, 0.15, 0.08), Color(0.95, 0.78, 0.45), 1, 5, 6.0)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	var disabled := box(Color(0.2, 0.18, 0.16), Color(0.35, 0.32, 0.28), 1, 5, 6.0)
	disabled.content_margin_left = 10
	disabled.content_margin_right = 10
	var focus := box(Color(0, 0, 0, 0), Color(1, 0.9, 0.6, 0.6), 1, 5, 6.0)
	for cls in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 1, 0.9))
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color(0.5, 0.47, 0.42))
	var cb_normal := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 4.0)
	t.set_stylebox("normal", "CheckBox", cb_normal)
	t.set_stylebox("hover", "CheckBox", box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 4, 4.0))
	t.set_stylebox("pressed", "CheckBox", cb_normal)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	var tip := box(Color(0.08, 0.06, 0.05, 0.97), BORDER, 1, 4, 8.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.5), Color(0.4, 0.35, 0.28), 1, 3, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.72, 0.6, 1.0), Color(0, 0, 0, 0), 0, 3, 0.0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.12, 0.09, 0.07, 0.98), BORDER, 1, 4, 6.0))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.4, 0.28, 0.15), Color(0, 0, 0, 0), 0, 3, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_stylebox("separator", "HSeparator", box(BORDER.darkened(0.4), Color(0, 0, 0, 0), 0, 0, 0.0))
	t.set_constant("separation", "HSeparator", 10)
	return t


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b
