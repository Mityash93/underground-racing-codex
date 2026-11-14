class_name CityDistricts
extends RefCounted
## Original district landmarks. Supports and walls remain outside the 24 m racing lane.

static func build(track: CityTrack) -> void:
	_tunnel(track)
	_industrial(track)
	_waterfront(track)
	_portal(track, track.anchor_distance(4) - 60, "ЗАРЕЧЬЕ  /  ПРОМЫШЛЕННЫЙ РАЙОН", TrackLayout.COLORS[1])
	_portal(track, track.anchor_distance(9) - 70, "ПОРТОВАЯ НАБЕРЕЖНАЯ", TrackLayout.COLORS[2])
	_portal(track, track.anchor_distance(14) - 40, "СТАРЫЙ ЦЕНТР  /  ФИНИШ ВПЕРЕДИ", TrackLayout.COLORS[0])
	for gap in [100.0, 50.0]:
		_roadside_sign(track, track.anchor_distance(7) - gap, "СВЯЗКА\nПОВОРОТОВ\n%d м" % gap, Color("ffc56a"))

static func _root(track: CityTrack, title: String, distance: float) -> Node3D:
	var node := Node3D.new()
	node.name = title
	track.add_child(node)
	node.transform = track.transform_at(distance)
	node.position.y = 0.0
	return node

static func _label(parent: Node3D, words: String, at: Vector3, color: Color, pixel_size: float = 0.012) -> Label3D:
	var text := Label3D.new()
	text.text = words
	text.position = at
	text.font_size = 64
	text.pixel_size = pixel_size
	text.modulate = color
	parent.add_child(text)
	return text

static func _tunnel(track: CityTrack) -> void:
	var length := TrackLayout.TUNNEL_END - TrackLayout.TUNNEL_START
	var tunnel := _root(track, "ImpulseTunnel", TrackLayout.TUNNEL_START)
	var shell := StreetShowcase.concrete_material()
	var dark := GameGeometry.material(Color("101d2a"))
	var warm := GameGeometry.material(Color("ffc37d"), 1.5)
	var cyan := GameGeometry.material(Color("39dcea"), 1.7)
	for side in [-1.0, 1.0]:
		GameGeometry.box(tunnel, Vector3(0.8, 8.0, length), Vector3(side * 14.0, 4.0, -length * 0.5), shell)
		GameGeometry.collider(tunnel, Vector3(0.8, 8.0, length), Vector3(side * 14.0, 4.0, -length * 0.5))
		GameGeometry.box(tunnel, Vector3(0.05, 0.12, length), Vector3(side * 13.56, 2.0, -length * 0.5), cyan)
	GameGeometry.box(tunnel, Vector3(28.8, 0.8, length), Vector3(0, 8.4, -length * 0.5), shell)
	var ceiling := GameGeometry.collider(tunnel, Vector3(28.8, 0.8, length), Vector3(0, 8.4, -length * 0.5))
	ceiling.name = "TunnelRoofCollision"
	var ribs: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	for z in range(0, int(length) + 1, 10):
		for side in [-1.0, 1.0]:
			ribs.append(GameGeometry.box_transform(Vector3(side * 13.5, 4, -z), Vector3(0.18, 8, 0.35)))
		ribs.append(GameGeometry.box_transform(Vector3(0, 7.9, -z), Vector3(27, 0.2, 0.35)))
		lights.append(GameGeometry.box_transform(Vector3(0, 7.74, -z), Vector3(4.5, 0.08, 0.35)))
	GameGeometry.batch_boxes(tunnel, ribs, dark)
	GameGeometry.batch_boxes(tunnel, lights, warm)
	for i in 5:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 6.5, -20.0 - i * 40.0)
		light.light_color = Color("ffcc92")
		light.light_energy = 2.7
		light.omni_range = 32.0
		light.shadow_enabled = false
		tunnel.add_child(light)
	_portal(track, TrackLayout.TUNNEL_START - 8, "ПОРТОВЫЙ ТОННЕЛЬ / 200 м", Color("ffc37d"))

