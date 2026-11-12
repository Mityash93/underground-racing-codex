class_name RivalDriver
extends Node
## Independent driver. Only commands forces through ArcadeCar; no Input actions or path teleportation.

@export var max_speed_kmh := 165.0
@export var corner_acceleration := 21.0
@export var preferred_lane := 3.2
var car: ArcadeCar
var track: CityTrack
var other_car: ArcadeCar
var target_speed_kmh := 0.0
var lane_offset := 3.2
var _stuck_time := 0.0
var _distance_without_progress := 0.0
var _last_distance := 0.0
var _passing := false
var _passing_lane := -3.8

func _ready() -> void:
	process_physics_priority = -10
	car = get_parent() as ArcadeCar

func reset_driver() -> void:
	_stuck_time = 0.0
	_passing = false
	_distance_without_progress = 0.0
	lane_offset = preferred_lane
	if is_instance_valid(track):
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
	var forward := -car.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var lane_target := preferred_lane
	target_speed_kmh = max_speed_kmh
	# Look ahead to slow down before a corner rather than braking after missing it.
	for offset in [10.0, 35.0, 65.0]:
		var first := -track.transform_at(distance + offset).basis.z
		var second := -track.transform_at(distance + offset + 24.0).basis.z
		var curvature := absf(first.signed_angle_to(second, Vector3.UP)) / 24.0
		var safe_speed := sqrt(corner_acceleration / maxf(curvature, 0.0005)) * 3.6
		target_speed_kmh = minf(target_speed_kmh, maxf(100.0, safe_speed))
	if is_instance_valid(other_car):
		var relative := other_car.global_position - car.global_position
		var ahead := relative.dot(forward)
		var across := absf(relative.dot(car.global_basis.x))
		if _passing and (ahead < -9.0 or relative.length() > 85.0):
			_passing = false
		if not _passing and ahead > 0.0 and ahead < 55.0 and across < 4.0:
			var other_lane := road.basis.x.dot(other_car.global_position - road.origin)
			_passing_lane = -3.8 if other_lane >= 0 else 3.8
			_passing = true
		if _passing:
			lane_target = _passing_lane
			if ahead > 0.0 and ahead < 14.0 and across < 2.6:
				target_speed_kmh = minf(target_speed_kmh, maxf(12.0, other_car.speed_kmh - 8.0))
		car.engine.volume_trim_db = -8.0 - minf(relative.length() * 0.5, 42.0)
	lane_offset = move_toward(lane_offset, lane_target, delta * 4.2)
	var goal := track.transform_at(distance + 12.0 + car.speed_kmh * 0.13)
	var to_goal := goal.origin + goal.basis.x * lane_offset - car.global_position
	to_goal.y = 0
	var angle := forward.signed_angle_to(to_goal.normalized(), Vector3.UP)
	target_speed_kmh *= clampf(1.0 - absf(angle) * 0.28, 0.70, 1.0)
	var gas := clampf((target_speed_kmh + 4.0 - car.speed_kmh) / 12.0, 0.0, 1.0)
	var braking := clampf((car.speed_kmh - target_speed_kmh) / 12.0, 0.0, 1.0)
	car.set_drive_input(gas if braking < 0.05 else 0.0, braking, clampf(angle * 2.8, -1.0, 1.0))
	# Recover only when physically stuck/off the course, never to catch the player.
	var progress := fposmod(distance - _last_distance + track.track_length * 0.5, track.track_length) - track.track_length * 0.5
	_last_distance = distance
	if car.speed_kmh < 5.0 and gas > 0.4:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if progress < 0.02:
		_distance_without_progress += delta
	else:
		_distance_without_progress = 0.0
	if _stuck_time > 3.5 or _distance_without_progress > 8.0 or car.global_position.distance_to(road.origin) > 20.0:
		car.recovery_requested.emit()
		reset_driver()
