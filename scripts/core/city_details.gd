class_name CityDetails
extends RefCounted
## Batched streetscape beyond the barriers. All decorations stay outside the racing lane.

static func build(parent: Node3D, points: PackedVector3Array) -> void:
	var pavement := SurfaceTool.new()
	pavement.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pale_curbs: Array[Transform3D] = []
	var dark_curbs: Array[Transform3D] = []
	var joints: Array[Transform3D] = []
	for i in points.size():
		var next := (i + 1) % points.size()
		var direction := (points[next] - points[i]).normalized()
		var side_a := (points[next] - points[posmod(i - 1, points.size())]).normalized().cross(Vector3.UP)
		var side_b := (points[(i + 2) % points.size()] - points[i]).normalized().cross(Vector3.UP)
		var side := direction.cross(Vector3.UP)
		var center := (points[i] + points[next]) * 0.5
		var yaw := atan2(-direction.x, -direction.z)
		var length := points[i].distance_to(points[next])
		for sign_side in [-1.0, 1.0]:
			var a: Vector3 = points[i] + side_a * sign_side * 13.15 + Vector3.UP * 0.17
			var b: Vector3 = points[i] + side_a * sign_side * 20.5 + Vector3.UP * 0.17
			var c: Vector3 = points[next] + side_b * sign_side * 13.15 + Vector3.UP * 0.17
			var d: Vector3 = points[next] + side_b * sign_side * 20.5 + Vector3.UP * 0.17
			for vertex in [a, b, c, b, d, c]:
				pavement.set_normal(Vector3.UP)
				pavement.add_vertex(vertex)
			var curb := GameGeometry.box_transform(center + side * sign_side * 13.12 + Vector3.UP * 0.10, Vector3(0.25, 0.20, length + 0.1), yaw)
			if i % 2 == 0:
				pale_curbs.append(curb)
			else:
				dark_curbs.append(curb)
			if i % 2 == 0:
				joints.append(GameGeometry.box_transform(center + side * sign_side * 16.8 + Vector3.UP * 0.174, Vector3(7.2, 0.006, 0.045), yaw))
	var sidewalk := MeshInstance3D.new()
	sidewalk.name = "Sidewalks"
	sidewalk.mesh = pavement.commit()
	var mat := GameGeometry.material(Color("394654"))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sidewalk.material_override = mat
	parent.add_child(sidewalk)
	GameGeometry.batch_boxes(parent, pale_curbs, GameGeometry.material(Color("7f8991")))
	GameGeometry.batch_boxes(parent, dark_curbs, GameGeometry.material(Color("253343")))
	GameGeometry.batch_boxes(parent, joints, GameGeometry.material(Color("202c3b")))
	_turn_boards(parent, points)

static func _turn_boards(parent: Node3D, points: PackedVector3Array) -> void:
	var boards: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8, points.size(), 24):
		var direction := (points[(i + 1) % points.size()] - points[i]).normalized()
		var future := (points[(i + 13) % points.size()] - points[(i + 12) % points.size()]).normalized()
		var turn := direction.signed_angle_to(future, Vector3.UP)
		var right := direction.cross(Vector3.UP)
		var outside := 1.0 if turn > 0.0 else -1.0
		var yaw := atan2(-direction.x, -direction.z)
		var center := points[i] + right * outside * 16.2 + Vector3.UP * 2.3
		var pose := Transform3D(Basis(Vector3.UP, yaw), center)
		boards.append(GameGeometry.box_transform(center, Vector3(4.8, 1.45, 0.16), yaw))
		for x in [-1.7, 1.7]:
			poles.append(GameGeometry.box_transform(pose * Vector3(x, -1.05, 0), Vector3(0.10, 2.4, 0.10)))
		var arrow_sign := 1.0 if turn < 0.0 else -1.0
		for offset in [-1.4, 0.0, 1.4]:
			var upper := [Vector2(-0.5, 0.47), Vector2(-0.18, 0.47), Vector2(0.34, 0), Vector2(0.02, 0)]
			var lower := [Vector2(0.02, 0), Vector2(0.34, 0), Vector2(-0.18, -0.47), Vector2(-0.5, -0.47)]
			for quad in [upper, lower]:
				for index in [0, 1, 2, 0, 2, 3]:
					arrows.set_normal(pose.basis.z)
					arrows.add_vertex(pose * Vector3(offset + quad[index].x * arrow_sign, quad[index].y, 0.095))
	GameGeometry.batch_boxes(parent, boards, GameGeometry.material(Color("101c2a")))
	GameGeometry.batch_boxes(parent, poles, GameGeometry.material(Color("536477")))
	var mesh := MeshInstance3D.new()
	mesh.name = "TurnChevrons"
	mesh.mesh = arrows.commit()
	var luminous := GameGeometry.material(Color("ffc75c"), 1.3)
	luminous.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = luminous
	parent.add_child(mesh)
