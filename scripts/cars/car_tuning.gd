class_name CarTuning
extends Resource

@export var max_speed_kmh: float = 225.0
@export var reverse_speed_kmh: float = 38.0
@export var engine_acceleration: float = 5.8
@export var brake_deceleration: float = 15.0
@export var rolling_resistance: float = 0.35
@export var aerodynamic_drag: float = 0.0010
@export var lateral_grip: float = 9.0
@export var drift_grip: float = 1.8
@export var drift_entry_rate: float = 3.5
@export var drift_recovery_rate: float = 1.8
@export var handbrake_deceleration: float = 3.8
@export var steering_response: float = 5.5
@export var steering_return_speed: float = 6.8
@export var high_speed_steering_scale: float = 0.78
@export var low_speed_yaw_rate: float = 1.45
@export var high_speed_yaw_rate: float = 0.68
@export var stabilization: float = 18.0

@export_group("Нитро")
@export var nitro_acceleration := 6.0
@export var nitro_extra_speed_kmh := 30.0
@export var nitro_duration := 4.5
@export var nitro_recharge_delay := 1.8
@export var nitro_recharge_rate := 0.10

@export_group("Звук автомобиля")
@export_range(-24.0, 6.0, 0.5) var effects_volume_db := 0.0
@export_range(0.0, 0.6, 0.01) var tunnel_reverb_wet := 0.28
@export_range(0.5, 10.0, 0.1) var impact_min_speed := 1.8
