class_name HarborPromenade
extends RefCounted
## Original quayside: continuous seawall, boardwalk, marina and planted promenade.
static func build(track: CityTrack) -> void:
	var root := Node3D.new()
	root.name = "HarborPromenade"
	track.add_child(root)
	var b := {}
	var trees: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 14112026
	var start := track.anchor_distance(9)
	var end := track.anchor_distance(14)
	_structure(root, track)
	for index in range(int((end - start) / 32.0)):
		var distance := start + 18 + index * 32.0
		var p := track.transform_at(distance)
		p.origin.y = 0
		_bench(b, p, Vector3(-24.7, 0.25, 0))
		_put(b, "metal", p, Vector3(-20.8, 2.8, -8), Vector3(0.13, 5.6, 0.13))
		_put(b, "metal", p, Vector3(-21.5, 5.55, -8), Vector3(1.5, 0.09, 0.10))
		_put(b, "warm", p, Vector3(-22, 5.48, -8), Vector3(0.65, 0.04, 0.38))
		_put(b, "stone", p, Vector3(-20.6, 0.45, 9), Vector3(1.6, 0.5, 1.6))
		var tree := p * Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(Vector3.ONE * rng.randf_range(0.83, 1.12)), Vector3(-20.6, 0.7, 9))
		trees.append(tree)
		if index % 3 == 0:
			_put(b, "metal", p, Vector3(-24.8, 0.68, 6), Vector3(0.45, 0.85, 0.45))
	for i in [10, 12]:
		var p := track.transform_at(track.anchor_distance(i) + 80)
		p.origin.y = 0
		_pier(root, b, p, i)
		_light(root, p)
	_flush(root, b)
	var meshes := HarborTrees.meshes()
	var bark := GameGeometry.material(Color("4f493d"))
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = load("res://assets/materials/harbor_leaves.gdshader")
	for i in 2:
		CityDistricts._batch_mesh(root, meshes[i], trees, bark if i == 0 else leaf_material)
		var batch := root.get_child(root.get_child_count() - 1) as GeometryInstance3D
		batch.name = "TreeBranches" if i == 0 else "TreeLeaves"
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("tree_count", trees.size())
	root.set_meta("pier_count", 2)
	root.set_meta("boat_count", 4)
	var instances := trees.size() * 2
	for poses in b.values():
		instances += poses.size()
	root.set_meta("instance_count", instances)

static func _put(b: Dictionary, key: String, p: Transform3D, at: Vector3, size: Vector3) -> void:
	StreetShowcase._put(b, key, p, at, size)

static func _bench(b: Dictionary, p: Transform3D, at: Vector3) -> void:
	for i in 5:
		_put(b, "wood", p, at + Vector3(-0.27 + i * 0.135, 0.43, 0), Vector3(0.10, 0.055, 2.2))
	for i in 4:
		_put(b, "wood", p, at + Vector3(-0.35, 0.68 + i * 0.14, 0), Vector3(0.055, 0.10, 2.2))
	for z in [-0.82, 0.82]:
		_put(b, "metal", p, at + Vector3(0, 0.22, z), Vector3(0.6, 0.40, 0.07))
		_put(b, "metal", p, at + Vector3(-0.35, 0.7, z), Vector3(0.07, 0.9, 0.07))

