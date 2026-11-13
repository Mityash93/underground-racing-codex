extends SceneTree
## Native audio mixer recording; no music or external samples in the preview.
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func verify(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/audio_records.cfg"
	main.music.set_enabled(false)
	main.race.rival_enabled = false
	main.start_race()
	await create_timer(3.3).timeout
	var recording := AudioEffectRecord.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	var effect_slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recording)
	recording.set_recording_active(true)
	Input.action_press("accelerate")
	await create_timer(1.8).timeout
	Input.action_press("nitro")
	await create_timer(0.8).timeout
	verify(main.car.sound._nitro.playing and main.car.sound.nitro_level > 0.1, "native audio driver plays nitro loop")
	main.toggle_pause()
	await create_timer(0.25).timeout
	verify(main.car.sound._nitro.stream_paused and AudioServer.is_bus_mute(AudioServer.get_bus_index(main.car.sound.bus_name)), "real playing voice and bus pause together")
	main.toggle_pause()
	await create_timer(0.3).timeout
	verify(not main.car.sound._nitro.stream_paused, "real voice resumes after pause")
	Input.action_release("nitro")
	Input.action_press("handbrake")
	Input.action_press("steer_left", 0.7)
	await create_timer(0.8).timeout
	verify(main.car.sound._tires.playing and main.car.sound.tire_level > 0.01, "native audio driver plays physical tire skid")
	Input.action_release("handbrake")
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	var pose: Transform3D = main.track.transform_at(130)
	pose.origin.y = 0.15
	main.car.recover_to(pose)
	main.camera.reset_camera()
	await create_timer(0.5).timeout
	Input.action_press("accelerate")
	await create_timer(1.6).timeout
	Input.action_press("nitro")
	await create_timer(0.7).timeout
	verify(main.car.sound.tunnel_blend > 0.9 and main.car.sound._reverb.wet > 0.25, "native mixer enables tunnel reverb")
	Input.action_release("nitro")
	Input.action_release("accelerate")
	pose = main.track.transform_at(350)
	pose.origin.y = 0.15
	main.car.recover_to(pose)
	await create_timer(0.6).timeout
	var forward := -pose.basis.z
	var wall := GameGeometry.collider(main, Vector3(22, 4, 0.6), pose.origin + forward * 15 + Vector3.UP * 2, pose.basis.get_euler().y)
	main.car.linear_velocity = forward * 18.0
	var before: int = main.car.sound.impact_count
	await create_timer(1.5).timeout
	verify(main.car.sound.impact_count > before, "native mixer scenario produces real collision impact")
	await create_timer(0.4).timeout
	recording.set_recording_active(false)
	var sample := recording.get_recording()
	verify(sample != null and sample.data.size() > 10000, "AudioServer captured native mixed output")
	if sample != null:
		var peak := 0.0
		var energy := 0.0
		for i in sample.data.size() / 2:
			var value := sample.data.decode_s16(i * 2) / 32768.0
			peak = maxf(peak, absf(value))
			energy += value * value
		var rms := sqrt(energy / maxf(1, sample.data.size() / 2))
		verify(rms > 0.001 and peak < 0.98, "mixed preview is non-silent and has headroom")
		var path := "res://tests/artifacts/vehicle_audio_demo.wav"
		verify(sample.save_to_wav(path) == OK, "saved mixed engine/nitro/skid/tunnel/impact preview")
		var report := "Length %.2f s; mix rate %d Hz; stereo %s; peak %.4f; RMS %.4f\nNative mixer recording, music disabled, no subjective listening assessment.\n" % [sample.get_length(), sample.mix_rate, sample.stereo, peak, rms]
		print(report)
		FileAccess.open("res://tests/artifacts/vehicle_audio_report.txt", FileAccess.WRITE).store_string(report)
	AudioServer.remove_bus_effect(0, effect_slot)
	wall.queue_free()
	main.queue_free()
	await process_frame
	print("NATIVE AUDIO FAILURES: ", failures)
	quit(1 if failures else 0)
