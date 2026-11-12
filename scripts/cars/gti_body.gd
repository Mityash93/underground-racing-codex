class_name GTIBody
extends RefCounted
## Hand-built stylized Golf V GTI hatchback. No downloaded models or textures.

const AXLE_X := 0.82
const WHEEL_Y := 0.41
const FRONT_AXLE_Z := -1.30
const REAR_AXLE_Z := 1.26
const ARCH_RADIUS := 0.445
const LENGTH_Z := 2.05
const STATIONS := [-2.05, -1.84, -1.30, -0.72, 0.64, 1.26, 1.82, 2.05]

static func build(parent: Node3D, paint: Material, trim: Material, glass: Material, rear_lights: Material) -> void:
	_body(parent, paint)
	_cabin(parent, paint, glass, trim)
	_arches(parent, trim)
	_panels(parent, trim)
	_front(parent, paint, trim)
	_rear(parent, paint, trim, glass, rear_lights)
	for side in [-1.0, 1.0]:
		CoupeBody.rounded_box(parent, Vector3(0.20, 0.12, 0.26), Vector3(side * 0.92, 1.09, -0.45), 0.035, paint)
		CoupeBody.rounded_box(parent, Vector3(0.025, 0.075, 0.17), Vector3(side * 1.02, 1.09, -0.41), 0.008, glass)
		CoupeBody.rounded_box(parent, Vector3(0.032, 0.038, 0.18), Vector3(side * 0.93, 0.88, 0.37), 0.009, trim)
		CoupeBody.rounded_box(parent, Vector3(0.07, 0.11, 1.48), Vector3(side * 0.92, 0.30, 0), 0.025, trim)
	CoupeBody.rounded_box(parent, Vector3(1.10, 0.12, 3.65), Vector3(0, 0.28, 0), 0.035, trim)

static func width_at(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [0.82, 0.91, 0.945, 0.925, 0.925, 0.955, 0.94, 0.88])

static func deck_height(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [0.93, 0.97, 1.00, 1.03, 1.04, 1.04, 1.06, 1.04])

static func arch_height(z: float) -> float:
	var height := 0.265
	for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
		var offset: float = absf(z - axle)
		if offset < ARCH_RADIUS:
			height = maxf(height, WHEEL_Y + sqrt(ARCH_RADIUS * ARCH_RADIUS - offset * offset))
	return height

static func _body(parent: Node3D, paint: Material) -> void:
	var st := CoupeBody._surface()
	var rows: Array[PackedVector3Array] = []
	for i in 113:
		var z := lerpf(-LENGTH_Z, LENGTH_Z, i / 112.0)
		var w := width_at(z)
		var h := deck_height(z)
		var bottom := arch_height(z)
		rows.append(PackedVector3Array([
			Vector3(-w + 0.025, bottom, z), Vector3(-w, h - 0.07, z),
			Vector3(-w + 0.04, h, z), Vector3(-0.63, h + 0.014, z), Vector3(0, h + 0.025, z),
			Vector3(0.63, h + 0.014, z), Vector3(w - 0.04, h, z),
			Vector3(w, h - 0.07, z), Vector3(w - 0.025, bottom, z)]))
	for i in range(rows.size() - 1):
		var a := rows[i]
		var b := rows[i + 1]
		CoupeBody._quad(st, a[0], a[1], b[1], b[0])
		for strip in range(1, 7):
			CoupeBody._quad(st, a[strip], a[strip + 1], b[strip + 1], b[strip])
		CoupeBody._quad(st, a[8], b[8], b[7], a[7])
	for end in [0, rows.size() - 1]:
		var row := rows[end]
		var center := Vector3(0, 0.30, row[0].z)
		for i in range(row.size() - 1):
			if end == 0:
				CoupeBody._triangle(st, center, row[i + 1], row[i])
			else:
				CoupeBody._triangle(st, center, row[i], row[i + 1])
	CoupeBody._mesh(parent, st, paint, "GTIWhiteBody")

