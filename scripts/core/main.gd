extends Node3D

@onready var track: CityTrack = $NeonDistrict
@onready var car: ArcadeCar = $PlayerCar
@onready var camera: ChaseCamera = $ChaseCamera
@onready var race: RaceManager = $RaceManager
@onready var ui: GameUI = $GameUI
var in_menu := true
var _orbit := 0.4
var _gate_marker: Node3D

func _ready() -> void:
	_build_environment()
	camera.target = car
	race.track = track
	race.car = car
	ui.minimap.track = track
	ui.minimap.car = car
	ui.minimap.race = race
	ui.start_requested.connect(start_race)
	ui.restart_requested.connect(start_race)
	ui.pause_requested.connect(toggle_pause)
	ui.resume_requested.connect(toggle_pause)
	ui.menu_requested.connect(show_menu)
	car.recovery_requested.connect(race.recover)
	race.race_finished.connect(func(): ui.show_results(race))
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
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("030819")
	sky_material.sky_horizon_color = Color("263453")
	sky_material.ground_bottom_color = Color("0a1220")
	sky_material.ground_horizon_color = Color("3b374c")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da5cd")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("27334f")
	environment.fog_density = 0.0018
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, -32, 0)
	moon.light_color = Color("a2bded")
	moon.light_energy = 1.3
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 150.0
	add_child(moon)

func start_race() -> void:
	get_tree().paused = false
	in_menu = false
	camera.set_physics_process(true)
	race.start_race()
	camera.reset_camera()
	ui.show_race()
	_gate_marker.show()

func show_menu() -> void:
	get_tree().paused = false
	in_menu = true
	race.state = RaceManager.State.IDLE
	car.park_at(track.grid_transform())
	camera.set_physics_process(false)
	ui.show_menu()
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
	text.text = "▼     CHECKPOINT     ▼"
	text.font_size = 80
	text.pixel_size = 0.01
	text.position.y = 5.5
	text.modulate = Color("35deec")
	text.no_depth_test = false
	_gate_marker.add_child(text)

func _update_gate_marker() -> void:
	_gate_marker.transform = track.checkpoints[race.next_checkpoint]
