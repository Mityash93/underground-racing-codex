class_name TRocBody
extends RefCounted
## Hand-built first-generation T-Roc facelift silhouette, referenced to model year 2022.
## Temporary procedural artwork; the controller also accepts an authored GLB body/wheel scene.

const AXLE_X := 0.80
const WHEEL_Y := 0.41
const FRONT_AXLE_Z := -1.30
const REAR_AXLE_Z := 1.29
const ARCH_RADIUS := 0.455
const STATIONS := [-2.11, -1.85, -1.30, -0.72, 0.64, 1.29, 1.84, 2.11]

static func build(parent: Node3D, paint: Material, trim: Material, glass: Material, rear_lights: Material) -> void:
	_body(parent, paint)
	_cabin(parent, paint, trim, glass)
	_arches(parent, trim)
	_panels(parent, trim)
	_front(parent, paint, trim)
	_rear(parent, paint, trim, rear_lights)
	for side in [-1.0, 1.0]:
		CoupeBody.rounded_box(parent, Vector3(0.22, 0.135, 0.27), Vector3(side * 0.93, 1.17, -0.46), 0.04, trim)
		CoupeBody.rounded_box(parent, Vector3(0.025, 0.085, 0.18), Vector3(side * 1.04, 1.17, -0.42), 0.008, glass)
		for z in [0.10, 0.86]:
			CoupeBody.rounded_box(parent, Vector3(0.033, 0.035, 0.16), Vector3(side * 0.932, 0.97, z), 0.009, paint)
		CoupeBody.rounded_box(parent, Vector3(0.075, 0.17, 1.48), Vector3(side * 0.92, 0.40, 0), 0.028, trim)
		_roof_rail(parent, side, trim)
	CoupeBody.rounded_box(parent, Vector3(1.06, 0.12, 3.65), Vector3(0, 0.34, 0), 0.035, trim)

static func width_at(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [0.84, 0.91, 0.935, 0.92, 0.92, 0.94, 0.93, 0.87])

static func deck_height(z: float) -> float:
	return CoupeBody.profile(z, STATIONS, [1.04, 1.075, 1.105, 1.12, 1.125, 1.13, 1.145, 1.12])

static func arch_height(z: float) -> float:
	var height := 0.33
	for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
		var offset: float = absf(z - axle)
		if offset < ARCH_RADIUS:
			height = maxf(height, WHEEL_Y + sqrt(ARCH_RADIUS * ARCH_RADIUS - offset * offset))
	return height

static func _body(parent: Node3D, paint: Material) -> void:
	var st := CoupeBody._surface()
	var rows: Array[PackedVector3Array] = []
	for i in 121:
		var z := lerpf(-2.11, 2.11, i / 120.0)
		var w := width_at(z)
		var h := deck_height(z)
		var bottom := arch_height(z)
		rows.append(PackedVector3Array([
			Vector3(-w + 0.035, bottom, z), Vector3(-w, h - 0.075, z),
			Vector3(-w + 0.05, h, z), Vector3(-0.63, h + 0.013, z), Vector3(0, h + 0.025, z),
			Vector3(0.63, h + 0.013, z), Vector3(w - 0.05, h, z),
			Vector3(w, h - 0.075, z), Vector3(w - 0.035, bottom, z)]))
	for i in range(rows.size() - 1):
		var a := rows[i]
		var b := rows[i + 1]
		CoupeBody._quad(st, a[0], a[1], b[1], b[0])
		for strip in range(1, 7):
			CoupeBody._quad(st, a[strip], a[strip + 1], b[strip + 1], b[strip])
		CoupeBody._quad(st, a[8], b[8], b[7], a[7])
	for end in [0, rows.size() - 1]:
		var row := rows[end]
		var center := Vector3(0, 0.35, row[0].z)
		for i in range(row.size() - 1):
			if end == 0:
				CoupeBody._triangle(st, center, row[i + 1], row[i])
			else:
				CoupeBody._triangle(st, center, row[i], row[i + 1])
	CoupeBody._mesh(parent, st, paint, "TRocWhiteBody")

