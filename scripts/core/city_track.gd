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
var map_bounds := Rect2()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 481516
	_build_path()
	_build_surface()
	_build_streetscape()
	CityDetails.build(self, points)
	_build_city()
	_build_start()
	CityDistricts.build(self)
	StreetShowcase.build(self)
	LanternQuarter.build(self)

func _build_path() -> void:
	points.clear()
	distances.clear()
	checkpoints.clear()
	track_length = 0.0
	var anchors := PackedVector3Array(TrackLayout.ANCHORS)
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
	map_bounds = Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for point in points:
		map_bounds = map_bounds.expand(Vector2(point.x, point.z))
	for i in CHECKPOINT_COUNT:
		checkpoints.append(transform_at(track_length * i / CHECKPOINT_COUNT))

func district_at(distance: float) -> int:
	var wrapped := fposmod(distance, track_length)
	if wrapped >= anchor_distance(4) and wrapped < anchor_distance(9):
		return 1
	if wrapped >= anchor_distance(9) and wrapped < anchor_distance(14):
		return 2
	return 0

func anchor_distance(index: int) -> float:
	return distances[index * SAMPLES_PER_CORNER]

func in_tunnel(distance: float) -> bool:
	var wrapped := fposmod(distance, track_length)
	return wrapped >= TrackLayout.TUNNEL_START and wrapped <= TrackLayout.TUNNEL_END

func section_name(distance: float) -> String:
	if in_tunnel(distance):
		return "ТОННЕЛЬ «ПОРТОВЫЙ»"
	var wrapped := fposmod(distance, track_length)
	if wrapped >= anchor_distance(7) and wrapped < anchor_distance(9):
		return "СВЯЗКА «ВОЛНА»"
	return TrackLayout.NAMES[district_at(distance)]

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
	var ground := GameGeometry.box(self, Vector3(1300, 2, 1300), Vector3(0, -1.04, 0), HarborCoast.ground_material(self))
	ground.name = "CoastalGround"
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
	road.name = "RoadSurface"
	road.mesh = st.commit()
	road.material_override = load("res://resources/road_asphalt.tres")
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
			if not LanternQuarter.contains(distances[i]):
				strips.append(GameGeometry.box_transform(edge + Vector3.UP * 1.01, Vector3(0.12, 0.035, length), yaw))
			markings.append(GameGeometry.box_transform(center + side * sign_side * 10.8 + Vector3.UP * 0.038, Vector3(0.13, 0.025, length + 0.05), yaw))
		if i % 2 == 0:
			markings.append(GameGeometry.box_transform(center + Vector3.UP * 0.04, Vector3(0.16, 0.025, length * 0.58), yaw))
		if i % 6 == 0 and not in_tunnel(distances[i]):
			var lamp_at := p + side * 14.4
			poles.append(GameGeometry.box_transform(lamp_at + Vector3.UP * 5.2, Vector3(0.18, 10.4, 0.18)))
			poles.append(GameGeometry.box_transform(lamp_at - side * 1.7 + Vector3.UP * 10.3, Vector3(3.6, 0.14, 0.18), yaw))
			lamps.append(GameGeometry.box_transform(lamp_at - side * 3.2 + Vector3.UP * 10.15, Vector3(1.0, 0.12, 0.7), yaw))
			if i % 36 == 0:
				var light := OmniLight3D.new()
				light.position = lamp_at - side * 3.5 + Vector3.UP * 8.7
				light.light_color = Color("a9cfff")
				light.light_energy = 3.5
				light.omni_range = 26.0
				light.shadow_enabled = false
				add_child(light)
	GameGeometry.batch_boxes(self, concrete, StreetShowcase.concrete_material())
	GameGeometry.batch_boxes(self, cyan, GameGeometry.material(Color("1fd7eb"), 0.8))
	GameGeometry.batch_boxes(self, orange, GameGeometry.material(Color("ff673b"), 0.7))
	GameGeometry.batch_boxes(self, markings, GameGeometry.material(Color("a1bacb"), 0.12))
	GameGeometry.batch_boxes(self, poles, GameGeometry.material(Color("27384a")))
	GameGeometry.batch_boxes(self, lamps, GameGeometry.material(Color("c2e9ff"), 2.2))

func _build_city() -> void:
	CityArchitecture.build(self)

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
