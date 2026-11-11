extends SceneTree
## Render inspection of the real car assembly at stationary wheel poses.

func _initialize() -> void:
	_run.call_deferred()

func capture(main: Node3D, filename: String, offset: Vector3) -> void:
	main.camera.global_position = main.car.global_position + main.car.global_basis * offset
	main.camera.look_at(main.car.global_position + Vector3.UP * 0.72)
	main.camera.fov = 45.0
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/" + filename)
	print("CAPTURE: ", filename)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.in_menu = false
	main.camera.set_physics_process(false)
	main.car.set_physics_process(false)
	main.ui.hide()
	main.car.visual.update_motion(Vector3.ZERO, 0.0, 0.0, false, 0.0)
	await capture(main, "car_rear.png", Vector3(4.8, 2.6, 6.6))
	await capture(main, "car_front.png", Vector3(-4.8, 2.2, -6.6))
	main.car.visual.update_motion(Vector3(0, 0, -15), 0.0, 1.0, false, 0.07)
	await capture(main, "car_steering.png", Vector3(-5.8, 1.6, -3.0))
	for i in 120:
		main.car.visual.update_body_attitude(Vector3(15, 0, 10), 1.0 / 60.0)
	await capture(main, "car_body_lean.png", Vector3(-5.8, 1.5, -3.0))
	main.queue_free()
	await process_frame
	quit()
