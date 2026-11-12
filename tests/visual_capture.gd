extends SceneTree
## Engine-level rendered smoke run, without OS input automation.
## Writes real viewport captures and frame timings into tests/artifacts.

func _initialize() -> void:
	_run.call_deferred()

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/" + filename)
	print("CAPTURE: ", filename)

func wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/ignored_records.cfg"
	await wait_frames(90)
	await capture("menu.png")
	main.start_race()
	await create_timer(3.5).timeout
	await capture("race.png")
	Input.action_press("accelerate")
	await create_timer(2.2).timeout
	Input.action_press("steer_right")
	await create_timer(0.45).timeout
	Input.action_release("steer_right")
	Input.action_release("accelerate")
	await capture("driving.png")
	Input.action_press("accelerate")
	Input.action_press("steer_left", 0.65)
	Input.action_press("handbrake")
	await create_timer(0.7).timeout
	await capture("drift.png")
	Input.action_release("handbrake")
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	Input.action_press("brake")
	await create_timer(0.35).timeout
	await capture("braking.png")
	Input.action_release("brake")
	main.toggle_pause()
	await wait_frames(5)
	await capture("pause.png")
	main.toggle_pause()
	main.race.recover()
	await wait_frames(20)
	# Measure a fixed race view after warmup, at actual wall-clock frame intervals.
	var samples: Array[float] = []
	for i in 180:
		var started := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	var sum := 0.0
	for sample in samples:
		sum += sample
	var average := sum / samples.size()
	var report := "GPU: %s\nWindow: %s\nFrames: %d\nAverage: %.2f ms (%.1f FPS)\nP95: %.2f ms\nScope: stationary start grid, after warmup; not a full-lap performance guarantee.\n" % [RenderingServer.get_video_adapter_name(), root.size, samples.size(), average, 1000.0 / average, samples[int(samples.size() * 0.95)]]
	FileAccess.open("res://tests/artifacts/performance_%dx%d.txt" % [root.size.x, root.size.y], FileAccess.WRITE).store_string(report)
	print(report)
	main.car.freeze = true
	for lap_index in 2:
		for gate_index in 12:
			var gate: Transform3D = main.track.checkpoints[main.race.next_checkpoint]
			main.car.global_position = gate.origin + gate.basis.z * 2.0
			main.race._previous_position = main.car.global_position
			main.race._check_gate()
			main.car.global_position = gate.origin - gate.basis.z * 2.0
			main.race._check_gate()
	await wait_frames(5)
	await capture("results.png")
	main.show_menu()
	await wait_frames(5)
	quit()