static func _cabin(parent: Node3D, paint: Material, trim: Material, glass: Material) -> void:
	var painted := CoupeBody._surface()
	var glazed := CoupeBody._surface()
	var roof := CoupeBody._surface()
	var surround := CoupeBody._surface()
	var chrome := GameGeometry.material(Color("a5b2bd"))
	chrome.metallic = 0.8
	chrome.roughness = 0.3
	var stations := [-0.83, -0.72, -0.53, -0.25, -0.17, 0.0, 0.18, 0.26, 0.55, 0.94, 1.23, 1.30, 1.45, 1.56, 1.70, 1.85, 1.98]
	var rows: Array[PackedVector3Array] = []
	for z in stations:
		var h := CoupeBody.profile(z, [-0.83, -0.72, -0.25, 0.0, 0.94, 1.23, 1.45, 1.70, 1.98], [1.10, 1.145, 1.54, 1.575, 1.59, 1.55, 1.46, 1.30, 1.145])
		var w := CoupeBody.profile(z, [-0.83, -0.25, 1.23, 1.98], [0.79, 0.815, 0.825, 0.78])
		rows.append(PackedVector3Array([
			Vector3(-w, 1.105, z), Vector3(-w * 0.84, h - 0.04, z),
			Vector3(-w * 0.60, h + 0.008, z), Vector3(0, h + 0.025, z),
			Vector3(w * 0.60, h + 0.008, z), Vector3(w * 0.84, h - 0.04, z), Vector3(w, 1.105, z)]))
	for i in range(rows.size() - 1):
		var z: float = (stations[i] + stations[i + 1]) * 0.5
		for strip in 6:
			var outer := strip == 0 or strip == 5
			var side_glass := outer and ((z > -0.17 and z < 0.18) or (z > 0.26 and z < 1.23) or (z > 1.30 and z < 1.45))
			var windscreen := not outer and ((z > -0.72 and z < -0.25) or (z > 1.56 and z < 1.85))
			var target := painted
			if side_glass or windscreen:
				target = glazed
			elif z > -0.25 and z < 1.56 and not outer or outer and z > 0.18 and z < 0.26:
				target = roof
			CoupeBody._quad(target, rows[i][strip], rows[i][strip + 1], rows[i + 1][strip + 1], rows[i + 1][strip])
		# Narrow chrome line follows the angled top and lower edge of each side window.
		if z > -0.17 and z < 1.45:
			for side_index in [0, 5]:
				var edge := 1 if side_index == 0 else 5
				CoupeBody._line(surround, PackedVector3Array([rows[i][edge], rows[i + 1][edge]]), Vector3.LEFT if edge == 1 else Vector3.RIGHT, 0.014)
	CoupeBody._mesh(parent, painted, paint, "TRocPillars")
	CoupeBody._mesh(parent, glazed, glass, "TRocGlazing")
	CoupeBody._mesh(parent, roof, trim, "ContrastingBlackRoof")
	CoupeBody._mesh(parent, surround, chrome, "ChromeWindowSurround")

static func _arches(parent: Node3D, trim: Material) -> void:
	var st := CoupeBody._surface()
	for side in [-1.0, 1.0]:
		for axle in [FRONT_AXLE_Z, REAR_AXLE_Z]:
			for i in 36:
				var a := PI * i / 36.0
				var b := PI * (i + 1) / 36.0
				var p := Vector3(side * (width_at(axle + cos(a) * ARCH_RADIUS) + 0.005), WHEEL_Y + sin(a) * ARCH_RADIUS, axle + cos(a) * ARCH_RADIUS)
				var q := Vector3(side * (width_at(axle + cos(b) * ARCH_RADIUS) + 0.005), WHEEL_Y + sin(b) * ARCH_RADIUS, axle + cos(b) * ARCH_RADIUS)
				CoupeBody._quad(st, p, q, q + Vector3(0, sin(b), cos(b)) * 0.047, p + Vector3(0, sin(a), cos(a)) * 0.047)
				CoupeBody._quad(st, p, Vector3(side * 0.61, p.y, p.z), Vector3(side * 0.61, q.y, q.z), q)
	var mat: StandardMaterial3D = trim.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, st, mat, "ProtectiveArchCladding")

