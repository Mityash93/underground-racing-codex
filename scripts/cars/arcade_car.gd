class_name ArcadeCar
extends RigidBody3D

signal recovery_requested

@export var tuning: CarTuning
@export_group("Управление")
@export var external_driver := false
@export_enum("T-Roc 2022", "Красный спортивный седан") var appearance := 0
@export_group("Внешний вид — импорт модели")
@export var body_model: PackedScene
@export var wheel_model: PackedScene
@export_range(0.01, 10.0, 0.01) var body_model_scale := 1.0
@export var body_model_offset := Vector3.ZERO
@export var body_model_rotation_degrees := Vector3.ZERO
@export_range(0.01, 10.0, 0.01) var wheel_model_scale := 1.0
var controls_enabled := false
var steer := 0.0
var throttle := 0.0
var brake := 0.0
var handbrake := false
var grounded := false
var drift_blend := 0.0
var slip_angle := 0.0
var nitro := NitroSystem.new()
var tire_effects: TireEffects
var sound: VehicleSound
var _impact_velocity := Vector3.ZERO
var _wall_contacts: Dictionary = {}
var engine: EngineAudio
var speed_kmh: float:
	get: return Vector2(linear_velocity.x, linear_velocity.z).length() * 3.6
var visual: CarVisual
var _recovery_transform := Transform3D.IDENTITY
var _reset_pending := false
var _upside_down_time := 0.0
var _previous_velocity := Vector3.ZERO
var _filtered_acceleration := Vector3.ZERO
var _drive_command := Vector3.ZERO
var _drift_command := false

func _ready() -> void:
	if tuning == null:
		tuning = CarTuning.new()
	mass = 1250.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0.15)
	continuous_cd = true
	can_sleep = false
	linear_damp = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 2.8
	contact_monitor = true
	max_contacts_reported = 8
	var physics_mat := PhysicsMaterial.new()
	physics_mat.friction = 0.0
	physics_mat.bounce = 0.05
	physics_material_override = physics_mat
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.95, 1.1, 4.25)
	shape.shape = box
	shape.position.y = 0.60
	add_child(shape)
	_build_visual()
	tire_effects = TireEffects.new()
	tire_effects.name = "TireEffects"
	add_child(tire_effects)
	engine = EngineAudio.new()
	engine.car = self
	add_child(engine)
	sound = VehicleSound.new()
	sound.name = "VehicleSound"
	add_child(sound)
	var headlights := SpotLight3D.new()
	headlights.position = Vector3(0, 1.02, -2.18)
	headlights.light_color = Color("b5ddff")
	headlights.light_energy = 5.0
	headlights.spot_range = 42.0
	headlights.spot_angle = 38.0
	headlights.shadow_enabled = false
	add_child(headlights)

func _build_visual() -> void:
	visual = CarVisual.new()
	visual.name = "WhiteTRoc2022Visual"
	visual.appearance = appearance
	if appearance == 1:
		visual.name = "RedRivalVisual"
	visual.body_model = body_model
	visual.wheel_model = wheel_model
	visual.body_model_scale = body_model_scale
	visual.body_model_offset = body_model_offset
	visual.body_model_rotation_degrees = body_model_rotation_degrees
	visual.wheel_model_scale = wheel_model_scale
	add_child(visual)

func _physics_process(delta: float) -> void:
	_read_controls(delta)
	_update_vehicle_feedback(delta)
	var wanted := not external_driver and Input.is_action_pressed("nitro")
	var eligible := grounded and throttle > 0.1 and brake < 0.1 and not handbrake and linear_velocity.dot(-global_basis.z) > 2.8
	nitro.update(delta, wanted, eligible, controls_enabled and not freeze, tuning)

func set_drive_input(gas: float, braking: float, steering: float, drift: bool = false) -> void:
	_drive_command = Vector3(clampf(gas, 0.0, 1.0), clampf(braking, 0.0, 1.0), clampf(steering, -1.0, 1.0))
	_drift_command = drift

func _read_controls(delta: float) -> void:
	if controls_enabled:
		throttle = _drive_command.x if external_driver else Input.get_action_strength("accelerate")
		brake = _drive_command.y if external_driver else Input.get_action_strength("brake")
		handbrake = _drift_command if external_driver else Input.is_action_pressed("handbrake")
		var input_steer := _drive_command.z if external_driver else Input.get_axis("steer_right", "steer_left")
		var speed_ratio := clampf(speed_kmh / tuning.max_speed_kmh, 0.0, 1.0)
		var steering_scale := lerpf(1.0, tuning.high_speed_steering_scale, speed_ratio)
		var response := tuning.steering_return_speed if is_zero_approx(input_steer) else lerpf(tuning.steering_response, 3.7, speed_ratio)
		steer = move_toward(steer, input_steer * steering_scale, response * delta)
		if not external_driver and Input.is_action_just_pressed("recover"):
			recovery_requested.emit()
	else:
		throttle = 0.0
		brake = 0.0
		handbrake = false
		steer = move_toward(steer, 0.0, delta * 5.0)