static func _pier(root: Node3D, b: Dictionary, p: Transform3D, index: int) -> void:
	# Steps descend from the stone quay to the lower marina pontoons.
	for step in 7:
		_put(b, "cap", p, Vector3(-28.5 - step * 0.55, 0.15 - step * 0.19, 0), Vector3(0.6, 0.18, 3.0))
	_put(b, "deck", p, Vector3(-46, -1.05, 0), Vector3(29, 0.22, 3.0))
	_put(b, "deck", p, Vector3(-59.5, -1.05, 0), Vector3(3, 0.22, 19))
	for x in [-34.0, -44.0, -54.0, -59.5]:
		_put(b, "metal", p, Vector3(x, -1.6, 0), Vector3(0.22, 1.6, 0.22))
		for z in [-1.3, 1.3]:
			_put(b, "metal", p, Vector3(x, -0.82, z), Vector3(0.10, 0.22, 0.10))
	for side in [-1.0, 1.0]:
		var boat := Node3D.new()
		boat.name = "CabinBoat_%d_%s" % [index, "Left" if side < 0 else "Right"]
		root.add_child(boat)
		boat.transform = p * Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(-47, HarborCoast.WATER_Y, side * 3.8))
		_boat(boat, index == 10)
		for x in [-44.0, -54.0]:
			var cleat := Vector3(x, -0.82, side * 1.3)
			var mooring := Vector3(-44.5 if x == -44 else -50.0, -0.90, side * 2.75)
			var rope_pose := p * Transform3D(Basis.looking_at((mooring - cleat).normalized(), Vector3.UP), (cleat + mooring) / 2)
			_put(b, "rope", rope_pose, Vector3.ZERO, Vector3(0.025, 0.025, cleat.distance_to(mooring)))
	var sign := Label3D.new()
	sign.text = "ПРИЧАЛ %02d\nПОРТОВАЯ НАБЕРЕЖНАЯ" % (1 if index == 10 else 2)
	sign.font_size = 48
	sign.pixel_size = 0.008
	sign.modulate = Color("d2c5ad")
	sign.shaded = true
	root.add_child(sign)
	sign.transform = p * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-25.8, 1.55, 2.8))
	_put(b, "metal", p, Vector3(-25.9, 1.55, 2.8), Vector3(0.12, 1.15, 4))

static func _boat(root: Node3D, blue: bool) -> void:
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lower := [Vector3(0, -0.48, -3.0), Vector3(0.70, -0.40, -1.7), Vector3(0.7, -0.35, 2.5), Vector3(-0.7, -0.35, 2.5), Vector3(-0.7, -0.40, -1.7)]
	var upper := [Vector3(0, 0.55, -3.4), Vector3(1.10, 0.55, -1.7), Vector3(1.05, 0.55, 2.7), Vector3(-1.05, 0.55, 2.7), Vector3(-1.10, 0.55, -1.7)]
	for i in 5:
		var j := (i + 1) % 5
		for point in [lower[i], upper[i], upper[j], lower[i], upper[j], lower[j]]:
			hull.add_vertex(point)
	hull.generate_normals()
	var material := GameGeometry.material(Color("d6d1c2"))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := MeshInstance3D.new()
	mesh.mesh = hull.commit()
	mesh.material_override = material
	root.add_child(mesh)
	var trim := GameGeometry.material(Color("2b4b60") if blue else Color("6d493a"))
	var deck := GameGeometry.material(Color("b3a58a"))
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := PackedVector2Array()
	for point in upper:
		outline.append(Vector2(point.x, point.z))
	for index in Geometry2D.triangulate_polygon(outline):
		cap.set_normal(Vector3.UP)
		cap.add_vertex(Vector3(outline[index].x, 0.49, outline[index].y))
	var cap_mesh := MeshInstance3D.new()
	cap_mesh.mesh = cap.commit()
	var deck_material: StandardMaterial3D = deck.duplicate()
	deck_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cap_mesh.material_override = deck_material
	root.add_child(cap_mesh)
	GameGeometry.box(root, Vector3(1.85, 0.12, 3.8), Vector3(0, 0.48, 0.5), deck)
	GameGeometry.box(root, Vector3(1.55, 0.95, 2), Vector3(0, 0.98, 0.7), trim)
	var glass := GameGeometry.material(Color("203947"))
	glass.roughness = 0.20
	GameGeometry.box(root, Vector3(1.38, 0.55, 0.045), Vector3(0, 1.07, -0.32), glass)
	for side in [-1.0, 1.0]:
		GameGeometry.box(root, Vector3(0.045, 0.55, 1.6), Vector3(side * 0.79, 1.07, 0.7), glass)
		GameGeometry.box(root, Vector3(0.055, 0.65, 4.6), Vector3(side * 0.98, 0.55, 0.4), trim)
	GameGeometry.box(root, Vector3(1.9, 0.1, 2.4), Vector3(0, 1.5, 0.7), material)
	GameGeometry.box(root, Vector3(0.04, 1.3, 0.04), Vector3(0, 2.15, 0.7), trim)

