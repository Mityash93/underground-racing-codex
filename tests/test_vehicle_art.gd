extends SceneTree
## Authoring-scene override integration: body/wheels/materials must preserve gameplay contracts.
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _fixture(body: bool) -> PackedScene:
	var root_node := Node3D.new()
	var mesh := GameGeometry.box(root_node, Vector3(0.6, 0.2, 0.6), Vector3.UP if body else Vector3.ZERO, GameGeometry.material(Color.WHITE))
	mesh.name = "BrakeLights" if body else "RimAndTire"
	mesh.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	root_node.free()
	return packed

func _run() -> void:
	var body := _fixture(true)
	var wheels := _fixture(false)
	var car: ArcadeCar = load("res://scenes/cars/player_car.tscn").instantiate()
	car.body_model = body
	car.wheel_model = wheels
	car.body_model_scale = 1.2
	car.body_model_offset = Vector3(0, 0.1, 0)
	car.freeze = true
	root.add_child(car)
	await process_frame
	var imported := car.visual.find_children("ImportedBody", "Node3D", true, false)
	check(imported.size() == 1 and car.visual.find_children("TRocWhiteBody", "MeshInstance3D", true, false).is_empty(), "authored body replaces procedural shell")
	var model: Node3D = imported[0]
	check(model.scale.is_equal_approx(Vector3.ONE * 1.2) and is_equal_approx(model.position.y, 0.1), "authored body calibration is applied")
	var wheel_art := true
	for wheel in car.visual.wheels:
		wheel_art = wheel_art and wheel.roll.has_node("ImportedWheel")
	check(wheel_art, "authored wheels mount on all four rolling axles")
	car.visual.update_motion(Vector3(0, 0, -10), 0, 0.5, true, 0.1)
	check(car.visual.wheels[0].roll.rotation.x < 0 and car.visual.wheels[0].rotation.y > 0, "authored wheels roll and steer through existing controller")
	var brake: MeshInstance3D = model.get_node("BrakeLights")
	check(brake.material_override.emission_enabled and is_equal_approx(brake.material_override.emission_energy_multiplier, 5.0), "authored brake materials respond to braking")
	car.visual.update_motion(Vector3.ZERO, 0, 0, false, 0.1)
	check(is_equal_approx(brake.material_override.emission_energy_multiplier, 1.5), "authored brake lights return to tail-light intensity")
	check(is_equal_approx(car.mass, 1250.0) and car.get_children().any(func(node): return node is CollisionShape3D), "art override preserves rigid body and collider")
	var original := body.instantiate()
	var original_brake: MeshInstance3D = original.get_node("BrakeLights")
	check(not original_brake.material_override.emission_enabled, "authored source material is not mutated by brake animation")
	original.free()
	car.queue_free()
	await process_frame
	print("VEHICLE ART SUMMARY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
