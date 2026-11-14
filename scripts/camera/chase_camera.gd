class_name ChaseCamera
extends Camera3D

var target: ArcadeCar
var close_view := false
var _heading := Vector3.FORWARD
var _anchor := Vector3.ZERO
var _initialized := false
var _obstacle_shape := SphereShape3D.new()

func _ready() -> void:
	_obstacle_shape.radius = 0.3
	near = 0.15

func reset_camera() -> void:
	_initialized = false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if Input.is_action_just_pressed("camera_view"):
		close_view = not close_view
	var forward := -target.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# A little travel-direction bias keeps a slide readable while retaining the car's heading.
	var velocity := Vector3(target.linear_velocity.x, 0, target.linear_velocity.z)
	if velocity.length() > 8.0 and velocity.dot(forward) > 0.0:
		forward = forward.lerp(velocity.normalized(), 0.28).normalized()
	if _anchor.distance_to(target.global_position) > 25.0:
		_initialized = false
	if not _initialized:
		_heading = forward
		_anchor = target.global_position
		_initialized = true
	_heading = _heading.lerp(forward, 1.0 - exp(-5.0 * delta)).normalized()
	_anchor = _anchor.lerp(target.global_position, 1.0 - exp(-14.0 * delta))
	var ratio := clampf(target.speed_kmh / target.tuning.max_speed_kmh, 0.0, 1.0)
	var profile: VehicleArtProfile
	if target.body_model == null and target.visual != null and target.visual.body_model != null:
		profile = target.art_profile
	var distance := (6.2 if close_view else 8.7) + ratio
	var height := 2.6 if close_view else 3.65
	var focus_height := 1.15
	var base_fov := 66.0
	if profile != null:
		distance = (profile.close_distance if close_view else profile.chase_distance) + ratio
		height = profile.close_height if close_view else profile.chase_height
		focus_height = profile.camera_focus_height
		base_fov = profile.camera_fov
	var focus := _anchor + Vector3.UP * focus_height
	var desired := _anchor - _heading * distance + Vector3.UP * height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _obstacle_shape
	query.transform = Transform3D(Basis.IDENTITY, focus)
	query.motion = desired - focus
	query.collision_mask = 1
	query.exclude = [target.get_rid()]
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	if fractions[0] < 1.0:
		desired = focus.lerp(desired, maxf(0.0, fractions[0] - 0.015))
	global_position = desired
	look_at(focus + _heading * (3.0 + ratio * 3.0), Vector3.UP)
	fov = lerpf(fov, base_fov + ratio * 16.0 + target.nitro.blend * 8.0, 1.0 - exp(-3.0 * delta))
