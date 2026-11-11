class_name MusicManager
extends Node
## Separate from the car engine. Original bundled loop or a user-selected local file.

signal track_changed(title: String)
signal settings_changed(enabled: bool, volume: float)
signal load_failed(message: String)

const DEFAULT_TRACK := "res://assets/audio/neon_pulse.wav"
var enabled := true
var volume := 0.55
var track_title := "Неоновый пульс"
var current_source := DEFAULT_TRACK
var _racing := false
var _paused := false
var player: AudioStreamPlayer
var _picker: FileDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.volume_db = -80.0
	add_child(player)
	_picker = FileDialog.new()
	_picker.title = "Выбрать музыку"
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.ogg,*.mp3,*.wav; Музыка (OGG, MP3, WAV)"])
	_picker.file_selected.connect(load_custom_track)
	add_child(_picker)
	use_default_track()

func _loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	return stream

func _set_track(stream: AudioStream, title: String, source: String) -> void:
	player.stop()
	player.stream = _loop(stream)
	player.volume_db = -80.0
	track_title = title
	current_source = source
	if DisplayServer.get_name() != "headless":
		player.play()
	track_changed.emit(track_title)

func use_default_track() -> void:
	var stream := load(DEFAULT_TRACK) as AudioStream
	if stream != null:
		_set_track(stream.duplicate(), "Неоновый пульс", DEFAULT_TRACK)

func load_custom_track(path: String) -> bool:
	if not FileAccess.file_exists(path):
		load_failed.emit("Аудиофайл не найден. Текущий трек продолжает играть.")
		return false
	var stream: AudioStream
	match path.get_extension().to_lower():
		"ogg": stream = AudioStreamOggVorbis.load_from_file(path)
		"mp3": stream = AudioStreamMP3.load_from_file(path)
		"wav": stream = AudioStreamWAV.load_from_file(path)
	if stream == null or stream.get_length() < 0.1:
		load_failed.emit("Не удалось открыть музыку. Нужен файл OGG, MP3 или WAV.")
		return false
	_set_track(stream, path.get_file().get_basename(), path)
	return true

func choose_local_track() -> void:
	_picker.popup_centered_ratio(0.65)

func set_enabled(value: bool) -> void:
	enabled = value
	settings_changed.emit(enabled, volume)

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	settings_changed.emit(enabled, volume)

func set_context(racing: bool, paused: bool) -> void:
	_racing = racing
	_paused = paused

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mute_music"):
		set_enabled(not enabled)
	var context_gain := 0.45 if _paused else (1.0 if _racing else 0.72)
	var level := volume * 0.34 * context_gain if enabled else 0.0
	var desired_db := linear_to_db(level) if level > 0.0001 else -80.0
	player.volume_db = lerpf(player.volume_db, desired_db, 1.0 - exp(-5.0 * delta))
	player.stream_paused = player.volume_db < -78.0 and level < 0.0001

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
