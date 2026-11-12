extends SceneTree
## Track geometry and actual physics corridor checks, no mocked collision world.
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await physics_frame
	var track: CityTrack = main.track
	print("TRACK LENGTH: %.2f m; %d samples" % [track.track_length, track.points.size()])
	check(track.track_length > 2400 and track.track_length < 2700, "circuit is more than 2.4 km and closed")
	check(track.transform_at(0).origin.is_equal_approx(track.transform_at(track.track_length).origin), "start/end wrap is seamless")
	var straight := true
	var start := track.transform_at(0)
	for distance in range(0, 301, 10):
		var pose := track.transform_at(distance)
		straight = straight and absf((pose.origin - start.origin).dot(start.basis.x)) < 0.02 and pose.basis.z.dot(start.basis.z) > 0.999
	check(straight, "first 300 m is a true straight for nitro and tunnel")
	var min_separation := INF
	for i in track.points.size():
		for j in range(i + 1, track.points.size()):
			var gap := absf(track.distances[i] - track.distances[j])
			gap = minf(gap, track.track_length - gap)
			if gap > 110.0:
				min_separation = minf(min_separation, track.points[i].distance_to(track.points[j]))
	check(min_separation > 65.0, "non-neighboring road sections have no overlap")
	var left := false
	var right := false
	for d in range(int(track.anchor_distance(7)), int(track.anchor_distance(9)), 10):
		var angle := (-track.transform_at(d).basis.z).signed_angle_to(-track.transform_at(d + 20).basis.z, Vector3.UP)
		left = left or angle > 0.04
		right = right or angle < -0.04
	check(left and right, "wave section has both left and right bends")
	check(track.district_at(track.anchor_distance(5)) == 1 and track.district_at(track.anchor_distance(11)) == 2 and track.district_at(0) == 0, "three distinct districts along route")
	check(track.in_tunnel(170) and not track.in_tunnel(30) and track.section_name(170).contains("ТОННЕЛЬ"), "tunnel location and HUD name")
	var space := track.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.95, 1.1, 4.25)
	var corridor_clear := true
	var exclusions: Array[RID] = [main.car.get_rid(), main.rival.get_rid()]
	for i in track.points.size():
		var pose := track.transform_at(track.distances[i])
		for lane in [-9.0, 0.0, 9.0]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = pose.translated(pose.basis.x * lane + Vector3.UP * 0.6)
			query.exclude = exclusions
			var hits := space.intersect_shape(query, 1)
			if not hits.is_empty():
				corridor_clear = false
				print("BLOCKED: %.1f m, lane %.0f, %s" % [track.distances[i], lane, hits[0].collider.name])
	check(corridor_clear, "full physical car fits three lanes around entire circuit, under tunnel and portals")
	var tunnel_pose := track.transform_at(170)
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(tunnel_pose.origin + Vector3.UP, tunnel_pose.origin + Vector3.UP * 15))
	check(not roof.is_empty() and absf(roof.position.y - 8.0) < 0.1, "tunnel ceiling has physical collision and 8 m clearance")
	var camera_query := PhysicsRayQueryParameters3D.create(tunnel_pose.origin + Vector3.UP * 1.15, tunnel_pose.origin + tunnel_pose.basis.z * 9 + Vector3.UP * 3.65)
	check(space.intersect_ray(camera_query).is_empty(), "default chase camera fits inside tunnel")
	check(track.has_node("ImpulseTunnel") and track.has_node("IskraWorks") and track.has_node("FreightYard") and track.has_node("NorthHarborWater") and track.has_node("HarborBeacon"), "district landmark geometry exists")
	var lights := track.find_children("*", "OmniLight3D", true, false)
	check(lights.size() <= 14, "local track light budget stays at 14 without added shadows")
	for light in lights:
		check(not light.shadow_enabled, "district point light has no shadow")
	var all_inside := true
	for point in track.points:
		var on_map: Vector2 = main.ui.minimap._map(point)
		all_inside = all_inside and Rect2(Vector2(15, 15), main.ui.minimap.size - Vector2(30, 30)).has_point(on_map)
	check(all_inside, "new circuit fits minimap without clipping")
	var records := RaceRecords.new()
	records.path = "res://tests/artifacts/old_track_records.cfg"
	var old := ConfigFile.new()
	old.set_value("neon_v1_nitro_v1_2_laps_1", "race", 65.0)
	old.save(records.path)
	records.select_event(1, 2)
	check(is_inf(records.best_time), "old circuit records do not compete with new route")
	main.queue_free()
	await process_frame
	print("TRACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
