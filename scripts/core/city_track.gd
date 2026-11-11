class_name CityTrack
extends Node3D
## Smooth closed circuit. Road and props are batched; barrier colliders are simple boxes.

const ROAD_WIDTH := 24.0
const SAMPLES_PER_CORNER := 24
const CHECKPOINT_COUNT := 12
var points := PackedVector3Array()
var distances := PackedFloat32Array()
var track_length := 0.0
var checkpoints: Array[Transform3D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 481516
	_build_path()
	_build_surface()
	_build_streetscape()
	CityDetails.build(self, points)
	_build_city()
	_build_start()

func _build_path() -> void:
	var anchors := PackedVector3Array([
		Vector3(0, 0, 180), Vector3(-155, 0, 170), Vector3(-235, 0, 65),
		Vector3(-205, 0, -95), Vector3(-75, 0, -175), Vector3(110, 0, -160),
		Vector3(225, 0, -45), Vector3(205, 0, 95)])
	for i in anchors.size():
		for j in SAMPLES_PER_CORNER:
			var t := float(j) / SAMPLES_PER_CORNER
			var a := anchors[posmod(i - 1, anchors.size())]
			var b := anchors[i]
			var c := anchors[(i + 1) % anchors.size()]
			var d := anchors[(i + 2) % anchors.size()]
			points.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
	distances.append(0.0)
	for i in points.size():
		track_length += points[i].distance_to(points[(i + 1) % points.size()])
		distances.append(track_length)
	for i in CHECKPOINT_COUNT:
		checkpoints.append(transform_at(track_length * i / CHECKPOINT_COUNT))

func transform_at(distance: float) -> Transform3D:
	var wrapped := fposmod(distance, track_length)
	for i in points.size():
		if wrapped <= distances[i + 1]:
			var next := (i + 1) % points.size()
			var fraction := (wrapped - distances[i]) / (distances[i + 1] - distances[i])
			var forward := (points[next] - points[i]).normalized()
			return Transform3D(Basis.looking_at(forward, Vector3.UP), points[i].lerp(points[next], fraction) + Vector3.UP * 0.13)
	return Transform3D.IDENTITY

func nearest_distance(at: Vector3) -> float:
	var best := INF
	var result := 0.0
	for i in points.size():
		var segment := points[(i + 1) % points.size()] - points[i]
		var t := clampf((at - points[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var squared := at.distance_squared_to(points[i] + segment * t)
		if squared < best:
			best = squared
			result = lerpf(distances[i], distances[i + 1], t)
	return fposmod(result, track_length)

func grid_transform() -> Transform3D:
	var grid := transform_at(0.0)
	# This transform describes tire contact on the visible asphalt, not the body origin.
	grid.origin.y = 0.018
	return grid

func _build_surface() -> void:
	GameGeometry.box(self, Vector3(1300, 2, 1300), Vector3(0, -1.04, 0), GameGeometry.material(Color("111d27")))
	GameGeometry.collider(self, Vector3(1300, 2, 1300), Vector3(0, -1, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var next := (i + 1) % points.size()
		var side_a := (points[next] - points[posmod(i - 1, points.size())]).normalized().cross(Vector3.UP)
		var side_b := (points[(i + 2) % points.size()] - points[i]).normalized().cross(Vector3.UP)
		var a := points[i] - side_a * ROAD_WIDTH / 2.0 + Vector3.UP * 0.018
		var b := points[i] + side_a * ROAD_WIDTH / 2.0 + Vector3.UP * 0.018
		var c := points[next] - side_b * ROAD_WIDTH / 2.0 + Vector3.UP * 0.018
		var d := points[next] + side_b * ROAD_WIDTH / 2.0 + Vector3.UP * 0.018
		for vertex in [a, b, c, b, d, c]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	var asphalt := ShaderMaterial.new()
	asphalt.shader = load("res://assets/materials/asphalt.gdshader")
	road.material_override = asphalt
	add_child(road)

func _build_streetscape() -> void:
	var concrete: Array[Transform3D] = []
	var cyan: Array[Transform3D] = []
	var orange: Array[Transform3D] = []
	var markings: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var direction := (q - p).normalized()
		var side := direction.cross(Vector3.UP)
		var center := (p + q) / 2.0
		var yaw := atan2(-direction.x, -direction.z)
		var length := p.distance_to(q)
		for sign_side in [-1.0, 1.0]:
			var edge: Vector3 = center + side * sign_side * (ROAD_WIDTH / 2.0 + 0.6)
			concrete.append(GameGeometry.box_transform(edge + Vector3.UP * 0.48, Vector3(0.8, 0.96, length + 0.18), yaw))
			GameGeometry.collider(self, Vector3(0.8, 1.1, length + 0.18), edge + Vector3.UP * 0.55, yaw)
			var strips := cyan if sign_side < 0 else orange
			strips.append(GameGeometry.box_transform(edge + Vector3.UP * 1.01, Vector3(0.85, 0.055, length), yaw))
			markings.append(GameGeometry.box_transform(center + side * sign_side * 10.8 + Vector3.UP * 0.038, Vector3(0.13, 0.025, length + 0.05), yaw))
		if i % 2 == 0:
			markings.append(GameGeometry.box_transform(center + Vector3.UP * 0.04, Vector3(0.16, 0.025, length * 0.58), yaw))
		if i % 6 == 0:
			var lamp_at := p + side * 14.4
			poles.append(GameGeometry.box_transform(lamp_at + Vector3.UP * 5.2, Vector3(0.18, 10.4, 0.18)))
			poles.append(GameGeometry.box_transform(lamp_at - side * 1.7 + Vector3.UP * 10.3, Vector3(3.6, 0.14, 0.18), yaw))
			lamps.append(GameGeometry.box_transform(lamp_at - side * 3.2 + Vector3.UP * 10.15, Vector3(1.0, 0.12, 0.7), yaw))
			if i % 18 == 0:
				var light := OmniLight3D.new()
				light.position = lamp_at - side * 3.5 + Vector3.UP * 8.7
				light.light_color = Color("a9cfff")
				light.light_energy = 3.5
				light.omni_range = 26.0
				light.shadow_enabled = false
				add_child(light)
	GameGeometry.batch_boxes(self, concrete, GameGeometry.material(Color("3a4657")))
	GameGeometry.batch_boxes(self, cyan, GameGeometry.material(Color("1fd7eb"), 1.7))
	GameGeometry.batch_boxes(self, orange, GameGeometry.material(Color("ff673b"), 1.5))
	GameGeometry.batch_boxes(self, markings, GameGeometry.material(Color("a1bacb"), 0.12))
	GameGeometry.batch_boxes(self, poles, GameGeometry.material(Color("27384a")))
	GameGeometry.batch_boxes(self, lamps, GameGeometry.material(Color("c2e9ff"), 2.2))

func _build_city() -> void:
	var towers: Array[Transform3D] = []
	var brick_towers: Array[Transform3D] = []
	var pale_towers: Array[Transform3D] = []
	var warm_windows: Array[Transform3D] = []
	var shopfronts: Array[Transform3D] = []
	var awnings: Array[Transform3D] = []
	var equipment: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	var rooftops: Array[Transform3D] = []
	for i in range(0, points.size(), 4):
		var direction := (points[(i + 1) % points.size()] - points[i]).normalized()
		var side := direction.cross(Vector3.UP)
		var yaw := atan2(-direction.x, -direction.z)
		for side_sign in [-1.0, 1.0]:
			var height := _rng.randf_range(14, 65)
			var width := _rng.randf_range(12, 22)
			var at: Vector3 = points[i] + side * side_sign * _rng.randf_range(36, 48)
			var tower := GameGeometry.box_transform(at + Vector3.UP * height / 2.0, Vector3(width, height, 17), yaw)
			var variant := (int(i / 4) + int(side_sign)) % 3
			if variant == 0:
				towers.append(tower)
			elif variant == 1:
				brick_towers.append(tower)
			else:
				pale_towers.append(tower)
			var facade: Vector3 = at - side * side_sign * (width / 2.0 + 0.06)
			shopfronts.append(GameGeometry.box_transform(facade + Vector3.UP * 1.9, Vector3(0.10, 2.7, 12.8), yaw))
			awnings.append(GameGeometry.box_transform(facade - side * side_sign * 0.55 + Vector3.UP * 3.7, Vector3(1.3, 0.24, 13.8), yaw))
			equipment.append(GameGeometry.box_transform(at + Vector3.UP * (height + 1.0), Vector3(width * 0.30, 2.0, 4.5), yaw))
			if i % 24 == 0 and side_sign > 0:
				var sign := Label3D.new()
				sign.text = ["НОЧНОЙ ФИЛИН", "ГАРАЖ АПЕКС", "24 / МАРКЕТ", "ПОСЛЕ ЗАКАТА"][int(i / 24) % 4]
				sign.font_size = 64
				sign.pixel_size = 0.012
				sign.modulate = Color("edb76f")
				sign.position = facade - side * side_sign * 0.13 + Vector3.UP * 2.5
				sign.basis = Basis.looking_at(side * side_sign, Vector3.UP)
				add_child(sign)
			GameGeometry.collider(self, Vector3(width, height, 17), at + Vector3.UP * height / 2.0, yaw)
			rooftops.append(GameGeometry.box_transform(at + Vector3.UP * (height + 0.12), Vector3(width + 0.1, 0.15, 17.1), yaw))
			for floor_index in range(2, int(height / 3.2)):
				for column in [-1.0, 0.0, 1.0]:
					if _rng.randf() < 0.3:
						continue
					var window_at: Vector3 = at - side * side_sign * (width / 2.0 + 0.03) + direction * column * 4.8 + Vector3.UP * floor_index * 3.2
					var window := GameGeometry.box_transform(window_at, Vector3(0.05, 1.1, 2.0), yaw)
					if (floor_index + i) % 3 == 0:
						warm_windows.append(window)
					else:
						windows.append(window)
	GameGeometry.batch_boxes(self, towers, GameGeometry.material(Color("18293b")))
	GameGeometry.batch_boxes(self, brick_towers, GameGeometry.material(Color("3b3036")))
	GameGeometry.batch_boxes(self, pale_towers, GameGeometry.material(Color("33434d")))
	GameGeometry.batch_boxes(self, warm_windows, GameGeometry.material(Color("c69c6b"), 0.65))
	GameGeometry.batch_boxes(self, shopfronts, GameGeometry.material(Color("204557"), 0.35))
	GameGeometry.batch_boxes(self, awnings, GameGeometry.material(Color("263644")))
	GameGeometry.batch_boxes(self, equipment, GameGeometry.material(Color("334453")))
	GameGeometry.batch_boxes(self, windows, GameGeometry.material(Color("649fb9"), 0.8))
	GameGeometry.batch_boxes(self, rooftops, GameGeometry.material(Color("236c8c"), 0.5))
	for i in [12, 48, 84, 120, 156]:
		var transform_here := transform_at(distances[i])
		var billboard := Node3D.new()
		add_child(billboard)
		billboard.transform = transform_here
		GameGeometry.box(billboard, Vector3(12, 5, 0.3), Vector3(20, 8, 0), GameGeometry.material(Color("0b1828")))
		var text := Label3D.new()
		text.text = ["ПОЛУНОЧЬ / 01", "ПОСЛЕ ЗАКАТА", "НЕОНОВЫЙ РАЙОН", "УЛИЧНЫЕ ЛЕГЕНДЫ", "БЕЗ ОГРАНИЧЕНИЙ"][int(i / 36)]
		text.font_size = 62
		text.pixel_size = 0.012
		text.modulate = Color("37d7ec")
		text.position = Vector3(20, 8, 0.2)
		billboard.add_child(text)

func _build_start() -> void:
	var start := Node3D.new()
	add_child(start)
	start.transform = transform_at(0.0)
	var white := GameGeometry.material(Color("d8e5e8"))
	var black := GameGeometry.material(Color("111720"))
	for x in 24:
		for z in 3:
			GameGeometry.box(start, Vector3(1.0, 0.025, 0.7), Vector3(x - 11.5, -0.095, -z * 0.7), white if (x + z) % 2 == 0 else black)
	var dark := GameGeometry.material(Color("1b2d40"))
	for x in [-13, 13]:
		GameGeometry.box(start, Vector3(0.6, 8, 0.6), Vector3(x, 4, 0), dark)
	GameGeometry.box(start, Vector3(27, 1.5, 0.6), Vector3(0, 8, 0), dark)
	var title := Label3D.new()
	title.text = "УЛИЧНЫЕ ЛЕГЕНДЫ   //   НОЧНОЙ ЗАЕЗД"
	title.font_size = 80
	title.pixel_size = 0.008
	title.position = Vector3(0, 8, 0.34)
	title.modulate = Color("ff7847")
	start.add_child(title)