static func _light(root: Node3D, p: Transform3D) -> void:
	var light := OmniLight3D.new()
	light.name = "QuayLight"
	root.add_child(light)
	light.position = p * Vector3(-23, 4.6, 0)
	light.light_color = Color("ffdfb6")
	light.light_energy = 2.5
	light.omni_range = 19
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 85
	light.distance_fade_length = 20

static func _flush(root: Node3D, b: Dictionary) -> void:
	var wood := GameGeometry.material(Color("7b6b52"))
	var deck := ShaderMaterial.new()
	deck.shader = load("res://assets/materials/harbor_deck.gdshader")
	var materials := {"stone": CityArchitecture._masonry(Color("555d5c"), false),
		"cap": GameGeometry.material(Color("85877e")), "deck": deck, "wood": wood,
		"metal": GameGeometry.material(Color("37444b")), "warm": GameGeometry.material(Color("ebc795"), 0.6),
		"rope": GameGeometry.material(Color("817861"))}
	for key in b:
		var poses: Array[Transform3D] = []
		poses.assign(b[key])
		GameGeometry.batch_boxes(root, poses, materials[key])
		root.get_child(root.get_child_count() - 1).name = "Batch_" + key

static func _structure(root: Node3D, track: CityTrack) -> void:
	var deck := SurfaceTool.new()
	var cap := SurfaceTool.new()
	var wall := SurfaceTool.new()
	for st in [deck, cap, wall]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(9 * CityTrack.SAMPLES_PER_CORNER, 14 * CityTrack.SAMPLES_PER_CORNER):
		var p := track.points[i]
		var q := track.points[i + 1]
		var a := -(q - track.points[i - 1]).normalized().cross(Vector3.UP)
		var b := -(track.points[i + 2] - p).normalized().cross(Vector3.UP)
		_strip(deck, p, q, a, b, 19.4, 27.2, 0.26, track.distances[i], track.distances[i + 1])
		_strip(cap, p, q, a, b, 26.35, 28.25, 0.33, 0, 1)
		for offset in [26.4, 28.2]:
			var top_a: Vector3 = p + a * offset + Vector3.UP * 0.27
			var top_b: Vector3 = q + b * offset + Vector3.UP * 0.27
			var lower_a := top_a - Vector3.UP * 2.25
			var lower_b := top_b - Vector3.UP * 2.25
			var normal: Vector3 = (a + b).normalized() * (1.0 if offset > 27 else -1.0)
			for vertex in [top_a, lower_a, top_b, lower_a, lower_b, top_b, top_b, lower_a, top_a, top_b, lower_b, lower_a]:
				wall.set_normal(normal)
				wall.add_vertex(vertex)
	var deck_material := ShaderMaterial.new()
	deck_material.shader = load("res://assets/materials/harbor_deck.gdshader")
	deck_material.set_shader_parameter("metric_uv", true)
	var cap_material := GameGeometry.material(Color("85877e"))
	cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var materials: Array[Material] = [deck_material, cap_material, CityArchitecture._masonry(Color("555d5c"), false)]
	var names := ["ContinuousBoardwalk", "QuayCoping", "QuayWall"]
	var tools := [deck, cap, wall]
	for i in 3:
		var mesh := MeshInstance3D.new()
		mesh.name = names[i]
		mesh.mesh = tools[i].commit()
		mesh.material_override = materials[i]
		root.add_child(mesh)

static func _strip(st: SurfaceTool, p: Vector3, q: Vector3, a: Vector3, b: Vector3, inner: float, outer: float, y: float, d0: float, d1: float) -> void:
	var vertices := [p + a * inner, p + a * outer, q + b * inner, q + b * outer]
	var uvs := [Vector2(0, d0), Vector2(outer - inner, d0), Vector2(0, d1), Vector2(outer - inner, d1)]
	for index in [0, 1, 2, 1, 3, 2]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[index])
		var vertex: Vector3 = vertices[index]
		vertex.y = y
		st.add_vertex(vertex)
