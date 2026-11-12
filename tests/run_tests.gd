extends SceneTree
## Behavioral integration tests. No external framework or downloaded dependency.

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/ignored_records.cfg"
	await ticks(3)
	check(main.in_menu and main.ui.menu.visible, "main scene opens in menu")
	check(main.track.points.size() == TrackLayout.ANCHORS.size() * CityTrack.SAMPLES_PER_CORNER and main.track.track_length > 2400, "new closed circuit > 2.4 km")
	check(main.track.checkpoints.size() == 12, "12 sequential checkpoint transforms")
	check(main.car.freeze and not main.car.controls_enabled, "car cannot drive through menu")
	check(is_equal_approx(main.car.position.y + CarVisual.WHEEL_Y - WheelVisual.RADIUS, 0.018), "parked tires touch asphalt instead of floating")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "recover", "camera_view", "pause", "mute_audio"]:
		check(InputMap.has_action(action) and InputMap.action_get_events(action).size() > 0, "input map: " + action)
	main.start_race()
	check(main.race.state == RaceManager.State.COUNTDOWN, "start enters countdown")
	await ticks(190)
	check(main.race.state == RaceManager.State.RUNNING and main.car.controls_enabled, "countdown enables driving")
	var camera_mode: bool = main.camera.close_view
	Input.action_press("camera_view")
	await ticks(2)
	Input.action_release("camera_view")
	check(main.camera.close_view != camera_mode, "C switches chase-camera distance")
	main.camera.reset_camera()
	await ticks(2)
	var camera_distance: float = main.camera.global_position.distance_to(main.car.global_position)
	var obstruction := GameGeometry.collider(main, Vector3(8, 5, 0.3), main.car.global_transform * Vector3(0, 2, 3.7), main.car.rotation.y)
	await ticks(4)
	check(main.camera.global_position.distance_to(main.car.global_position) < camera_distance - 1.0, "camera volume retracts before a wall")
	obstruction.queue_free()
	await ticks(2)
	main.toggle_pause()
	var time_before: float = main.race.elapsed
	await ticks(10)
	check(paused and main.race.elapsed == time_before, "pause freezes race timer")
	main.toggle_pause()
	# Out-of-order and backwards crossings must not count.
	var race: RaceManager = main.race
	var first_gate: Transform3D = main.track.checkpoints[1]
	main.car.freeze = true
	race._previous_position = first_gate.origin - first_gate.basis.z * 2.0
	main.car.global_position = first_gate.origin + first_gate.basis.z * 2.0
	race._check_gate()
	check(race.next_checkpoint == 1, "backwards crossing rejected")
	var wrong_gate: Transform3D = main.track.checkpoints[4]
	race._previous_position = wrong_gate.origin + wrong_gate.basis.z * 2.0
	main.car.global_position = wrong_gate.origin - wrong_gate.basis.z * 2.0
	race._check_gate()
	check(race.next_checkpoint == 1, "out-of-order gate rejected")
	# Exercise geometric plane-crossing logic at each gate for two laps.
	for lap_index in 2:
		for gate_index in 12:
			var gate: Transform3D = main.track.checkpoints[race.next_checkpoint]
			main.car.global_position = gate.origin + gate.basis.z * 2.0
			race._previous_position = main.car.global_position
			race._check_gate()
			main.car.global_position = gate.origin - gate.basis.z * 2.0
			race._check_gate()
	check(race.state == RaceManager.State.FINISHED and race.lap_times.size() == 2, "two ordered laps produce finish/results")
	check(main.ui.results.visible, "finish displays results panel")
	main.start_race()
	await ticks(190)
	var before_recovery: float = race.elapsed
	race.recover()
	await ticks(3)
	check(race.recoveries == 1 and race.elapsed >= before_recovery + 5.0, "recovery adds five-second penalty")
	check(main.car.global_position.distance_to(main.track.checkpoints[0].origin) < 6, "recovery returns to last accepted gate")
	main.show_menu()
	check(main.ui.menu.visible and not paused, "return to menu restores interactive state")
	main.queue_free()
	await ticks(3)
	await _test_vehicle()
	print("TEST SUMMARY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_vehicle() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GameGeometry.collider(world, Vector3(20000, 2, 20000), Vector3(0, -1, 0))
	var car: ArcadeCar = load("res://scenes/cars/player_car.tscn").instantiate()
	world.add_child(car)
	car.position = Vector3(0, 0.2, 0)
	car.controls_enabled = true
	await ticks(60)
	check(car.grounded and absf(car.position.y) < 0.2, "vehicle rests on physical ground")
	var engine: EngineAudio
	for child in car.get_children():
		if child is EngineAudio:
			engine = child
	check(engine != null and engine.stream is AudioStreamWAV and engine.stream.data.size() == 44100, "original engine audio loop is generated")
	Input.action_press("accelerate")
	var zero_to_hundred := -1.0
	for i in 540:
		await physics_frame
		if car.speed_kmh >= 100 and zero_to_hundred < 0:
			zero_to_hundred = (i + 1) / 60.0
	print("MEASURE: 0–100 km/h = %.2f s, speed after 9s = %.1f km/h" % [zero_to_hundred, car.speed_kmh])
	check(zero_to_hundred >= 4.5 and zero_to_hundred <= 7.0, "arcade acceleration meets 5–7 second target approximately")
	check(car.global_position.z < -100 and car.global_basis.y.y > 0.95, "forward motion stays stable")
	await ticks(2400)
	print("MEASURE: terminal speed = %.2f km/h" % car.speed_kmh)
	check(car.speed_kmh > 200 and car.speed_kmh < car.tuning.max_speed_kmh + 1.0, "terminal speed in 200–225 km/h range")
	Input.action_release("accelerate")
	Input.action_press("brake")
	await ticks(420)
	check(car.linear_velocity.dot(-car.global_basis.z) < -2 and car.speed_kmh < 40, "S brakes and engages limited reverse")
	Input.action_release("brake")
	car.recover_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)))
	await ticks(15)
	Input.action_press("accelerate")
	await ticks(180)
	Input.action_press("steer_left")
	await ticks(55)
	check((-car.global_basis.z).x < -0.3, "left steering rotates car to the left")
	Input.action_release("steer_left")
	Input.action_press("handbrake")
	await ticks(3)
	check(car.handbrake, "handbrake input engages drift mode")
	check(car.drift_blend > 0.0 and car.drift_blend < 0.5, "drift grip enters progressively")
	await ticks(30)
	car.linear_velocity += car.global_basis.x * 8.0
	Input.action_release("handbrake")
	await ticks(3)
	check(car.drift_blend > 0.8 and car.drift_blend < 1.0, "releasing handbrake restores grip progressively")
	await ticks(90)
	check(is_zero_approx(car.drift_blend) and absf(car.linear_velocity.dot(car.global_basis.x)) < 0.8, "released slide recovers lateral grip")
	Input.action_release("accelerate")
	engine.set_process(false)
	engine.reset_engine()
	for i in 60:
		engine.update_engine(95.0, 1.0, true, 1.0 / 60.0)
	check(engine.current_gear == 2 and engine.engine_rpm > 3000, "engine upshifts and maintains coupled RPM")
	for i in 120:
		engine.update_engine(94.0 + sin(i) * 2.0, 0.4, true, 1.0 / 60.0)
	check(engine.current_gear == 2, "gear hysteresis prevents hunting at steady speed")
	engine.muted = true
	engine.update_engine(94.0, 1.0, true, 0.7)
	check(engine.volume_db < -79.0, "mute fades engine layer to silence")
	# Drive directly into a physical wall.
	car.controls_enabled = false
	car.recover_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)))
	await ticks(15)
	GameGeometry.collider(world, Vector3(18, 4, 1), Vector3(0, 2, -18))
	car.linear_velocity = Vector3(0, 0, -32)
	await ticks(60)
	check(car.global_position.z > -17.0 and car.linear_velocity.z > -5.0, "collision wall blocks car at speed")
	car.transform = Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0, 2, 0))
	car.recover_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)))
	await ticks(20)
	check(car.global_basis.y.y > 0.99 and car.linear_velocity.length() < 1.0, "recovery clears inverted orientation and momentum")
	world.queue_free()
	await ticks(3)
