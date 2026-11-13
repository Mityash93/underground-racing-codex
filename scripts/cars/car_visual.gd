class_name CarVisual
extends Node3D
## Temporary white T-Roc 2022 crossover. Visual proportions are independent of the rigid-body controller.

const AXLE_X := TRocBody.AXLE_X
const WHEEL_Y := TRocBody.WHEEL_Y
const FRONT_AXLE_Z := TRocBody.FRONT_AXLE_Z
const REAR_AXLE_Z := TRocBody.REAR_AXLE_Z
const ARCH_RADIUS := TRocBody.ARCH_RADIUS
var wheels: Array[WheelVisual] = []
var rear_lights: StandardMaterial3D
var body_pose: Node3D
var _shell: Node3D
var _pose_velocity := Vector3.ZERO
var body_model: PackedScene
var wheel_model: PackedScene
var brake_model: PackedScene
var front_half_track := AXLE_X
var rear_half_track := AXLE_X
var wheel_y := WHEEL_Y
var front_z := FRONT_AXLE_Z
var rear_z := REAR_AXLE_Z
var wheel_radius := WheelVisual.RADIUS
var body_model_scale := 1.0
var body_model_offset := Vector3.ZERO
var body_model_rotation_degrees := Vector3.ZERO
var wheel_model_scale := 1.0
var _brake_materials: Array[StandardMaterial3D] = []
var appearance := 0

func _ready() -> void:
	body_pose = Node3D.new()
	body_pose.name = "SprungBody"
	body_pose.position.y = 0.72
	add_child(body_pose)
	_shell = Node3D.new()
	_shell.position.y = -0.72
	body_pose.add_child(_shell)
	var paint := GameGeometry.material(Color("f1f1ed"))
	if appearance == 1:
		paint.albedo_color = Color("ca1833")
	paint.metallic = 0.18
	paint.roughness = 0.27
	var trim := GameGeometry.material(Color("141c26"))
	var glass := GameGeometry.material(Color("1b3547"))
	glass.metallic = 0.28
	glass.roughness = 0.20
	rear_lights = GameGeometry.material(Color("ed2941"), 1.5)
	_brake_materials.append(rear_lights)
	if not _build_imported_body():
		if appearance == 1:
			RivalSedanBody.build(_shell, paint, trim, glass, rear_lights)
		else:
			TRocBody.build(_shell, paint, trim, glass, rear_lights)
	for side in [-1.0, 1.0]:
		for axle_z in [front_z, rear_z]:
			var wheel := WheelVisual.new()
			wheel.name = ("Front" if axle_z < 0 else "Rear") + ("Left" if side < 0 else "Right")
			wheel.side = side
			wheel.is_front = axle_z < 0
			wheel.wheel_model = wheel_model
			wheel.brake_model = brake_model
			wheel.rolling_radius = wheel_radius
			wheel.model_scale = wheel_model_scale
			add_child(wheel)
			wheel.position = Vector3(side * (front_half_track if axle_z < 0 else rear_half_track), wheel_y, axle_z)
			wheels.append(wheel)

func _build_imported_body() -> bool:
	if body_model == null:
		return false
	var model := body_model.instantiate()
	if not model is Node3D:
		model.free()
		push_warning("Модель кузова должна иметь корневой Node3D. Используется процедурный T-Roc.")
		return false
	_shell.add_child(model)
	model.name = "ImportedBody"
	model.scale *= body_model_scale
	model.position += body_model_offset
	model.rotation_degrees += body_model_rotation_degrees
	for mesh in model.find_children("BrakeLight*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		if mesh.material_override is StandardMaterial3D:
			var material := _imported_brake_material(mesh.material_override)
			mesh.material_override = material
		else:
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					mesh.set_surface_override_material(surface, _imported_brake_material(material))
	return true

func _imported_brake_material(source: StandardMaterial3D) -> StandardMaterial3D:
	var copy: StandardMaterial3D = source.duplicate()
	copy.emission_enabled = true
	copy.emission = Color("d62232")
	_brake_materials.append(copy)
	return copy

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
	return TRocBody.arch_height(z)

func update_motion(velocity: Vector3, angular_velocity_y: float, steering: float, braking: bool, delta: float) -> void:
	for wheel in wheels:
		# Angular motion changes the rolling distance of inner/outer wheels.
		var wheel_velocity := velocity + Vector3.UP.cross(wheel.position) * angular_velocity_y
		var heading := Vector3.FORWARD.rotated(Vector3.UP, steering * 0.36 if wheel.is_front else 0.0)
		wheel.update_motion(wheel_velocity.dot(heading), steering, delta)
	for material in _brake_materials:
		material.emission_energy_multiplier = 5.0 if braking else 1.5
