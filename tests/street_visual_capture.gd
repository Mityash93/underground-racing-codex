extends SceneTree
## Fixed comparison cameras plus an actual two-car drive through the detailed street/tunnel.
var main
var label := "after"
var _started_at := Time.get_ticks_msec()
func _initialize() -> void:
	_run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started_at > 90000:
		push_error("Street preview exceeded 90 seconds of wall time")
		quit(1)
	return false
func photo(name: String, distance: float, offset: Vector3, focus: Vector3) -> void:
	var pose: Transform3D = main.track.transform_at(distance)
	pose.origin.y = 0.018
	pose.origin -= pose.basis.x * 3.2
	main.car.park_at(pose)
	main.camera.global_position = main.car.global_position + pose.basis * offset
	main.camera.look_at(main.car.global_position + pose.basis * focus)
	main.camera.fov = 62
	for i in 12:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/street_%s_%s.png" % [label, name])
	print("CAPTURE: ", label, " ", name)
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	root.grab_focus()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/street_preview_records.cfg"
	main.music.set_enabled(false)
	main.in_menu = false
	main.camera.set_physics_process(false)
	main.ui.hide()
	await photo("start", 0, Vector3(1, 3.5, 9), Vector3(0, 1.4, -20))
	await photo("shops", -40, Vector3(-1, 3.7, 6), Vector3(9, 4, -24))
	await photo("entrance", 42, Vector3(0, 3.2, 8), Vector3(0, 2.6, -22))
	await photo("tunnel", 145, Vector3(3, 3.4, 9), Vector3(0, 1.8, -18))
	if "--views-only" in OS.get_cmdline_user_args():
		main.queue_free()
		await process_frame
		quit()
		return
	main.ui.show()
	main.in_menu = true
	main.set_difficulty(0)
	main.start_race()
	for i in 190:
		await physics_frame
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	var distance := 0.0
	while distance < 340.0 and main.race.elapsed < 30.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
		var car: ArcadeCar = main.car
		distance = main.track.nearest_distance(car.global_position)
		if distance > main.track.track_length - 20.0:
			distance -= main.track.track_length
		var goal: Vector3 = main.track.transform_at(distance + 12.0 + car.speed_kmh * 0.13).origin
		var angle := (-car.global_basis.z).signed_angle_to((goal - car.global_position).normalized(), Vector3.UP)
		Input.action_press("steer_left", clampf(angle * 2.5, 0, 1))
		Input.action_press("steer_right", clampf(-angle * 2.5, 0, 1))
		Input.action_press("accelerate", clampf((140.0 - car.speed_kmh) / 12.0, 0, 1))
		if distance > 20 and distance < 190 and car.nitro.charge > 0.02:
			Input.action_press("nitro")
		else:
			Input.action_release("nitro")
	for action in ["accelerate", "steer_left", "steer_right", "nitro"]:
		Input.action_release(action)
	samples.sort()
	var sum := 0.0
	for sample in samples:
		sum += sample
	var mean := sum / maxf(1, samples.size())
	var complete: bool = distance >= 340 and main.race.elapsed > 6.0 and samples.size() > 100 and main.race.recoveries == 0 and main.race.rival_race.recoveries == 0
	var report := "Label: %s; GPU: %s; window: %s\nTwo physical cars, normal chase camera, nitro, street and tunnel, audio active.\nCompleted 340 m: %s; elapsed %.2f s; distance %.1f m; player/rival recoveries %d/%d\n%d frames; mean %.2f ms (%.1f FPS); P95 %.2f ms; >33.3 ms: %d\nShort scripted drive, not a full-race or hardware-independent guarantee.\n" % [label, RenderingServer.get_video_adapter_name(), root.size, complete, main.race.elapsed, distance, main.race.recoveries, main.race.rival_race.recoveries, samples.size(), mean, 1000.0 / mean, samples[int(samples.size() * 0.95)], samples.filter(func(value): return value > 33.3).size()]
	print(report)
	FileAccess.open("res://tests/artifacts/street_%s_performance.txt" % label, FileAccess.WRITE).store_string(report)
	main.queue_free()
	await process_frame
	quit(0 if complete else 1)
