class_name CoupeBody
extends RefCounted
## Original procedural coachwork: continuous beveled sections, framed glazing and trim.

const AXLE_X := 0.87
const WHEEL_Y := 0.47
const FRONT_AXLE_Z := -1.34
const REAR_AXLE_Z := 1.36
const ARCH_RADIUS := 0.505
const LENGTH_Z := 2.27
const STATIONS := [-2.27, -2.00, -1.34, -0.73, 0.70, 1.36, 1.98, 2.27]

static func build(parent: Node3D, paint: StandardMaterial3D, trim: Material, glass: Material, rear_lights: Material) -> void:
	_body(parent, paint)
	_cabin(parent, paint, glass)
	_arches(parent, paint, trim)
	_panels(parent, trim)
	_bumpers(parent, paint, trim, rear_lights)
	var alloy := GameGeometry.material(Color("a7b5c4"))
	alloy.metallic = 0.85
	alloy.roughness = 0.25
	for side in [-1.0, 1.0]:
		var mirror := rounded_box(parent, Vector3(0.22, 0.115, 0.25), Vector3(side * 0.92, 1.0, -0.43), 0.035, paint)
		mirror.name = "Mirror"
		rounded_box(parent, Vector3(0.025, 0.078, 0.15), Vector3(side * 1.04, 1.0, -0.41), 0.008, glass)
		rounded_box(parent, Vector3(0.035, 0.04, 0.19), Vector3(side * 0.997, 0.76, 0.41), 0.01, alloy)
		rounded_box(parent, Vector3(0.07, 0.11, 1.47), Vector3(side * 0.98, 0.34, 0.01), 0.025, trim)
		GameGeometry.box(parent, Vector3(0.05, 0.13, 0.065), Vector3(side * 0.57, 0.98, 1.86), trim)
		_cylinder(parent, 0.065, 0.15, Vector3(side * 0.72, 0.35, 2.30), alloy)
		_cylinder(parent, 0.046, 0.155, Vector3(side * 0.72, 0.35, 2.31), trim)
	rounded_box(parent, Vector3(1.80, 0.065, 0.25), Vector3(0, 1.065, 1.87), 0.027, trim)
	rounded_box(parent, Vector3(1.16, 0.13, 3.85), Vector3(0, 0.30, 0), 0.04, trim)

static func width_at(z: float) -> float:
	return profile(z, STATIONS, [0.875, 0.985, 1.04, 0.99, 0.995, 1.045, 1.00, 0.92])

static func deck_height(z: float) -> float:
	return profile(z, STATIONS, [0.70, 0.79, 0.875, 0.90, 0.90, 0.91, 0.855, 0.765])

static func fender_height(z: float) -> float:
	return profile(z, STATIONS, [0.72, 0.87, 1.065, 0.94, 0.94, 1.065, 0.93, 0.79])

static func arch_height(z: float) -> float:
	var height := 0.30
	for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
		var offset: float = absf(z - axle)
		if offset < ARCH_RADIUS:
			height = maxf(height, WHEEL_Y + sqrt(ARCH_RADIUS * ARCH_RADIUS - offset * offset))
	return height

static func profile(z: float, stations: Array, values: Array) -> float:
	for i in range(stations.size() - 1):
		if z <= stations[i + 1]:
			var t := clampf(inverse_lerp(stations[i], stations[i + 1], z), 0.0, 1.0)
			return lerpf(values[i], values[i + 1], t * t * (3.0 - 2.0 * t))
	return values[values.size() - 1]

static func _body(parent: Node3D, paint: Material) -> void:
	var st := _surface()
	var rows: Array[PackedVector3Array] = []
	for i in 129:
		var z := lerpf(-LENGTH_Z, LENGTH_Z, i / 128.0)
		var w := width_at(z)
		var h := fender_height(z)
		var d := deck_height(z)
		var bottom := arch_height(z)
		rows.append(PackedVector3Array([
			Vector3(-w + 0.022, bottom, z), Vector3(-w, maxf(h - 0.065, bottom + 0.015), z),
			Vector3(-w + 0.045, h, z), Vector3(-0.65, d + 0.012, z), Vector3(0, d + 0.025, z),
			Vector3(0.65, d + 0.012, z), Vector3(w - 0.045, h, z),
			Vector3(w, maxf(h - 0.065, bottom + 0.015), z), Vector3(w - 0.022, bottom, z)]))
	for i in range(rows.size() - 1):
		var a := rows[i]
		var b := rows[i + 1]
		_quad(st, a[0], a[1], b[1], b[0])
		for strip in range(1, 7):
			_quad(st, a[strip], a[strip + 1], b[strip + 1], b[strip])
		_quad(st, a[8], b[8], b[7], a[7])
	for end in [0, rows.size() - 1]:
		var row := rows[end]
		var center := Vector3(0, 0.33, row[0].z)
		for i in range(row.size() - 1):
			if end == 0:
				_triangle(st, center, row[i + 1], row[i])
			else:
				_triangle(st, center, row[i], row[i + 1])
	_mesh(parent, st, paint, "SculptedBody")

