class_name LanternQuarter
extends RefCounted
## Hand-authored human-scale block after the tunnel, with actual shop interiors.
const START := 327.0
const END := 511.0
const FRONTAGES := [340.0, 380.0, 424.0, 466.0]

static func contains(distance: float) -> bool:
	return distance >= START and distance <= END

static func build(track: CityTrack) -> void:
	var root := Node3D.new()
	root.name = "LanternQuarter"
	track.add_child(root)
	var b := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 140626
	var count := 0
	for side in [-1.0, 1.0]:
		for index in FRONTAGES.size():
			var road := track.transform_at(FRONTAGES[index])
			road.origin.y = 0
			var normal: Vector3 = -road.basis.x * side
			var pose := Transform3D(Basis.looking_at(-normal, Vector3.UP), road.origin + road.basis.x * side * 23.0)
			if not CityArchitecture._site_clear(track, pose, 28.0):
				continue
			var variant := posmod(index + (2 if side > 0 else 0), 4)
			_facade(root, b, pose, variant, rng)
			if variant == 0 or variant == 2:
				_light(root, pose, variant)
			count += 1
		for distance in [360.0, 402.0, 445.0]:
			var road := track.transform_at(distance)
			road.origin.y = 0
			var normal: Vector3 = -road.basis.x * side
			var pose := Transform3D(Basis.looking_at(-normal, Vector3.UP), road.origin + road.basis.x * side * 23.0)
			_alley(b, pose, 17.0 if distance == 402.0 else (13.0 if distance == 360.0 else 15.0))
		_furniture(b, track, side)
	_flush(root, b, track.transform_at(407).origin)
	root.set_meta("frontage_count", count)
	var instances := 0
	for poses in b.values():
		instances += poses.size()
	root.set_meta("instance_count", instances)
	root.set_meta("batch_count", b.size())

static func _box(b: Dictionary, key: String, p: Transform3D, at: Vector3, size: Vector3) -> void:
	StreetShowcase._put(b, key, p, at, size)

static func _facade(root: Node3D, b: Dictionary, p: Transform3D, variant: int, rng: RandomNumberGenerator) -> void:
	var floors: int = [3, 4, 2, 5][variant]
	var height := 4.2 + floors * 3.2
	var wall: String = ["brick", "cream", "brick_dark", "cream"][variant]
	_box(b, wall, p, Vector3(0, 4.2 + (height - 4.2) / 2, -6.5), Vector3(28, height - 4.2, 13))
	for x in [-12.8, 0.0, 12.8]:
		_box(b, wall, p, Vector3(x, 2.1, -6.5), Vector3(2.4 if x != 0 else 3.6, 4.2, 13))
	# Ground-floor openings are not covered by a solid building box.
	_box(b, "interior", p, Vector3(0, 2.05, -4.8), Vector3(28, 4.1, 0.18))
	_box(b, "wood", p, Vector3(0, 0.22, -2.4), Vector3(28, 0.12, 4.8))
	_box(b, "ceiling", p, Vector3(0, 4.06, -2.4), Vector3(28, 0.12, 4.8))
	var collision := GameGeometry.collider(root, Vector3(28, height, 13), p * Vector3(0, height / 2, -6.5), p.basis.get_euler().y)
	collision.name = "QuarterBuilding"
	for floor_index in floors:
		var y := 5.8 + floor_index * 3.2
		for x in [-9.9, -3.3, 3.3, 9.9]:
			CityArchitecture._pane(b, p, x, y, 2.0, 1.85, rng, true)
			if variant == 3 and floor_index in [1, 3] and absf(x) > 5:
				CityArchitecture._balcony(b, p, x, y - 1.15)
		_box(b, "limestone", p, Vector3(0, y - 1.6, 0.10), Vector3(28.2, 0.13, 0.28))
		for side in [-1.0, 1.0]:
			var return_pose := p * Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(side * 14, 0, -6.5))
			for x in [-3.3, 3.3]:
				CityArchitecture._pane(b, return_pose, x, y, 1.7, 1.85, rng, true)
	_box(b, "limestone", p, Vector3(0, 0.5, 0.12), Vector3(28, 0.65, 0.32))
	for y in [4.2, height]:
		_box(b, "limestone", p, Vector3(0, y, 0.22), Vector3(28.6, 0.24, 0.65))
	_box(b, "roof", p, Vector3(0, height + 0.12, -6.5), Vector3(28.5, 0.24, 13.5))
	for x in [-13.5, 13.5]:
		_box(b, "metal", p, Vector3(x, height * 0.5, 0.18), Vector3(0.10, height, 0.10))
		_box(b, "limestone", p, Vector3(x, height + 0.5, -6.5), Vector3(0.35, 0.8, 13))
	CityArchitecture._roof(b, p, height, 28)
	for x in [-7.0, 7.0]:
		_shop(root, b, p, x, variant)
	if variant == 1:
		_fire_escape(b, p)
	if variant == 3:
		_box(b, "cream", p, Vector3(0, height + 1.1, -7), Vector3(12, 2.0, 9))

