class_name GameGeometry
extends RefCounted
## Small shared factory; all meshes and materials are original procedural assets.

static func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = at
	return node

static func collider(parent: Node3D, size: Vector3, at: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	body.position = at
	body.rotation.y = yaw
	return body

static func batch_boxes(parent: Node3D, transforms: Array[Transform3D], mat: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	parent.add_child(node)

static func box_transform(at: Vector3, size: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at)

static func hull(parent: Node3D, bottom_width: float, top_width: float, bottom_y: float,
		top_y: float, front_z: float, rear_z: float, top_front: float,
		top_rear: float, mat: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array([
		Vector3(-bottom_width, bottom_y, front_z), Vector3(bottom_width, bottom_y, front_z),
		Vector3(bottom_width, bottom_y, rear_z), Vector3(-bottom_width, bottom_y, rear_z),
		Vector3(-top_width, top_y, top_front), Vector3(top_width, top_y, top_front),
		Vector3(top_width, top_y, top_rear), Vector3(-top_width, top_y, top_rear)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]:
		for index in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			st.add_vertex(vertices[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	parent.add_child(node)
	return node