static func _cabin(parent: Node3D, paint: Material, glass: Material, trim: Material) -> void:
	var painted := CoupeBody._surface()
	var glazed := CoupeBody._surface()
	var pillars := CoupeBody._surface()
	var stations := [-0.82, -0.72, -0.58, -0.38, -0.17, 0.0, 0.34, 0.50, 0.57, 0.78, 1.03, 1.26, 1.45, 1.60, 1.75, 1.87, 1.97]
	var rows: Array[PackedVector3Array] = []
	for z in stations:
		var h := CoupeBody.profile(z, [-0.82, -0.72, -0.17, 0.0, 0.78, 1.26, 1.45, 1.60, 1.75, 1.97], [1.04, 1.08, 1.47, 1.505, 1.51, 1.49, 1.44, 1.34, 1.22, 1.06])
		var w := CoupeBody.profile(z, [-0.82, -0.17, 1.26, 1.97], [0.79, 0.81, 0.82, 0.79])
		rows.append(PackedVector3Array([
			Vector3(-w, 1.035, z), Vector3(-w * 0.84, h - 0.04, z),
			Vector3(-w * 0.60, h + 0.008, z), Vector3(0, h + 0.025, z),
			Vector3(w * 0.60, h + 0.008, z), Vector3(w * 0.84, h - 0.04, z), Vector3(w, 1.035, z)]))
	for i in range(rows.size() - 1):
		var z: float = (stations[i] + stations[i + 1]) * 0.5
		for strip in 6:
			var outer := strip == 0 or strip == 5
			var side_glass := outer and ((z > -0.17 and z < 0.50) or (z > 0.57 and z < 1.45))
			var windscreen := not outer and ((z > -0.72 and z < -0.17) or (z > 1.45 and z < 1.87))
			var target := glazed if side_glass or windscreen else painted
			if outer and z > 0.50 and z < 0.57:
				target = pillars
			CoupeBody._quad(target, rows[i][strip], rows[i][strip + 1], rows[i + 1][strip + 1], rows[i + 1][strip])
	CoupeBody._mesh(parent, painted, paint, "HatchbackRoofAndPillars")
	CoupeBody._mesh(parent, glazed, glass, "HatchbackGlazing")
	CoupeBody._mesh(parent, pillars, trim, "BlackBPillars")

static func _arches(parent: Node3D, trim: Material) -> void:
	var st := CoupeBody._surface()
	for side in [-1.0, 1.0]:
		for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
			for i in 36:
				var a := PI * i / 36.0
				var b := PI * (i + 1) / 36.0
				var p := Vector3(side * (width_at(axle + cos(a) * ARCH_RADIUS) + 0.003), WHEEL_Y + sin(a) * ARCH_RADIUS, axle + cos(a) * ARCH_RADIUS)
				var q := Vector3(side * (width_at(axle + cos(b) * ARCH_RADIUS) + 0.003), WHEEL_Y + sin(b) * ARCH_RADIUS, axle + cos(b) * ARCH_RADIUS)
				CoupeBody._quad(st, p, q, q + Vector3(0, sin(b), cos(b)) * 0.016, p + Vector3(0, sin(a), cos(a)) * 0.016)
				CoupeBody._quad(st, p, Vector3(side * 0.62, p.y, p.z), Vector3(side * 0.62, q.y, q.z), q)
	var mat: StandardMaterial3D = trim.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, st, mat, "DarkWheelArchTrim")

static func _panels(parent: Node3D, trim: Material) -> void:
	var seams := CoupeBody._surface()
	for side in [-1.0, 1.0]:
		var outline := PackedVector3Array()
		for yz in [Vector2(0.33, -0.72), Vector2(0.985, -0.72), Vector2(0.995, 0.72), Vector2(0.33, 0.72), Vector2(0.33, -0.72)]:
			outline.append(Vector3(side * (width_at(yz.y) + 0.006), yz.x, yz.y))
		CoupeBody._line(seams, outline, Vector3.RIGHT * side, 0.005)
		var crease := PackedVector3Array()
		for z in [-0.72, 0.0, 0.72]:
			crease.append(Vector3(side * (width_at(z) + 0.008), 0.68, z))
		CoupeBody._line(seams, crease, Vector3.RIGHT * side, 0.008)
		var hood := PackedVector3Array()
		for z in [-1.88, -1.65, -1.30, -1.0, -0.81]:
			hood.append(Vector3(side * 0.60, deck_height(z) + 0.019, z))
		CoupeBody._line(seams, hood, Vector3.UP, 0.005)
	CoupeBody._mesh(parent, seams, trim, "GTIDoorAndHoodSeams")

