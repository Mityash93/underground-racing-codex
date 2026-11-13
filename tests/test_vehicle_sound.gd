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
func advance(sound: VehicleSound, n: int) -> void:
	for i in n:
		sound._process(1.0 / 60.0)
func _run() -> void:
	_test_bank()
	var initial_buses := AudioServer.bus_count
	var world := Node3D.new()
	root.add_child(world)
	GameGeometry.collider(world, Vector3(1000, 2, 1000), Vector3(0, -1, 0))
	var car := ArcadeCar.new()
	car.external_driver = true
	world.add_child(car)
	car.controls_enabled = true
	await ticks(60)
	var sound := car.sound
	check(sound.impact_count == 0, "settling on asphalt produces no repeated collision sounds")
	check(car.engine.bus == sound.bus_name and car.engine._load_layer.bus == sound.bus_name, "both engine layers share dedicated vehicle reverb bus")
	sound.set_process(false)
	car.grounded = true
	car.linear_velocity = Vector3(2.5, 0, -20)
	advance(sound, 60)
	var gentle := sound.tire_level
	car.linear_velocity = Vector3(10, 0, -20)
	advance(sound, 60)
	check(sound.tire_level > gentle + 0.4, "stronger lateral slip produces louder squeal")
	car.grounded = false
	advance(sound, 120)
	check(sound.tire_level < 0.001, "airborne wheels fade tire squeal to silence")
	car.nitro.active = true
	car.nitro.blend = 1.0
	advance(sound, 60)
	check(sound.nitro_level > 0.95 and sound.nitro_start_count == 1, "nitro attack and sustained hiss follow boost activation")
	advance(sound, 60)
	check(sound.nitro_start_count == 1, "held nitro does not retrigger attack every frame")
	car.nitro.active = false
	advance(sound, 90)
	check(sound.nitro_level < 0.001, "released nitro sound fades out")
	car.nitro.active = true
	advance(sound, 30)
	check(sound.nitro_start_count == 2, "new activation plays a new nitro attack")
	car.engine.muted = true
	advance(sound, 90)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.bus_name)) and sound.nitro_level < 0.001, "M mutes all vehicle effects along with engine")
	car.engine.muted = false
	advance(sound, 30)
	var before := sound.nitro_level
	paused = true
	advance(sound, 60)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.bus_name)) and sound.nitro_level == before, "pause silences bus and freezes sound state")
	paused = false
	advance(sound, 1)
	check(not sound._nitro.stream_paused and not AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.bus_name)), "resume restores vehicle bus and voices")
	car.nitro.active = false
	advance(sound, 90)
	var count := sound.impact_count
	sound.report_impact(0.7)
	check(sound.impact_count == count, "tiny contacts are below impact threshold")
	sound.report_impact(4.0)
	var quiet := sound.last_impact_db
	sound.report_impact(22.0)
	check(sound.impact_count == count + 1, "impact cooldown suppresses duplicate contact reports")
	advance(sound, 20)
	sound.report_impact(22.0)
	check(sound.last_impact_db > quiet + 10.0 and sound.last_impact_db <= -12.0, "impact strength controls bounded volume")
	sound.set_process(true)
	# Real contacts at four yaw angles catch incorrect local/world normal handling.
	for angle in [0.0, PI / 2.0, 1.1, PI]:
		var pose := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
		pose.origin.y = 0.15
		car.recover_to(pose)
		car.set_drive_input(0, 0, 0)
		await ticks(40)
		var forward := -pose.basis.z
		var wall := GameGeometry.collider(world, Vector3(24, 4, 0.6), forward * 15.0 + Vector3.UP * 2, angle)
		await ticks(3)
		var old_count := sound.impact_count
		car.linear_velocity = forward * 20.0
		await ticks(70)
		check(sound.impact_count > old_count, "physical wall impact detected at yaw %.2f" % angle)
		# A real bounce followed by acceleration can legitimately cause a second hit.
		car.set_drive_input(1, 0, 0)
		await ticks(90)
		var after_hit := sound.impact_count
		await ticks(120)
		check(sound.impact_count == after_hit, "pushing wall does not spam hits at yaw %.2f" % angle)
		wall.queue_free()
		await ticks(2)
	world.queue_free()
	await ticks(2)
	await _test_tunnel()
	await ticks(2)
	check(AudioServer.bus_count == initial_buses, "scene cleanup removes only its own sound buses")
	print("VEHICLE SOUND TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_bank() -> void:
	for kind in ["nitro_loop", "nitro_start", "tires", "impact"]:
		var sound := VehicleSoundBank.get_sound(kind)
		var peak := 0.0
		var energy := 0.0
		for i in sound.data.size() / 2:
			var value := sound.data.decode_s16(i * 2) / 32768.0
			peak = maxf(peak, absf(value))
			energy += value * value
		var rms := sqrt(energy / (sound.data.size() / 2))
		check(peak > 0.10 and peak < 0.96 and rms > 0.02, kind + " PCM is audible, bounded, nonempty")
		check(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size() - 2) == 0, kind + " endpoints have click-prevention ramps")
		check(sound == VehicleSoundBank.get_sound(kind), kind + " shares cached PCM between cars")
		check((sound.loop_mode != AudioStreamWAV.LOOP_DISABLED) == (kind in ["nitro_loop", "tires"]), kind + " loop/one-shot mode is correct")

func _test_tunnel() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.in_menu = false
	var car: ArcadeCar = main.car
	var sound := car.sound
	sound.set_process(false)
	car.controls_enabled = true
	car.freeze = false
	var pose: Transform3D = main.track.transform_at(170)
	car.global_transform = pose
	advance(sound, 90)
	check(sound.tunnel_blend > 0.98 and sound._reverb.wet > 0.27, "inside tunnel builds reverb for engine and effects")
	check(main.music.player.bus != sound.bus_name, "music stays outside vehicle reverb bus")
	car.global_transform = main.track.transform_at(310)
	advance(sound, 1)
	check(sound.tunnel_blend > 0.8 and sound.tunnel_blend < 1.0, "exit fades tunnel acoustics smoothly")
	advance(sound, 120)
	check(sound.tunnel_blend < 0.001, "open road returns to dry mix")
	car.global_transform = pose.translated(Vector3.UP * 12)
	check(sound.tunnel_amount() == 0.0, "above tunnel roof does not count as tunnel interior")
	car.global_transform = pose.translated(pose.basis.x * 30)
	check(sound.tunnel_amount() == 0.0, "beside tunnel does not count as tunnel interior")
	car.global_transform = pose
	advance(sound, 90)
	main.show_menu()
	check(sound.tunnel_blend == 0.0 and sound._reverb.wet == 0.0 and not sound._nitro.playing, "menu/reset clears voices and old reverb tail")
	main.queue_free()
	await process_frame
