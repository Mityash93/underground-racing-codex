class_name RivalDriver
extends Node
## Physical driver: predictive braking, racing line and committed, collision-aware passes.
@export var max_speed_kmh := 180.0
@export var corner_acceleration := 18.0
@export var preferred_lane := 3.2
enum Difficulty { EASY, MEDIUM, HARD }
var difficulty := Difficulty.MEDIUM
var profile: RivalDifficulty
var car: ArcadeCar
var track: CityTrack
var other_car: ArcadeCar
var target_speed_kmh := 0.0
var lane_offset := 3.2
var defending := false
var _stuck_time := 0.0
var _distance_without_progress := 0.0
var _last_distance := 0.0
var _passing := false
var _passing_lane := -3.8
var _decision_remaining := 0.0
var _planned_speed := 0.0
var _planned_curvature := 0.0
var _defend_remaining := 0.0
var _defend_lane := 0.0

func _ready() -> void:
	process_physics_priority = -10
	car = get_parent() as ArcadeCar
	set_difficulty(difficulty)

func set_difficulty(level: int) -> void:
	difficulty = clampi(level, Difficulty.EASY, Difficulty.HARD)
	profile = RivalDifficulty.for_level(difficulty)
	max_speed_kmh = profile.speed_limit
	corner_acceleration = profile.corner_acceleration
	reset_driver()

func reset_driver() -> void:
	_stuck_time = 0.0
	_passing = false
	defending = false
	_defend_remaining = 0.0
	_decision_remaining = 0.0
	_planned_speed = max_speed_kmh
	_distance_without_progress = 0.0
	lane_offset = preferred_lane
	if is_instance_valid(car):
		car.set_nitro_input(false)
	if is_instance_valid(track) and is_instance_valid(car):
		_last_distance = track.nearest_distance(car.global_position)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(car) or not is_instance_valid(track):
		return
	if not car.controls_enabled or car.freeze:
		car.set_drive_input(0, 0, 0)
		reset_driver()
		return
	var distance := track.nearest_distance(car.global_position)
	var road := track.transform_at(distance)
	var forward := Vector3(-car.global_basis.z.x, 0, -car.global_basis.z.z).normalized()
	_decision_remaining -= delta
	if _decision_remaining <= 0:
		_planned_speed = _plan_speed(distance)
		_decision_remaining = profile.reaction_time
	target_speed_kmh = minf(_planned_speed, max_speed_kmh)
	var lane_target := _racing_lane(distance)
	lane_target = _traffic_lane(lane_target, distance, road, delta)
	lane_offset = move_toward(lane_offset, lane_target, delta * profile.lane_change_rate)
	var goal := track.transform_at(distance + 12.0 + car.speed_kmh * 0.13)
	var to_goal := goal.origin + goal.basis.x * lane_offset - car.global_position
	to_goal.y = 0
	var angle := forward.signed_angle_to(to_goal.normalized(), Vector3.UP)
	# Pure pursuit converts path curvature to the actual speed-dependent yaw authority.
	var speed := maxf(car.linear_velocity.dot(forward), 6.0)
	var yaw_rate := lerpf(car.tuning.low_speed_yaw_rate, car.tuning.high_speed_yaw_rate, clampf(speed / 55.0, 0, 1))
	var steering_scale := lerpf(1.0, car.tuning.high_speed_steering_scale, clampf(car.speed_kmh / car.tuning.max_speed_kmh, 0, 1))
	var desired_yaw := 2.0 * speed * sin(angle) / maxf(to_goal.length(), 6.0)
	var steering := clampf(desired_yaw / maxf(yaw_rate * steering_scale * clampf(speed / 9.0, 0.1, 1), 0.2), -1, 1)
	# A large recovery heading error requires slowing, independent of difficulty.
	target_speed_kmh *= clampf(1.0 - maxf(0, absf(angle) - 0.16) * 0.6, 0.45, 1.0)
	var tank_ready := car.nitro.active or (car.nitro.charge >= 0.5 and not car.nitro.exhausted)
	var boost := profile.use_nitro and tank_ready and _planned_curvature < 0.0025 and _planned_speed > max_speed_kmh + 8 and absf(steering) < 0.22 and car.speed_kmh > 95 and not _passing and target_speed_kmh >= max_speed_kmh - 2
	car.set_nitro_input(boost)
	if boost:
		target_speed_kmh = minf(_planned_speed, max_speed_kmh + car.tuning.nitro_extra_speed_kmh)
	var braking := clampf((car.speed_kmh - target_speed_kmh) / 12.0, 0, 1)
	var gas := minf(profile.throttle_limit, clampf((target_speed_kmh + 3 - car.speed_kmh) / 12.0, 0, 1))
	car.set_drive_input(gas if braking < 0.05 else 0.0, braking, steering)
	_recover_if_stuck(distance, road, gas, delta)

