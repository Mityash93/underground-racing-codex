extends SceneTree
## Local-only media check. The private recording/config are intentionally not distributed.
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
	if not FileAccess.file_exists(MusicManager.LOCAL_CONFIG):
		print("SKIP: no private startup music configured on this computer")
		quit()
		return
	var music := MusicManager.new()
	root.add_child(music)
	await process_frame
	var config := ConfigFile.new()
	config.load(MusicManager.LOCAL_CONFIG)
	check(music.current_source == str(config.get_value("music", "path", "")), "private startup recording is selected automatically")
	check(music.player.stream is AudioStreamMP3, "Desktop MP3 is decoded by Godot")
	check(music.player.stream.loop and music.player.stream.get_length() > 60.0, "local recording has valid duration and looping")
	check(music.track_title == str(config.get_value("music", "title", "")), "private track title is displayed")
	print("LOCAL MP3 DURATION: %.2f s" % music.player.stream.get_length())
	music.use_default_track()
	check(music.current_source == MusicManager.DEFAULT_TRACK, "bundled track remains available")
	music.queue_free()
	await process_frame
	print("LOCAL MUSIC SUMMARY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
