extends SceneTree
## Rendered art review and physical two-car drive through the after-tunnel block.
var main
var started_at := Time.get_ticks_msec()
func _initialize() -> void:
	_run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_at > 100000:
		push_error("Quarter preview exceeded wall time")
		quit(1)
	return false
func photo(title: String, distance: float, offset: Vector3, focus: Vector3, show_car: bool = false) -> void:
	var pose: Transform3D = main.track.transform_at(distance)
	pose.origin.y = 0.018
	main.car.park_at(pose)
	main.car.visual.visible = show_car
	main.camera.global_position = pose.origin + pose.basis * offset
	main.camera.look_at(pose.origin + pose.basis * focus)
	main.camera.fov = 60
	for i in 10:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/quarter_" + title + ".png")
	print("CAPTURE: quarter_", title)
func _run() -> void:
	root.grab_focus()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/quarter_records.cfg"
	main.music.set_enabled(false)
	main.in_menu = false
	main.camera.set_physics_process(false)
	main.ui.hide()
	await photo("arrival", 310, Vector3(0, 3, 8), Vector3(0, 2.5, -32), true)
	await photo("cafe", 340, Vector3(-11, 2.1, 4), Vector3(-25, 2.1, -1))
	await photo("workshop", 424, Vector3(-11, 2.1, 4), Vector3(-25, 1.7, -1))
	await photo("street", 403, Vector3(1, 3, 8), Vector3(0, 3, -34), true)
	await photo("alley", 402, Vector3(-12, 2, 0), Vector3(-38, 2, 0))
	if "--views-only" in OS.get_cmdline_user_args():
		main.queue_free()
		await process_frame
		quit()
		return
	main.car.visual.show()
	main.ui.show()
	main.camera.set_physics_process(true)
	main.start_race()
	for i in 195:
		await physics_frame
	# Scoped drive, not a timed race: both cars spawn at 300 m after countdown.
	for car in [main.car, main.rival]:
		var pose: Transform3D = main.track.transform_at(300)
		pose.origin.y = 0.018
		pose.origin += pose.basis.x * (3.2 if car == main.rival else -3.2)
		car.park_at(pose)
		car.freeze = false
		car.controls_enabled = true
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	var distance := 300.0
	var start_time: float = main.race.elapsed
	while distance < 580 and main.race.elapsed - start_time < 30:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
		var car: ArcadeCar = main.car
		distance = main.track.nearest_distance(car.global_position)
		var goal: Vector3 = main.track.transform_at(distance + 12 + car.speed_kmh * 0.13).origin
		var angle := (-car.global_basis.z).signed_angle_to((goal - car.global_position).normalized(), Vector3.UP)
		Input.action_press("steer_left", clampf(angle * 2.5, 0, 1))
		Input.action_press("steer_right", clampf(-angle * 2.5, 0, 1))
		Input.action_press("accelerate", clampf((100 - car.speed_kmh) / 12, 0, 1))
	for action in ["accelerate", "steer_left", "steer_right"]:
		Input.action_release(action)
	var complete: bool = distance >= 580 and main.race.recoveries == 0 and main.race.rival_race.recoveries == 0
	samples.sort()
	var sum := 0.0
	for value in samples:
		sum += value
	var mean := sum / maxf(samples.size(), 1)
	var report := "Quarter physical drive, both cars spawned at 300 m, chase camera, no nitro.\nGPU: %s; window %s; completed %s; elapsed %.2f s; distance %.1f m; recoveries %d/%d\n%d frames; mean %.2f ms (%.1f FPS); P95 %.2f ms; >33.3 ms: %d\nTargeted automated preview, not a full-race performance guarantee.\n" % [RenderingServer.get_video_adapter_name(), root.size, complete, main.race.elapsed - start_time, distance, main.race.recoveries, main.race.rival_race.recoveries, samples.size(), mean, 1000 / mean, samples[int(samples.size() * 0.95)], samples.filter(func(v): return v > 33.3).size()]
	print(report)
	FileAccess.open("res://tests/artifacts/quarter_performance.txt", FileAccess.WRITE).store_string(report)
	main.queue_free()
	await process_frame
	quit(0 if complete else 1)
