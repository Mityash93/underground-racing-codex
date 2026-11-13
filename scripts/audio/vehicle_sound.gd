class_name VehicleSound
extends Node
## Per-car mix and tunnel reverb. Music never enters the vehicle buses.
var car: ArcadeCar
var track: CityTrack
var bus_name := ""
var tunnel_blend := 0.0
var nitro_level := 0.0
var tire_level := 0.0
var impact_count := 0
var nitro_start_count := 0
var last_impact_db := -80.0
var _reverb: AudioEffectReverb
var _nitro: AudioStreamPlayer
var _tires: AudioStreamPlayer
var _start: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _impact_cooldown := 0.0
var _start_cooldown := 0.0
var _suppress_contacts := 0.35
var _was_boosting := false
var _headless := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	car = get_parent() as ArcadeCar
	_headless = DisplayServer.get_name() == "headless"
	bus_name = "Vehicle_%d" % get_instance_id()
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	car.engine.set_output_bus(bus_name)
	_nitro = _player("nitro_loop")
	_tires = _player("tires")
	_start = _player("nitro_start")
	_impact = _player("impact")
	reset_sounds()

func _create_reverb() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if AudioServer.get_bus_effect_count(index) > 0:
		AudioServer.remove_bus_effect(index, 0)
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.8
	_reverb.damping = 0.55
	_reverb.predelay_msec = 65.0
	_reverb.dry = 1.0
	_reverb.wet = 0.0
	AudioServer.add_bus_effect(index, _reverb)
	AudioServer.set_bus_effect_enabled(index, 0, false)

func _player(kind: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = kind.to_pascal_case()
	player.stream = VehicleSoundBank.get_sound(kind)
	player.bus = bus_name
	player.volume_db = -80.0
	add_child(player)
	return player

func reset_sounds() -> void:
	nitro_level = 0.0
	tire_level = 0.0
	tunnel_blend = 0.0
	_was_boosting = false
	_impact_cooldown = 0.0
	_start_cooldown = 0.0
	_suppress_contacts = 0.35
	for player in [_nitro, _tires, _start, _impact]:
		player.stop()
		player.volume_db = -80.0
	# Replacing the effect clears delay buffers; a restart must not replay the old tail.
	_create_reverb()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name), true)

func _process(delta: float) -> void:
	var paused := get_tree().paused
	var running := car.controls_enabled and not car.freeze
	var silent := paused or not running or car.engine.muted
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, silent)
	for player in [_nitro, _tires, _start, _impact]:
		player.stream_paused = paused
	if paused:
		return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	_start_cooldown = maxf(0.0, _start_cooldown - delta)
	_suppress_contacts = maxf(0.0, _suppress_contacts - delta)
	var boost := running and not car.engine.muted and car.nitro.active
	if boost and not _was_boosting and _start_cooldown <= 0.0:
		nitro_start_count += 1
		_start.volume_db = maxf(-70.0, -23.0 + car.engine.volume_trim_db + car.tuning.effects_volume_db)
		_start.pitch_scale = 1.0
		if not _headless:
			_start.play()
		_start_cooldown = 0.3
	_was_boosting = boost
	var local_velocity := car.global_basis.inverse() * car.linear_velocity
	var slip := clampf((absf(local_velocity.x) - 1.4) / 7.0, 0.0, 1.0)
	var speed_factor := clampf((car.speed_kmh - 20.0) / 45.0, 0.0, 1.0)
	var sliding := running and car.grounded and not car.engine.muted
	var tire_target := maxf(slip, car.drift_blend * 0.22) * speed_factor if sliding else 0.0
	nitro_level = lerpf(nitro_level, car.nitro.blend if boost else 0.0, 1.0 - exp(-12.0 * delta))
	tire_level = lerpf(tire_level, tire_target, 1.0 - exp(-8.0 * delta))
	_loop(_nitro, nitro_level, -24.0, 1.0 + car.speed_kmh / 1200.0)
	_loop(_tires, tire_level, -25.0, clampf(0.85 + car.speed_kmh / 350.0, 0.85, 1.5))
	var target := tunnel_amount() if running else 0.0
	tunnel_blend = lerpf(tunnel_blend, target, 1.0 - exp(-3.5 * delta))
	_reverb.wet = tunnel_blend * car.tuning.tunnel_reverb_wet
	AudioServer.set_bus_effect_enabled(index, 0, tunnel_blend > 0.001)

func _loop(player: AudioStreamPlayer, intensity: float, base_db: float, pitch: float) -> void:
	player.pitch_scale = pitch
	player.volume_db = clampf(base_db + linear_to_db(maxf(intensity, 0.0001)) + car.engine.volume_trim_db + car.tuning.effects_volume_db, -80.0, -12.0)
	if not _headless:
		if intensity > 0.001 and not player.playing:
			player.play()
		elif intensity <= 0.001 and player.playing:
			player.stop()

func tunnel_amount() -> float:
	if not is_instance_valid(track):
		return 0.0
	var distance := track.nearest_distance(car.global_position)
	var local := track.transform_at(distance).affine_inverse() * car.global_position
	if absf(local.x) > 13.5 or local.y < -1.0 or local.y > 7.5:
		return 0.0
	return smoothstep(TrackLayout.TUNNEL_START - 5, TrackLayout.TUNNEL_START + 10, distance) * (1.0 - smoothstep(TrackLayout.TUNNEL_END - 10, TrackLayout.TUNNEL_END + 5, distance))

func report_impact(closing_speed: float) -> void:
	if _suppress_contacts > 0.0 or _impact_cooldown > 0.0 or get_tree().paused:
		return
	if not car.controls_enabled or car.freeze or car.engine.muted or closing_speed < car.tuning.impact_min_speed:
		return
	var strength := clampf((closing_speed - car.tuning.impact_min_speed) / 22.0, 0.0, 1.0)
	last_impact_db = clampf(lerpf(-32.0, -12.0, strength) + car.engine.volume_trim_db + car.tuning.effects_volume_db, -70.0, -12.0)
	_impact.volume_db = last_impact_db
	_impact.pitch_scale = lerpf(1.2, 0.8, strength)
	impact_count += 1
	_impact_cooldown = 0.22
	if not _headless:
		_impact.play()

func _exit_tree() -> void:
	for player in [_nitro, _tires, _start, _impact]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