static func _portal(track: CityTrack, distance: float, words: String, color: Color) -> void:
	var portal := _root(track, "DistrictPortal", distance)
	var dark := GameGeometry.material(Color("122333"))
	for side in [-1.0, 1.0]:
		GameGeometry.box(portal, Vector3(0.35, 8, 0.35), Vector3(side * 14.2, 4, 0), dark)
		GameGeometry.collider(portal, Vector3(0.35, 8, 0.35), Vector3(side * 14.2, 4, 0))
	GameGeometry.box(portal, Vector3(29, 1.7, 0.45), Vector3(0, 8.5, 0), dark)
	GameGeometry.box(portal, Vector3(29, 0.07, 0.5), Vector3(0, 7.62, 0), GameGeometry.material(color, 1.5))
	_label(portal, words, Vector3(0, 8.5, 0.24), color, 0.010)

static func _roadside_sign(track: CityTrack, distance: float, words: String, color: Color) -> void:
	var sign := _root(track, "CornerWarning", distance)
	var dark := GameGeometry.material(Color("12202a"))
	GameGeometry.box(sign, Vector3(6, 2.3, 0.2), Vector3(-16.5, 3.4, 0), dark)
	GameGeometry.box(sign, Vector3(0.12, 3.0, 0.12), Vector3(-16.5, 1.5, 0), dark)
	_label(sign, words, Vector3(-16.5, 3.4, 0.13), color, 0.012)

static func _industrial(track: CityTrack) -> void:
	var factory := _root(track, "IskraWorks", track.anchor_distance(5) + 40.0)
	var steel := GameGeometry.material(Color("a96533"))
	var dark := GameGeometry.material(Color("303b45"))
	var beams: Array[Transform3D] = []
	for x in [-64.0, -32.0]:
		for z in [-10.0, 10.0]:
			beams.append(GameGeometry.box_transform(Vector3(x, 10, z), Vector3(0.8, 20, 0.8)))
	for z in [-10.0, 10.0]:
		beams.append(GameGeometry.box_transform(Vector3(-48, 20.0, z), Vector3(40, 1.2, 1.2)))
		beams.append(GameGeometry.box_transform(Vector3(-48, 22.0, z), Vector3(40, 0.3, 0.3)))
	beams.append(GameGeometry.box_transform(Vector3(-48, 21, 0), Vector3(2, 2, 24)))
	beams.append(GameGeometry.box_transform(Vector3(-48, 13, 0), Vector3(0.15, 14, 0.15)))
	GameGeometry.batch_boxes(factory, beams, steel)
	var cylinders := CylinderMesh.new()
	cylinders.top_radius = 1.8
	cylinders.bottom_radius = 2.0
	cylinders.height = 26
	cylinders.radial_segments = 12
	var chimney_poses: Array[Transform3D] = []
	for x in [-38.0, -48.0, -58.0]:
		chimney_poses.append(Transform3D(Basis.IDENTITY, Vector3(x, 13, 38)))
	_batch_mesh(factory, cylinders, chimney_poses, dark)
	var containers := _root(track, "FreightYard", track.anchor_distance(6) + 35.0)
	var orange: Array[Transform3D] = []
	var blue: Array[Transform3D] = []
	for row in 3:
		for level in 2:
			var pose := GameGeometry.box_transform(Vector3(-32 - row * 8, 1.5 + level * 3.1, 0), Vector3(6, 3, 12))
			if (row + level) % 2 == 0:
				orange.append(pose)
			else:
				blue.append(pose)
	GameGeometry.batch_boxes(containers, orange, GameGeometry.material(Color("a85b35")))
	GameGeometry.batch_boxes(containers, blue, GameGeometry.material(Color("24516a")))
	_label(containers, "ЗАРЕЧЬЕ / ГРУЗОВОЙ ТЕРМИНАЛ", Vector3(-38, 7.5, 6.1), Color("ffc56a"))

