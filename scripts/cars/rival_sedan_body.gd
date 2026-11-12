class_name RivalSedanBody
extends RefCounted
## Original red sport sedan, sharing mesh helpers with CoupeBody. No external model or brand assets.

const AXLE_X := 0.80
const WHEEL_Y := 0.41
const FRONT_AXLE_Z := -1.30
const REAR_AXLE_Z := 1.29
const ARCH_RADIUS := 0.465
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
		var mirror := CoupeBody.rounded_box(parent, Vector3(0.22, 0.115, 0.25), Vector3(side * 0.92, 1.0, -0.43), 0.035, paint)
		mirror.name = "Mirror"
		CoupeBody.rounded_box(parent, Vector3(0.025, 0.078, 0.15), Vector3(side * 1.04, 1.0, -0.41), 0.008, glass)
		CoupeBody.rounded_box(parent, Vector3(0.035, 0.04, 0.19), Vector3(side * 0.997, 0.76, 0.41), 0.01, alloy)
		CoupeBody.rounded_box(parent, Vector3(0.07, 0.11, 1.47), Vector3(side * 0.98, 0.34, 0.01), 0.025, trim)
		GameGeometry.box(parent, Vector3(0.05, 0.13, 0.065), Vector3(side * 0.57, 0.98, 1.86), trim)
		CoupeBody._cylinder(parent, 0.065, 0.15, Vector3(side * 0.72, 0.35, 2.30), alloy)
		CoupeBody._cylinder(parent, 0.046, 0.155, Vector3(side * 0.72, 0.35, 2.31), trim)
	CoupeBody.rounded_box(parent, Vector3(1.80, 0.065, 0.25), Vector3(0, 1.065, 1.87), 0.027, trim)
	CoupeBody.rounded_box(parent, Vector3(1.16, 0.13, 3.85), Vector3(0, 0.30, 0), 0.04, trim)

static func width_at(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [0.85, 0.93, 0.97, 0.95, 0.95, 0.97, 0.94, 0.88])

static func deck_height(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [0.70, 0.79, 0.875, 0.90, 0.90, 0.91, 0.855, 0.765])

static func fender_height(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [0.72, 0.87, 1.065, 0.94, 0.94, 1.065, 0.93, 0.79])

static func arch_height(z: float) -> float:
	var height := 0.30
	for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
		var offset: float = absf(z - axle)
		if offset < ARCH_RADIUS:
			height = maxf(height, WHEEL_Y + sqrt(ARCH_RADIUS * ARCH_RADIUS - offset * offset))
	return height

static func _body(parent: Node3D, paint: Material) -> void:
	var st := CoupeBody._surface()
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
		CoupeBody._quad(st, a[0], a[1], b[1], b[0])
		for strip in range(1, 7):
			CoupeBody._quad(st, a[strip], a[strip + 1], b[strip + 1], b[strip])
		CoupeBody._quad(st, a[8], b[8], b[7], a[7])
	for end in [0, rows.size() - 1]:
		var row := rows[end]
		var center := Vector3(0, 0.33, row[0].z)
		for i in range(row.size() - 1):
			if end == 0:
				CoupeBody._triangle(st, center, row[i + 1], row[i])
			else:
				CoupeBody._triangle(st, center, row[i], row[i + 1])
	CoupeBody._mesh(parent, st, paint, "SculptedBody")

static func _cabin(parent: Node3D, paint: Material, glass: Material) -> void:
	var painted := CoupeBody._surface()
	var glazed := CoupeBody._surface()
	var stations := [-0.94, -0.84, -0.72, -0.56, -0.40, -0.28, -0.20, -0.06, 0.12, 0.28, 0.34, 0.41, 0.56, 0.70, 0.77, 0.93, 1.09, 1.17]
	var rows: Array[PackedVector3Array] = []
	for z in stations:
		var h := CoupeBody.profile(z, [-0.94, -0.84, -0.28, -0.06, 0.56, 0.77, 1.17], [0.91, 0.94, 1.29, 1.345, 1.345, 1.28, 0.925])
		var w := CoupeBody.profile(z, [-0.94, -0.28, 0.56, 1.17], [0.78, 0.765, 0.775, 0.75])
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
			CoupeBody._quad(target, rows[i][strip], rows[i][strip + 1], rows[i + 1][strip + 1], rows[i + 1][strip])
	CoupeBody._mesh(parent, painted, paint, "RoofAndWindowFrames")
	CoupeBody._mesh(parent, glazed, glass, "FramedGlazing")

static func _arches(parent: Node3D, paint: Material, trim: Material) -> void:
	var lips := CoupeBody._surface()
	var liners := CoupeBody._surface()
	for side in [-1.0, 1.0]:
		for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
			for i in 36:
				var a := PI * i / 36.0
				var b := PI * (i + 1) / 36.0
				var p := Vector3(side * (width_at(axle + cos(a) * ARCH_RADIUS) + 0.003), WHEEL_Y + sin(a) * ARCH_RADIUS, axle + cos(a) * ARCH_RADIUS)
				var q := Vector3(side * (width_at(axle + cos(b) * ARCH_RADIUS) + 0.003), WHEEL_Y + sin(b) * ARCH_RADIUS, axle + cos(b) * ARCH_RADIUS)
				var p_outer := p + Vector3(0, sin(a), cos(a)) * 0.018
				var q_outer := q + Vector3(0, sin(b), cos(b)) * 0.018
				CoupeBody._quad(lips, p, q, q_outer, p_outer)
				CoupeBody._quad(liners, p, Vector3(side * 0.69, p.y, p.z), Vector3(side * 0.69, q.y, q.z), q)
	# Both sides of these thin strips must be visible from outside/inside the wheel well.
	var lip_mat: Material = paint.duplicate()
	lip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var liner_mat: Material = trim.duplicate()
	liner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, lips, lip_mat, "FenderLips")
	CoupeBody._mesh(parent, liners, liner_mat, "WheelWellLiners")