static func _panels(parent: Node3D, trim: Material) -> void:
	var seams := CoupeBody._surface()
	for side in [-1.0, 1.0]:
		for outline in [[Vector2(0.38, -0.70), Vector2(1.055, -0.70), Vector2(1.07, 0.30), Vector2(0.38, 0.30), Vector2(0.38, -0.70)], [Vector2(1.07, 0.33), Vector2(1.075, 0.93), Vector2(0.75, 0.91), Vector2(0.38, 0.77), Vector2(0.38, 0.33), Vector2(1.07, 0.33)]]:
			var points := PackedVector3Array()
			for yz in outline:
				points.append(Vector3(side * (width_at(yz.y) + 0.006), yz.x, yz.y))
			CoupeBody._line(seams, points, Vector3.RIGHT * side, 0.005)
		var crease := PackedVector3Array()
		for z in [-1.0, -0.70, 0.0, 0.70, 1.1]:
			crease.append(Vector3(side * (width_at(z) + 0.008), 0.79, z))
		CoupeBody._line(seams, crease, Vector3.RIGHT * side, 0.006)
	CoupeBody._mesh(parent, seams, trim, "FourDoorSeams")

static func _front(parent: Node3D, paint: Material, trim: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(1.88, 0.46, 0.28), Vector3(0, 0.65, -2.00), 0.075, paint)
	CoupeBody.rounded_box(parent, Vector3(1.90, 0.18, 0.32), Vector3(0, 0.36, -2.00), 0.045, trim)
	CoupeBody.rounded_box(parent, Vector3(0.98, 0.065, 0.045), Vector3(0, 0.325, -2.175), 0.015, GameGeometry.material(Color("87939d")))
	CoupeBody.rounded_box(parent, Vector3(0.95, 0.22, 0.035), Vector3(0, 1.00, -2.135), 0.022, trim)
	var chrome := GameGeometry.material(Color("9fadb9"))
	chrome.metallic = 0.8
	var led := GameGeometry.material(Color("d4eeff"), 1.35)
	for y in [0.945, 0.995, 1.045]:
		GameGeometry.box(parent, Vector3(0.86, 0.012, 0.012), Vector3(0, y, -2.162), chrome)
	for side in [-1.0, 1.0]:
		CoupeBody.rounded_box(parent, Vector3(0.44, 0.125, 0.055), Vector3(side * 0.67, 1.015, -2.105), 0.025, trim)
		GameGeometry.box(parent, Vector3(0.35, 0.021, 0.016), Vector3(side * 0.67, 1.035, -2.14), led)
		GameGeometry.box(parent, Vector3(0.28, 0.017, 0.016), Vector3(side * 0.67, 0.985, -2.14), led)
		CoupeBody.rounded_box(parent, Vector3(0.40, 0.285, 0.045), Vector3(side * 0.70, 0.605, -2.145), 0.044, trim)
		var signature := PackedVector3Array()
		for xy in [Vector2(0.54, 0.72), Vector2(0.82, 0.72), Vector2(0.875, 0.645), Vector2(0.84, 0.495), Vector2(0.55, 0.495)]:
			signature.append(Vector3(side * xy.x, xy.y, -2.175))
		var st := CoupeBody._surface()
		CoupeBody._line(st, signature, Vector3.FORWARD, 0.022)
		var mat: StandardMaterial3D = led.duplicate()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		CoupeBody._mesh(parent, st, mat, "LowerDaytimeRunningLight")
	CoupeBody.rounded_box(parent, Vector3(0.76, 0.18, 0.032), Vector3(0, 0.58, -2.16), 0.025, trim)
	_badge(parent, Vector3(0, 1.01, -2.185), true, chrome)
	_plate(parent, Vector3(0, 0.79, -2.18), true, paint)

