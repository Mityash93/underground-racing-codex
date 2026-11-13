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
	main.in_menu = false
	main.rival.set_physics_process(false)
	main.camera.set_physics_process(false)
	main.ui.hide()
	for shot in ["front", "rear", "steering"]:
		var offset := Vector3(-4.8, 2.2, -6.6) if shot == "front" else Vector3(4.8, 2.6, 6.6)
		if shot == "steering":
			main.car.visual.hide()
			for wheel in main.rival.visual.wheels:
				wheel.update_motion(0, 1.0, 0)
			offset = Vector3(3.0, 1.1, -4.3)
		main.camera.global_position = main.rival.global_position + main.rival.global_basis * offset
		main.camera.look_at(main.rival.global_position + Vector3.UP * 0.72)
		main.camera.fov = 45
		for i in 12:
			await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/artifacts/rival_" + shot + ".png")
		print("CAPTURE: rival_", shot)
	main.car.visual.show()
	main.rival.set_physics_process(true)
	main.ui.show()
	main.start_race()
	main.camera.set_physics_process(true)
	await create_timer(4.5).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/duel.png")
	main.queue_free()
	await process_frame
	quit()
