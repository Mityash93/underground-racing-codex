class_name GameUI
extends CanvasLayer

signal start_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal music_toggled(enabled: bool)
signal music_volume_changed(volume: float)
signal custom_music_requested
signal default_music_requested

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
var place: Label
var result_title: Label
var results_text: Label
var minimap: RaceMinimap
var _speed_bar: ProgressBar
var _fps: Label
var _gear: Label
var _music_panel: PanelContainer
var _music_title: Label
var _music_toggle: CheckButton
var _music_volume: HSlider

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
	_label(menu_box, "УЛ / УЛИЧНЫЕ ГОНКИ", 22, CYAN)
	_label(menu_box, "УЛИЧНЫЕ\nЛЕГЕНДЫ", 88, Color.WHITE)
	_label(menu_box, "Город — твоя стартовая решётка.", 22, ORANGE)
	_space(menu_box, 24)
	_label(menu_box, "НЕОНОВЫЙ РАЙОН / НОЧНОЙ ЗАЕЗД\n2 КРУГА · ДУЭЛЬ С AI «ВЕКТОР»", 24, Color("adc1d3"))
	_space(menu_box, 24)
	_button(menu_box, "НАЧАТЬ ЗАЕЗД   →", func(): start_requested.emit())
	_button(menu_box, "ВЫХОД", func(): get_tree().quit())
	_label(menu_box, "WASD / СТРЕЛКИ · ПРОБЕЛ — ЗАНОС", 19, Color("9bb1c3"))
	var version := _label(menu, "ПРОТОТИП 01     //     РОЖДЁННЫЙ ДЛЯ НОЧИ", 18, Color("9cb5c7"))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(110, 1020)
	hud = _layer(root)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _panel(hud, Vector2(52, 40), Vector2(760, 170))
	stats = _label(top, "", 30)
	stats.position = Vector2(24, 16)
	status = _label(top, "НЕОНОВЫЙ РАЙОН", 19, CYAN)
	status.position = Vector2(24, 82)
	place = _label(top, "", 24, ORANGE)
	place.position = Vector2(24, 117)
	var pause_button := Button.new()
	pause_button.text = "Ⅱ   ПАУЗА"
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
	_gear = _label(speed_box, "КМ/Ч     /     ПЕРЕДАЧА 1", 18, ORANGE)
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
	var help := _label(hud, "WASD / СТРЕЛКИ — УПРАВЛЕНИЕ · ПРОБЕЛ — ЗАНОС · R — ВОЗВРАТ (+5 с)\nC — КАМЕРА · M — МОТОР · N — МУЗЫКА · ESC — ПАУЗА", 16, Color("aac1d2"))
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -650
	help.offset_top = -50
	help.offset_right = 650
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.offset_bottom = -8
	_fps = _label(hud, "", 16, Color("9fb4c6"))
	_fps.position = Vector2(54, 224)
	countdown_label = _label(hud, "", 120, ORANGE)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.offset_left = -420
	countdown_label.offset_top = -170
	countdown_label.offset_right = 420
	countdown_label.offset_bottom = 0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel = _modal(root)
	var pause_box := _vbox(pause_panel, Vector2(690, 240), Vector2(540, 600))
	_label(pause_box, "ПАУЗА", 56)
	_label(pause_box, "ПЕРЕДОХНИ — И СНОВА НА ТРАССУ.", 18, CYAN)
	_space(pause_box, 26)
	_button(pause_box, "ПРОДОЛЖИТЬ", func(): resume_requested.emit())
	_button(pause_box, "НАЧАТЬ ЗАНОВО", func(): restart_requested.emit())
	_button(pause_box, "ГЛАВНОЕ МЕНЮ", func(): menu_requested.emit())
	_button(pause_box, "ВЫХОД", func(): get_tree().quit())
	results = _modal(root)
	var result_box := _vbox(results, Vector2(600, 200), Vector2(720, 700))
	_label(result_box, "НОЧНОЙ ЗАЕЗД ЗАВЕРШЁН", 24, CYAN)
	result_title = _label(result_box, "ФИНИШ!", 72, ORANGE)
	results_text = _label(result_box, "", 28)
	_space(result_box, 25)
	_button(result_box, "ЕЩЁ ОДИН ЗАЕЗД", func(): restart_requested.emit())
	_button(result_box, "ГЛАВНОЕ МЕНЮ", func(): menu_requested.emit())
	_build_music_panel(root)
	show_menu()