static func _rear(parent: Node3D, paint: Material, trim: Material, rear_lights: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(1.88, 0.46, 0.28), Vector3(0, 0.66, 2.00), 0.075, paint)
	CoupeBody.rounded_box(parent, Vector3(1.89, 0.20, 0.31), Vector3(0, 0.36, 2.015), 0.045, trim)
	CoupeBody.rounded_box(parent, Vector3(1.12, 0.055, 0.025), Vector3(0, 0.32, 2.185), 0.012, GameGeometry.material(Color("87939d")))
	CoupeBody.rounded_box(parent, Vector3(1.46, 0.05, 0.23), Vector3(0, 1.56, 1.44), 0.022, trim)
	CoupeBody.rounded_box(parent, Vector3(0.34, 0.02, 0.02), Vector3(0, 1.53, 1.57), 0.005, rear_lights)
	GameGeometry.box(parent, Vector3(0.36, 0.016, 0.018), Vector3(0, 1.24, 1.92), trim)
	var lens := GameGeometry.material(Color("581722"), 0.05)
	for side in [-1.0, 1.0]:
		CoupeBody.rounded_box(parent, Vector3(0.47, 0.19, 0.06), Vector3(side * 0.65, 1.085, 2.10), 0.03, lens)
		GameGeometry.box(parent, Vector3(0.37, 0.022, 0.018), Vector3(side * 0.65, 1.135, 2.14), rear_lights)
		GameGeometry.box(parent, Vector3(0.022, 0.095, 0.018), Vector3(side * 0.825, 1.09, 2.14), rear_lights)
		GameGeometry.box(parent, Vector3(0.24, 0.018, 0.018), Vector3(side * 0.68, 1.045, 2.14), rear_lights)
		GameGeometry.box(parent, Vector3(0.23, 0.023, 0.016), Vector3(side * 0.70, 0.50, 2.16), lens)
	var chrome := GameGeometry.material(Color("aebbc5"))
	chrome.metallic = 0.8
	_badge(parent, Vector3(0, 1.025, 2.15), false, chrome)
	_text(parent, "T - R O C", Vector3(0, 0.88, 2.15), false, 0.00075, Color("81909c"))
	_plate(parent, Vector3(0, 0.69, 2.16), false, paint)

static func _roof_rail(parent: Node3D, side: float, trim: Material) -> void:
	var points := [Vector3(side * 0.60, 1.62, -0.06), Vector3(side * 0.60, 1.65, 0.30), Vector3(side * 0.60, 1.66, 0.94), Vector3(side * 0.60, 1.59, 1.30)]
	for i in range(points.size() - 1):
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var beam := GameGeometry.box(parent, Vector3(0.035, from.distance_to(to), 0.035), (from + to) * 0.5, trim)
		beam.quaternion = Quaternion(Vector3.UP, (to - from).normalized())

static func _badge(parent: Node3D, at: Vector3, front: bool, chrome: Material) -> void:
	CoupeBody._cylinder(parent, 0.085, 0.018, at, GameGeometry.material(Color("14212c")))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.073
	torus.outer_radius = 0.085
	torus.rings = 24
	torus.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = chrome
	ring.position = at + Vector3(0, 0, -0.012 if front else 0.012)
	ring.rotation.x = PI / 2.0
	parent.add_child(ring)
	var monogram := CoupeBody._surface()
	var normal := Vector3.FORWARD if front else Vector3.BACK
	for shape in [[Vector2(-0.041, 0.044), Vector2(0, 0.004), Vector2(0.041, 0.044)], [Vector2(-0.058, 0.003), Vector2(-0.029, -0.050), Vector2(0, -0.012), Vector2(0.029, -0.050), Vector2(0.058, 0.003)]]:
		var line := PackedVector3Array()
		for xy in shape:
			line.append(at + Vector3(xy.x, xy.y, -0.025 if front else 0.025))
		CoupeBody._line(monogram, line, normal, 0.010)
	var mat: StandardMaterial3D = chrome.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	CoupeBody._mesh(parent, monogram, mat, "VWMonogram")

static func _plate(parent: Node3D, at: Vector3, front: bool, paint: Material) -> void:
	CoupeBody.rounded_box(parent, Vector3(0.61, 0.125, 0.024), at, 0.012, paint)
	_text(parent, "УЛ  •  2022", at + Vector3(0, 0, -0.018 if front else 0.018), front, 0.0010, Color("1b2530"))

static func _text(parent: Node3D, value: String, at: Vector3, front: bool, scale: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 64
	label.pixel_size = scale
	label.position = at
	label.rotation.y = PI if front else 0.0
	label.modulate = color
	parent.add_child(label)