func _update_vehicle_feedback(delta: float) -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, global_position - Vector3.UP * 0.25, 1, [get_rid()])
	grounded = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var wants_drift := handbrake and grounded and speed_kmh > 15.0
	drift_blend = move_toward(drift_blend, 1.0 if wants_drift else 0.0,
		(tuning.drift_entry_rate if wants_drift else tuning.drift_recovery_rate) * delta)
	var local_velocity := global_basis.inverse() * linear_velocity
	slip_angle = rad_to_deg(atan2(local_velocity.x, maxf(absf(local_velocity.z), 1.0)))
	var acceleration := (linear_velocity - _previous_velocity) / maxf(delta, 0.001)
	_previous_velocity = linear_velocity
	_filtered_acceleration = _filtered_acceleration.lerp((global_basis.inverse() * acceleration).limit_length(22.0), 1.0 - exp(-8.0 * delta))
	visual.update_body_attitude(_filtered_acceleration if grounded and not freeze else Vector3.ZERO, delta)
	if global_basis.y.dot(Vector3.UP) < 0.25:
		_upside_down_time += delta
	else:
		_upside_down_time = 0.0
	if global_position.y < -8.0 or _upside_down_time > 3.0:
		_upside_down_time = 0.0
		recovery_requested.emit()
	visual.update_motion(global_basis.inverse() * linear_velocity, angular_velocity.y,
		steer, brake > 0.1 or handbrake, delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		state.transform = _recovery_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false
		_reset_feedback()
		return
	# Previous incoming velocity survives the contact solver's loss of speed on impact.
	if controls_enabled and not freeze:
		for collider in _wall_contacts.keys():
			_wall_contacts[collider] -= state.step
			if _wall_contacts[collider] <= 0.0:
				_wall_contacts.erase(collider)
		var touched: Dictionary = {}
		var closing_speed := 0.0
		for i in state.get_contact_count():
			# Godot reports this normal in world space despite the method name.
			var normal := state.get_contact_local_normal(i)
			if absf(normal.y) > 0.65:
				continue
			var collider := state.get_contact_collider(i)
			touched[collider] = true
			if _wall_contacts.has(collider):
				continue
			var relative := _impact_velocity - state.get_contact_collider_velocity_at_position(i)
			closing_speed = maxf(closing_speed, -relative.dot(normal))
		for collider in touched:
			_wall_contacts[collider] = 0.4
		sound.report_impact(closing_speed)
	_impact_velocity = state.linear_velocity
	var forward := -state.transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var velocity := state.linear_velocity
	var speed := velocity.dot(forward)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if grounded:
		var acceleration := throttle * tuning.engine_acceleration * (1.0 - 0.18 * clampf(speed / (tuning.max_speed_kmh / 3.6), 0.0, 1.0))
		if brake > 0.0:
			if speed > 0.8:
				acceleration -= tuning.brake_deceleration * brake
			elif speed > -tuning.reverse_speed_kmh / 3.6:
				acceleration -= tuning.engine_acceleration * 0.58 * brake
		var speed_limit := tuning.max_speed_kmh
		if nitro.active and controls_enabled:
			acceleration += tuning.nitro_acceleration * nitro.blend
			speed_limit += tuning.nitro_extra_speed_kmh
		if speed >= speed_limit / 3.6 and acceleration > 0.0:
			acceleration = 0.0
		if handbrake:
			acceleration -= signf(speed) * minf(absf(speed) / state.step, tuning.handbrake_deceleration)
		var grip := lerpf(tuning.lateral_grip, tuning.drift_grip, drift_blend)
		var side_accel := clampf(-velocity.dot(right) * grip, -22.0, 22.0)
		state.apply_central_force((forward * acceleration + right * side_accel) * mass)
		var yaw_rate := lerpf(tuning.low_speed_yaw_rate, tuning.high_speed_yaw_rate, clampf(absf(speed) / 55.0, 0.0, 1.0))
		var target_yaw := steer * yaw_rate * clampf(speed / 9.0, -1.0, 1.0)
		target_yaw *= lerpf(1.0, 1.25, drift_blend)
		state.angular_velocity.y = lerpf(state.angular_velocity.y, target_yaw, 1.0 - exp(-6.0 * state.step))
		# Prevent the chassis from catching the ground in fast flat-road turns.
		var up := state.transform.basis.y
		var correction := up.cross(Vector3.UP) * tuning.stabilization
		state.angular_velocity.x += (correction.x - state.angular_velocity.x * 5.0) * state.step
		state.angular_velocity.z += (correction.z - state.angular_velocity.z * 5.0) * state.step
	if horizontal.length() > 0.01:
		var resistance := tuning.rolling_resistance + tuning.aerodynamic_drag * horizontal.length_squared()
		state.apply_central_force(-horizontal.normalized() * minf(resistance, horizontal.length() / state.step) * mass)

func recover_to(at: Transform3D) -> void:
	_recovery_transform = at
	_reset_pending = true
	nitro.stop()
	tire_effects.break_trail()
	steer = 0.0
	_upside_down_time = 0.0

func _reset_feedback() -> void:
	drift_blend = 0.0
	slip_angle = 0.0
	_previous_velocity = Vector3.ZERO
	_filtered_acceleration = Vector3.ZERO
	_impact_velocity = Vector3.ZERO
	_wall_contacts.clear()
	if is_instance_valid(sound):
		sound.reset_sounds()
	visual.reset_body_attitude()
	if is_instance_valid(engine):
		engine.reset_engine()

func park_at(ground: Transform3D) -> void:
	freeze = true
	controls_enabled = false
	_reset_pending = false
	ground.origin += ground.basis.y * (WheelVisual.RADIUS - CarVisual.WHEEL_Y)
	transform = ground
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	handbrake = false
	set_drive_input(0, 0, 0)
	nitro.reset()
	tire_effects.clear()
	_reset_feedback()
	visual.update_motion(Vector3.ZERO, 0.0, 0.0, false, 0.0)
