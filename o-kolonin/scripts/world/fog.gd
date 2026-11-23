extends Sprite2D
## Dimman över havet. Varje pixel i bilden täcker CELL x CELL världspixlar.
## Utforskade områden förblir öppna; fiendeskepp syns bara inom synhåll.

const CELL := 40.0

var img: Image
var tex: ImageTexture
var gw := 0
var gh := 0
var _dirty := false


func setup() -> void:
	gw = int(ceil(Data.WORLD_SIZE.x / CELL))
	gh = int(ceil(Data.WORLD_SIZE.y / CELL))
	img = Image.create_empty(gw, gh, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	tex = ImageTexture.create_from_image(img)
	texture = tex
	centered = false
	scale = Vector2(CELL, CELL)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog.gdshader")
	mat.set_shader_parameter("grid", Vector2(gw, gh))
	material = mat
	z_index = 20


func reveal(pos: Vector2, radius: float) -> void:
	var cx := pos.x / CELL
	var cy := pos.y / CELL
	var r := radius / CELL
	var x0 := maxi(0, int(cx - r - 1))
	var x1 := mini(gw - 1, int(cx + r + 1))
	var y0 := maxi(0, int(cy - r - 1))
	var y1 := mini(gh - 1, int(cy + r + 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d >= r:
				continue
			var a: float = clamp((d - (r - 2.0)) / 2.0, 0.0, 1.0)
			if a < img.get_pixel(x, y).a - 0.01:
				img.set_pixel(x, y, Color(1, 1, 1, a))
				_dirty = true


func reveal_all() -> void:
	img.fill(Color(1, 1, 1, 0))
	_dirty = true


func commit() -> void:
	if _dirty:
		tex.update(img)
		_dirty = false


func is_explored(pos: Vector2) -> bool:
	var x := clampi(int(pos.x / CELL), 0, gw - 1)
	var y := clampi(int(pos.y / CELL), 0, gh - 1)
	return img.get_pixel(x, y).a < 0.5


func explored_value(x: int, y: int) -> float:
	return 1.0 - img.get_pixel(x, y).a