static func _cabin(parent: Node3D, paint: Material, glass: Material) -> void:
	var painted := _surface()
	var glazed := _surface()
	var stations := [-0.94, -0.84, -0.72, -0.56, -0.40, -0.28, -0.20, -0.06, 0.12, 0.28, 0.34, 0.41, 0.56, 0.70, 0.77, 0.93, 1.09, 1.17]
	var rows: Array[PackedVector3Array] = []
	for z in stations:
		var h := profile(z, [-0.94, -0.84, -0.28, -0.06, 0.56, 0.77, 1.17], [0.91, 0.94, 1.29, 1.345, 1.345, 1.28, 0.925])
		var w := profile(z, [-0.94, -0.28, 0.56, 1.17], [0.78, 0.765, 0.775, 0.75])
		rows.append(PackedVector3Array([
			Vector3(-w, 0.905, z), Vector3(-w * 0.84, h - 0.04, z),
			Vector3(-w * 0.60, h + 0.008, z), Vector3(0, h + 0.025, z),
			Vector3(w * 0.60, h + 0.008, z), Vector3(w * 0.84, h - 0.04, z), Vector3(w, 0.905, z)]))
	for i in range(rows.size() - 1):
		var z: float = (stations[i] + stations[i + 1]) * 0.5
		for strip in 6:
			var outer := strip == 0 or strip == 5
			var side_glass := outer and ((z > -0.20 and z < 0.34) or (z > 0.41 and z < 0.70) or (z > 0.77 and z < 1.09))
			var windscreen := not outer and ((z > -0.84 and z < -0.28) or (z > 0.77 and z < 1.11))
			var target := glazed if side_glass or windscreen else painted
			_quad(target, rows[i][strip], rows[i][strip + 1], rows[i + 1][strip + 1], rows[i + 1][strip])
	_mesh(parent, painted, paint, "RoofAndWindowFrames")
	_mesh(parent, glazed, glass, "FramedGlazing")

static func _arches(parent: Node3D, paint: Material, trim: Material) -> void:
	var lips := _surface()
	var liners := _surface()
	for side in [-1.0, 1.0]:
		for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
			for i in 36:
				var a := PI * i / 36.0
				var b := PI * (i + 1) / 36.0
				var p := Vector3(side * (width_at(axle + cos(a) * ARCH_RADIUS) + 0.003), WHEEL_Y + sin(a) * ARCH_RADIUS, axle + cos(a) * ARCH_RADIUS)
				var q := Vector3(side * (width_at(axle + cos(b) * ARCH_RADIUS) + 0.003), WHEEL_Y + sin(b) * ARCH_RADIUS, axle + cos(b) * ARCH_RADIUS)
				var p_outer := p + Vector3(0, sin(a), cos(a)) * 0.018
				var q_outer := q + Vector3(0, sin(b), cos(b)) * 0.018
				_quad(lips, p, q, q_outer, p_outer)
				_quad(liners, p, Vector3(side * 0.69, p.y, p.z), Vector3(side * 0.69, q.y, q.z), q)
	# Both sides of these thin strips must be visible from outside/inside the wheel well.
	var lip_mat: Material = paint.duplicate()
	lip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var liner_mat: Material = trim.duplicate()
	liner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(parent, lips, lip_mat, "FenderLips")
	_mesh(parent, liners, liner_mat, "WheelWellLiners")

static func _panels(parent: Node3D, trim: Material) -> void:
	var seams := _surface()
	for side in [-1.0, 1.0]:
		var outline := PackedVector3Array()
		for yz in [Vector2(0.37, -0.70), Vector2(0.85, -0.70), Vector2(0.865, 0.72), Vector2(0.37, 0.72), Vector2(0.37, -0.70)]:
			outline.append(Vector3(side * (width_at(yz.y) + 0.006), yz.x, yz.y))
		_line(seams, outline, Vector3.RIGHT * side, 0.006)
		var hood := PackedVector3Array()
		for z in [-1.98, -1.75, -1.34, -1.08, -0.87]:
			hood.append(Vector3(side * 0.61, deck_height(z) + 0.019, z))
		_line(seams, hood, Vector3.UP, 0.006)
		for i in 4:
			var z := -1.38 + i * 0.065
			GameGeometry.box(parent, Vector3(0.17, 0.006, 0.025), Vector3(side * 0.40, deck_height(z) + 0.024, z), trim)
	_mesh(parent, seams, trim, "DoorAndHoodSeams")

