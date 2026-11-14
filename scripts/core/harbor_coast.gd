class_name HarborCoast
extends RefCounted
## Matching coastline for the visual ground cutout and the lower water surface.
const WATER_Y := -1.45
const SHORE_DISTANCE := 27.4
const WATER_START := 26.4
const WATER_EXTENT := 1800.0
const GROUND_EXTENT := 1300.0

static func water_polygon(track: CityTrack) -> PackedVector2Array:
	var near_edge := PackedVector2Array()
	var far_edge := PackedVector2Array()
	for i in range(9 * CityTrack.SAMPLES_PER_CORNER, 14 * CityTrack.SAMPLES_PER_CORNER + 1):
		var p := track.points[i % track.points.size()]
		var before := track.points[posmod(i - 1, track.points.size())]
		var after := track.points[(i + 1) % track.points.size()]
		var outside := -(after - before).normalized().cross(Vector3.UP)
		var near_point := p + outside * SHORE_DISTANCE
		var far_point := p + outside * WATER_EXTENT
		near_edge.append(Vector2(near_point.x, near_point.z))
		far_edge.append(Vector2(far_point.x, far_point.z))
	far_edge.reverse()
	near_edge.append_array(far_edge)
	return near_edge

static func ground_material(track: CityTrack) -> ShaderMaterial:
	# One scanline-rasterized static mask; no per-frame shoreline search or readback.
	const SIZE := 1024
	var polygon := water_polygon(track)
	for i in polygon.size():
		polygon[i] = (polygon[i] / GROUND_EXTENT + Vector2.ONE * 0.5) * SIZE
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for row in SIZE:
		var y := row + 0.5
		var intersections: Array[float] = []
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				intersections.append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		for i in range(0, intersections.size() - 1, 2):
			for column in range(maxi(0, ceili(intersections[i] - 0.5)), mini(SIZE, ceili(intersections[i + 1] - 0.5))):
				image.set_pixel(column, row, Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/coastal_ground.gdshader")
	material.set_shader_parameter("coast_mask", ImageTexture.create_from_image(image))
	return material
