extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/" + name + ".png")
	print("CAPTURE: ", name)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/visual_records.cfg"
	main.set_difficulty(0)
	await create_timer(0.8).timeout
	await capture("features_menu")
	main.start_race()
	await create_timer(3.2).timeout
	Input.action_press("accelerate")
	await create_timer(2.0).timeout
	Input.action_press("nitro")
	await create_timer(1.0).timeout
	await capture("nitro")
	Input.action_release("nitro")
	Input.action_press("handbrake")
	Input.action_press("steer_left", 0.6)
	await create_timer(0.6).timeout
	await capture("tire_effects")
	main.toggle_pause()
	main.ui.hide()
	var saved_transform: Transform3D = main.camera.global_transform
	main.camera.global_position = main.car.global_position + main.car.global_basis * Vector3(4, 3.5, 6)
	main.camera.look_at(main.car.global_position - main.car.global_basis.z * -2.5)
	await capture("tire_marks_close")
	main.ui.show()
	main.camera.global_transform = saved_transform
	main.toggle_pause()
	var samples: Array[float] = []
	for i in 120:
		var started := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	Input.action_release("handbrake")
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	samples.sort()
	var sum := 0.0
	for time in samples:
		sum += time
	var average := sum / samples.size()
	var report := "Window: %s; GPU: %s\n120 frames during short drift near start; two cars and tire effects.\nMean %.2f ms (%.1f FPS); P95 %.2f ms. Not a full-lap guarantee.\n" % [root.size, RenderingServer.get_video_adapter_name(), average, 1000.0 / average, samples[114]]
	print(report)
	FileAccess.open("res://tests/artifacts/features_performance.txt", FileAccess.WRITE).store_string(report)
	main.toggle_pause()
	await capture("features_pause")
	main.toggle_pause()
	# Synthetic finish tests record UI; timings are not real driven records.
	main.car.freeze = true
	main.race.elapsed = 85.0
	for i in 24:
		main.race.lap_time = 42.5
		main.race._accept_checkpoint()
	await capture("features_results")
	main.queue_free()
	await process_frame
	quit()
