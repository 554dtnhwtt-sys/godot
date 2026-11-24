extends RefCounted
## Bygger lågpolygonmodeller med färg per hörn (SurfaceTool). Alla delar läggs i
## samma mesh, så en hel modell ritas med ett enda anrop.

var st := SurfaceTool.new()
var xform := Transform3D.IDENTITY
var _empty := true


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Triangel med normal som pekar bort från "inside" (Godot vill ha medurs framsidor).
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-8:
		return
	var n := cr.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	if cr.dot(n) > 0.0:
		var t := b
		b = c
		c = t
	var wn := (xform.basis * n).normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(wn)
		st.add_vertex(xform * v)
	_empty = false


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	tri(a, b, c, col, inside)
	tri(a, c, d, col, inside)


## Tvåsidig yta (segel, blad, vingar): båda sidorna läggs ut med var sin normal.
func plane_tri(a: Vector3, b: Vector3, c: Vector3, col: Color, _n := Vector3.UP) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-8:
		return
	var n := cr.normalized()
	for side in [[a, b, c, -n], [a, c, b, n]]:
		var wn: Vector3 = (xform.basis * side[3]).normalized()
		for i in 3:
			st.set_color(col)
			st.set_normal(wn)
			st.add_vertex(xform * side[i])
	_empty = false


func box(center: Vector3, size: Vector3, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	var c := center
	var p := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z),
		c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	var tc := top if top.a > 0.0 else col.lightened(0.08)
	quad(p[4], p[5], p[6], p[7], tc, c)
	quad(p[0], p[1], p[5], p[4], col.darkened(0.06), c)
	quad(p[1], p[2], p[6], p[5], col, c)
	quad(p[2], p[3], p[7], p[6], col.darkened(0.03), c)
	quad(p[3], p[0], p[4], p[7], col.darkened(0.1), c)


## Sadeltak längs X-axeln, med gavlar.
func gable(base_center: Vector3, w: float, d: float, h: float, col: Color, overhang := 2.0) -> void:
	var x := w * 0.5 + overhang
	var z := d * 0.5 + overhang
	var c := base_center
	var l1 := c + Vector3(-x, 0, -z)
	var l2 := c + Vector3(x, 0, -z)
	var r1 := c + Vector3(-x, 0, z)
	var r2 := c + Vector3(x, 0, z)
	var t1 := c + Vector3(-x, h, 0)
	var t2 := c + Vector3(x, h, 0)
	var inside := c + Vector3(0, h * 0.3, 0)
	quad(l1, l2, t2, t1, col, inside)
	quad(r1, r2, t2, t1, col.darkened(0.12), inside)
	var gw := Color(col.lightened(0.15))
	tri(c + Vector3(-w * 0.5, 0, -d * 0.5), c + Vector3(-w * 0.5, 0, d * 0.5), c + Vector3(-w * 0.5, h * 0.92, 0), gw, inside)
	tri(c + Vector3(w * 0.5, 0, -d * 0.5), c + Vector3(w * 0.5, 0, d * 0.5), c + Vector3(w * 0.5, h * 0.92, 0), gw, inside)


func pyramid(base_center: Vector3, w: float, d: float, h: float, col: Color) -> void:
	var c := base_center
	var a := c + Vector3(-w * 0.5, 0, -d * 0.5)
	var b := c + Vector3(w * 0.5, 0, -d * 0.5)
	var e := c + Vector3(w * 0.5, 0, d * 0.5)
	var f := c + Vector3(-w * 0.5, 0, d * 0.5)
	var t := c + Vector3(0, h, 0)
	var inside := c + Vector3(0, h * 0.25, 0)
	tri(a, b, t, col.darkened(0.08), inside)
	tri(b, e, t, col, inside)
	tri(e, f, t, col.darkened(0.04), inside)
	tri(f, a, t, col.darkened(0.14), inside)


func cylinder(p0: Vector3, p1: Vector3, r: float, col: Color, seg := 6, r1 := -1.0) -> void:
	if r1 < 0.0:
		r1 = r
	var axis := (p1 - p0)
	if axis.length() < 0.001:
		return
	var ax := axis.normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := ax.cross(u).normalized()
	var mid := (p0 + p1) * 0.5
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		quad(p0 + d0 * r, p0 + d1 * r, p1 + d1 * r1, p1 + d0 * r1, col.darkened(0.08 * (i % 2)), mid)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		tri(p1, p1 + (u * cos(a0) + v * sin(a0)) * r1, p1 + (u * cos(a1) + v * sin(a1)) * r1, col.lightened(0.05), p1 - ax)


func cone(base: Vector3, r: float, h: float, col: Color, seg := 7) -> void:
	var top := base + Vector3(0, h, 0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		tri(base + Vector3(cos(a0) * r, 0, sin(a0) * r), base + Vector3(cos(a1) * r, 0, sin(a1) * r), top, col.darkened(0.06 * (i % 3)), base + Vector3(0, h * 0.3, 0))


## Halvklot (kupol) eller hel låg klot (stenar, buskar, trädkronor).
func dome(center: Vector3, r: float, col: Color, seg := 8, rings := 4, full := false, squash := 1.0, jitter := 0.0, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var start := -rings if full else 0
	var pts := {}
	for j in range(start, rings + 1):
		for i in seg + 1:
			var phi := PI * 0.5 * j / rings
			var th := TAU * i / seg
			var jj := 1.0 + (rng.randf_range(-jitter, jitter) if jitter > 0.0 and i < seg and absi(j) < rings else 0.0)
			pts[Vector2i(i, j)] = center + Vector3(cos(th) * cos(phi) * r * jj, sin(phi) * r * squash * jj, sin(th) * cos(phi) * r * jj)
	for j in range(start, rings):
		for i in seg:
			var c := col.darkened(0.05 * ((i + j) % 3))
			quad(pts[Vector2i(i, j)], pts[Vector2i(i + 1, j)], pts[Vector2i(i + 1, j + 1)], pts[Vector2i(i, j + 1)], c, center)


func is_empty() -> bool:
	return _empty


func commit() -> ArrayMesh:
	return st.commit()
