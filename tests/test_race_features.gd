extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
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
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GameGeometry.collider(world, Vector3(10000, 2, 10000), Vector3(0, -1, 0))
	var boosted := ArcadeCar.new()
	var ordinary := ArcadeCar.new()
	ordinary.external_driver = true
	world.add_child(boosted)
	world.add_child(ordinary)
	boosted.position = Vector3(-10, 0.15, 0)
	ordinary.position = Vector3(10, 0.15, 0)
	boosted.controls_enabled = true
	ordinary.controls_enabled = true
	await ticks(60)
	check(InputMap.action_get_events("nitro")[0].physical_keycode == KEY_SHIFT, "Shift mapped to nitro")
	boosted.linear_velocity = Vector3(0, 0, -80.0 / 3.6)
	ordinary.linear_velocity = boosted.linear_velocity
	ordinary.set_drive_input(1, 0, 0)
	Input.action_press("accelerate")
	Input.action_press("nitro")
	await ticks(120)
	print("BOOST MEASURE: %.1f vs %.1f km/h after 2 s from 80 km/h" % [boosted.speed_kmh, ordinary.speed_kmh])
	check(boosted.nitro.active and boosted.speed_kmh > ordinary.speed_kmh + 25.0, "nitro adds real forward acceleration")
	check(boosted.nitro.charge > 0.50 and boosted.nitro.charge < 0.60, "reservoir consumes about two seconds of 4.5-second capacity")
	check(not ordinary.nitro.active and ordinary.nitro.charge == 1.0, "Shift never boosts external AI driver")
	ordinary.set_nitro_input(true)
	await ticks(60)
	check(ordinary.nitro.active and ordinary.nitro.charge < 0.80 and ordinary.nitro.charge > 0.70, "external driver's own command spends the same nitro reservoir")
	ordinary.controls_enabled = false
	var ai_charge := ordinary.nitro.charge
	await ticks(10)
	check(not ordinary.nitro.active and is_equal_approx(ai_charge, ordinary.nitro.charge), "disabled AI cannot consume or refill nitro")
	ordinary.park_at(Transform3D(Basis.IDENTITY, Vector3(10, 0, 0)))
	ordinary.freeze = false
	ordinary.controls_enabled = true
	ordinary.set_drive_input(1, 0, 0)
	await ticks(2)
	check(not ordinary.nitro.active and is_equal_approx(ordinary.nitro.charge, 1.0), "new grid clears AI boost command while player Shift remains held")
	await ticks(138)
	check(boosted.nitro.exhausted and not boosted.nitro.active and is_zero_approx(boosted.nitro.charge), "holding empty tank cannot restart boost")
	await ticks(150)
	check(is_zero_approx(boosted.nitro.charge), "empty held Shift cannot pulse or refill nitro")
	Input.action_release("nitro")
	await ticks(240)
	check(boosted.nitro.charge > 0.35 and not boosted.nitro.exhausted, "released nitro recharges")
	var charge := boosted.nitro.charge
	boosted.freeze = true
	await ticks(120)
	check(is_equal_approx(charge, boosted.nitro.charge), "frozen vehicle neither spends nor refills nitro")
	boosted.freeze = false
	Input.action_press("nitro")
	Input.action_press("brake")
	await ticks(2)
	check(not boosted.nitro.active, "brake blocks nitro")
	Input.action_release("brake")
	boosted.linear_velocity = Vector3(0, 0, 8)
	await ticks(2)
	check(not boosted.nitro.active, "reverse blocks nitro")
	boosted.global_position.y = 4
	boosted.linear_velocity = Vector3(0, 0, -20)
	await ticks(2)
	check(not boosted.nitro.active, "airborne car cannot boost")
	Input.action_release("nitro")
	boosted.nitro.charge = 0.3
	boosted.recover_to(Transform3D(Basis.IDENTITY, Vector3(-10, 0.15, 0)))
	await ticks(3)
	check(boosted.nitro.charge < 0.32, "recovery does not grant a fresh tank")
	boosted.park_at(Transform3D.IDENTITY)
	check(boosted.nitro.charge == 1.0 and not boosted.nitro.active, "new grid resets nitro")
	boosted.freeze = false
	boosted.controls_enabled = true
	boosted.linear_velocity = Vector3(9, 0, -20)
	Input.action_press("handbrake")
	Input.action_press("steer_left", 0.7)
	await ticks(45)
	check(boosted.tire_effects.segment_count > 0, "physical slide leaves rear tire marks")
	# Dummy headless renderer does not retain MultiMesh transforms. Check CPU contacts.
	var contacts: Array[Vector3] = boosted.tire_effects._previous
	check(contacts[0].y > 0.022 and contacts[1].y > 0.022, "skid contacts clear visible road above collision plane")
	check(boosted.tire_effects._marks.instance_count == TireEffects.MAX_SEGMENTS, "skid memory has fixed segment budget")
	Input.action_release("handbrake")
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	boosted.park_at(Transform3D.IDENTITY)
	check(boosted.tire_effects.segment_count == 0, "restart clears skid ring")
	world.queue_free()
	await process_frame
	_test_records()
	await _test_difficulty_and_ui()
	print("FEATURE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_records() -> void:
	var records := RaceRecords.new()
	records.path = "res://tests/artifacts/record_test_%d.cfg" % Time.get_ticks_usec()
	records.select_event(1, 2)
	var race := RaceManager.new()
	race.elapsed = 83.5
	race.best_lap = 41.5
	race.lap_times.assign([41.5, 42.0])
	records.record_finish(race)
	check(not FileAccess.file_exists(records.path), "incomplete race cannot create record")
	race.course_completed = true
	records.record_finish(race)
	check(records.new_record and not records.save_failed, "completed race writes personal best")
	var reloaded := RaceRecords.new()
	reloaded.path = records.path
	reloaded.select_event(1, 2)
	check(is_equal_approx(reloaded.best_time, 83.5) and is_equal_approx(reloaded.best_lap, 41.5), "best race and lap survive new instance")
	race.elapsed = 90.0
	reloaded.record_finish(race)
	check(not reloaded.new_record and reloaded.best_time == 83.5, "slower finish preserves personal best")
	race.elapsed = 82.0
	reloaded.record_finish(race)
	check(reloaded.new_record and reloaded.best_time == 82.0, "faster finish updates personal best")
	reloaded.select_event(2, 2)
	check(is_inf(reloaded.best_time), "difficulty records are separate")
	reloaded.select_event(1, 3)
	check(is_inf(reloaded.best_time), "lap-count records are separate")
	var bad := ConfigFile.new()
	bad.set_value(TrackLayout.RECORD_ID + "_nitro_v1_2_laps_1", "race", -1)
	bad.set_value(TrackLayout.RECORD_ID + "_nitro_v1_2_laps_1", "lap", "bad")
	bad.save(records.path)
	reloaded.select_event(1, 2)
	check(is_inf(reloaded.best_time) and is_inf(reloaded.best_lap), "invalid stored values do not become records")
	race.free()

func _test_difficulty_and_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/ignored_records.cfg"
	main.set_difficulty(0)
	var driver: RivalDriver = main.rival.get_node("Driver")
	check(driver.max_speed_kmh == 140.0 and main.ui.difficulty_select.selected == 0, "menu applies easy difficulty")
	main.set_difficulty(2)
	check(driver.max_speed_kmh == 210.0, "menu applies hard difficulty")
	main.start_race()
	main.set_difficulty(0)
	check(driver.difficulty == 2, "difficulty locked during race")
	await ticks(190)
	Input.action_press("accelerate")
	Input.action_press("nitro")
	await ticks(120)
	check(main.car.nitro.active and main.ui.nitro_bar.value < 1.0, "HUD displays physical nitro consumption")
	var amount: float = main.car.nitro.charge
	main.toggle_pause()
	await ticks(60)
	check(is_equal_approx(amount, main.car.nitro.charge), "pause freezes nitro reservoir")
	main.toggle_pause()
	Input.action_release("accelerate")
	Input.action_release("nitro")
	main.race._finish_race("rival")
	await ticks(2)
	check(not main.car.nitro.active and is_inf(main.records.best_time), "loss disables nitro and cannot set unfinished race record")
	main.start_race()
	check(main.car.nitro.charge == 1.0, "race restart restores full nitro")
	main.queue_free()
	await process_frame
