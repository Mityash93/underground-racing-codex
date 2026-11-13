class_name EngineAudio
extends AudioStreamPlayer
## Two original seamless engine layers, driven by a hysteretic virtual gearbox.

const RATIOS := [3.2, 2.1, 1.5, 1.12, 0.89]
var car: ArcadeCar
var muted := false
var current_gear := 1
var engine_rpm := 900.0
var volume_trim_db := 0.0
var _shift_cooldown := 0.0
var _load_layer: AudioStreamPlayer

func _ready() -> void:
	stream = _make_loop(false)
	volume_db = -80.0
	_load_layer = AudioStreamPlayer.new()
	_load_layer.stream = _make_loop(true)
	_load_layer.volume_db = -80.0
	add_child(_load_layer)
	if DisplayServer.get_name() != "headless":
		play()
		_load_layer.play()

func _make_loop(loaded: bool) -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(rate * 2)
	for i in rate:
		var phase := TAU * 60.0 * i / rate
		var wave := sin(phase) * 0.48 + sin(phase * 2.0) * 0.18 + sin(phase * 3.0) * 0.09
		if loaded:
			wave += sin(phase * 4.0) * 0.11 + sin(phase * 6.0) * 0.07 + sin(phase * 8.0) * 0.035
		wave *= 0.87 + 0.13 * sin(TAU * 30.0 * i / rate)
		samples.encode_s16(i * 2, int(wave * 22000))
	var loop := AudioStreamWAV.new()
	loop.format = AudioStreamWAV.FORMAT_16_BITS
	loop.mix_rate = rate
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = rate
	loop.data = samples
	return loop

func set_output_bus(output: String) -> void:
	bus = output
	_load_layer.bus = output

func reset_engine() -> void:
	current_gear = 1
	engine_rpm = 900.0
	_shift_cooldown = 0.0

func update_engine(speed_kmh: float, throttle: float, driving: bool, delta: float) -> void:
	_shift_cooldown = maxf(0.0, _shift_cooldown - delta)
	var wheel_rpm := absf(speed_kmh) / 3.6 / (TAU * WheelVisual.RADIUS) * 60.0
	var coupled_rpm: float = wheel_rpm * RATIOS[current_gear - 1] * 3.8
	if driving and _shift_cooldown <= 0.0:
		if coupled_rpm > 5900.0 and current_gear < RATIOS.size():
			current_gear += 1
			_shift_cooldown = 0.22
		elif current_gear > 1:
			var lower_gear_rpm: float = wheel_rpm * RATIOS[current_gear - 2] * 3.8
			if coupled_rpm < 2700.0 and lower_gear_rpm < 5100.0:
				current_gear -= 1
				_shift_cooldown = 0.25
	coupled_rpm = wheel_rpm * RATIOS[current_gear - 1] * 3.8
	var desired_rpm := clampf(maxf(900.0 + throttle * 650.0, coupled_rpm + throttle * 180.0), 900.0, 6800.0)
	engine_rpm = lerpf(engine_rpm, desired_rpm, 1.0 - exp(-10.0 * delta))
	pitch_scale = clampf(engine_rpm / 1800.0, 0.5, 3.8)
	_load_layer.pitch_scale = pitch_scale
	var audible := driving and not muted
	var shift_cut := 5.0 if _shift_cooldown > 0.10 else 0.0
	var idle_db := maxf(-80.0, -29.0 - shift_cut + volume_trim_db) if audible else -80.0
	var load_db := maxf(-80.0, -38.0 + throttle * 15.0 - shift_cut + volume_trim_db) if audible else -80.0
	volume_db = lerpf(volume_db, idle_db, 1.0 - exp(-10.0 * delta))
	_load_layer.volume_db = lerpf(_load_layer.volume_db, load_db, 1.0 - exp(-10.0 * delta))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mute_audio"):
		muted = not muted
	if is_instance_valid(car):
		update_engine(car.speed_kmh, car.throttle, car.controls_enabled, delta)

func _exit_tree() -> void:
	stop()
	stream = null
	if is_instance_valid(_load_layer):
		_load_layer.stop()
		_load_layer.stream = null
