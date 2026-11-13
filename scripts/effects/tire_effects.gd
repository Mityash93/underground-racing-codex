class_name TireEffects
extends Node3D
## Fixed-size world-space skid ring and two tiny procedural smoke emitters.
const MAX_SEGMENTS := 384
const LIFETIME := 8.0
var car: ArcadeCar
var segment_count := 0
var _cursor := 0
var _clock := 0.0
var _interval := 0.0
var _born := PackedFloat32Array()
var _previous: Array[Vector3] = []
var _connected := false
var _marks: MultiMesh
var smoke: Array[GPUParticles3D] = []

func _ready() -> void:
	car = get_parent() as ArcadeCar
	top_level = true
	global_transform = Transform3D.IDENTITY
	_marks = MultiMesh.new()
	_marks.transform_format = MultiMesh.TRANSFORM_3D
	_marks.use_colors = true
	_marks.instance_count = MAX_SEGMENTS
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_marks.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.025, 0.023, 0.03, 0.62)
	mesh.material = material
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _marks
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_born.resize(MAX_SEGMENTS)
	_previous = [Vector3.ZERO, Vector3.ZERO]
	clear()
	if DisplayServer.get_name() != "headless":
		_build_smoke()

func _build_smoke() -> void:
	var shader := load("res://assets/materials/tire_smoke.gdshader")
	for i in 2:
		var emitter := GPUParticles3D.new()
		emitter.amount = 12
		emitter.lifetime = 0.65
		emitter.local_coords = false
		emitter.emitting = false
		emitter.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 6, 10))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = 38.0
		process.initial_velocity_min = 0.35
		process.initial_velocity_max = 1.2
		process.gravity = Vector3(0, 0.25, 0)
		process.scale_min = 0.35
		process.scale_max = 0.75
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		process.color_ramp = ramp
		emitter.process_material = process
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var material := ShaderMaterial.new()
		material.shader = shader
		quad.material = material
		emitter.draw_pass_1 = quad
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(emitter)
		smoke.append(emitter)

func clear() -> void:
	_connected = false
	segment_count = 0
	_cursor = 0
	for i in MAX_SEGMENTS:
		_born[i] = -LIFETIME
		_marks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	for emitter in smoke:
		emitter.emitting = false
		emitter.restart()

func break_trail() -> void:
	_connected = false
	for emitter in smoke:
		emitter.emitting = false

func _physics_process(delta: float) -> void:
	_clock += delta
	_interval += delta
	for i in MAX_SEGMENTS:
		if _born[i] > -LIFETIME:
			var fade := clampf(1.0 - (_clock - _born[i]) / LIFETIME, 0.0, 1.0)
			_marks.set_instance_color(i, Color(1, 1, 1, fade))
			if fade <= 0.0:
				_born[i] = -LIFETIME
				_marks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	var sliding := car.controls_enabled and not car.freeze and car.grounded and car.speed_kmh > 22.0 and (car.drift_blend > 0.2 or absf(car.slip_angle) > 12.0)
	for i in smoke.size():
		smoke[i].emitting = sliding
		smoke[i].global_position = car.global_transform * Vector3((-1.0 if i == 0 else 1.0) * car.visual.rear_half_track, 0.15, car.visual.rear_z)
	if not sliding:
		_connected = false
		return
	if _interval < 0.05:
		return
	_interval = 0.0
	var contacts: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var wheel := car.global_transform * Vector3(side * car.visual.rear_half_track, car.visual.wheel_y, car.visual.rear_z)
		var query := PhysicsRayQueryParameters3D.create(wheel, wheel - Vector3.UP * 0.9, 1, [car.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.9 or hit.collider is ArcadeCar:
			_connected = false
			return
		# Road mesh is 0.018 m above its flat collision plane.
		contacts.append(hit.position + Vector3.UP * 0.027)
	for i in 2:
		var distance := contacts[i].distance_to(_previous[i])
		if _connected and distance > 0.06 and distance < 4.0:
			var along := (contacts[i] - _previous[i]).normalized()
			var across := Vector3.UP.cross(along).normalized()
			var basis := Basis(across * 0.2, Vector3.UP * 0.008, along * distance)
			_marks.set_instance_transform(_cursor, Transform3D(basis, contacts[i].lerp(_previous[i], 0.5)))
			_marks.set_instance_color(_cursor, Color.WHITE)
			_born[_cursor] = _clock
			_cursor = (_cursor + 1) % MAX_SEGMENTS
			segment_count = mini(segment_count + 1, MAX_SEGMENTS)
		_previous[i] = contacts[i]
	_connected = true