func _build_music_panel(root: Control) -> void:
	_music_panel = PanelContainer.new()
	_music_panel.add_theme_stylebox_override("panel", _style())
	root.add_child(_music_panel)
	_music_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_music_panel.offset_left = -660
	_music_panel.offset_right = -52
	_music_panel.offset_top = -285
	_music_panel.offset_bottom = -55
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_music_panel.add_child(box)
	_music_title = _label(box, "МУЗЫКА / НЕОНОВЫЙ ПУЛЬС", 20, CYAN)
	_music_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var settings := HBoxContainer.new()
	box.add_child(settings)
	_music_toggle = CheckButton.new()
	_music_toggle.text = "Музыка (N)"
	_music_toggle.button_pressed = true
	_music_toggle.add_theme_font_size_override("font_size", 20)
	_music_toggle.toggled.connect(func(value: bool): music_toggled.emit(value))
	settings.add_child(_music_toggle)
	_music_volume = HSlider.new()
	_music_volume.min_value = 0
	_music_volume.max_value = 100
	_music_volume.value = 55
	_music_volume.custom_minimum_size.x = 240
	_music_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_volume.tooltip_text = "Громкость музыки"
	_music_volume.value_changed.connect(func(value: float): music_volume_changed.emit(value / 100.0))
	settings.add_child(_music_volume)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for i in 2:
		var button := Button.new()
		button.text = "СВОЙ ТРЕК…" if i == 0 else "ВСТРОЕННЫЙ ТРЕК"
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size.y = 46
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			button.pressed.connect(func(): custom_music_requested.emit())
		else:
			button.pressed.connect(func(): default_music_requested.emit())
		buttons.add_child(button)
	_label(box, "OGG, MP3, WAV · файл остаётся на компьютере", 16, Color("9cb5c7"))

func _process(_delta: float) -> void:
	if is_instance_valid(_music_panel):
		_music_panel.visible = menu.visible or pause_panel.visible

func set_music_title(title: String) -> void:
	_music_title.text = "МУЗЫКА / " + title.to_upper()

func set_music_settings(enabled: bool, volume: float) -> void:
	_music_toggle.set_pressed_no_signal(enabled)
	_music_volume.set_value_no_signal(volume * 100.0)

func update_race(car: ArcadeCar, race: RaceManager) -> void:
	var reverse := car.linear_velocity.dot(-car.global_basis.z) < -0.6
	_gear.text = "КМ/Ч     /     %s" % ("ЗАДНИЙ ХОД" if reverse else "ПЕРЕДАЧА %d" % car.engine.current_gear)
	speed.text = "%03d" % roundi(car.speed_kmh)
	_speed_bar.value = car.speed_kmh
	stats.text = "КРУГ  %d / %d      %s" % [race.lap, race.total_laps, RaceManager.format_time(race.elapsed)]
	status.text = "ВОРОТА %02d / %02d   /   КРУГ %s" % [race.next_checkpoint if race.next_checkpoint > 0 else 12, 12, RaceManager.format_time(race.lap_time)]
	var gap := race.rival_gap_meters()
	place.text = "МЕСТО %d / 2 · ВЕКТОР %s %d м" % [race.player_position(), "ПОЗАДИ" if gap >= 0 else "ВПЕРЕДИ", roundi(absf(gap))] if race.is_duel() else "ЗАЕЗД НА ВРЕМЯ"
	_fps.text = "%d кадр/с  /  %s" % [Engine.get_frames_per_second(), "ЗАНОС" if car.drift_blend > 0.15 or absf(car.slip_angle) > 9.0 and car.speed_kmh > 25.0 else "НЕОНОВЫЙ РАЙОН"]
	countdown_label.text = str(ceili(race.countdown)) if race.state == RaceManager.State.COUNTDOWN else ("СТАРТ!" if race.state == RaceManager.State.RUNNING and race.elapsed < 0.85 else "")

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
	result_title.text = ("ПОБЕДА!" if race.winner == "player" else "ВЕКТОР ПОБЕДИЛ") if race.is_duel() else "ФИНИШ!"
	results_text.text = "ОБЩЕЕ ВРЕМЯ    %s\nЛУЧШИЙ КРУГ    %s\n\nКРУГ 1    %s\nКРУГ 2    %s\nВОЗВРАТОВ: %d  (штраф +5 с включён)" % [RaceManager.format_time(race.elapsed), RaceManager.format_time(race.best_lap), RaceManager.format_time(race.lap_times[0] if race.lap_times.size() > 0 else INF), RaceManager.format_time(race.lap_times[1] if race.lap_times.size() > 1 else INF), race.recoveries]
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
