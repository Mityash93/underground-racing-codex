extends SceneTree
## Test-only keyboard-action driver; follows road center without teleportation.
var main

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/ignored_records.cfg"
	main.race.rival_enabled = false
	main.start_race()
	for i in 190:
		await physics_frame
	var max_error := 0.0
	for i in 18000:
		await physics_frame
		var car: ArcadeCar = main.car
		var track: CityTrack = main.track
		var nearest := track.nearest_distance(car.global_position)
		var road := track.transform_at(nearest)
		var error := car.global_position.distance_to(road.origin)
		max_error = maxf(max_error, error)
		var ahead := track.transform_at(nearest + 12.0 + car.speed_kmh * 0.13).origin
		var desired := (ahead - car.global_position).normalized()
		var forward := -car.global_basis.z
		var angle := forward.signed_angle_to(desired, Vector3.UP)
		Input.action_press("steer_left", clampf(angle * 2.5, 0, 1))
		Input.action_press("steer_right", clampf(-angle * 2.5, 0, 1))
		if car.speed_kmh < 118:
			Input.action_press("accelerate", clampf((123.0 - car.speed_kmh) / 10.0, 0, 1))
			Input.action_release("brake")
		else:
			Input.action_release("accelerate")
			Input.action_press("brake", clampf((car.speed_kmh - 123.0) / 10.0, 0, 1))
		if main.race.state == RaceManager.State.FINISHED:
			print("FULL DRIVE PASS: 2 physical laps, %.2f s; max centerline distance %.2f m; recoveries %d; track length %.1f m" % [main.race.elapsed, max_error, main.race.recoveries, track.track_length])
			quit(0)
			return
		if error > 16.0:
			push_error("Driver left road at %.1f m, speed %.1f, offset %.1f" % [nearest, car.speed_kmh, error])
			quit(1)
			return
	push_error("Driver did not finish within 300 simulated seconds. Next checkpoint: %d" % main.race.next_checkpoint)
	quit(1)
