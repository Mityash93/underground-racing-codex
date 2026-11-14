extends Node3D

@onready var track: CityTrack = $NeonDistrict
@onready var car: ArcadeCar = $PlayerCar
@onready var rival: ArcadeCar = $RivalCar
@onready var camera: ChaseCamera = $ChaseCamera
@onready var race: RaceManager = $RaceManager
@onready var ui: GameUI = $GameUI
var in_menu := true
var _orbit := 0.4
var _gate_marker: Node3D
var records := RaceRecords.new()
var difficulty := RivalDriver.Difficulty.MEDIUM
var music: MusicManager

func _ready() -> void:
	_build_environment()
	music = MusicManager.new()
	music.name = "Music"
	add_child(music)
	ui.music_toggled.connect(music.set_enabled)
	ui.music_volume_changed.connect(music.set_volume)
	ui.custom_music_requested.connect(music.choose_local_track)
	ui.default_music_requested.connect(music.use_default_track)
	music.track_changed.connect(ui.set_music_title)
	music.settings_changed.connect(ui.set_music_settings)
	music.load_failed.connect(ui.set_music_title)
	ui.set_music_title(music.track_title)
	ui.set_music_settings(music.enabled, music.volume)
	camera.target = car
	race.track = track
	race.car = car
	race.configure_rival(rival)
	var driver: RivalDriver = rival.get_node("Driver")
	driver.track = track
	driver.other_car = car
	car.sound.track = track
	rival.sound.track = track
	rival.engine.volume_trim_db = -14.0
	ui.minimap.rival = rival
	ui.minimap.track = track
	ui.minimap.car = car
	ui.minimap.race = race
	ui.difficulty_changed.connect(set_difficulty)
	ui.start_requested.connect(start_race)
	ui.restart_requested.connect(start_race)
	ui.pause_requested.connect(toggle_pause)
	ui.resume_requested.connect(toggle_pause)
	ui.menu_requested.connect(show_menu)
	car.recovery_requested.connect(race.recover)
	race.race_finished.connect(_on_race_finished)
	race.checkpoint_passed.connect(_update_gate_marker)
	_build_gate_marker()
	show_menu()
	if "--smoke-race" in OS.get_cmdline_user_args():
		start_race()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://assets/materials/night_sky.gdshader")
	sky_material.set_shader_parameter("reflection_panorama", load("res://assets/environment/polyhaven/cobblestone_street_night_1k.hdr"))
	sky_material.set_shader_parameter("reflection_energy", 0.28)
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2bdcf")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("111d30")
	environment.fog_density = 0.0012
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, -32, 0)
	moon.light_color = Color("c2d3e8")
	moon.light_energy = 0.65
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 150.0
	add_child(moon)

func set_difficulty(level: int) -> void:
	if not in_menu:
		return
	difficulty = clampi(level, 0, 2)
	ui.update_difficulty(difficulty)
	(rival.get_node("Driver") as RivalDriver).set_difficulty(difficulty)
	records.select_event(difficulty, race.total_laps)
	ui.set_record(records)

func _on_race_finished() -> void:
	records.record_finish(race)
	ui.show_results(race, records)

func start_race() -> void:
	get_tree().paused = false
	in_menu = false
	camera.set_physics_process(true)
	records.select_event(difficulty, race.total_laps)
	race.start_race()
	camera.reset_camera()
	ui.show_race()
	_gate_marker.show()

func show_menu() -> void:
	get_tree().paused = false
	in_menu = true
	race.state = RaceManager.State.IDLE
	race.rival_race.state = RaceManager.State.IDLE
	var rival_grid := track.grid_transform()
	rival_grid.origin += rival_grid.basis.x * 3.2
	rival.park_at(rival_grid)
	car.park_at(track.grid_transform())
	camera.set_physics_process(false)
	ui.show_menu()
	set_difficulty(difficulty)
	_gate_marker.hide()

func toggle_pause() -> void:
	if in_menu or race.state == RaceManager.State.FINISHED:
		return
	get_tree().paused = not get_tree().paused
	ui.pause_panel.visible = get_tree().paused

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	music.set_context(not in_menu and race.state == RaceManager.State.RUNNING, get_tree().paused)
	if in_menu:
		_orbit += delta * 0.09
		camera.global_position = car.global_position + Vector3(sin(_orbit) * 9.0, 3.2, cos(_orbit) * 9.0)
		camera.look_at(car.global_position + Vector3.UP * 0.7)
		camera.fov = 58.0
	else:
		ui.update_race(car, race)

func _build_gate_marker() -> void:
	_gate_marker = Node3D.new()
	add_child(_gate_marker)
	var neon := GameGeometry.material(Color("34ddeb"), 2.4)
	for side in [-1.0, 1.0]:
		GameGeometry.box(_gate_marker, Vector3(0.25, 4.0, 0.25), Vector3(side * 11.6, 2.0, 0), neon)
	var text := Label3D.new()
	text.text = "▼     КОНТРОЛЬНАЯ ТОЧКА     ▼"
	text.font_size = 80
	text.pixel_size = 0.01
	text.position.y = 5.5
	text.modulate = Color("35deec")
	text.no_depth_test = false
	_gate_marker.add_child(text)

func _update_gate_marker() -> void:
	_gate_marker.transform = track.checkpoints[race.next_checkpoint]
