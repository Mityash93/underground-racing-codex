extends SceneTree
## Real Metal views, followed by a physical full-lap render profile using keyboard actions.
var main
func _initialize() -> void:
	_run.call_deferred()
func capture(title: String) -> void:
	for i in 5:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/track_" + title + ".png")
	print("CAPTURE: track_", title)
func park(distance: float) -> void:
	var pose: Transform3D = main.track.transform_at(distance)
	pose.origin.y = 0.018
	main.car.park_at(pose)
func viewpoint(offset: Vector3, focus: Vector3) -> void:
	main.camera.global_position = main.car.global_position + main.car.global_basis * offset
	main.camera.look_at(main.car.global_position + main.car.global_basis * focus)
	main.camera.fov = 65.0
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/track_visual_records.cfg"
	main.in_menu = false
	main.camera.set_physics_process(false)
	main.ui.hide()
	main.camera.far = 2000
	main.camera.global_position = Vector3(0, 850, 560)
	main.camera.look_at(Vector3(0, 0, 30))
	main.camera.fov = 62
	await capture("overview")
	main.camera.far = 1100
	park(145)
	viewpoint(Vector3(3, 3.4, 9), Vector3(0, 1.8, -18))
	await capture("tunnel")
	park(main.track.anchor_distance(5) + 5)
	viewpoint(Vector3(5, 6, 15), Vector3(-16, 6, -35))
	await capture("industry")
	park(main.track.anchor_distance(8))
	main.camera.global_position = main.car.global_position + Vector3(85, 140, 100)
	main.camera.look_at(main.car.global_position)
	await capture("wave")
	park(main.track.anchor_distance(11))
	viewpoint(Vector3(10, 7, 20), Vector3(-25, 3, -40))
	await capture("waterfront")
	if "--views-only" in OS.get_cmdline_user_args():
		main.queue_free()
		await process_frame
		quit()
		return
	# Solo profiling keeps an AI finish from cutting the measured circuit short.
	# Independent two-car racing is covered by test_rival on all three difficulty levels.
	main.ui.show()
	main.race.rival_enabled = false
	main.race.total_laps = 1
	main.start_race()
	for i in 190:
		await physics_frame
	var samples: Array[float] = []
	var sectors: Array[Array] = [[], [], []]
	var last_time := Time.get_ticks_usec()
	var maximum_error := 0.0
	var last_lap := 0.0
	while main.race.state != RaceManager.State.FINISHED and main.race.elapsed < 160.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_time := (now - last_time) / 1000.0
		last_time = now
		samples.append(frame_time)
		var car: ArcadeCar = main.car
		var track: CityTrack = main.track
		var distance := track.nearest_distance(car.global_position)
		sectors[track.district_at(distance)].append(frame_time)
		maximum_error = maxf(maximum_error, car.global_position.distance_to(track.transform_at(distance).origin))
		var ahead := track.transform_at(distance + 12.0 + car.speed_kmh * 0.13).origin
		var angle := (-car.global_basis.z).signed_angle_to((ahead - car.global_position).normalized(), Vector3.UP)
		Input.action_press("steer_left", clampf(angle * 2.5, 0, 1))
		Input.action_press("steer_right", clampf(-angle * 2.5, 0, 1))
		if car.speed_kmh < 118:
			Input.action_press("accelerate", clampf((123.0 - car.speed_kmh) / 10.0, 0, 1))
			Input.action_release("brake")
		else:
			Input.action_release("accelerate")
			Input.action_press("brake", clampf((car.speed_kmh - 123.0) / 10.0, 0, 1))
		if main.race.elapsed - last_lap > 15.0:
			last_lap = main.race.elapsed
			print("PROFILE: %.0f s / %.0f m / %s" % [main.race.elapsed, distance, track.section_name(distance)])
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)
	var complete: bool = main.race.course_completed and main.race.recoveries == 0
	var report := "GPU: %s; window: %s\nPhysical player lap, no nitro, solo (rival parked), normal following camera.\nCompleted: %s; lap %.2f s; track %.2f m; max offset %.2f m; recoveries %d\n" % [RenderingServer.get_video_adapter_name(), root.size, complete, main.race.elapsed, main.track.track_length, maximum_error, main.race.recoveries]
	report += summarize(samples) + "\n"
	for i in 3:
		report += TrackLayout.NAMES[i] + ": " + summarize(sectors[i]) + "\n"
	report += "Single automated run; not a guarantee for all races, devices or displays.\n"
	print(report)
	FileAccess.open("res://tests/artifacts/track_full_lap_performance.txt", FileAccess.WRITE).store_string(report)
	await capture("finish")
	main.queue_free()
	await process_frame
	quit(0 if complete else 1)
func summarize(values: Array) -> String:
	if values.is_empty():
		return "no frames"
	values.sort()
	var sum := 0.0
	for sample in values:
		sum += sample
	var mean := sum / values.size()
	return "%d frames; mean %.2f ms (%.1f FPS); P95 %.2f ms; >33.3 ms: %d" % [values.size(), mean, 1000.0 / mean, values[int(values.size() * 0.95)], values.filter(func(value): return value > 33.3).size()]