static func _panels(parent: Node3D, trim: Material) -> void:
	var seams := CoupeBody._surface()
	for side in [-1.0, 1.0]:
		var outline := PackedVector3Array()
		for yz in [Vector2(0.37, -0.70), Vector2(0.85, -0.70), Vector2(0.865, 0.72), Vector2(0.37, 0.72), Vector2(0.37, -0.70)]:
			outline.append(Vector3(side * (width_at(yz.y) + 0.006), yz.x, yz.y))
		CoupeBody._line(seams, outline, Vector3.RIGHT * side, 0.006)
		var hood := PackedVector3Array()
		for z in [-1.98, -1.75, -1.34, -1.08, -0.87]:
			hood.append(Vector3(side * 0.61, deck_height(z) + 0.019, z))
		CoupeBody._line(seams, hood, Vector3.UP, 0.006)
		for i in 4:
			var z := -1.38 + i * 0.065
			GameGeometry.box(parent, Vector3(0.17, 0.006, 0.025), Vector3(side * 0.40, deck_height(z) + 0.024, z), trim)
	CoupeBody._mesh(parent, seams, trim, "DoorAndHoodSeams")

static func _bumpers(parent: Node3D, paint: Material, trim: Material, rear_lights: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(1.98, 0.35, 0.33), Vector3(0, 0.49, -2.12), 0.075, paint).name = "FrontBumper"
	CoupeBody.rounded_box(parent, Vector3(1.99, 0.34, 0.34), Vector3(0, 0.49, 2.12), 0.075, paint).name = "RearBumper"
	CoupeBody.rounded_box(parent, Vector3(2.04, 0.055, 0.39), Vector3(0, 0.295, -2.12), 0.04, trim)
	CoupeBody.rounded_box(parent, Vector3(1.40, 0.15, 0.10), Vector3(0, 0.335, 2.285), 0.035, trim)
	CoupeBody.rounded_box(parent, Vector3(0.82, 0.16, 0.035), Vector3(0, 0.69, -2.292), 0.025, trim)
	var slats := GameGeometry.material(Color("3a4755"))
	for i in range(-3, 4):
		GameGeometry.box(parent, Vector3(0.015, 0.115, 0.012), Vector3(i * 0.10, 0.69, -2.318), slats)
	for i in [-2, -1, 0, 1, 2]:
		GameGeometry.box(parent, Vector3(0.016, 0.13, 0.13), Vector3(i * 0.18, 0.33, 2.32), trim)
	CoupeBody.rounded_box(parent, Vector3(0.035, 0.18, 0.045), Vector3(0, 0.69, -2.32), 0.009, paint)
	var led := GameGeometry.material(Color("c5ecff"), 2.0)
	var amber := GameGeometry.material(Color("ff9c30"), 1.0)
	for side in [-1.0, 1.0]:
		CoupeBody.rounded_box(parent, Vector3(0.57, 0.16, 0.065), Vector3(side * 0.63, 0.675, -2.29), 0.025, trim)
		for offset in [0.51, 0.74]:
			CoupeBody._cylinder(parent, 0.045, 0.025, Vector3(side * offset, 0.69, -2.337), led)
		GameGeometry.box(parent, Vector3(0.44, 0.018, 0.018), Vector3(side * 0.63, 0.625, -2.337), led)
		GameGeometry.box(parent, Vector3(0.023, 0.075, 0.018), Vector3(side * 0.87, 0.681, -2.337), amber)
		CoupeBody.rounded_box(parent, Vector3(0.26, 0.12, 0.032), Vector3(side * 0.74, 0.432, -2.29), 0.022, trim)
		for y in [0.41, 0.45]:
			GameGeometry.box(parent, Vector3(0.22, 0.009, 0.012), Vector3(side * 0.74, y, -2.315), slats)
		CoupeBody.rounded_box(parent, Vector3(0.69, 0.16, 0.06), Vector3(side * 0.56, 0.72, 2.28), 0.025, trim)
		for y in [0.685, 0.748]:
			CoupeBody.rounded_box(parent, Vector3(0.57, 0.024, 0.016), Vector3(side * 0.56, y, 2.32), 0.009, rear_lights)
	CoupeBody.rounded_box(parent, Vector3(0.49, 0.155, 0.025), Vector3(0, 0.535, 2.30), 0.015, trim)
	var plate := Label3D.new()
	plate.text = "ВЕКТОР"
	plate.font_size = 48
	plate.pixel_size = 0.0018
	plate.position = Vector3(0, 0.535, 2.32)
	plate.modulate = Color("b1c7d6")
	parent.add_child(plate)

