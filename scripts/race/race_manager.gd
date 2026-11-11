class_name RaceManager
extends Node

signal race_finished
signal checkpoint_passed

enum State { IDLE, COUNTDOWN, RUNNING, FINISHED }
@export var total_laps := 2
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

func start_race() -> void:
	state = State.COUNTDOWN
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
	car.park_at(track.grid_transform())
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
			state = State.FINISHED
			car.controls_enabled = false
			car.freeze = true
			race_finished.emit()
		else:
			lap += 1
	next_checkpoint = (next_checkpoint + 1) % track.checkpoints.size()
	checkpoint_passed.emit()

func recover() -> void:
	if state != State.RUNNING:
		return
	var safe := track.checkpoints[last_checkpoint]
	safe.origin += -safe.basis.z * 4.0 + Vector3.UP * 0.35
	car.recover_to(safe)
	_previous_position = safe.origin
	_gate_armed = false
	recoveries += 1
	elapsed += 5.0
	lap_time += 5.0

static func format_time(seconds: float) -> String:
	if is_inf(seconds):
		return "--:--.---"
	var millis := int(round(seconds * 1000.0))
	return "%02d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]