static func _bumpers(parent: Node3D, paint: Material, trim: Material, rear_lights: Material) -> void:
	rounded_box(parent, Vector3(1.98, 0.35, 0.33), Vector3(0, 0.49, -2.12), 0.075, paint).name = "FrontBumper"
	rounded_box(parent, Vector3(1.99, 0.34, 0.34), Vector3(0, 0.49, 2.12), 0.075, paint).name = "RearBumper"
	rounded_box(parent, Vector3(2.04, 0.055, 0.39), Vector3(0, 0.295, -2.12), 0.04, trim)
	rounded_box(parent, Vector3(1.40, 0.15, 0.10), Vector3(0, 0.335, 2.285), 0.035, trim)
	rounded_box(parent, Vector3(0.82, 0.14, 0.035), Vector3(0, 0.475, -2.292), 0.025, trim)
	var slats := GameGeometry.material(Color("3a4755"))
	for i in range(-3, 4):
		GameGeometry.box(parent, Vector3(0.015, 0.115, 0.012), Vector3(i * 0.10, 0.475, -2.318), slats)
	for i in [-2, -1, 0, 1, 2]:
		GameGeometry.box(parent, Vector3(0.016, 0.13, 0.13), Vector3(i * 0.18, 0.33, 2.32), trim)
	var led := GameGeometry.material(Color("c5ecff"), 2.0)
	var amber := GameGeometry.material(Color("ff9c30"), 1.0)
	for side in [-1.0, 1.0]:
		rounded_box(parent, Vector3(0.57, 0.16, 0.065), Vector3(side * 0.63, 0.675, -2.29), 0.025, trim)
		for offset in [0.51, 0.74]:
			_cylinder(parent, 0.045, 0.025, Vector3(side * offset, 0.69, -2.337), led)
		GameGeometry.box(parent, Vector3(0.44, 0.018, 0.018), Vector3(side * 0.63, 0.625, -2.337), led)
		GameGeometry.box(parent, Vector3(0.023, 0.075, 0.018), Vector3(side * 0.87, 0.681, -2.337), amber)
		rounded_box(parent, Vector3(0.26, 0.12, 0.032), Vector3(side * 0.74, 0.432, -2.29), 0.022, trim)
		for y in [0.41, 0.45]:
			GameGeometry.box(parent, Vector3(0.22, 0.009, 0.012), Vector3(side * 0.74, y, -2.315), slats)
		rounded_box(parent, Vector3(0.69, 0.16, 0.06), Vector3(side * 0.56, 0.72, 2.28), 0.025, trim)
		for y in [0.685, 0.748]:
			rounded_box(parent, Vector3(0.57, 0.024, 0.016), Vector3(side * 0.56, y, 2.32), 0.009, rear_lights)
	rounded_box(parent, Vector3(0.49, 0.155, 0.025), Vector3(0, 0.535, 2.30), 0.015, trim)
	var plate := Label3D.new()
	plate.text = "SL / 01"
	plate.font_size = 48
	plate.pixel_size = 0.0018
	plate.position = Vector3(0, 0.535, 2.32)
	plate.modulate = Color("b1c7d6")
	parent.add_child(plate)

static func rounded_box(parent: Node3D, size: Vector3, at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var st := _surface()
	var bevel := minf(0.025, minf(size.y * 0.22, minf(size.x, size.z) * 0.20))
	var rings: Array[PackedVector3Array] = []
	for layer in 4:
		var inset := bevel if layer == 0 or layer == 3 else 0.0
		var y: float = [-size.y / 2.0, -size.y / 2.0 + bevel, size.y / 2.0 - bevel, size.y / 2.0][layer]
		var hx := size.x / 2.0 - inset
		var hz := size.z / 2.0 - inset
		var r := maxf(0.002, minf(radius - inset, minf(hx, hz) * 0.85))
		var row := PackedVector3Array()
		for corner in 4:
			var cx := (hx - r) * (1.0 if corner == 0 or corner == 3 else -1.0)
			var cz := (hz - r) * (1.0 if corner < 2 else -1.0)
			for step in 4:
				var angle := corner * PI / 2.0 + step * PI / 6.0
				row.append(Vector3(cx + cos(angle) * r, y, cz + sin(angle) * r))
		rings.append(row)
	for layer in 3:
		for i in 16:
			var next := (i + 1) % 16
			_quad(st, rings[layer][i], rings[layer][next], rings[layer + 1][next], rings[layer + 1][i])
	for i in 16:
		var next := (i + 1) % 16
		_triangle(st, Vector3(0, -size.y / 2.0, 0), rings[0][next], rings[0][i])
		_triangle(st, Vector3(0, size.y / 2.0, 0), rings[3][i], rings[3][next])
	var mesh := _mesh(parent, st, mat, "RoundedTrim")
	mesh.position = at
	return mesh

static func _cylinder(parent: Node3D, radius: float, depth: float, at: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.rotation.x = PI / 2.0
	node.position = at
	parent.add_child(node)

static func _line(st: SurfaceTool, points: PackedVector3Array, normal: Vector3, thickness: float) -> void:
	for i in range(points.size() - 1):
		var across := normal.cross((points[i + 1] - points[i]).normalized()) * thickness * 0.5
		_quad(st, points[i] - across, points[i] + across, points[i + 1] + across, points[i + 1] - across)

static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		st.add_vertex(vertex)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(st, a, b, c)
	_triangle(st, a, c, d)

static func _mesh(parent: Node3D, st: SurfaceTool, mat: Material, node_name: String) -> MeshInstance3D:
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh
