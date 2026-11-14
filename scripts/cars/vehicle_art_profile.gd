class_name VehicleArtProfile
extends Resource
## Optional local art. String paths keep the procedural car playable on a fresh clone.
@export var body_path := ""
@export var wheel_path := ""
@export var brake_path := ""
@export var front_half_track := 0.8
@export var rear_half_track := 0.8
@export var wheel_y := 0.41
@export var front_z := -1.3
@export var rear_z := 1.29
@export var radius := 0.36
@export var headlight_position := Vector3(0, 1.02, -2.18)
@export_group("Камера")
@export var chase_distance := 8.7
@export var chase_height := 3.65
@export var close_distance := 6.2
@export var close_height := 2.6
@export var camera_focus_height := 1.15
@export var camera_fov := 66.0

func available() -> bool:
	return not body_path.is_empty() and not wheel_path.is_empty() and not brake_path.is_empty() \
		and ResourceLoader.exists(body_path) and ResourceLoader.exists(wheel_path) and ResourceLoader.exists(brake_path)
