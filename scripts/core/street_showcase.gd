class_name StreetShowcase
extends RefCounted
## A bounded modular art pass for the start boulevard. Dimensions in metres.
const FRONTAGE_OFFSET := 21.2
const BUILDING_DEPTH := 13.0
const FRONTAGES := [-84.0, -50.0, -16.0, 18.0, 52.0]

static func contains_distance(track: CityTrack, distance: float) -> bool:
	return distance < 80.0 or distance > track.track_length - 120.0

static func concrete_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/materials/masonry.gdshader")
	mat.set_shader_parameter("base_color", Color("596069"))
	mat.set_shader_parameter("brick_pattern", 0.0)
	return mat

static func build(track: CityTrack) -> void:
	var root := Node3D.new()
	root.name = "StartBoulevard"
	track.add_child(root)
	var batches: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 29415
	for side in [-1.0, 1.0]:
		for i in FRONTAGES.size():
			var road := track.transform_at(FRONTAGES[i])
			var normal: Vector3 = -road.basis.x * side
			var pose := Transform3D(Basis.looking_at(-normal, Vector3.UP), road.origin + road.basis.x * side * FRONTAGE_OFFSET)
			pose.origin.y = 0.0
			_facade(root, batches, pose, i, side, rng)
		for distance in [-72.0, -25.0, 28.0]:
			_furniture(batches, track.transform_at(distance), side)
	_crossing(batches, track.transform_at(-40.0))
	_entrance(batches, track.transform_at(TrackLayout.TUNNEL_START))
	_flush(root, batches)
	root.set_meta("frontage_count", FRONTAGES.size() * 2)
	var count := 0
	for entries in batches.values():
		count += entries.size()
	root.set_meta("instance_count", count)
	_accent_light(root, track, -26.0, -17.0, Color("ffc78f"), 2.4)
	_accent_light(root, track, 36.0, 17.0, Color("8ac8ed"), 2.0)

static func _put(batches: Dictionary, group: String, pose: Transform3D, at: Vector3, size: Vector3) -> void:
	if not batches.has(group):
		batches[group] = []
	batches[group].append(pose * Transform3D(Basis.IDENTITY.scaled(size), at))