static func _shop(root: Node3D, b: Dictionary, p: Transform3D, x: float, variant: int) -> void:
	var title: String = CityNames.QUARTER_MAIN[variant]
	if x > 0:
		title = CityNames.QUARTER_SECONDARY[variant]
	var canopy: String = "sage" if variant == 0 else ("canvas" if variant == 3 else "awning")
	_box(b, canopy, p, Vector3(x, 3.5, 0.7), Vector3(9.8, 0.16, 1.7))
	_box(b, "recess", p, Vector3(x, 3.93, 0.24), Vector3(10.0, 0.52, 0.18))
	_sign(root, p, title, Vector3(x, 3.93, 0.35), 0.0075)
	_box(b, "warm", p, Vector3(x, 3.36, 0.65), Vector3(8.8, 0.035, 0.08))
	for dx in [-4.6, 0.0, 4.6]:
		_box(b, "metal", p, Vector3(x + dx, 1.9, 0.18), Vector3(0.085, 2.85, 0.16))
	_box(b, "metal", p, Vector3(x, 0.5, 0.18), Vector3(9.4, 0.1, 0.16))
	if variant != 2 or x > 0:
		_box(b, "shopglass", p, Vector3(x, 1.9, 0.10), Vector3(9.2, 2.7, 0.04))
	if variant == 0:
		for dx in [-2.7, 2.7]:
			_box(b, "wood", p, Vector3(x + dx, 1.05, -2.4), Vector3(2, 0.12, 0.85))
			_box(b, "metal", p, Vector3(x + dx, 0.6, -2.4), Vector3(0.12, 0.9, 0.12))
			for seat in [-0.8, 0.8]:
				_box(b, "wood", p, Vector3(x + dx + seat, 0.65, -1.6), Vector3(0.48, 0.1, 0.5))
				_box(b, "wood", p, Vector3(x + dx + seat, 1.0, -1.35), Vector3(0.48, 0.65, 0.07))
		_box(b, "wood", p, Vector3(x, 1.2, -3.6), Vector3(7.5, 1.8, 0.7))
		_box(b, "metal", p, Vector3(x - 2, 2.3, -3.5), Vector3(1.1, 0.5, 0.55))
		for dx in [-2.8, -1.0, 1.0, 2.8]:
			_box(b, "metal", p, Vector3(x + dx, 3.4, -2), Vector3(0.025, 1.3, 0.025))
			_box(b, "warm", p, Vector3(x + dx, 2.7, -2), Vector3(0.35, 0.09, 0.35))
	elif variant == 1:
		for shelf in 3:
			var y := 0.8 + shelf * 0.85
			_box(b, "wood", p, Vector3(x, y, -2.8), Vector3(8, 0.12, 0.8))
			for item in 8:
				_box(b, ["sage", "canvas", "oxide", "metal"][item % 4], p, Vector3(x - 3.4 + item * 0.95, y + 0.28, -2.8), Vector3(0.55, 0.48, 0.12))
		for dx in [-3.5, 3.5]:
			_box(b, "recess", p, Vector3(x + dx, 1.3, -1.2), Vector3(0.65, 1.8, 0.55))
	elif variant == 2:
		# A partially open shutter reveals a workbench and service ramp.
		if x < 0:
			for row in 7:
				_box(b, "metal", p, Vector3(x, 3.2 + row * 0.12, 0.12), Vector3(9.1, 0.08, 0.12))
			for dx in [-1.6, 1.6]:
				_box(b, "metal", p, Vector3(x + dx, 0.5, -2.2), Vector3(0.5, 0.16, 3.5))
		_box(b, "wood", p, Vector3(x, 1.15, -3.5), Vector3(7.4, 0.14, 1.1))
		_box(b, "oxide", p, Vector3(x - 2.4, 0.65, -3.5), Vector3(1.6, 0.95, 0.8))
		for dx in [-2.2, -1.4, 0.0, 1.0, 2.0, 2.8]:
			_box(b, "steel", p, Vector3(x + dx, 2.4, -4.5), Vector3(0.1, 0.65, 0.08))
	else:
		for dx in [-2.4, 2.4]:
			_box(b, "wood", p, Vector3(x + dx, 0.65, -2.5), Vector3(1.8, 0.55, 0.8))
		_box(b, "cream", p, Vector3(x, 1.1, -3.6), Vector3(5.0, 1.6, 0.7))
	# A few lit surfaces rather than uniformly luminous window rectangles.
	_box(b, "warm", p, Vector3(x, 3.96, -2.6), Vector3(3.2, 0.035, 0.15))

