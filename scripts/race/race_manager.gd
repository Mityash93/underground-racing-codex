class_name RaceManager
extends Node

signal race_finished
signal checkpoint_passed

enum State { IDLE, COUNTDOWN, RUNNING, FINISHED }
@export var total_laps := 2
@export var rival_enabled := true
var rival_car: ArcadeCar
var rival_race: RaceManager
var grid_lane_offset := 0.0
var winner := ""
var course_completed := false
var state := State.IDLE
var car: ArcadeCar
var track: CityTrack
var countdown := 3.0
var elapsed := 0.0
var lap_time := 0.0
var lap := 1
var next_checkpoint := 1
var last_checkpoint := 0
var best_lap := INF
var lap_times: Array[float] = []
var recoveries := 0
var _previous_position := Vector3.ZERO
var _gate_armed := false

func configure_rival(other: ArcadeCar) -> void:
	rival_car = other
	rival_race = RaceManager.new()
	rival_race.name = "RivalProgress"
	rival_race.track = track
	rival_race.car = other
	rival_race.grid_lane_offset = 3.2
	add_child(rival_race)
	rival_race.race_finished.connect(func(): _finish_race("rival"))
	other.recovery_requested.connect(rival_race.recover)
	grid_lane_offset = -3.2

func is_duel() -> bool:
	return rival_enabled and is_instance_valid(rival_race)

func start_race() -> void:
	state = State.COUNTDOWN
	winner = ""
	course_completed = false
	countdown = 3.0
	elapsed = 0.0
	lap_time = 0.0
	lap = 1
	next_checkpoint = 1
	last_checkpoint = 0
	lap_times.clear()
	best_lap = INF
	recoveries = 0
	_gate_armed = false
	var grid := track.grid_transform()
	grid.origin += grid.basis.x * grid_lane_offset
	car.park_at(grid)
	if is_duel():
		rival_race.total_laps = total_laps
		rival_race.start_race()
	elif is_instance_valid(rival_race):
		rival_race.state = State.IDLE
		rival_car.park_at(track.grid_transform().translated(track.grid_transform().basis.x * 3.2))
	_previous_position = car.global_position
	checkpoint_passed.emit()

func _physics_process(delta: float) -> void:
	if state == State.COUNTDOWN:
		countdown -= delta
		if countdown <= 0.0:
			state = State.RUNNING
			car.freeze = false
			car.controls_enabled = true
			_previous_position = car.global_position
	elif state == State.RUNNING:
		elapsed += delta
		lap_time += delta
		_check_gate()

func _check_gate() -> void:
	var gate := track.checkpoints[next_checkpoint]
	var forward := -gate.basis.z
	var before := (_previous_position - gate.origin).dot(forward)
	var after := (car.global_position - gate.origin).dot(forward)
	if after < -1.0:
		_gate_armed = true
	if _gate_armed and before <= 0.0 and after > 0.0:
		var fraction := -before / maxf(after - before, 0.0001)
		var crossing := _previous_position.lerp(car.global_position, fraction)
		var local_crossing := gate.affine_inverse() * crossing
		if absf(local_crossing.x) < CityTrack.ROAD_WIDTH / 2.0 + 0.4 and absf(local_crossing.y) < 3.0 and _previous_position.distance_to(car.global_position) < 15.0:
			_accept_checkpoint()
	_previous_position = car.global_position

func _accept_checkpoint() -> void:
	last_checkpoint = next_checkpoint
	_gate_armed = false
	if next_checkpoint == 0:
		lap_times.append(lap_time)
		best_lap = minf(best_lap, lap_time)
		lap_time = 0.0
		if lap == total_laps:
			course_completed = true
			_finish_race("player")
		else:
			lap += 1
	next_checkpoint = (next_checkpoint + 1) % track.checkpoints.size()
	checkpoint_passed.emit()

func recover() -> void:
	if state != State.RUNNING:
		return
	var safe := track.checkpoints[last_checkpoint]
	safe.origin += safe.basis.x * grid_lane_offset - safe.basis.z * 4.0 + Vector3.UP * 0.35
	car.recover_to(safe)
	_previous_position = safe.origin
	_gate_armed = false
	recoveries += 1
	elapsed += 5.0
	lap_time += 5.0

func _finish_race(first: String) -> void:
	if state == State.FINISHED:
		return
	winner = first
	state = State.FINISHED
	car.controls_enabled = false
	car.freeze = true
	if is_duel():
		rival_race.state = State.FINISHED
		rival_car.controls_enabled = false
		rival_car.freeze = true
	race_finished.emit()

func progress_score() -> float:
	var count := track.checkpoints.size()
	if course_completed:
		return float(total_laps * count)
	var segment := track.track_length / count
	var distance := track.nearest_distance(car.global_position)
	var traveled := fposmod(distance - last_checkpoint * segment + track.track_length * 0.5, track.track_length) - track.track_length * 0.5
	return (lap - 1) * count + last_checkpoint + clampf(traveled / segment, 0.0, 0.999)

func player_position() -> int:
	if not is_duel():
		return 1
	if state == State.FINISHED:
		return 1 if winner == "player" else 2
	return 1 if progress_score() >= rival_race.progress_score() else 2

func rival_gap_meters() -> float:
	return (progress_score() - rival_race.progress_score()) * track.track_length / track.checkpoints.size() if is_duel() else 0.0

static func format_time(seconds: float) -> String:
	if is_inf(seconds):
		return "--:--.---"
	var millis := int(round(seconds * 1000.0))
	return "%02d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]
