class_name CarVisual
extends Node3D
## Original low-poly coupe. Visual proportions are independent of the rigid-body controller.

const AXLE_X := CoupeBody.AXLE_X
const WHEEL_Y := CoupeBody.WHEEL_Y
const FRONT_AXLE_Z := CoupeBody.FRONT_AXLE_Z
const REAR_AXLE_Z := CoupeBody.REAR_AXLE_Z
const ARCH_RADIUS := CoupeBody.ARCH_RADIUS
var wheels: Array[WheelVisual] = []
var rear_lights: StandardMaterial3D
var body_pose: Node3D
var _shell: Node3D
var _pose_velocity := Vector3.ZERO

func _ready() -> void:
	body_pose = Node3D.new()
	body_pose.name = "SprungBody"
	body_pose.position.y = 0.72
	add_child(body_pose)
	_shell = Node3D.new()
	_shell.position.y = -0.72
	body_pose.add_child(_shell)
	var paint := GameGeometry.material(Color("e94c28"))
	paint.metallic = 0.55
	paint.roughness = 0.30
	var trim := GameGeometry.material(Color("141c26"))
	var glass := GameGeometry.material(Color("1b3547"))
	glass.metallic = 0.28
	glass.roughness = 0.20
	rear_lights = GameGeometry.material(Color("ed2941"), 1.5)
	CoupeBody.build(_shell, paint, trim, glass, rear_lights)
	for side in [-1.0, 1.0]:
		for axle_z in [FRONT_AXLE_Z, REAR_AXLE_Z]:
			var wheel := WheelVisual.new()
			wheel.name = ("Front" if axle_z < 0 else "Rear") + ("Left" if side < 0 else "Right")
			wheel.side = side
			wheel.is_front = axle_z < 0
			add_child(wheel)
			wheel.position = Vector3(side * AXLE_X, WHEEL_Y, axle_z)
			wheels.append(wheel)

func update_body_attitude(acceleration: Vector3, delta: float) -> void:
	var target := Vector3(clampf(-acceleration.z * 0.0025, -0.021, 0.021), 0.0,
		clampf(acceleration.x * 0.0025, -0.038, 0.038))
	# Analytic critically damped spring: stable across different render/physics rates.
	var omega := 13.0
	var displacement := body_pose.rotation - target
	var step := (_pose_velocity + omega * displacement) * delta
	var decay := exp(-omega * delta)
	body_pose.rotation = target + (displacement + step) * decay
	_pose_velocity = (_pose_velocity - omega * step) * decay

func reset_body_attitude() -> void:
	body_pose.rotation = Vector3.ZERO
	_pose_velocity = Vector3.ZERO

static func arch_height(z: float) -> float:
	return CoupeBody.arch_height(z)

func update_motion(velocity: Vector3, angular_velocity_y: float, steering: float, braking: bool, delta: float) -> void:
	for wheel in wheels:
		# Angular motion changes the rolling distance of inner/outer wheels.
		var wheel_velocity := velocity + Vector3.UP.cross(wheel.position) * angular_velocity_y
		var heading := Vector3.FORWARD.rotated(Vector3.UP, steering * 0.36 if wheel.is_front else 0.0)
		wheel.update_motion(wheel_velocity.dot(heading), steering, delta)
	rear_lights.emission_energy_multiplier = 5.0 if braking else 1.5
