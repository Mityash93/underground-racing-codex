class_name HarborTrees
extends RefCounted
## Shared original branching tree mesh and cutout leaf clusters, no downloaded textures.
static var _cached: Array[Mesh] = []
static func meshes() -> Array[Mesh]:
	if not _cached.is_empty():
		return _cached
	var bark := SurfaceTool.new()
	var leaves := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 146319
	_branch(bark, Vector3.ZERO, Vector3(0.08, 3.7, 0.05), 0.17, 0.09)
	_branch(bark, Vector3(0.08, 3.7, 0.05), Vector3(-0.2, 5.4, 0.12), 0.09, 0.025)
	for i in 7:
		var angle := i * 2.399
		var end := Vector3(cos(angle) * 1.6, 4.2 + rng.randf() * 1.1, sin(angle) * 1.5)
		_branch(bark, Vector3(0.05, 2.5 + i * 0.17, 0.05), end, 0.065, 0.015)
	for i in 76:
		var angle := rng.randf_range(0, TAU)
		var radius := sqrt(rng.randf()) * 1.9
		var center := Vector3(cos(angle) * radius, 4.7 + rng.randf_range(-0.75, 0.9), sin(angle) * radius * 0.85)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(0, TAU), rng.randf_range(-0.5, 0.5)))
		var width := rng.randf_range(1.0, 1.7)
		var height := rng.randf_range(1.0, 1.6)
		var color := Color.WHITE * rng.randf_range(0.72, 1.15)
		var corners := [Vector3(-width / 2, -height / 2, 0), Vector3(width / 2, -height / 2, 0), Vector3(width / 2, height / 2, 0), Vector3(-width / 2, height / 2, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for index in [0, 2, 1, 0, 3, 2]:
			leaves.set_normal(basis.z)
			leaves.set_color(color)
			leaves.set_uv(uvs[index])
			leaves.add_vertex(center + basis * corners[index])
	_cached = [bark.commit(), leaves.commit()]
	return _cached

static func _branch(st: SurfaceTool, a: Vector3, b: Vector3, lower: float, upper: float) -> void:
	var axis := (b - a).normalized()
	var right := axis.cross(Vector3.RIGHT if absf(axis.y) > 0.95 else Vector3.UP).normalized()
	var forward := axis.cross(right).normalized()
	for i in 7:
		var n := right * cos(TAU * i / 7) + forward * sin(TAU * i / 7)
		var m := right * cos(TAU * (i + 1) / 7) + forward * sin(TAU * (i + 1) / 7)
		var points := [a + n * lower, b + n * upper, a + m * lower, b + m * upper]
		for index in [0, 1, 2, 1, 3, 2]:
			st.set_normal(n if index < 2 else m)
			st.add_vertex(points[index])