static func _front(parent: Node3D, paint: Material, trim: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(1.88, 0.43, 0.29), Vector3(0, 0.505, -1.98), 0.07, paint).name = "GTIFrontBumper"
	CoupeBody.rounded_box(parent, Vector3(1.89, 0.065, 0.32), Vector3(0, 0.29, -1.98), 0.035, trim)
	var shield := CoupeBody._surface()
	CoupeBody._quad(shield, Vector3(-0.48, 0.91, -2.137), Vector3(0.48, 0.91, -2.137), Vector3(0.37, 0.37, -2.137), Vector3(-0.37, 0.37, -2.137))
	var double_sided: StandardMaterial3D = trim.duplicate()
	double_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, shield, double_sided, "GTIShieldGrille")
	_honeycomb(parent, trim)
	var red := GameGeometry.material(Color("db162f"), 0.12)
	var red_line := CoupeBody._surface()
	CoupeBody._line(red_line, PackedVector3Array([Vector3(-0.45, 0.76, -2.16), Vector3(-0.47, 0.89, -2.16), Vector3(0.47, 0.89, -2.16), Vector3(0.45, 0.76, -2.16)]), Vector3.FORWARD, 0.018)
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, red_line, red, "GTIRedGrilleOutline")
	var led := GameGeometry.material(Color("d7efff"), 1.25)
	var chrome := GameGeometry.material(Color("b7c4d0"))
	chrome.metallic = 0.8
	chrome.roughness = 0.25
	for side in [-1.0, 1.0]:
		_headlight_lens(parent, side)
		for x in [0.555, 0.735]:
			var lens_z: float = -2.115 + (x - 0.40) * 0.12
			CoupeBody._cylinder(parent, 0.067, 0.012, Vector3(side * x, 0.85, lens_z - 0.009), chrome)
			CoupeBody._cylinder(parent, 0.047, 0.016, Vector3(side * x, 0.85, lens_z - 0.018), led)
		CoupeBody.rounded_box(parent, Vector3(0.32, 0.17, 0.035), Vector3(side * 0.70, 0.46, -2.135), 0.022, trim)
		CoupeBody._cylinder(parent, 0.049, 0.025, Vector3(side * 0.72, 0.46, -2.161), led)
	_plate(parent, Vector3(0, 0.62, -2.17), true, paint)
	_badge(parent, Vector3(0, 0.805, -2.172), true, chrome)
	_text(parent, "GTI", Vector3(0.30, 0.815, -2.174), true, 0.0008, Color("e32b3c"))

static func _headlight_lens(parent: Node3D, side: float) -> void:
	var st := CoupeBody._surface()
	var rim := CoupeBody._surface()
	var outline := [Vector2(0.43, 0.895), Vector2(0.59, 0.928), Vector2(0.77, 0.936), Vector2(0.89, 0.901), Vector2(0.908, 0.864), Vector2(0.884, 0.775), Vector2(0.77, 0.762), Vector2(0.47, 0.77), Vector2(0.435, 0.80)]
	var center := Vector2(0.67, 0.846)
	var center_3d := Vector3(side * center.x, center.y, -2.115 + (center.x - 0.40) * 0.12)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var p := Vector3(side * a.x, a.y, -2.115 + (a.x - 0.40) * 0.12)
		var q := Vector3(side * b.x, b.y, -2.115 + (b.x - 0.40) * 0.12)
		CoupeBody._triangle(st, center_3d, p, q)
		var outer_a := center + (a - center) * 1.045
		var outer_b := center + (b - center) * 1.045
		CoupeBody._quad(rim, p, q, Vector3(side * outer_b.x, outer_b.y, q.z + 0.001), Vector3(side * outer_a.x, outer_a.y, p.z + 0.001))
	var lens := GameGeometry.material(Color("718493"))
	lens.metallic = 0.65
	lens.roughness = 0.18
	lens.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rubber := GameGeometry.material(Color("18222d"))
	rubber.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, st, lens, "SweptHeadlightLens")
	CoupeBody._mesh(parent, rim, rubber, "HeadlightSeal")

static func _honeycomb(parent: Node3D, trim: Material) -> void:
	var st := CoupeBody._surface()
	var mat := GameGeometry.material(Color("46505c"))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for row in 6:
		var y := 0.415 + row * 0.077
		for col in range(-5, 6):
			var x := col * 0.072 + (0.036 if row % 2 else 0.0)
			if absf(x) > 0.36 and y < 0.70:
				continue
			var ring := PackedVector3Array()
			for corner in 7:
				var angle := TAU * corner / 6.0
				ring.append(Vector3(x + cos(angle) * 0.039, y + sin(angle) * 0.039, -2.150))
			CoupeBody._line(st, ring, Vector3.FORWARD, 0.006)
	CoupeBody._mesh(parent, st, mat, "HoneycombGrille")

