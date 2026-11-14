extends SceneTree
## Actual Metal review of lowered water, vegetation, marina and driving view.
var main
var started_at := Time.get_ticks_msec()
func _initialize() -> void:
	_run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_at > 90000:
		push_error("Harbor art review exceeded wall time")
		quit(1)
	return false
func photo(title: String, distance: float, offset: Vector3, focus: Vector3, car_visible: bool = false) -> void:
	var pose: Transform3D = main.track.transform_at(distance)
	pose.origin.y = 0.018
	main.car.park_at(pose)
	main.car.visual.visible = car_visible
	main.camera.global_position = pose.origin + pose.basis * offset
	main.camera.look_at(pose.origin + pose.basis * focus)
	main.camera.fov = 58
	for i in 12:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/artifacts/harbor_" + title + ".png")
	print("CAPTURE: harbor_", title)
func _run() -> void:
	root.grab_focus()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.records.path = "res://tests/artifacts/harbor_records.cfg"
	main.music.set_enabled(false)
	main.in_menu = false
	main.camera.set_physics_process(false)
	main.ui.hide()
	await photo("drive_view", main.track.anchor_distance(11), Vector3(0, 2.8, 7.5), Vector3(0, 1.3, -32), true)
	await photo("marina", main.track.anchor_distance(10) + 80, Vector3(-29, 3.8, 16), Vector3(-45, -0.7, -2))
	await photo("walkway", main.track.anchor_distance(12), Vector3(-21, 2.0, 7), Vector3(-23.5, 2, -24))
	await photo("shore", main.track.anchor_distance(12) + 80, Vector3(-35, 0.8, 14), Vector3(-25, -0.1, -8))
	await photo("beacon", main.track.anchor_distance(11) + 35, Vector3(-33, 4, 12), Vector3(-72, 6, 0))
	main.queue_free()
	await process_frame
	quit()