static func _waterfront(track: CityTrack) -> void:
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for i in range(9 * CityTrack.SAMPLES_PER_CORNER, 14 * CityTrack.SAMPLES_PER_CORNER):
		var p := track.points[i]
		var q := track.points[i + 1]
		var forward := (q - p).normalized()
		var outside_a := -(q - track.points[i - 1]).normalized().cross(Vector3.UP)
		var outside_b := -(track.points[i + 2] - p).normalized().cross(Vector3.UP)
		var a := p + outside_a * HarborCoast.WATER_START + Vector3.UP * HarborCoast.WATER_Y
		var b := p + outside_a * HarborCoast.WATER_EXTENT + Vector3.UP * HarborCoast.WATER_Y
		var c := q + outside_b * HarborCoast.WATER_START + Vector3.UP * HarborCoast.WATER_Y
		var d := q + outside_b * HarborCoast.WATER_EXTENT + Vector3.UP * HarborCoast.WATER_Y
		for vertex in [a, b, c, b, d, c]:
			water.set_normal(Vector3.UP)
			water.add_vertex(vertex)
		var center := p.lerp(q, 0.5) + (outside_a + outside_b).normalized() * HarborCoast.SHORE_DISTANCE
		var yaw := atan2(-forward.x, -forward.z)
		var pier_entry := absf((track.distances[i] + track.distances[i + 1]) * 0.5 - track.anchor_distance(10) - 80) < 4 or absf((track.distances[i] + track.distances[i + 1]) * 0.5 - track.anchor_distance(12) - 80) < 4
		if not pier_entry:
			for height in [0.5, 1.05]:
				rails.append(GameGeometry.box_transform(center + Vector3.UP * height, Vector3(0.10, 0.09, p.distance_to(q) + 0.1), yaw))
		if i % 3 == 0:
			posts.append(GameGeometry.box_transform(p + outside_a * HarborCoast.SHORE_DISTANCE + Vector3.UP * 0.6, Vector3(0.15, 1.2, 0.15)))
	var surface := MeshInstance3D.new()
	surface.name = "NorthHarborWater"
	surface.mesh = water.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/harbor_water.gdshader")
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	track.add_child(surface)
	GameGeometry.batch_boxes(track, rails, GameGeometry.material(Color("879aa4")))
	GameGeometry.batch_boxes(track, posts, GameGeometry.material(Color("233f4a")))
	var beacon := _root(track, "HarborBeacon", track.anchor_distance(11) + 35)
	var lighthouse := CylinderMesh.new()
	lighthouse.top_radius = 2.3
	lighthouse.bottom_radius = 3.2
	lighthouse.height = 20
	lighthouse.radial_segments = 16
	_batch_mesh(beacon, lighthouse, [Transform3D(Basis.IDENTITY, Vector3(-72, 8, 0))], GameGeometry.material(Color("9fabb1")))
	var foundation := CylinderMesh.new()
	foundation.top_radius = 4.2
	foundation.bottom_radius = 4.7
	foundation.height = 1.4
	foundation.radial_segments = 20
	_batch_mesh(beacon, foundation, [Transform3D(Basis.IDENTITY, Vector3(-72, -1.4, 0))], StreetShowcase.concrete_material())
	GameGeometry.box(beacon, Vector3(6, 2.8, 6), Vector3(-72, 19, 0), GameGeometry.material(Color("41c8d9"), 0.8))
	GameGeometry.box(beacon, Vector3(7, 0.5, 7), Vector3(-72, 20.6, 0), GameGeometry.material(Color("24394d")))
	GameGeometry.box(beacon, Vector3(0.15, 1.5, 10), Vector3(-68.7, 12, 0), GameGeometry.material(Color("122333")))
	var sign := _label(beacon, "ГРУЗОВОЙ ПОРТ", Vector3(-68.6, 12, 0), Color("64c5ff"), 0.012)
	sign.rotation.y = PI / 2.0
	HarborPromenade.build(track)

static func _batch_mesh(parent: Node3D, mesh: Mesh, poses: Array[Transform3D], material: Material) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in poses.size():
		multi.set_instance_transform(i, poses[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	parent.add_child(node)