static func _rear(parent: Node3D, paint: Material, trim: Material, glass: Material, rear_lights: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(1.89, 0.42, 0.29), Vector3(0, 0.50, 1.985), 0.07, paint).name = "GTIRearBumper"
	CoupeBody.rounded_box(parent, Vector3(1.77, 0.17, 0.11), Vector3(0, 0.335, 2.09), 0.035, trim)
	CoupeBody.rounded_box(parent, Vector3(1.48, 0.055, 0.22), Vector3(0, 1.505, 1.45), 0.025, paint)
	CoupeBody.rounded_box(parent, Vector3(1.41, 0.018, 0.17), Vector3(0, 1.473, 1.47), 0.008, trim)
	CoupeBody.rounded_box(parent, Vector3(0.40, 0.022, 0.018), Vector3(0, 1.468, 1.57), 0.006, rear_lights)
	CoupeBody.rounded_box(parent, Vector3(0.38, 0.016, 0.018), Vector3(0.03, 1.16, 1.90), 0.005, trim)
	var hatch_seam := CoupeBody._surface()
	CoupeBody._line(hatch_seam, PackedVector3Array([Vector3(-0.68, 0.69, 2.065), Vector3(-0.68, 1.025, 2.065), Vector3(0.68, 1.025, 2.065), Vector3(0.68, 0.69, 2.065), Vector3(-0.68, 0.69, 2.065)]), Vector3.BACK, 0.005)
	CoupeBody._mesh(parent, hatch_seam, trim, "TailgateSeam")
	for side in [-1.0, 1.0]:
		CoupeBody.rounded_box(parent, Vector3(0.34, 0.27, 0.07), Vector3(side * 0.72, 0.935, 2.055), 0.055, trim)
		var inset := GameGeometry.material(Color("741622"), 0.12)
		CoupeBody.rounded_box(parent, Vector3(0.295, 0.23, 0.035), Vector3(side * 0.72, 0.94, 2.10), 0.045, inset)
		CoupeBody._cylinder(parent, 0.052, 0.016, Vector3(side * 0.72, 0.98, 2.132), inset)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.052
		torus.outer_radius = 0.074
		torus.rings = 24
		torus.ring_segments = 8
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = rear_lights
		ring.position = Vector3(side * 0.72, 0.98, 2.13)
		ring.rotation.x = PI / 2.0
		parent.add_child(ring)
		CoupeBody._cylinder(parent, 0.039, 0.018, Vector3(side * 0.72, 0.875, 2.132), GameGeometry.material(Color("9fabb4")))
		CoupeBody.rounded_box(parent, Vector3(0.20, 0.03, 0.02), Vector3(side * 0.73, 0.55, 2.14), 0.008, inset)
	var chrome := GameGeometry.material(Color("bec7cf"))
	chrome.metallic = 0.8
	chrome.roughness = 0.3
	for x in [-0.61, -0.44]:
		CoupeBody._cylinder(parent, 0.055, 0.13, Vector3(x, 0.32, 2.16), chrome)
		CoupeBody._cylinder(parent, 0.040, 0.14, Vector3(x, 0.32, 2.17), trim)
	_badge(parent, Vector3(0, 0.955, 2.085), false, chrome)
	_plate(parent, Vector3(0, 0.73, 2.10), false, paint)
	_text(parent, "GOLF", Vector3(-0.47, 0.84, 2.084), false, 0.0007, Color("b3c0ca"))
	_text(parent, "GTI", Vector3(0.49, 0.84, 2.084), false, 0.0008, Color("d91932"))

static func _badge(parent: Node3D, at: Vector3, front: bool, chrome: Material) -> void:
	var backing := GameGeometry.material(Color("14212c"))
	CoupeBody._cylinder(parent, 0.094, 0.018, at, backing)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.082
	torus.outer_radius = 0.094
	torus.rings = 24
	torus.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = chrome
	ring.position = at + Vector3(0, 0, -0.012 if front else 0.012)
	ring.rotation.x = PI / 2.0
	parent.add_child(ring)
	_text(parent, "VW", at + Vector3(0, 0, -0.023 if front else 0.023), front, 0.001, Color("dce3e8"))

static func _plate(parent: Node3D, at: Vector3, front: bool, paint: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(0.63, 0.125, 0.024), at, 0.013, paint)
	_text(parent, "УЛ  •  GTI", at + Vector3(0, 0, -0.017 if front else 0.017), front, 0.0011, Color("1b2530"))

static func _text(parent: Node3D, value: String, at: Vector3, front: bool, scale: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 64
	label.pixel_size = scale
	label.position = at
	label.rotation.y = PI if front else 0.0
	label.modulate = color
	parent.add_child(label)
