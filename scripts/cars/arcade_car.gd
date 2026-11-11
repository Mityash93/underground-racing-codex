class_name ArcadeCar
extends RigidBody3D

signal recovery_requested

@export var tuning: CarTuning
var controls_enabled := false
var steer := 0.0
var throttle := 0.0
var brake := 0.0
var handbrake := false
var grounded := false
var drift_blend := 0.0
var slip_angle := 0.0
var engine: EngineAudio
var speed_kmh: float:
	get: return Vector2(linear_velocity.x, linear_velocity.z).length() * 3.6
var visual: CarVisual
var _recovery_transform := Transform3D.IDENTITY
var _reset_pending := false
var _upside_down_time := 0.0
var _previous_velocity := Vector3.ZERO
var _filtered_acceleration := Vector3.ZERO

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
	engine = EngineAudio.new()
	engine.car = self
	add_child(engine)
	var headlights := SpotLight3D.new()
	headlights.position = Vector3(0, 0.76, -2.12)
	headlights.light_color = Color("b5ddff")
	headlights.light_energy = 3.5
	headlights.spot_range = 42.0
	headlights.spot_angle = 38.0
	headlights.shadow_enabled = false
	add_child(headlights)

func _build_visual() -> void:
	visual = CarVisual.new()
	visual.name = "CoupeVisual"
	add_child(visual)

func _physics_process(delta: float) -> void:
	if controls_enabled:
		throttle = Input.get_action_strength("accelerate")
		brake = Input.get_action_strength("brake")
		handbrake = Input.is_action_pressed("handbrake")
		var input_steer := Input.get_axis("steer_right", "steer_left")
		var speed_ratio := clampf(speed_kmh / tuning.max_speed_kmh, 0.0, 1.0)
		var steering_scale := lerpf(1.0, tuning.high_speed_steering_scale, speed_ratio)
		var response := tuning.steering_return_speed if is_zero_approx(input_steer) else lerpf(tuning.steering_response, 3.7, speed_ratio)
		steer = move_toward(steer, input_steer * steering_scale, response * delta)
		if Input.is_action_just_pressed("recover"):
			recovery_requested.emit()
	else:
		throttle = 0.0
		brake = 0.0
		handbrake = false
		steer = move_toward(steer, 0.0, delta * 5.0)
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
		if speed >= tuning.max_speed_kmh / 3.6 and acceleration > 0.0:
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
	steer = 0.0
	_upside_down_time = 0.0

func _reset_feedback() -> void:
	drift_blend = 0.0
	slip_angle = 0.0
	_previous_velocity = Vector3.ZERO
	_filtered_acceleration = Vector3.ZERO
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
	_reset_feedback()
	visual.update_motion(Vector3.ZERO, 0.0, 0.0, false, 0.0)
