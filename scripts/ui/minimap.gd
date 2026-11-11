class_name RaceMinimap
extends Control

var track: CityTrack
var car: ArcadeCar
var race: RaceManager
var _background: StyleBoxFlat

func _ready() -> void:
	_background = StyleBoxFlat.new()
	_background.bg_color = Color(0.025, 0.045, 0.075, 0.88)
	_background.set_corner_radius_all(12)

func _process(_delta: float) -> void:
	queue_redraw()

func _map(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) * 0.38 + size / 2.0

func _draw() -> void:
	if not is_instance_valid(track):
		return
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	var line := PackedVector2Array()
	for point in track.points:
		line.append(_map(point))
	line.append(line[0])
	draw_polyline(line, Color("304559"), 9.0, true)
	draw_polyline(line, Color("8bafc3"), 2.0, true)
	if is_instance_valid(race):
		draw_circle(_map(track.checkpoints[race.next_checkpoint].origin), 6.0, Color("ff794d"))
	if is_instance_valid(car):
		var at := _map(car.global_position)
		var f := -car.global_basis.z
		var direction := Vector2(f.x, f.z).normalized()
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([at + direction * 9.0, at - direction * 5.0 + side * 5.0, at - direction * 5.0 - side * 5.0]), Color("30e0ed"))