func _plan_speed(distance: float) -> float:
	var result := max_speed_kmh + (car.tuning.nitro_extra_speed_kmh if profile.use_nitro else 0.0)
	_planned_curvature = 0.0
	var buffer := profile.brake_buffer + car.speed_kmh / 3.6 * profile.reaction_time
	for offset in [0.0, 12.0, 24.0, 40.0, 60.0, 85.0, 115.0, 150.0]:
		var first := -track.transform_at(distance + offset - 10).basis.z
		var second := -track.transform_at(distance + offset + 10).basis.z
		var curvature := absf(first.signed_angle_to(second, Vector3.UP)) / 20.0
		if offset <= 40:
			_planned_curvature = maxf(_planned_curvature, curvature)
		var safe_speed := sqrt(corner_acceleration / maxf(curvature, 0.0001))
		var permitted := sqrt(safe_speed * safe_speed + 2 * profile.planning_brake * maxf(0, offset - buffer)) * 3.6
		result = minf(result, permitted)
	return result

func _racing_lane(distance: float) -> float:
	if profile.apex_offset <= 0:
		return preferred_lane
	var entry := -track.transform_at(distance + 18).basis.z
	var exit := -track.transform_at(distance + 55).basis.z
	var bend := entry.signed_angle_to(exit, Vector3.UP)
	return lerpf(preferred_lane, -signf(bend) * profile.apex_offset, smoothstep(0.04, 0.28, absf(bend)))

func _traffic_lane(base_lane: float, distance: float, road: Transform3D, delta: float) -> float:
	defending = false
	_defend_remaining = maxf(0, _defend_remaining - delta)
	if not is_instance_valid(other_car):
		return base_lane
	var relative := other_car.global_position - car.global_position
	car.engine.volume_trim_db = -8.0 - minf(relative.length() * 0.5, 42)
	var other_distance := track.nearest_distance(other_car.global_position)
	var ahead := fposmod(other_distance - distance + track.track_length * 0.5, track.track_length) - track.track_length * 0.5
	var other_road := track.transform_at(other_distance)
	var other_lane := other_road.basis.x.dot(other_car.global_position - other_road.origin)
	var own_lane := road.basis.x.dot(car.global_position - road.origin)
	var across := absf(own_lane - other_lane)
	if _passing and (ahead < -10 or absf(ahead) > 145):
		_passing = false
	var lookahead := profile.passing_distance + car.speed_kmh / 3.6 * 0.7
	if not _passing and ahead > 0 and ahead < lookahead and across < 4.2 and car.speed_kmh > other_car.speed_kmh - 8:
		_passing_lane = -3.8 if other_lane >= 0 else 3.8
		_passing = true
	var lane := _passing_lane if _passing else base_lane
	# One early defensive choice; never block by moving across a car already alongside.
	if profile.defend_position and not _passing and ahead < -14 and ahead > -36 and other_car.speed_kmh > car.speed_kmh + 3 and _defend_remaining <= 0:
		_defend_lane = clampf(other_lane, -2.8, 2.8)
		_defend_remaining = 2.5
	if _defend_remaining > 0 and ahead < -8 and ahead > -42 and not _passing:
		lane = _defend_lane
		defending = true
	if absf(ahead) < 8:
		_defend_remaining = 0
		defending = false
		if across < 3.0:
			var side := signf(own_lane - other_lane)
			if is_zero_approx(side):
				side = signf(_passing_lane)
			lane = clampf(other_lane + side * 3.4, -6, 6)
	# Braking uses relative closing speed, including a stationary or abruptly slower car.
	var closing := maxf(0, (car.speed_kmh - other_car.speed_kmh) / 3.6)
	var safe_gap := 5.5 + closing * profile.reaction_time + closing * closing / (2 * profile.planning_brake)
	if ahead > 0 and ahead < safe_gap and across < 2.7:
		target_speed_kmh = minf(target_speed_kmh, maxf(0, other_car.speed_kmh - 6))
	return lane

func _recover_if_stuck(distance: float, road: Transform3D, gas: float, delta: float) -> void:
	var progress := fposmod(distance - _last_distance + track.track_length * 0.5, track.track_length) - track.track_length * 0.5
	_last_distance = distance
	_stuck_time = _stuck_time + delta if car.speed_kmh < 5 and gas > 0.4 else 0.0
	_distance_without_progress = _distance_without_progress + delta if progress < 0.02 else 0.0
	if _stuck_time > 3.5 or _distance_without_progress > 8 or car.global_position.distance_to(road.origin) > 20:
		car.recovery_requested.emit()
		reset_driver()
