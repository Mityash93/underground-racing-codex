extends SceneTree
## Integration checks against the actual downloaded local model, not a mock mesh.
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func bounds(model: Node3D, relative_to: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (relative_to.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	return combined

func verify_wheel_geometry(wheel: WheelVisual) -> void:
	var points: Array[Vector3] = []
	var face_counts := {}
	for mesh in wheel.roll.get_node("ImportedWheel").find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = wheel.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				points.append(local * vertex)
			if mesh.name == "Surface0":
				for normal in arrays[Mesh.ARRAY_NORMAL]:
					var n: Vector3 = (local.basis * normal).normalized()
					if n.x < 0:
						n = -n
					var key := Vector3i(roundi(n.x * 1000), roundi(n.y * 1000), roundi(n.z * 1000))
					face_counts[key] = face_counts.get(key, 0) + 1
	var dominant := Vector3i.ZERO
	var count := 0
	for key in face_counts:
		if face_counts[key] > count:
			count = face_counts[key]
			dominant = key
	check(count > 100 and dominant.x == 1000 and absi(dominant.y) <= 1 and absi(dominant.z) <= 1,
		"actual rim face is perpendicular to rolling axle: " + wheel.name)
	var lowest := INF
	var highest := -INF
	for phase in 24:
		var bottom := INF
		for point in points:
			bottom = minf(bottom, point.rotated(Vector3.RIGHT, TAU * phase / 24.0).y)
		lowest = minf(lowest, bottom)
		highest = maxf(highest, bottom)
	check(highest - lowest < 0.001 and absf(lowest + wheel.rolling_radius) < 0.001,
		"tire contact has no vertical wobble over full revolution: " + wheel.name)
func _run() -> void:
	var car: ArcadeCar = load("res://scenes/cars/player_car.tscn").instantiate()
	car.freeze = true
	root.add_child(car)
	await process_frame
	check(car.art_profile.available(), "local Audi resources are available")
	var body := car.visual.find_children("ImportedBody", "Node3D", true, false)
	check(body.size() == 1, "Audi replaces player shell")
	if body.is_empty():
		quit(1)
		return
	var box := bounds(body[0], car.visual)
	print("AUDI BODY BOUNDS: ", box)
	check(box.size.x < 2.3 and box.size.z < 4.7 and box.size.y < 1.8, "closed doors and hatch fit driving silhouette")
	check(body[0].find_children("JEREZ*", "Node3D", true, false).is_empty(), "body contains no duplicate rolling wheels")
	check(body[0].find_children("BRAKE*", "Node3D", true, false).is_empty(), "body contains no duplicate brakes")
	check(body[0].find_children("*AIRBAGS*", "Node3D", true, false).is_empty(), "airbag animation geometry removed")
	check(body[0].find_children("*", "AnimationPlayer", true, false).is_empty(), "door animations cannot reopen in race")
	check(car.visual.wheels.size() == 4, "four wheels mounted")
	check(not car.external_driver, "Audi remains keyboard-controlled player")
	for wheel in car.visual.wheels:
		verify_wheel_geometry(wheel)
		var tire := bounds(wheel.roll.get_node("ImportedWheel"), wheel)
		check(absf(tire.get_center().y) < 0.003 and absf(tire.get_center().z) < 0.003, "wheel geometry centred on rolling axle: " + wheel.name)
		check(absf(tire.size.y * 0.5 - car.visual.wheel_radius) < 0.003, "rolling radius matches tire: " + wheel.name)
		var fixed: Node3D = wheel.get_node("FixedBrake")
		var before := fixed.transform
		wheel.update_motion(8.0, 0.5, 0.1)
		check(fixed.transform.is_equal_approx(before) and not is_zero_approx(wheel.roll.rotation.x), "brake stays fixed while wheel rolls: " + wheel.name)
		check(is_equal_approx(wheel.rotation.y, 0.18 if wheel.is_front else 0.0), "front-only steering: " + wheel.name)
	var lights := body[0].find_children("BrakeLight*", "MeshInstance3D", true, false)
	check(lights.size() == 1, "rear light inserts identified")
	car.visual.update_motion(Vector3.ZERO, 0, 0, true, 0.1)
	for light in lights:
		check(is_equal_approx(light.get_active_material(0).emission_energy_multiplier, 5.0), "Audi brake light responds")
	car.park_at(Transform3D.IDENTITY)
	check(is_equal_approx(car.position.y + car.visual.wheel_y - car.visual.wheel_radius, 0.0), "recovery places tire contact at ground")
	car.queue_free()
	await process_frame
	var fallback: ArcadeCar = load("res://scenes/cars/player_car.tscn").instantiate()
	fallback.art_profile = VehicleArtProfile.new()
	fallback.art_profile.body_path = "res://missing_audi.gltf"
	fallback.freeze = true
	root.add_child(fallback)
	await process_frame
	check(fallback.visual.body_model == null and is_equal_approx(fallback.visual.wheel_y, CarVisual.WHEEL_Y), "missing local art preserves procedural car and calibration")
	fallback.queue_free()
	await process_frame
	print("AUDI ART SUMMARY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
