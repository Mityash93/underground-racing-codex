extends SceneTree
## Music integration and Russian UI smoke checks, without external files/services.
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
		push_error(description)

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var music: MusicManager = main.music
	# Explicitly test the bundled track even when this computer has a private startup selection.
	music.use_default_track()
	check(music.player.stream is AudioStreamWAV and music.player.stream.get_length() > 58.0, "original 58-second music asset loads")
	check(music.player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.player.stream.loop_end > 1200000, "bundled music loops across full arrangement")
	check(InputMap.has_action("mute_music"), "N music action exists")
	Input.action_press("mute_music")
	for i in 3:
		await process_frame
	Input.action_release("mute_music")
	check(not music.enabled, "N toggles music without changing car controls")
	music.set_enabled(true)
	var engine_muted: bool = main.car.engine.muted
	Input.action_press("mute_audio")
	for i in 3:
		await process_frame
	Input.action_release("mute_audio")
	check(music.enabled and main.car.engine.muted != engine_muted, "M engine mute is independent of music")
	music.set_volume(2.0)
	check(is_equal_approx(music.volume, 1.0), "music volume clamps at upper limit")
	music.set_volume(-1.0)
	check(is_zero_approx(music.volume), "music volume clamps at lower limit")
	music.set_volume(0.4)
	check(is_equal_approx(main.ui._music_volume.value, 40.0), "music volume updates visible slider")
	var custom_path := ProjectSettings.globalize_path(MusicManager.DEFAULT_TRACK)
	check(music.load_custom_track(custom_path) and music.current_source == custom_path, "local WAV loads without copying")
	var stream_before := music.player.stream
	check(not music.load_custom_track("res://README.md") and music.player.stream == stream_before, "unsupported local file preserves current track")
	check(not music.load_custom_track("res://tests/does_not_exist.mp3") and music.player.stream == stream_before, "missing track preserves current playback resource")
	music.use_default_track()
	check(music.current_source == MusicManager.DEFAULT_TRACK and music.track_title == "Неоновый пульс", "restore bundled track works")
	var russian_start := false
	var english_button := false
	for button in main.ui.find_children("*", "Button", true, false):
		russian_start = russian_start or button.text == "НАЧАТЬ ЗАЕЗД   →"
		english_button = english_button or button.text in ["START RACE", "QUIT", "RESUME", "MAIN MENU"]
	check(russian_start and not english_button, "Russian menu is active")
	main.start_race()
	for i in 190:
		await physics_frame
	main.toggle_pause()
	for i in 3:
		await process_frame
	check(main.ui._music_panel.visible and music.process_mode == Node.PROCESS_MODE_ALWAYS, "music controls remain usable on pause")
	main.toggle_pause()
	main.show_menu()
	main.queue_free()
	for i in 3:
		await process_frame
	print("MEDIA SUMMARY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
