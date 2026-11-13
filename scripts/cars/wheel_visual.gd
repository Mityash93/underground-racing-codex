class_name WheelVisual
extends Node3D
## Steering pivot (Y) -> rolling axle (X) -> all wheel geometry.
## Cylinder alignment is fixed; steering never changes the rolling axle's local axis.

const RADIUS := 0.36
const WIDTH := 0.235
var is_front := false
var side := 1.0
var roll: Node3D
var roll_angle := 0.0
var wheel_model: PackedScene
var brake_model: PackedScene
var rolling_radius := RADIUS
var model_scale := 1.0

func _ready() -> void:
	roll = Node3D.new()
	roll.name = "RollingAxle"
	add_child(roll)
	if wheel_model != null:
		var model := wheel_model.instantiate()
		if model is Node3D:
			roll.add_child(model)
			model.name = "ImportedWheel"
			model.scale *= model_scale
			if side < 0.0:
				model.rotate_y(PI)
			if brake_model != null:
				var fixed_brake := brake_model.instantiate() as Node3D
				add_child(fixed_brake)
				fixed_brake.name = "FixedBrake"
				fixed_brake.scale *= model_scale
				if side < 0.0:
					fixed_brake.rotate_y(PI)
			return
		model.free()
		push_warning("Модель колеса должна иметь корневой Node3D. Используется процедурное колесо.")
	var rubber := GameGeometry.material(Color("11151b"))
	rubber.roughness = 0.96
	var alloy := GameGeometry.material(Color("b2bfcd"))
	alloy.metallic = 0.8
	alloy.roughness = 0.28
	var recess := GameGeometry.material(Color("242d38"))
	var rotor := GameGeometry.material(Color("46515c"))
	rotor.metallic = 0.65
	rotor.roughness = 0.7
	_cylinder("Tire", RADIUS, WIDTH, 0.0, rubber)
	_cylinder("RimBarrel", 0.295, WIDTH + 0.008, 0.0, recess)
	var face_x := side * (WIDTH / 2.0 + 0.008)
	_cylinder("RimFace", 0.247, 0.014, face_x, rotor)
	_cylinder("Hub", 0.072, 0.032, face_x + side * 0.012, alloy)
	# Split spokes, a contrasting brake disc and a fixed caliper.
	for i in 5:
		var angle := TAU * i / 5.0
		for offset in [-0.10, 0.10]:
			var direction: float = angle + offset
			var spoke := GameGeometry.box(roll, Vector3(0.025, 0.20, 0.027),
				Vector3(face_x + side * 0.013, cos(direction) * 0.16, sin(direction) * 0.16), alloy)
			spoke.rotation.x = direction
	var caliper := GameGeometry.box(self, Vector3(0.024, 0.16, 0.065),
		Vector3(side * (WIDTH / 2.0 + 0.015), 0.06, 0.19), GameGeometry.material(Color("65717d")))
	caliper.name = "FixedCaliper"
	var rim_lip := TorusMesh.new()
	rim_lip.inner_radius = 0.272
	rim_lip.outer_radius = 0.298
	rim_lip.rings = 24
	rim_lip.ring_segments = 8
	var lip := MeshInstance3D.new()
	lip.mesh = rim_lip
	lip.material_override = alloy
	lip.position.x = face_x
	lip.rotation.z = PI / 2.0
	roll.add_child(lip)

func _cylinder(node_name: String, radius: float, width: float, x: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 32
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.rotation.z = PI / 2.0
	instance.position.x = x
	instance.material_override = mat
	roll.add_child(instance)

func update_motion(signed_speed: float, steering: float, delta: float) -> void:
	rotation.y = steering * 0.36 if is_front else 0.0
	# Forward is -Z; rolling forward therefore rotates around negative X.
	roll_angle = wrapf(roll_angle - signed_speed * delta / rolling_radius, -PI, PI)
	roll.rotation.x = roll_angle
