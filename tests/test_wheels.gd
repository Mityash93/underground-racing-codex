extends SceneTree
## Regression: wheel rolling must not yaw the tire, separate the rim or move its center.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _run() -> void:
	var visual := CarVisual.new()
	root.add_child(visual)
	check(visual.wheels.size() == 4, "four complete wheel assemblies")
	var valid_axes := true
	var fixed_centers := true
	var shared_roller := true
	for wheel in visual.wheels:
		var center := wheel.position
		for i in 900:
			wheel.update_motion(28.0, sin(i * 0.03), 1.0 / 60.0)
			valid_axes = valid_axes and wheel.roll.basis.x.is_equal_approx(Vector3.RIGHT)
			fixed_centers = fixed_centers and wheel.position.is_equal_approx(center)
		for child in wheel.roll.get_children():
			shared_roller = shared_roller and child is MeshInstance3D
		shared_roller = shared_roller and wheel.roll.get_node("Tire").get_parent() == wheel.roll.get_node("RimFace").get_parent()
		check(absf(wheel.position.x) + WheelVisual.WIDTH / 2.0 < 1.0, "%s tire fits neutral fender width" % wheel.name)
	check(valid_axes, "rolling stays on local X axle while steering")
	check(fixed_centers, "no wheel-center movement after 900 rolling/steering updates")
	check(shared_roller, "tires, rims and spokes roll as one assembly")
	var wheel := visual.wheels[0]
	wheel.roll_angle = 0.0
	wheel.update_motion(10.0, 0.0, 0.01)
	check(is_equal_approx(wheel.roll_angle, -10.0 * 0.01 / WheelVisual.RADIUS), "forward rolling angle equals distance / radius")
	wheel.update_motion(-10.0, 0.0, 0.01)
	check(is_zero_approx(wheel.roll_angle), "reverse rolls back in opposite direction")
	visual.update_motion(Vector3.ZERO, 0.0, 0.8, false, 0.1)
	check(is_equal_approx(visual.wheels[0].rotation.y, 0.8 * 0.36) and is_zero_approx(visual.wheels[1].rotation.y), "only front assemblies steer")
	check(CarVisual.arch_height(CarVisual.FRONT_AXLE_Z) > CarVisual.WHEEL_Y + WheelVisual.RADIUS + 0.04, "wheel arches clear tire crown")
	check(is_equal_approx(CarVisual.WHEEL_Y - WheelVisual.RADIUS, 0.05), "tire contact matches chassis collider bottom")
	var wheel_center := visual.wheels[0].global_position
	for i in 180:
		visual.update_body_attitude(Vector3(12, 0, -6), 1.0 / 60.0)
	check(visual.body_pose.rotation.x > 0.01 and visual.body_pose.rotation.z > 0.02, "body leans outward and pitches up under acceleration")
	check(visual.wheels[0].global_position.is_equal_approx(wheel_center), "body spring cannot move wheel contact points")
	for i in 180:
		visual.update_body_attitude(Vector3.ZERO, 1.0 / 60.0)
	check(visual.body_pose.rotation.length() < 0.0001, "body spring settles without residual wobble")
	var intersections := 0
	for pose in [Vector3.ZERO, Vector3(0.021, 0, 0.038), Vector3(-0.021, 0, 0.038), Vector3(0.021, 0, -0.038), Vector3(-0.021, 0, -0.038)]:
		visual.body_pose.rotation = pose
		for steering in [-1.0, 0.0, 1.0]:
			visual.update_motion(Vector3.ZERO, 0.0, steering, false, 0.0)
			intersections += _tire_intersections(visual)
	check(intersections == 0, "coachwork vertices clear tire volume across full steering and body-lean poses (%d intersections)" % intersections)
	visual.queue_free()
	await process_frame
	print("WHEEL TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)

func _tire_intersections(visual: CarVisual) -> int:
	var count := 0
	for mesh in visual.body_pose.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh is ArrayMesh:
			continue
		for wheel in visual.wheels:
			var relative: Transform3D = wheel.global_transform.affine_inverse() * mesh.global_transform
			for surface_index in mesh.mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var at := relative * vertex
					if absf(at.x) < WheelVisual.WIDTH / 2.0 - 0.006 and Vector2(at.y, at.z).length() < WheelVisual.RADIUS - 0.006:
						if count == 0:
							print("CLEARANCE: ", mesh.name, " / ", wheel.name, " / ", at)
						count += 1
	return count
