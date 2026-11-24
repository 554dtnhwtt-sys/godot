extends Node
## Laddar spelets målade grafik (assets/). Använder Godots import när den finns
## (i editorn) och läser annars bildfilen direkt, så att spelet alltid hittar bilderna.

var _cache := {}


func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_cache[path] = t
	return t


func ship(type: String) -> Texture2D:
	return tex("res://assets/ships/%s.png" % type)


func building(type: String) -> Texture2D:
	return tex("res://assets/buildings/%s.png" % type)


func deco(name: String) -> Texture2D:
	return tex("res://assets/deco/%s.png" % name)


func portrait(nation: String) -> Texture2D:
	return tex("res://assets/portraits/%s.jpg" % nation)


func texture(name: String) -> Texture2D:
	return tex("res://assets/textures/%s.jpg" % name)


func ui(name: String) -> Texture2D:
	return tex("res://assets/ui/%s" % name)