static func _fire_escape(b: Dictionary, p: Transform3D) -> void:
	var side := p * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(14.05, 0, -6.5))
	for level in [7.2, 10.4, 13.6]:
		_box(b, "metal", side, Vector3(0, level, 0.8), Vector3(5, 0.10, 1.8))
		_box(b, "metal", side, Vector3(0, level + 0.9, 1.65), Vector3(5, 0.06, 0.06))
		for x in [-2.3, -1.1, 0.0, 1.1, 2.3]:
			_box(b, "metal", side, Vector3(x, level + 0.45, 1.65), Vector3(0.05, 0.9, 0.05))
		for step in 11:
			_box(b, "metal", side, Vector3(-2.2 + step * 0.4, level - 2.9 + step * 0.29, 0.8), Vector3(0.45, 0.07, 0.85))

static func _alley(b: Dictionary, p: Transform3D, width: float) -> void:
	_box(b, "roof", p, Vector3(0, 0.16, -8), Vector3(width, 0.08, 17))
	_box(b, "brick_dark", p, Vector3(0, 2.6, -16.5), Vector3(width, 5.2, 0.35))
	for x in [-width / 2, width / 2]:
		_box(b, "brick_dark", p, Vector3(x, 2.6, -8), Vector3(0.3, 5.2, 17.4))
	_box(b, "steel", p, Vector3(-width / 2 + 0.25, 3.5, -8), Vector3(0.5, 0.85, 1.4))
	for z in [-8.5, -8.25, -8.0, -7.75, -7.5]:
		_box(b, "recess", p, Vector3(-width / 2 + 0.52, 3.5, z), Vector3(0.02, 0.65, 0.07))
	_box(b, "sage", p, Vector3(-1.7, 0.9, -11), Vector3(1.7, 1.4, 1.3))
	_box(b, "metal", p, Vector3(-1.7, 1.65, -11), Vector3(1.85, 0.10, 1.4))
	_box(b, "recess", p, Vector3(1.5, 1.6, -16.25), Vector3(1.2, 2.8, 0.12))
	_box(b, "warm", p, Vector3(1.5, 3.2, -15.9), Vector3(0.45, 0.10, 0.15))
	for x in [-2.6, 2.6]:
		_box(b, "metal", p, Vector3(x, 2.3, -16.1), Vector3(0.10, 4.4, 0.1))

static func _furniture(b: Dictionary, track: CityTrack, side: float) -> void:
	for distance in [342.0, 386.0, 430.0, 472.0]:
		var p := track.transform_at(distance)
		p.origin.y = 0
		var x: float = side * 18.6
		_box(b, "wood", p, Vector3(x, 0.65, 0), Vector3(0.65, 0.13, 2.1))
		_box(b, "wood", p, Vector3(x + side * 0.3, 1.0, 0), Vector3(0.1, 0.6, 2.1))
		for z in [-0.7, 0.7]:
			_box(b, "metal", p, Vector3(x, 0.4, z), Vector3(0.5, 0.5, 0.08))
		_box(b, "limestone", p, Vector3(side * 20, 0.5, -5), Vector3(1.0, 0.8, 1.4))
		_box(b, "hedge", p, Vector3(side * 20, 1.05, -5), Vector3(0.9, 0.55, 1.3))
		_box(b, "metal", p, Vector3(side * 17.3, 0.6, 6), Vector3(0.5, 0.9, 0.5))
		_box(b, "recess", p, Vector3(side * 17.3, 1.06, 6), Vector3(0.36, 0.025, 0.36))
		# Small damp gutter patches with irregular feathered edges.
		var pose := p * Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled_local(Vector3(1.0, 3.3, 1)), Vector3(side * 11.7, 0.028, 1.5))
		if not b.has("puddle"):
			b["puddle"] = []
		b["puddle"].append(pose)
	for distance in range(330, 512, 8):
		var p := track.transform_at(distance)
		p.origin.y = 0
		_box(b, "reflector", p, Vector3(side * 12.17, 0.65, 0), Vector3(0.04, 0.12, 0.25))

