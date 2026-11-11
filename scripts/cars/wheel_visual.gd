class_name WheelVisual
extends Node3D
## Steering pivot (Y) -> rolling axle (X) -> all wheel geometry.
## Cylinder alignment is fixed; steering never changes the rolling axle's local axis.

const RADIUS := 0.42
const WIDTH := 0.25
var is_front := false
var side := 1.0
var roll: Node3D
var roll_angle := 0.0

func _ready() -> void:
	roll = Node3D.new()
	roll.name = "RollingAxle"
	add_child(roll)
	var rubber := GameGeometry.material(Color("11151b"))
	rubber.roughness = 0.96
	var alloy := GameGeometry.material(Color("b2bfcd"))
	alloy.metallic = 0.8
	alloy.roughness = 0.28
	var recess := GameGeometry.material(Color("242d38"))
	_cylinder("Tire", RADIUS, WIDTH, 0.0, rubber)
	_cylinder("RimBarrel", 0.295, WIDTH + 0.008, 0.0, recess)
	var face_x := side * (WIDTH / 2.0 + 0.008)
	_cylinder("RimFace", 0.267, 0.014, face_x, recess)
	_cylinder("Hub", 0.072, 0.032, face_x + side * 0.012, alloy)
	# Five spokes make rolling visible, unlike a featureless cylinder cap.
	for i in 5:
		var angle := TAU * i / 5.0
		var spoke := GameGeometry.box(roll, Vector3(0.025, 0.205, 0.045),
			Vector3(face_x + side * 0.013, cos(angle) * 0.15, sin(angle) * 0.15), alloy)
		spoke.rotation.x = angle
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
	roll_angle = wrapf(roll_angle - signed_speed * delta / RADIUS, -PI, PI)
	roll.rotation.x = roll_angle
