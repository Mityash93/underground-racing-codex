extends SceneTree
## End-to-end physical AI race plus input, pause, progress and restart checks.
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
func ticks(n: int) -> void:
	for i in n:
		await physics_frame
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/ignored_records.cfg"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			main.set_difficulty(int(argument.get_slice("=", 1)))
	await ticks(3)
	var rival: ArcadeCar = main.rival
	var race: RaceManager = main.race
	var driver: RivalDriver = rival.get_node("Driver")
	check(rival.freeze and not rival.controls_enabled and rival.external_driver, "independent opponent parked in menu")
	check(rival.appearance == 1 and rival.visual.wheels.size() == 4, "red sedan with four working wheels")
	# Keyboard actions must never supply AI controls.
	driver.set_physics_process(false)
	rival.controls_enabled = true
	Input.action_press("accelerate")
	Input.action_press("steer_left")
	await ticks(3)
	check(is_zero_approx(rival.throttle) and is_zero_approx(rival.steer), "player keys do not drive rival")
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	driver.set_physics_process(true)
	main.start_race()
	check(rival.freeze and main.car.freeze and race.rival_race.state == RaceManager.State.COUNTDOWN, "shared countdown freezes both cars")
	check(rival.global_position.distance_to(main.car.global_position) > 6.0, "side-by-side starting grid")
	await ticks(220)
	check(rival.controls_enabled and rival.speed_kmh > 5.0, "AI accelerates without keyboard input")
	main.toggle_pause()
	var before := rival.global_position
	var time := race.rival_race.elapsed
	await ticks(20)
	check(rival.global_position.is_equal_approx(before) and race.rival_race.elapsed == time, "pause freezes opponent and its clock")
	main.toggle_pause()
	main.start_race()
	check(race.rival_race.last_checkpoint == 0 and race.rival_race.lap == 1 and race.rival_race.lap_times.is_empty(), "restart resets rival progress")
	await ticks(190)
	# Put the waiting player directly into the AI lane to exercise a physical pass.
	var blocker: Transform3D = main.track.transform_at(55.0)
	blocker.origin += blocker.basis.x * 3.2
	main.car.park_at(blocker)
	var avoided := false
	var passed := false
	var max_error := 0.0
	var max_speed := 0.0
	for i in 12000:
		await physics_frame
		var distance: float = main.track.nearest_distance(rival.global_position)
		max_error = maxf(max_error, rival.global_position.distance_to(main.track.transform_at(distance).origin))
		avoided = avoided or driver.lane_offset < 1.0
		passed = passed or race.rival_race.last_checkpoint >= 1
		max_speed = maxf(max_speed, rival.speed_kmh)
		if race.state == RaceManager.State.FINISHED:
			break
	check(avoided and passed, "AI changes lane and passes a stationary car in its path")
	check(race.state == RaceManager.State.FINISHED and race.winner == "rival", "AI physically completes two laps and wins against waiting player")
	check(race.rival_race.course_completed and race.rival_race.lap_times.size() == 2, "AI passes all ordered checkpoints on both laps")
	check(race.rival_race.recoveries == 0 and max_error < 11.5, "AI stays on asphalt without recovery during the race and pass")
	check(race.player_position() == 2 and main.ui.results.visible and main.ui.result_title.text == "ВЕКТОР ПОБЕДИЛ", "loss screen works with zero completed player laps")
	check(rival.freeze and main.car.freeze, "finish stops both physical cars")
	print("AI RACE: %.2f s, max speed %.1f km/h, max road offset %.2f m, recoveries %d" % [race.rival_race.elapsed, max_speed, max_error, race.rival_race.recoveries])
	# Deterministically exercise the player's finish branch; driving itself is tested by drive_lap.gd.
	main.start_race()
	await ticks(190)
	for i in 24:
		race._accept_checkpoint()
	check(race.winner == "player" and race.player_position() == 1 and rival.freeze, "player finish awards victory and stops rival")
	main.start_race()
	await ticks(190)
	rival.global_position += Vector3.UP * 25.0
	await ticks(10)
	check(race.rival_race.recoveries == 1 and race.rival_race.lap == 1, "off-course recovery preserves rival checkpoint progress")
	main.show_menu()
	check(rival.freeze and race.rival_race.state == RaceManager.State.IDLE, "return to menu stops rival")
	print("RIVAL TESTS: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
