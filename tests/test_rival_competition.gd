extends SceneTree
## Physical difficulty ladder, moving overtakes and position defense. Run with --fixed-fps 60.
var main
var failures := 0
var checks := 0
var metrics: Array[Dictionary] = []
var started_at := Time.get_ticks_msec()
func _initialize() -> void:
	_run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_at > 150000:
		push_error("Competition tests exceeded wall time")
		quit(1)
	return false
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
func ticks(n: int) -> void:
	for i in n:
		await physics_frame
func start(level: int) -> void:
	main.show_menu()
	main.set_difficulty(level)
	main.start_race()
	await ticks(195)
func place(car: ArcadeCar, distance: float, lane: float, speed_kmh: float) -> void:
	var pose: Transform3D = main.track.transform_at(distance)
	pose.origin.y = 0.018
	pose.origin += pose.basis.x * lane
	car.park_at(pose)
	car.freeze = false
	car.controls_enabled = true
	car.linear_velocity = -pose.basis.z * speed_kmh / 3.6
func ahead_gap() -> float:
	var track: CityTrack = main.track
	return fposmod(track.nearest_distance(main.car.global_position) - track.nearest_distance(main.rival.global_position) + track.track_length / 2, track.track_length) - track.track_length / 2
func drive_reference(speed: float, lane: float) -> void:
	var car: ArcadeCar = main.car
	var track: CityTrack = main.track
	var distance := track.nearest_distance(car.global_position)
	var goal := track.transform_at(distance + 12 + car.speed_kmh * 0.13)
	var direction := (goal.origin + goal.basis.x * lane - car.global_position).normalized()
	var angle := (-car.global_basis.z).signed_angle_to(direction, Vector3.UP)
	car.set_drive_input(clampf((speed + 3 - car.speed_kmh) / 12, 0, 1), clampf((car.speed_kmh - speed) / 12, 0, 1), clampf(angle * 2.8, -1, 1))
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/competition_records.cfg"
	var driver: RivalDriver = main.rival.get_node("Driver")
	var original_physics: CarTuning = main.rival.tuning.duplicate()
	for level in 3:
		await start(level)
		# Same physical obstruction and same race rules on every level.
		var obstacle: Transform3D = main.track.transform_at(55)
		obstacle.origin.y = 0.018
		obstacle.origin += obstacle.basis.x * 3.2
		main.car.park_at(obstacle)
		var max_speed := 0.0
		var max_offset := 0.0
		var boost_ticks := 0
		var min_charge := 1.0
		for i in 12000:
			await physics_frame
			var distance: float = main.track.nearest_distance(main.rival.global_position)
			max_offset = maxf(max_offset, main.rival.global_position.distance_to(main.track.transform_at(distance).origin))
			max_speed = maxf(max_speed, main.rival.speed_kmh)
			min_charge = minf(min_charge, main.rival.nitro.charge)
			if main.rival.nitro.active:
				boost_ticks += 1
			if main.race.state == RaceManager.State.FINISHED:
				break
		var race: RaceManager = main.race.rival_race
		check(race.course_completed and race.lap_times.size() == 2, "level %d completes two physical ordered laps" % level)
		check(race.recoveries == 0 and max_offset < 11.5, "level %d stays on asphalt without recovery" % level)
		check(boost_ticks > 0 and min_charge < 0.9 if level == 2 else boost_ticks == 0, "level %d uses only its intended boost strategy" % level)
		check(is_equal_approx(main.rival.tuning.engine_acceleration, original_physics.engine_acceleration) and is_equal_approx(main.rival.tuning.lateral_grip, original_physics.lateral_grip) and is_equal_approx(main.rival.tuning.max_speed_kmh, original_physics.max_speed_kmh), "difficulty does not change physical engine/grip/speed limit")
		var result := {"level": level, "time": race.elapsed, "max_speed": max_speed, "max_offset": max_offset, "recoveries": race.recoveries, "boost_seconds": boost_ticks / 60.0}
		metrics.append(result)
		print("DIFFICULTY LAP: ", JSON.stringify(result))
	check(metrics[0].time > metrics[1].time * 1.05 and metrics[1].time > metrics[2].time * 1.05, "each next level is measurably faster over identical two-lap race")
	for level in 3:
		await start(level)
		main.car.external_driver = true
		place(main.rival, 0, 3.2, 80)
		driver.reset_driver()
		place(main.car, 35, 3.2, 80)
		var committed := false
		var passed := false
		var contacts := 0
		for i in 1800:
			drive_reference(82, 3.2)
			await physics_frame
			committed = committed or driver._passing
			if main.rival.get_colliding_bodies().has(main.car):
				contacts += 1
			if ahead_gap() < -12:
				passed = true
				break
		check(committed and passed, "level %d physically overtakes a moving car" % level)
		check(contacts == 0 and main.race.rival_race.recoveries == 0, "level %d completes moving pass without contact or recovery" % level)
		main.car.external_driver = false
	# Defensive maneuver starts with the player safely behind, and releases alongside.
	await start(2)
	main.car.external_driver = true
	place(main.rival, 80, 3.2, 100)
	driver.reset_driver()
	place(main.car, 58, 0, 140)
	var defended := false
	for i in 60:
		drive_reference(140, -3.8 if defended else 0.0)
		await physics_frame
		defended = defended or driver.defending
	check(defended, "hard rival makes an early defensive lane choice against closing player")
	await start(2)
	place(main.rival, 100, 3.2, 100)
	driver.reset_driver()
	place(main.car, 100, 0, 100)
	var cut_across := false
	for i in 60:
		drive_reference(100, 0)
		await physics_frame
		if absf(ahead_gap()) < 8:
			cut_across = cut_across or driver.defending
	check(not cut_across and not main.rival.get_colliding_bodies().has(main.car), "hard rival does not defensively cut across an already alongside car")
	main.car.external_driver = false
	main.show_menu()
	check(not main.rival.nitro.active and not driver.defending and not driver._passing, "menu clears boost and tactical state")
	FileAccess.open("res://tests/artifacts/rival_difficulty_report.json", FileAccess.WRITE).store_string(JSON.stringify(metrics, "  "))
	main.queue_free()
	await process_frame
	print("COMPETITION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