static func _light(root: Node3D, p: Transform3D, variant: int) -> void:
	var light: Light3D
	if variant == 0 and root.find_children("ShopShadow*", "SpotLight3D", true, false).is_empty():
		var spot := SpotLight3D.new()
		spot.spot_range = 17
		spot.spot_angle = 62
		spot.shadow_enabled = true
		spot.shadow_bias = 0.04
		spot.shadow_normal_bias = 0.7
		light = spot
		light.name = "ShopShadow"
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = 17
		omni.shadow_enabled = false
		light = omni
		light.name = "ShopLight"
	root.add_child(light)
	light.position = p * Vector3(-6.2, 3.1, 1.1)
	if light is SpotLight3D:
		light.look_at(p * Vector3(-6.2, 0.3, -2.6))
	light.light_color = Color("ffdbb0") if variant == 0 else Color("e0d4bd")
	light.light_energy = 2.8 if variant == 0 else 2.2
	light.distance_fade_enabled = true
	light.distance_fade_begin = 75
	light.distance_fade_length = 20

static func _sign(root: Node3D, p: Transform3D, words: String, at: Vector3, pixel: float) -> void:
	var text := Label3D.new()
	text.text = words
	text.font_size = 48
	text.pixel_size = pixel
	text.modulate = Color("dfd2b8")
	text.shaded = true
	text.visibility_range_end = 140
	root.add_child(text)
	text.transform = p * Transform3D(Basis.IDENTITY, at)

static func _flush(root: Node3D, b: Dictionary, center: Vector3) -> void:
	var materials := StreetShowcase._materials()
	materials["cream"] = CityArchitecture._masonry(Color("827d70"), false)
	materials["brick_dark"] = CityArchitecture._masonry(Color("50473f"), true)
	materials["limestone"] = CityArchitecture._masonry(Color("8a8476"), false)
	materials["brick"] = CityArchitecture._masonry(Color("775747"), true)
	materials["sage"] = GameGeometry.material(Color("414d45"))
	materials["canvas"] = GameGeometry.material(Color("887e67"))
	materials["steel"] = GameGeometry.material(Color("687071"))
	materials["oxide"] = GameGeometry.material(Color("775448"))
	materials["roof"] = GameGeometry.material(Color("30353a"))
	materials["ceiling"] = GameGeometry.material(Color("8a8170"))
	materials["warm"] = GameGeometry.material(Color("e4c6a0"), 0.45)
	materials["reflector"] = GameGeometry.material(Color("c2a36d"), 0.3)
	materials["glass_off"] = CityArchitecture._window_material(Color("69757b"), 0.0)
	materials["glass_warm"] = CityArchitecture._window_material(Color("c9af8c"), 0.65)
	materials["glass_cool"] = CityArchitecture._window_material(Color("b1bbc0"), 0.5)
	var puddle := ShaderMaterial.new()
	puddle.shader = load("res://assets/materials/gutter_damp.gdshader")
	materials["puddle"] = puddle
	var geometry := Node3D.new()
	geometry.name = "QuarterBatches"
	root.add_child(geometry)
	geometry.position = center
	geometry.position.y = 0
	for group in b:
		var key: String = group.trim_prefix("near_")
		var poses: Array[Transform3D] = []
		for world_pose in b[group]:
			var local_pose: Transform3D = world_pose
			local_pose.origin -= geometry.position
			poses.append(local_pose)
		if key.begins_with("glass_") or key == "puddle":
			CityDistricts._batch_mesh(geometry, QuadMesh.new(), poses, materials[key])
		else:
			GameGeometry.batch_boxes(geometry, poses, materials[key])
		var batch := geometry.get_child(geometry.get_child_count() - 1) as MultiMeshInstance3D
		batch.name = "Batch_" + group
		batch.visibility_range_end = 330
		batch.visibility_range_end_margin = 20
		if key in ["shopglass", "puddle", "warm"] or group.begins_with("near_"):
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
