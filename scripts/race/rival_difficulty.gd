class_name RivalDifficulty
extends Resource
## Driving decisions only; never changes the car's physics or the player's performance.
@export var description := ""
@export var speed_limit := 180.0
@export var corner_acceleration := 18.0
@export var planning_brake := 9.0
@export var brake_buffer := 9.0
@export var reaction_time := 0.14
@export var throttle_limit := 1.0
@export var passing_distance := 55.0
@export var lane_change_rate := 3.6
@export var apex_offset := 1.3
@export var defend_position := false
@export var use_nitro := false

static func for_level(level: int) -> RivalDifficulty:
	return load(["res://resources/rivals/easy.tres", "res://resources/rivals/medium.tres", "res://resources/rivals/hard.tres"][clampi(level, 0, 2)]) as RivalDifficulty
