extends Camera2D
## Kamera: WASD/piltangenter eller mellanknapp för att panorera, scrollhjul för zoom.
## Fungerar även när spelet är pausat och oberoende av tidshastigheten.

const PAN_SPEED := 1100.0
const MIN_ZOOM := 0.22
const MAX_ZOOM := 1.6

var _drag := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	zoom = Vector2(0.6, 0.6)
	limit_left = 0
	limit_top = 0
	limit_right = int(Data.WORLD_SIZE.x)
	limit_bottom = int(Data.WORLD_SIZE.y)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(0.001, Engine.time_scale)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO and not _text_focus():
		position += dir.normalized() * PAN_SPEED * real_delta / zoom.x
	_clamp()


func _text_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _clamp() -> void:
	position.x = clampf(position.x, 0.0, Data.WORLD_SIZE.x)
	position.y = clampf(position.y, 0.0, Data.WORLD_SIZE.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
			_last_mouse = mb.position
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		position -= (mm.position - _last_mouse) / zoom.x
		_last_mouse = mm.position
		_clamp()


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := get_global_mouse_position()
	var z: float = clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	var after := get_global_mouse_position()
	position += before - after
	_clamp()


func focus(p: Vector2) -> void:
	position = p
	_clamp()
