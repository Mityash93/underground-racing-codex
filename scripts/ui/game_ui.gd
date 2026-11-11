class_name GameUI
extends CanvasLayer

signal start_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested

const ORANGE := Color("ff774d")
const CYAN := Color("38dce9")
var menu: Control
var hud: Control
var pause_panel: Control
var results: Control
var speed: Label
var stats: Label
var status: Label
var countdown_label: Label
var results_text: Label
var minimap: RaceMinimap
var _speed_bar: ProgressBar
var _fps: Label
var _gear: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 24
	for kind in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ea623b") if kind in ["hover", "pressed"] else Color("152437")
		style.border_color = ORANGE if kind == "focus" else Color("365369")
		style.set_border_width_all(2 if kind == "focus" else 1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 24
		style.content_margin_right = 24
		theme.set_stylebox(kind, "Button", style)
	root.theme = theme
	menu = _layer(root)
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.028, 0.05, 0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 780
	menu.add_child(shade)
	var menu_box := _vbox(menu, Vector2(110, 145), Vector2(610, 760))
	_label(menu_box, "SL / ORIGINAL STREET RACING", 22, CYAN)
	_label(menu_box, "STREET\nLEGENDS", 102, Color.WHITE)
	_label(menu_box, "THE CITY IS YOUR STARTING GRID.", 22, ORANGE)
	_space(menu_box, 24)
	_label(menu_box, "NEON DISTRICT  /  NIGHT RUN\n2 LAPS  ·  SOLO TIME ATTACK", 24, Color("adc1d3"))
	_space(menu_box, 24)
	_button(menu_box, "START RACE   →", func(): start_requested.emit())
	_button(menu_box, "QUIT", func(): get_tree().quit())
	_label(menu_box, "WASD / ARROWS  •  SPACE TO DRIFT", 19, Color("9bb1c3"))
	var version := _label(menu, "PROTOTYPE 01     //     BUILT FOR THE NIGHT", 18, Color("9cb5c7"))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(110, 1020)
	hud = _layer(root)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _panel(hud, Vector2(52, 40), Vector2(690, 126))
	stats = _label(top, "", 30)
	stats.position = Vector2(24, 16)
	status = _label(top, "NEON DISTRICT", 19, CYAN)
	status.position = Vector2(24, 82)
	var pause_button := Button.new()
	pause_button.text = "Ⅱ   PAUSE"
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -244
	pause_button.offset_right = -52
	pause_button.offset_top = 40
	pause_button.offset_bottom = 100
	pause_button.pressed.connect(func(): pause_requested.emit())
	hud.add_child(pause_button)
	var speed_card := PanelContainer.new()
	speed_card.add_theme_stylebox_override("panel", _style())
	hud.add_child(speed_card)
	speed_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_card.offset_left = -400
	speed_card.offset_right = -52
	speed_card.offset_top = -238
	speed_card.offset_bottom = -48
	var speed_box := VBoxContainer.new()
	speed_card.add_child(speed_box)
	speed = _label(speed_box, "000", 88, Color.WHITE)
	_gear = _label(speed_box, "KM/H     /     GEAR 1", 18, ORANGE)
	_speed_bar = ProgressBar.new()
	_speed_bar.custom_minimum_size = Vector2(290, 8)
	_speed_bar.max_value = 225.0
	_speed_bar.show_percentage = false
	speed_box.add_child(_speed_bar)
	minimap = RaceMinimap.new()
	hud.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 52
	minimap.offset_right = 330
	minimap.offset_top = -275
	minimap.offset_bottom = -55
	var help := _label(hud, "WASD / ARROWS   DRIVE     SPACE   DRIFT     R   RECOVER +5s     C   CAMERA     M   SOUND     ESC   PAUSE", 18, Color("aac1d2"))
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -530
	help.offset_top = -38
	help.offset_right = 650
	help.offset_bottom = -8
	_fps = _label(hud, "", 16, Color("9fb4c6"))
	_fps.position = Vector2(54, 176)
	countdown_label = _label(hud, "", 120, ORANGE)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.offset_left = -420
	countdown_label.offset_top = -170
	countdown_label.offset_right = 420
	countdown_label.offset_bottom = 0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel = _modal(root)
	var pause_box := _vbox(pause_panel, Vector2(690, 240), Vector2(540, 600))
	_label(pause_box, "RACE PAUSED", 56)
	_label(pause_box, "TAKE A BREATH. THEN TAKE THE CORNER.", 18, CYAN)
	_space(pause_box, 26)
	_button(pause_box, "RESUME", func(): resume_requested.emit())
	_button(pause_box, "RESTART RACE", func(): restart_requested.emit())
	_button(pause_box, "MAIN MENU", func(): menu_requested.emit())
	_button(pause_box, "QUIT", func(): get_tree().quit())
	results = _modal(root)
	var result_box := _vbox(results, Vector2(600, 200), Vector2(720, 700))
	_label(result_box, "NIGHT RUN / COMPLETE", 24, CYAN)
	_label(result_box, "FINISH LINE.", 72, ORANGE)
	results_text = _label(result_box, "", 30)
	_space(result_box, 25)
	_button(result_box, "RACE AGAIN", func(): restart_requested.emit())
	_button(result_box, "MAIN MENU", func(): menu_requested.emit())
	show_menu()

func update_race(car: ArcadeCar, race: RaceManager) -> void:
	var reverse := car.linear_velocity.dot(-car.global_basis.z) < -0.6
	_gear.text = "KM/H     /     %s" % ("REVERSE" if reverse else "GEAR %d" % car.engine.current_gear)
	speed.text = "%03d" % roundi(car.speed_kmh)
	_speed_bar.value = car.speed_kmh
	stats.text = "LAP  %d / %d       %s" % [race.lap, race.total_laps, RaceManager.format_time(race.elapsed)]
	status.text = "GATE %02d / %02d    /    LAP %s" % [race.next_checkpoint if race.next_checkpoint > 0 else 12, 12, RaceManager.format_time(race.lap_time)]
	_fps.text = "%d FPS  /  %s" % [Engine.get_frames_per_second(), "DRIFT" if car.drift_blend > 0.15 or absf(car.slip_angle) > 9.0 and car.speed_kmh > 25.0 else "NEON DISTRICT"]
	countdown_label.text = str(ceili(race.countdown)) if race.state == RaceManager.State.COUNTDOWN else ("GO" if race.state == RaceManager.State.RUNNING and race.elapsed < 0.85 else "")

func show_menu() -> void:
	menu.show()
	hud.hide()
	pause_panel.hide()
	results.hide()

func show_race() -> void:
	menu.hide()
	hud.show()
	pause_panel.hide()
	results.hide()

func show_results(race: RaceManager) -> void:
	results_text.text = "TOTAL    %s\nBEST LAP    %s\n\nLAP 1    %s\nLAP 2    %s\nRECOVERIES    %d  (+5s each, included)" % [RaceManager.format_time(race.elapsed), RaceManager.format_time(race.best_lap), RaceManager.format_time(race.lap_times[0]), RaceManager.format_time(race.lap_times[1]), race.recoveries]
	results.show()

func _layer(parent: Node) -> Control:
	var control := Control.new()
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

func _modal(parent: Node) -> Control:
	var control := _layer(parent)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.045, 0.94)
	control.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control

func _vbox(parent: Node, at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	parent.add_child(box)
	box.position = at
	box.size = dimensions
	box.add_theme_constant_override("separation", 14)
	return box

func _label(parent: Node, text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	parent.add_child(button)

func _space(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.90)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _panel(parent: Node, at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	panel.position = at
	panel.size = dimensions
	return panel
