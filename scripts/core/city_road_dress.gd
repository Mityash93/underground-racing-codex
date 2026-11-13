class_name CityRoadDress
extends RefCounted
## Flat road details and sidewalk shelters; racing surface and route are unchanged.
static func build(track: CityTrack) -> void:
	var root := Node3D.new()
	root.name = "RoadDress"
	track.add_child(root)
	var b := {}
	var covers: Array[Transform3D] = []
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrow_count := 0
	for index in range(0, track.points.size(), 3):
		var distance := track.distances[index]
		var p := track.transform_at(distance)
		p.origin.y = 0
		var turn := (-p.basis.z).signed_angle_to(-track.transform_at(distance + 28).basis.z, Vector3.UP)
		if absf(turn) > 0.10:
			var side := -1.0 if turn > 0 else 1.0
			var key := "red" if index % 2 else "ivory"
			_put(b, key, p, Vector3(side * 11.45, 0.047, 0), Vector3(0.7, 0.018, 2.6))
		if index % 12 == 0:
			for side in [-1.0, 1.0]:
				_put(b, "metal", p, Vector3(side * 11.6, 0.039, 0), Vector3(0.5, 0.015, 1.0))
		if index % 24 == 0 and not track.in_tunnel(distance):
			covers.append(p * Transform3D(Basis.IDENTITY, Vector3(-5.2, 0.031, -5)))
		if index % 30 == 0 and absf(turn) < 0.06 and not track.in_tunnel(distance):
			for lane in [-5.2, 5.2]:
				for triangle in [[Vector2(-0.14, 2), Vector2(0.14, 2), Vector2(0.14, -1)], [Vector2(-0.14, 2), Vector2(0.14, -1), Vector2(-0.14, -1)], [Vector2(-0.8, -0.6), Vector2(0.8, -0.6), Vector2(0, -2.2)]]:
					for vertex in triangle:
						arrows.set_normal(Vector3.UP)
						arrows.add_vertex(p * Vector3(lane + vertex.x, 0.045, vertex.y))
				arrow_count += 1
	for distance in [360.0, 550.0, 1180.0, 1740.0, 2150.0]:
		var p := track.transform_at(distance)
		p.origin.y = 0
		_shelter(b, p)
	var materials := {"red": GameGeometry.material(Color("9b4539")), "ivory": GameGeometry.material(Color("adafa4")),
		"metal": GameGeometry.material(Color("303b43")), "concrete": StreetShowcase.concrete_material(),
		"glass": GameGeometry.material(Color("314b57")), "warm": GameGeometry.material(Color("dcb882"), 0.45)}
	for key in b:
		var poses: Array[Transform3D] = []
		poses.assign(b[key])
		GameGeometry.batch_boxes(root, poses, materials[key])
	var lid := CylinderMesh.new()
	lid.top_radius = 0.48
	lid.bottom_radius = 0.48
	lid.height = 0.012
	lid.radial_segments = 20
	CityDistricts._batch_mesh(root, lid, covers, materials["metal"])
	if arrow_count > 0:
		var mesh := MeshInstance3D.new()
		mesh.name = "LaneArrows"
		mesh.mesh = arrows.commit()
		var paint: StandardMaterial3D = materials["ivory"].duplicate()
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = paint
		root.add_child(mesh)

static func _put(b: Dictionary, key: String, p: Transform3D, at: Vector3, size: Vector3) -> void:
	StreetShowcase._put(b, key, p, at, size)

static func _shelter(b: Dictionary, p: Transform3D) -> void:
	_put(b, "concrete", p, Vector3(18.3, 0.3, 0), Vector3(3.5, 0.24, 8))
	_put(b, "metal", p, Vector3(18.3, 3.2, 0), Vector3(3.7, 0.18, 8.2))
	_put(b, "glass", p, Vector3(19.8, 1.8, 0), Vector3(0.08, 2.7, 7.6))
	for z in [-3.7, 0.0, 3.7]:
		_put(b, "metal", p, Vector3(19.7, 1.8, z), Vector3(0.10, 2.9, 0.10))
	_put(b, "metal", p, Vector3(19.2, 0.8, 0), Vector3(0.8, 0.12, 5.8))
	_put(b, "warm", p, Vector3(18.3, 3.08, 0), Vector3(0.15, 0.03, 6.8))
	_put(b, "metal", p, Vector3(16.5, 2.2, -4.5), Vector3(0.10, 4, 0.10))
	_put(b, "glass", p, Vector3(16.5, 3.5, -4.5), Vector3(0.12, 1.1, 0.9))
