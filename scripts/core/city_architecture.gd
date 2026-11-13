class_name CityArchitecture
extends RefCounted
## Modular architecture around the whole circuit; spatial batches keep detail local.
const SITE_SPACING := 48.0
const CHUNK_LENGTH := 240.0
const FACADE_OFFSET := 24.0
const DEPTH := 14.0

static func build(track: CityTrack) -> void:
	var city := Node3D.new()
	city.name = "CityArchitecture"
	track.add_child(city)
	var chunks := {}
	var sites := PackedFloat32Array()
	var counts := [0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 845203
	var materials := StreetShowcase._materials()
	materials["stone_blue"] = _masonry(Color("3d5361"), false)
	materials["brick_red"] = _masonry(Color("744b40"), true)
	materials["sandstone"] = _masonry(Color("8b806b"), false)
	materials["roof"] = GameGeometry.material(Color("28333b"))
	materials["steel"] = GameGeometry.material(Color("57636a"))
	materials["oxide"] = GameGeometry.material(Color("804e39"))
	materials["foliage"] = GameGeometry.material(Color("263d33"))
	materials["trunk"] = GameGeometry.material(Color("544438"))
	materials["glass_off"] = _window_material(Color("607b87"), 0.0)
	materials["glass_warm"] = _window_material(Color("dbb583"), 1.0)
	materials["glass_cool"] = _window_material(Color("9fbec8"), 1.0)
	for site in range(0, int(track.track_length / SITE_SPACING)):
		var distance := 110.0 + site * SITE_SPACING
		if distance >= track.track_length - 120.0 or track.in_tunnel(distance):
			continue
		var district := track.district_at(distance)
		var bucket := int(distance / CHUNK_LENGTH)
		if not chunks.has(bucket):
			chunks[bucket] = {}
		var b: Dictionary = chunks[bucket]
		var road := track.transform_at(distance)
		road.origin.y = 0
		for side in [-1.0, 1.0]:
			if district == 2 and side < 0:
				_promenade(b, road, site)
				continue
			# Keep the existing crane and freight yard readable rather than burying them.
			if district == 1 and side < 0 and (absf(distance - track.anchor_distance(5) - 40) < 45 or absf(distance - track.anchor_distance(6) - 35) < 38):
				continue
			var normal: Vector3 = -road.basis.x * side
			var pose := Transform3D(Basis.looking_at(-normal, Vector3.UP), road.origin + road.basis.x * side * FACADE_OFFSET)
			var width := 28.0 + float(site % 3) * 2.0
			if not _site_clear(track, pose, width):
				continue
			var style := posmod(site + (1 if side > 0 else 0), 3)
			if district == 1:
				_warehouse(city, b, pose, width, site, rng)
			else:
				_block(city, b, pose, width, style, district, site, rng)
			_furniture(b, road, side, site)
			sites.append(distance)
			counts[district] += 1
	var instances := 0
	var groups := 0
	for bucket in chunks:
		var root := Node3D.new()
		root.name = "Block_%02d" % bucket
		city.add_child(root)
		root.position = track.transform_at((float(bucket) + 0.5) * CHUNK_LENGTH).origin
		root.position.y = 0
		var b: Dictionary = chunks[bucket]
		for group in b:
			var poses: Array[Transform3D] = []
			for world_pose in b[group]:
				var local_pose: Transform3D = world_pose
				local_pose.origin -= root.position
				poses.append(local_pose)
			var near: bool = group.begins_with("near_")
			var key: String = group.trim_prefix("near_")
			if key in ["glass_off", "glass_warm", "glass_cool"]:
				CityDistricts._batch_mesh(root, QuadMesh.new(), poses, materials[key])
			elif key == "foliage":
				var sphere := SphereMesh.new()
				sphere.radial_segments = 12
				sphere.rings = 6
				CityDistricts._batch_mesh(root, sphere, poses, materials[key])
			else:
				GameGeometry.batch_boxes(root, poses, materials[key])
			var batch := root.get_child(root.get_child_count() - 1) as MultiMeshInstance3D
			batch.name = "Batch_" + group
			batch.visibility_range_end = 155.0 if near else 630.0
			batch.visibility_range_end_margin = 18.0
			if near or key in ["glass_off", "glass_warm", "glass_cool", "warm", "cyan", "foliage"]:
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instances += poses.size()
			groups += 1
	city.set_meta("site_distances", sites)
	city.set_meta("district_counts", counts)
	city.set_meta("instance_count", instances)
	city.set_meta("batch_count", groups)
	_dock_cranes(track, city)
	_skyline(track, city, materials)
	CityRoadDress.build(track)

static func _window_material(tint: Color, lit: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/city_window.gdshader")
	material.set_shader_parameter("room_tint", tint)
	material.set_shader_parameter("lit", lit)
	return material

static func _masonry(color: Color, brick: bool) -> ShaderMaterial:
	var material := StreetShowcase.concrete_material()
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("brick_pattern", 1.0 if brick else 0.0)
	return material

static func _put(b: Dictionary, key: String, pose: Transform3D, at: Vector3, size: Vector3, near: bool = false) -> void:
	StreetShowcase._put(b, ("near_" if near else "") + key, pose, at, size)

static func _site_clear(track: CityTrack, pose: Transform3D, width: float) -> bool:
	# Check the whole footprint against every road section, including tight inside bends.
	for x in [-width * 0.5 - 1, 0.0, width * 0.5 + 1]:
		for z in [1.9, -DEPTH * 0.5, -DEPTH - 1]:
			var point: Vector3 = pose * Vector3(x, 0, z)
			var distance := track.nearest_distance(point)
			var closest := track.transform_at(distance).origin
			if Vector2(point.x - closest.x, point.z - closest.z).length() < 18.5:
				return false
	return true

static func _block(root: Node3D, b: Dictionary, p: Transform3D, width: float, style: int, district: int, index: int, rng: RandomNumberGenerator) -> void:
	var floors := 5 + index % 3
	if style == 1:
		floors += 3
	var height := 4.2 + floors * 3.3
	var wall: String = ["brick_red", "stone_blue", "sandstone"][style]
	if district == 2:
		wall = "sandstone" if style != 1 else "stone_blue"
	_put(b, wall, p, Vector3(0, height / 2, -DEPTH / 2), Vector3(width, height, DEPTH))
	GameGeometry.collider(root, Vector3(width, height, DEPTH), p * Vector3(0, height / 2, -DEPTH / 2), p.basis.get_euler().y)
	_put(b, "concrete", p, Vector3(0, 0.45, 0.15), Vector3(width + 0.2, 0.9, 0.35))
	_put(b, "concrete", p, Vector3(0, 4.1, 0.24), Vector3(width + 0.6, 0.28, 0.65))
	var columns := 5 if style == 1 else 4
	for floor_index in floors:
		var y := 5.8 + floor_index * 3.3
		for column in columns:
			var x := (float(column) - (columns - 1) * 0.5) * (width - 5) / columns
			_pane(b, p, x, y, 2.7 if style == 1 else 2.1, 2.45 if style == 1 else 1.9, rng, true)
			if style == 2 and floor_index % 2 == 0 and column in [0, columns - 1]:
				_balcony(b, p, x, y - 1.15)
		if style != 1:
			_put(b, "concrete", p, Vector3(0, y - 1.65, 0.12), Vector3(width + 0.1, 0.12, 0.25), true)
		# Side returns keep buildings convincing when approaching a bend.
		for side in [-1.0, 1.0]:
			var side_pose := p * Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(side * width / 2, 0, -DEPTH / 2))
			for x in [-3.5, 3.5]:
				_pane(b, side_pose, x, y, 1.8, 1.9, rng, false)
	if style == 1:
		for x in [-width * 0.48, -width * 0.24, 0.0, width * 0.24, width * 0.48]:
			_put(b, "steel", p, Vector3(x, height * 0.5 + 2, 0.3), Vector3(0.18, height - 4, 0.65))
		_put(b, "stone_blue", p, Vector3(0, height + 2, -DEPTH / 2 - 1), Vector3(width - 5, 4, DEPTH - 3))
		_put(b, "cyan", p, Vector3(0, height + 3.8, 0.12), Vector3(width - 5, 0.09, 0.12))
	elif style == 2:
		_put(b, wall, p, Vector3(0, height + 1.3, -DEPTH / 2), Vector3(width - 9, 2.6, DEPTH - 3))
		for x in [-width / 2 + 1, width / 2 - 1]:
			_put(b, "concrete", p, Vector3(x, height / 2, 0.27), Vector3(0.55, height, 0.6))
	else:
		for x in [-width * 0.48, 0.0, width * 0.48]:
			_put(b, "concrete", p, Vector3(x, height / 2, 0.13), Vector3(0.32, height, 0.3), true)
	_put(b, "concrete", p, Vector3(0, height + 0.15, -DEPTH / 2), Vector3(width + 0.7, 0.32, DEPTH + 0.7))
	_put(b, "roof", p, Vector3(0, height + 0.4, -DEPTH / 2), Vector3(width - 1, 0.25, DEPTH - 1))
	_roof(b, p, height, width)
	_shop(b, p, width, style, index)
	if index % 3 == 0 or style == 2:
		_sign(root, p, ["НОЧНАЯ СМЕНА / КОФЕ", "ОРБИТА / МЕДИА", "ОТЕЛЬ «МЕРИДИАН»"][style], Vector3(0, 3.5, 0.82), Color("f1c38e"), 0.010)

static func _pane(b: Dictionary, p: Transform3D, x: float, y: float, width: float, height: float, rng: RandomNumberGenerator, detail: bool) -> void:
	var choice := rng.randf()
	var glass := "glass_off" if choice < 0.55 else ("glass_warm" if choice < 0.89 else "glass_cool")
	_put(b, "recess", p, Vector3(x, y, 0.035), Vector3(width + 0.24, height + 0.24, 0.08))
	_put(b, glass, p, Vector3(x, y, 0.10), Vector3(width, height, 0.035))
	_put(b, "frames", p, Vector3(x, y, 0.18), Vector3(0.06, height, 0.14), true)
	if detail:
		for side in [-1.0, 1.0]:
			_put(b, "frames", p, Vector3(x + side * (width / 2 + 0.06), y, 0.16), Vector3(0.10, height + 0.22, 0.18), true)
			_put(b, "frames", p, Vector3(x, y + side * (height / 2 + 0.06), 0.16), Vector3(width + 0.2, 0.10, 0.18), true)
		_put(b, "concrete", p, Vector3(x, y - height / 2 - 0.2, 0.25), Vector3(width + 0.45, 0.12, 0.5), true)

static func _balcony(b: Dictionary, p: Transform3D, x: float, y: float) -> void:
	_put(b, "concrete", p, Vector3(x, y, 0.72), Vector3(3.5, 0.16, 1.6), true)
	for level in [0.3, 0.9]:
		_put(b, "metal", p, Vector3(x, y + level, 1.43), Vector3(3.4, 0.07, 0.07), true)
	for dx in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		_put(b, "metal", p, Vector3(x + dx, y + 0.5, 1.43), Vector3(0.045, 0.9, 0.045), true)

static func _shop(b: Dictionary, p: Transform3D, width: float, style: int, index: int) -> void:
	for x in [-width * 0.27, width * 0.27]:
		_put(b, "recess", p, Vector3(x, 2, 0.08), Vector3(width * 0.37, 2.7, 0.18))
		_put(b, "glass_warm" if index % 2 else "glass_cool", p, Vector3(x, 2, 0.2), Vector3(width * 0.34, 2.4, 0.05))
		for dx in [-2.5, 0.0, 2.5]:
			_put(b, "metal", p, Vector3(x + dx, 2, 0.28), Vector3(0.08, 2.6, 0.12), true)
		_put(b, "awning", p, Vector3(x, 3.5, 0.7), Vector3(width * 0.4, 0.18, 1.5))
		_put(b, "warm", p, Vector3(x, 3.35, 0.6), Vector3(width * 0.34, 0.035, 0.08), true)
	_put(b, "recess", p, Vector3(0, 1.7, 0.1), Vector3(2.4, 3.4, 0.2))
	_put(b, "glass_off", p, Vector3(0, 1.7, 0.24), Vector3(2.1, 3.1, 0.06))
	_put(b, "steel", p, Vector3(0, 1.7, 0.32), Vector3(0.07, 3.2, 0.1), true)
	if style == 2:
		_put(b, "sandstone", p, Vector3(0, 4.2, 0.9), Vector3(8, 0.35, 2.0))
		for x in [-3.5, 3.5]:
			_put(b, "concrete", p, Vector3(x, 2, 1.45), Vector3(0.4, 4, 0.4))

static func _roof(b: Dictionary, p: Transform3D, height: float, width: float) -> void:
	for x in [-width * 0.25, width * 0.25]:
		_put(b, "metal", p, Vector3(x, height + 1.1, -8), Vector3(3, 1.4, 3.2))
		for offset in [-0.8, 0.0, 0.8]:
			_put(b, "recess", p, Vector3(x + offset, height + 1.82, -8), Vector3(0.15, 0.03, 2.6), true)
	_put(b, "steel", p, Vector3(width * 0.3, height + 2.8, -10), Vector3(0.10, 5, 0.10))
	_put(b, "steel", p, Vector3(width * 0.3, height + 4, -10), Vector3(2.5, 0.08, 0.08))

static func _warehouse(root: Node3D, b: Dictionary, p: Transform3D, width: float, index: int, rng: RandomNumberGenerator) -> void:
	var height := 8.5 + float(index % 3) * 1.3
	var wall := "brick_red" if index % 2 else "stone_blue"
	_put(b, wall, p, Vector3(0, height / 2, -DEPTH / 2), Vector3(width, height, DEPTH))
	GameGeometry.collider(root, Vector3(width, height + 3, DEPTH), p * Vector3(0, (height + 3) / 2, -DEPTH / 2), p.basis.get_euler().y)
	# Two sloping roof planes give the sheds an actual pitched silhouette.
	var rise := 2.8
	var slope := atan2(rise, width / 2)
	var gable := GameGeometry.hull(root, width / 2, 0.04, height, height + rise,
		-DEPTH, 0, -DEPTH, 0, _masonry(Color("744b40") if index % 2 else Color("3d5361"), index % 2 == 1))
	gable.transform = p
	gable.name = "WarehouseGable"
	gable.visibility_range_end = 630
	for side in [-1.0, 1.0]:
		var roof_pose := p * Transform3D(Basis(Vector3.FORWARD, side * slope), Vector3(side * width / 4, height + rise / 2, -DEPTH / 2))
		_put(b, "roof", roof_pose, Vector3.ZERO, Vector3(sqrt(width * width / 4 + rise * rise) + 0.5, 0.22, DEPTH + 0.8))
	for x in [-width / 2 + 0.6, -width / 4, 0.0, width / 4, width / 2 - 0.6]:
		_put(b, "concrete", p, Vector3(x, height / 2, 0.22), Vector3(0.42, height, 0.5))
		_pane(b, p, x * 0.9, height - 1.2, 3.2, 1.1, rng, false)
	for x in [-width * 0.27, width * 0.27]:
		_put(b, "recess", p, Vector3(x, 2.7, 0.1), Vector3(8, 5.4, 0.25))
		_put(b, "steel", p, Vector3(x, 2.65, 0.26), Vector3(7.2, 5, 0.1))
		for row in 14:
			_put(b, "metal", p, Vector3(x, 0.4 + row * 0.34, 0.34), Vector3(7, 0.06, 0.07), true)
		_put(b, "oxide", p, Vector3(x, 5.6, 0.7), Vector3(8.5, 0.2, 1.5))
		_put(b, "warm", p, Vector3(x, 5.4, 0.45), Vector3(3.2, 0.08, 0.14), true)
	for x in [-1.5, 1.5]:
		_put(b, "oxide", p, Vector3(x, 0.7, 1.0), Vector3(0.2, 1.4, 0.2))
	_roof(b, p, height + rise, width)
	if index % 2 == 0:
		_sign(root, p, "ИСКРА / ЦЕХ %02d" % (index % 8 + 1), Vector3(0, height + 0.8, 0.3), Color("e8b176"), 0.014)

static func _furniture(b: Dictionary, road: Transform3D, side: float, index: int) -> void:
	var x := side * 18.4
	_put(b, "concrete", road, Vector3(x, 0.55, 6), Vector3(1.3, 0.9, 2.2))
	_put(b, "hedge", road, Vector3(x, 1.25, 6), Vector3(1.15, 0.8, 2.0))
	_put(b, "wood", road, Vector3(x, 0.65, -6), Vector3(0.65, 0.15, 2.2), true)
	_put(b, "wood", road, Vector3(x + side * 0.3, 1.0, -6), Vector3(0.12, 0.6, 2.2), true)
	for z in [-6.8, -5.2]:
		_put(b, "metal", road, Vector3(x, 0.4, z), Vector3(0.5, 0.6, 0.10), true)
	if index % 2 == 0:
		_tree(b, road, Vector3(side * 20.4, 0.17, 13))

static func _tree(b: Dictionary, p: Transform3D, at: Vector3) -> void:
	_put(b, "trunk", p, at + Vector3.UP * 2.1, Vector3(0.25, 4.2, 0.25))
	_put(b, "foliage", p, at + Vector3.UP * 4.8, Vector3(5, 3.2, 4.5))
	_put(b, "foliage", p, at + Vector3(1.1, 4.5, 0.8), Vector3(3.4, 2.8, 3.6))
	_put(b, "foliage", p, at + Vector3(-1.3, 4.2, -0.6), Vector3(3.0, 2.6, 3.4))

static func _promenade(b: Dictionary, road: Transform3D, index: int) -> void:
	_furniture(b, road, -1.0, index)
	_put(b, "wood", road, Vector3(-22, 0.20, 0), Vector3(3.5, 0.08, 34))
	for z in [-12.0, 12.0]:
		_put(b, "metal", road, Vector3(-22, 3, z), Vector3(0.12, 6, 0.12))
		_put(b, "cyan", road, Vector3(-22, 5.9, z), Vector3(1.3, 0.08, 0.5))
		_put(b, "stone_blue", road, Vector3(-22, 4.5, z + 0.6), Vector3(0.08, 2, 1.1))

static func _sign(root: Node3D, p: Transform3D, words: String, at: Vector3, color: Color, pixel: float) -> void:
	var sign := Label3D.new()
	sign.text = words
	sign.font_size = 56
	sign.pixel_size = pixel
	sign.modulate = color
	sign.no_depth_test = false
	sign.visibility_range_end = 150
	root.add_child(sign)
	sign.transform = p * Transform3D(Basis.IDENTITY, at)

static func _dock_cranes(track: CityTrack, city: Node3D) -> void:
	var beams: Array[Transform3D] = []
	for index in [10, 12]:
		var p := track.transform_at(track.anchor_distance(index) + 20)
		p.origin.y = 0
		for x in [-75.0, -53.0]:
			for z in [-6.0, 6.0]:
				beams.append(p * GameGeometry.box_transform(Vector3(x, 15, z), Vector3(0.8, 30, 0.8)))
		for z in [-6.0, 6.0]:
			beams.append(p * GameGeometry.box_transform(Vector3(-64, 30, z), Vector3(48, 1.3, 0.9)))
		beams.append(p * GameGeometry.box_transform(Vector3(-64, 31.2, 0), Vector3(2, 1.8, 14)))
		beams.append(p * GameGeometry.box_transform(Vector3(-87, 22, 0), Vector3(0.12, 16, 0.12)))
		beams.append(p * GameGeometry.box_transform(Vector3(-87, 14, 0), Vector3(1.4, 0.5, 1.4)))
	GameGeometry.batch_boxes(city, beams, GameGeometry.material(Color("54717c")))
	city.get_child(city.get_child_count() - 1).name = "HarborCranes"

static func _skyline(track: CityTrack, city: Node3D, materials: Dictionary) -> void:
	var b := {}
	var count := 0
	for x in [-260.0, -150.0, -40.0, 70.0, 180.0, 290.0]:
		for z in [-65.0, 35.0, 125.0]:
			var center := Vector3(x, 0, z)
			if center.distance_to(track.transform_at(track.nearest_distance(center)).origin) < 90:
				continue
			var p := Transform3D(Basis(Vector3.UP, 0.08 * count), center)
			var width := 22.0 + (count % 3) * 5
			var height := 42.0 + (count % 5) * 9
			_put(b, "stone_blue", p, Vector3(0, height / 2, 0), Vector3(width, height, 22))
			_put(b, "sandstone", p, Vector3(0, height + 3, 0), Vector3(width - 4, 6, 18))
			_put(b, "roof", p, Vector3(0, height + 7, 0), Vector3(width - 9, 2, 13))
			for side in 4:
				var angle := side * PI / 2
				var face := p * Transform3D(Basis(Vector3.UP, angle), Vector3(sin(angle) * width / 2, 0, cos(angle) * 11.04))
				for floor_index in range(2, int(height / 3.4)):
					for column in [-1.0, 0.0, 1.0]:
						_put(b, "glass_warm" if (floor_index + count + int(column)) % 4 == 0 else "glass_off", face,
							Vector3(column * 6.2, floor_index * 3.4, 0), Vector3(2.4, 1.7, 0.05))
			count += 1
	var root := Node3D.new()
	root.name = "DistantSkyline"
	city.add_child(root)
	for key in b:
		var poses: Array[Transform3D] = []
		poses.assign(b[key])
		if key.begins_with("glass_"):
			CityDistricts._batch_mesh(root, QuadMesh.new(), poses, materials[key])
		else:
			GameGeometry.batch_boxes(root, poses, materials[key])
		var node := root.get_child(root.get_child_count() - 1) as GeometryInstance3D
		node.visibility_range_end = 1000
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("tower_count", count)
