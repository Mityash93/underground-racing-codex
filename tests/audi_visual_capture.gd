extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()
func _watchdog() -> void:
	await create_timer(90.0).timeout
	push_error("Visual capture timed out")
	quit(1)
func _run() -> void:
	root.grab_focus()
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/audi_menu.png")
	main.in_menu = false
	main.car.set_physics_process(false)
	main.camera.set_physics_process(false)
	main.ui.hide()
	for shot in ["front", "rear", "straight", "steering", "roll_0", "roll_1", "roll_2", "roll_3"]:
		for wheel in main.car.visual.wheels:
			wheel.roll_angle = 0
			wheel.update_motion(0, 0, 0)
		var offset := Vector3(-4.8, 2.2, -6.6) if shot == "front" else Vector3(4.8, 2.6, 6.6)
		if shot in ["straight", "steering"]:
			main.rival.visual.hide()
			for wheel in main.car.visual.wheels:
				wheel.update_motion(0, 1.0 if shot == "steering" else 0.0, 0)
			offset = Vector3(3.0, 1.1, -4.3)
		main.camera.global_position = main.car.global_position + main.car.global_basis * offset
		main.camera.look_at(main.car.global_position + Vector3.UP * 0.72)
		main.camera.fov = 45
		if shot.begins_with("roll_"):
			var phase := int(shot.get_slice("_", 1))
			for wheel in main.car.visual.wheels:
				wheel.roll_angle = -PI * 0.5 * phase
				wheel.update_motion(0, 0, 0)
			var focus: Vector3 = main.car.global_transform * main.car.visual.wheels[2].position
			main.camera.global_position = focus + main.car.global_basis * Vector3(2.5, 0.2, -0.35)
			main.camera.look_at(focus)
			main.camera.fov = 35
		for i in 12:
			await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/artifacts/audi_" + shot + ".png")
		print("CAPTURE: audi_", shot)
	main.rival.visual.show()
	main.car.set_physics_process(true)
	main.ui.show()
	main.start_race()
	main.camera.set_physics_process(true)
	await create_timer(4.5).timeout
	Input.action_press("accelerate")
	await create_timer(2.0).timeout
	Input.action_release("accelerate")
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/audi_duel.png")
	main.queue_free()
	await process_frame
	quit()
