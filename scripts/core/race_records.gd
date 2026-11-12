class_name RaceRecords
extends RefCounted
## Local personal bests, scoped to circuit/rules/difficulty. No incomplete races.
var path := "res://local_data/records.cfg"
var best_time := INF
var best_lap := INF
var new_record := false
var save_failed := false
var _key := ""
var _config := ConfigFile.new()

func select_event(difficulty: int, laps: int) -> void:
	_key = "%s_nitro_v1_%d_laps_%d" % [TrackLayout.RECORD_ID, laps, difficulty]
	_config = ConfigFile.new()
	_config.load(path)
	best_time = _valid_time(_config.get_value(_key, "race", INF))
	best_lap = _valid_time(_config.get_value(_key, "lap", INF))
	new_record = false
	save_failed = false

func record_finish(race: RaceManager) -> void:
	new_record = false
	if not race.course_completed or race.lap_times.size() != race.total_laps:
		return
	var time := _valid_time(race.elapsed)
	var lap_time := _valid_time(race.best_lap)
	if is_inf(time) or is_inf(lap_time):
		return
	new_record = time < best_time
	if not new_record and lap_time >= best_lap:
		return
	best_time = minf(best_time, time)
	best_lap = minf(best_lap, lap_time)
	_config.set_value(_key, "race", best_time)
	_config.set_value(_key, "lap", best_lap)
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	save_failed = err != OK or _config.save(path) != OK

static func _valid_time(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0:
		return float(value)
	return INF
