extends SceneTree
## Real menu review and a physical moving pass in the normal chase camera.
var main
var started_at := Time.get_ticks_msec()
func _initialize() -> void:
	_run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_at > 90000:
		quit(1)
	return false
func capture(title: String) -> void:
	for i in 5:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/competition_" + title + ".png")
	print("CAPTURE: competition_", title)
func place(car: ArcadeCar, distance: float, speed: float) -> void:
	var pose: Transform3D = main.track.transform_at(distance)
	pose.origin.y = 0.018
	pose.origin += pose.basis.x * 3.2
	car.park_at(pose)
	car.freeze = false
	car.controls_enabled = true
	car.linear_velocity = -pose.basis.z * speed / 3.6
func _run() -> void:
	root.grab_focus()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/competition_preview.cfg"
	main.music.set_enabled(false)
	for level in 3:
		main.set_difficulty(level)
		await capture("menu_%d" % level)
	main.start_race()
	for i in 195:
		await physics_frame
	main.car.external_driver = true
	place(main.rival, 20, 100)
	(main.rival.get_node("Driver") as RivalDriver).reset_driver()
	place(main.car, 50, 85)
	main.camera.reset_camera()
	var shot := false
	var boost_shot := false
	for i in 720:
		var car: ArcadeCar = main.car
		var distance: float = main.track.nearest_distance(car.global_position)
		var goal: Transform3D = main.track.transform_at(distance + 12 + car.speed_kmh * 0.13)
		var angle := (-car.global_basis.z).signed_angle_to((goal.origin + goal.basis.x * 3.2 - car.global_position).normalized(), Vector3.UP)
		car.set_drive_input(clampf((85 + 3 - car.speed_kmh) / 12, 0, 1), clampf((car.speed_kmh - 85) / 12, 0, 1), clampf(angle * 2.8, -1, 1))
		await physics_frame
		var gap: float = main.track.nearest_distance(main.rival.global_position) - distance
		if not shot and gap > 7:
			await capture("moving_pass")
			shot = true
		if shot and not boost_shot and main.rival.nitro.active:
			await capture("rival_nitro")
			boost_shot = true
		if shot and boost_shot:
			break
	main.queue_free()
	await process_frame
	quit(0 if shot else 1)