static func _facade(root: Node3D, b: Dictionary, pose: Transform3D, index: int, side: float, rng: RandomNumberGenerator) -> void:
	var width := 28.0
	var floors := 4 + index % 2
	var height := 4.4 + floors * 3.4
	var wall := "brick" if index % 2 == 0 else "stone"
	var upper_height := height - 4.4
	_put(b, wall, pose, Vector3(0, 4.4 + upper_height / 2, -BUILDING_DEPTH / 2), Vector3(width, upper_height, BUILDING_DEPTH))
	for x in [-12.75, -3.25, 3.25, 12.75]:
		var pier_width := 2.5 if absf(x) > 10 else 3.7
		_put(b, wall, pose, Vector3(x, 2.2, -BUILDING_DEPTH / 2), Vector3(pier_width, 4.4, BUILDING_DEPTH))
	_put(b, "interior", pose, Vector3(0, 2.1, -4.2), Vector3(width, 4.2, 0.25))
	_put(b, "wood", pose, Vector3(0, 0.15, -2.1), Vector3(width, 0.3, 4.2))
	GameGeometry.collider(root, Vector3(width, height, BUILDING_DEPTH), pose * Vector3(0, height / 2, -BUILDING_DEPTH / 2), pose.basis.get_euler().y)
	for level in range(1, floors + 1):
		var y := 4.4 + (level - 1) * 3.4
		_put(b, "concrete", pose, Vector3(0, y, 0.18), Vector3(width + 0.3, 0.18, 0.5))
		for x in [-10.2, -3.4, 3.4, 10.2]:
			_window(b, pose, x, y + 1.7, rng)
	_put(b, "concrete", pose, Vector3(0, 0.42, 0.12), Vector3(width, 0.84, 0.35))
	_put(b, "concrete", pose, Vector3(0, height - 0.05, -0.05), Vector3(width + 0.8, 0.4, 0.9))
	_put(b, "concrete", pose, Vector3(0, height + 0.25, -6.5), Vector3(width + 0.7, 0.18, 13.6))
	_put(b, "metal", pose, Vector3(-6, height + 0.85, -6), Vector3(3.6, 1.1, 2.6))
	for x in [-7.3, -6.7, -6.1, -5.5, -4.9]:
		_put(b, "recess", pose, Vector3(x, height + 1.42, -6), Vector3(0.13, 0.03, 2.1))
	for x in [-13.2, 13.2]:
		_put(b, "pipes", pose, Vector3(x, height * 0.5, 0.23), Vector3(0.14, height, 0.14))
	for x in [-8.3, 8.3]:
		for edge in [-1.0, 1.0]:
			_put(b, "recess", pose, Vector3(x + edge * 3.2, 1.9, 0.10), Vector3(0.15, 2.9, 0.22))
			_put(b, "recess", pose, Vector3(x, 1.9 + edge * 1.4, 0.10), Vector3(6.5, 0.15, 0.22))
		for level in 3:
			var shelf_y := 0.85 + level * 0.8
			_put(b, "wood", pose, Vector3(x, shelf_y, -2.4), Vector3(5.2, 0.10, 0.75))
			for item in 4:
				_put(b, "metal" if (item + level) % 2 else "concrete", pose, Vector3(x - 1.8 + item * 1.2, shelf_y + 0.24, -2.4), Vector3(0.62, 0.38, 0.4))
		_put(b, "shopglass", pose, Vector3(x, 1.9, 0.15), Vector3(6.0, 2.5, 0.06))
		for mullion in [-2.0, 0.0, 2.0]:
			_put(b, "metal", pose, Vector3(x + mullion, 1.9, 0.23), Vector3(0.065, 2.65, 0.12))
		_put(b, "awning", pose, Vector3(x, 3.55, 0.80), Vector3(7.2, 0.18, 1.8))
		_put(b, "warm", pose, Vector3(x, 3.43, 0.65), Vector3(5.9, 0.035, 0.12))
	_put(b, "recess", pose, Vector3(0, 1.65, 0.10), Vector3(2.8, 3.3, 0.22))
	for x in [-0.65, 0.65]:
		_put(b, "glass_off", pose, Vector3(x, 1.7, 0.24), Vector3(1.18, 2.95, 0.055))
		_put(b, "metal", pose, Vector3(x * 0.3, 1.6, 0.31), Vector3(0.025, 0.4, 0.05))
	_put(b, "metal", pose, Vector3(0, 1.65, 0.28), Vector3(0.06, 3.3, 0.12))
	_put(b, "recess", pose, Vector3(0, 4.02, 0.23), Vector3(13, 0.76, 0.22))
	var titles := ["АПЕКС / АВТОСЕРВИС", "НОЧНОЙ ФИЛИН", "24 / МАРКЕТ", "НЕОН / АУДИО", "ПОЛУНОЧЬ / КОФЕ"]
	var text := Label3D.new()
	text.text = titles[index]
	text.font_size = 48
	text.pixel_size = 0.011
	root.add_child(text)
	text.transform = pose * Transform3D(Basis.IDENTITY, Vector3(0, 4.02, 0.36))
	text.modulate = Color("ffcb8c") if index % 2 == 0 else Color("70d4e2")
	_put(b, "cyan" if index % 2 else "warm", pose, Vector3(0, 3.61, 0.35), Vector3(13, 0.035, 0.06))
	if index == 1 or index == 3:
		_put(b, "recess", pose, Vector3(12, 7.2, 1.1), Vector3(0.28, 5.2, 2.1))
		var blade := Label3D.new()
		blade.text = "Н\nЕ\nО\nН" if index == 3 else "24\nЧ"
		blade.font_size = 48
		blade.pixel_size = 0.015
		root.add_child(blade)
		blade.transform = pose * Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(12 + side * 0.15, 7.2, 1.1))
		blade.modulate = Color("70d4e2")

static func _window(b: Dictionary, pose: Transform3D, x: float, y: float, rng: RandomNumberGenerator) -> void:
	_put(b, "recess", pose, Vector3(x, y, 0.045), Vector3(2.55, 2.3, 0.09))
	var choice := rng.randf()
	var glass := "glass_off" if choice < 0.48 else ("glass_warm" if choice < 0.85 else "glass_cool")
	_put(b, glass, pose, Vector3(x, y, 0.105), Vector3(2.26, 2.02, 0.035))
	for side in [-1.0, 1.0]:
		_put(b, "frames", pose, Vector3(x + side * 1.24, y, 0.15), Vector3(0.12, 2.4, 0.22))
		_put(b, "frames", pose, Vector3(x, y + side * 1.12, 0.15), Vector3(2.6, 0.12, 0.22))
	_put(b, "metal", pose, Vector3(x, y, 0.19), Vector3(0.065, 2.15, 0.12))
	_put(b, "concrete", pose, Vector3(x, y - 1.25, 0.24), Vector3(2.85, 0.12, 0.6))

