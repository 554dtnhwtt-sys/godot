extends Control
## Minikarta i nedre högra hörnet. Klicka eller dra för att flytta kameran.

var world = null
var _drag := false
const W := 300.0


func _ready() -> void:
	var h := W * Data.WORLD_SIZE.y / Data.WORLD_SIZE.x
	custom_minimum_size = Vector2(W, h)
	size = Vector2(W, h)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -W - 14
	offset_right = -14
	offset_top = -h - 14
	offset_bottom = -14
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Minimap – click to move the camera, right-click to send selected ships"


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return p / Data.WORLD_SIZE * size


func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color(0.1, 0.08, 0.06, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.42, 0.55))
	for isl in world.islands:
		var c := _to_map(isl.position)
		var r: float = isl.radius / Data.WORLD_SIZE.x * size.x
		var col := Color(0.95, 0.88, 0.65)
		if isl.owner_id != "neutral":
			col = Data.nation_color(isl.owner_id).lightened(0.15)
		draw_circle(c, maxf(2.5, r), col)
	if world.fog and world.fog.tex:
		draw_texture_rect(world.fog.tex, Rect2(Vector2.ZERO, size), false, Color(0.85, 0.88, 0.9, 1.0))
	for s in world.ships:
		if not s.is_alive() or not s.visible:
			continue
		var c := _to_map(s.position)
		var col := Data.nation_color(s.owner_id).lightened(0.3)
		if s.owner_id == Game.player:
			col = Color(0.6, 1.0, 0.6) if s.selected else Color(1, 1, 1)
		draw_rect(Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), col)
	var cam: Camera2D = world.cam
	if cam:
		var vs := get_viewport_rect().size / cam.zoom
		var r := Rect2(_to_map(cam.position - vs * 0.5), vs / Data.WORLD_SIZE * size)
		draw_rect(r, Color(1, 1, 1, 0.9), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.62, 0.36), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		if event.pressed:
			_jump(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_jump(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Högerklick på minikartan: skicka markerade skepp dit.
		var wp: Vector2 = event.position / size * Data.WORLD_SIZE
		for s in world.selected_ships:
			s.order_move(wp)
		accept_event()


func _jump(p: Vector2) -> void:
	if world and world.cam:
		world.cam.focus(p / size * Data.WORLD_SIZE)