static func _furniture(b: Dictionary, road: Transform3D, side: float) -> void:
	road.origin.y = 0.0
	var x := side * 17.1
	_put(b, "wood", road, Vector3(x, 0.58, 0), Vector3(0.6, 0.12, 2.1))
	_put(b, "wood", road, Vector3(x + side * 0.3, 0.9, 0), Vector3(0.10, 0.55, 2.1))
	for z in [-0.72, 0.72]:
		_put(b, "metal", road, Vector3(x, 0.32, z), Vector3(0.45, 0.5, 0.08))
	_put(b, "concrete", road, Vector3(side * 18.0, 0.42, -4.0), Vector3(1.2, 0.84, 2.3))
	for z in [-4.7, -4.0, -3.3]:
		_put(b, "hedge", road, Vector3(side * 18.0, 1.03, z), Vector3(1.04, 0.7, 0.85))
	for z in [-10.0, -7.0, -4.0, -1.0, 2.0, 5.0, 8.0, 11.0]:
		_put(b, "pipes", road, Vector3(side * 14.2, 0.62, z), Vector3(0.12, 0.9, 0.12))
		_put(b, "warm", road, Vector3(side * 14.2, 0.94, z), Vector3(0.13, 0.05, 0.13))
	_put(b, "metal", road, Vector3(side * 11.55, 0.03, 1), Vector3(0.45, 0.015, 1.4))
	for z in range(7):
		_put(b, "recess", road, Vector3(side * 11.55, 0.04, 0.5 + z * 0.16), Vector3(0.32, 0.008, 0.07))

static func _crossing(b: Dictionary, road: Transform3D) -> void:
	road.origin.y = 0.0
	for i in 20:
		_put(b, "markings", road, Vector3(-10.5 + i * 1.1, 0.036, 0), Vector3(0.55, 0.015, 3.0))

static func _entrance(b: Dictionary, road: Transform3D) -> void:
	road.origin.y = 0.0
	for side in [-1.0, 1.0]:
		_put(b, "concrete", road, Vector3(side * 14.65, 4.8, -0.3), Vector3(1.3, 9.6, 2.8))
		for i in 8:
			_put(b, "warm" if i % 2 else "recess", road, Vector3(side * 13.94, 0.6 + i * 0.27, 1.15), Vector3(0.08, 0.25, 0.18))
		_put(b, "metal", road, Vector3(side * 13.3, 6.4, -100), Vector3(0.10, 0.10, 199))
	_put(b, "concrete", road, Vector3(0, 9.0, -0.3), Vector3(30.6, 1.2, 2.8))
	_put(b, "recess", road, Vector3(0, 9.45, 1.15), Vector3(28.8, 0.2, 0.06))

static func _accent_light(root: Node3D, track: CityTrack, distance: float, across: float, color: Color, energy: float) -> void:
	var pose := track.transform_at(distance)
	var light := OmniLight3D.new()
	light.name = "StorefrontLight"
	light.position = pose.origin + pose.basis.x * across + Vector3.UP * 4.8
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 23
	light.shadow_enabled = false
	root.add_child(light)

static func _flush(root: Node3D, b: Dictionary) -> void:
	var materials := _materials()
	for group in b:
		var poses: Array[Transform3D] = []
		poses.assign(b[group])
		if group == "pipes":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 8
			CityDistricts._batch_mesh(root, cylinder, poses, materials[group])
		else:
			GameGeometry.batch_boxes(root, poses, materials[group])
		root.get_child(root.get_child_count() - 1).name = "Batch_" + group

static func _materials() -> Dictionary:
	var brick := concrete_material()
	brick.set_shader_parameter("base_color", Color("684637"))
	brick.set_shader_parameter("brick_pattern", 1.0)
	var stone := concrete_material()
	stone.set_shader_parameter("base_color", Color("62666b"))
	var metal := GameGeometry.material(Color("303a40"))
	metal.metallic = 0.65
	metal.roughness = 0.34
	var glass := GameGeometry.material(Color("15262e"))
	glass.roughness = 0.24
	glass.metallic = 0.12
	var storefront := GameGeometry.material(Color(0.10, 0.17, 0.20, 0.22))
	storefront.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	storefront.roughness = 0.22
	storefront.metallic_specular = 0.25
	return {
		"brick": brick, "stone": stone, "concrete": concrete_material(),
		"metal": metal, "pipes": metal, "frames": GameGeometry.material(Color("7c858b")),
		"recess": GameGeometry.material(Color("0b1016")), "glass_off": glass,
		"glass_warm": GameGeometry.material(Color("c19a68"), 0.28),
		"glass_cool": GameGeometry.material(Color("63919d"), 0.18),
		"shopglass": storefront, "interior": GameGeometry.material(Color("6a5946"), 0.10),
		"wood": GameGeometry.material(Color("674f39")), "hedge": GameGeometry.material(Color("273b2c")),
		"awning": GameGeometry.material(Color("24313b")), "warm": GameGeometry.material(Color("edb777"), 0.8),
		"cyan": GameGeometry.material(Color("57bdce"), 0.8), "markings": GameGeometry.material(Color("9da5a8"))
	}
