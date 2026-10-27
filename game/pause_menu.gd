extends CanvasLayer
## Меню паузы (Esc): Продолжить / Настройки / Выйти в меню.
## Работает, когда игра на паузе (process_mode = ALWAYS).

var _root: Control
var _main: VBoxContainer
var _settings: VBoxContainer
var _sens_label: Label
var _vol_label: Label
var _mouse_was_captured := true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _root.visible:
			if _settings.visible:
				_show_main()
			else:
				resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	get_tree().paused = true
	_root.visible = true
	_show_main()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	get_tree().paused = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _show_main() -> void:
	_main.visible = true
	_settings.visible = false


func _show_settings() -> void:
	_main.visible = false
	_settings.visible = true


# ---------------------------------------------------------------- UI

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	# --- главный экран паузы
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	box.add_child(_main)
	_main.add_child(_title("ПАУЗА"))
	_main.add_child(_button("Продолжить", resume))
	_main.add_child(_button("Настройки", _show_settings))
	_main.add_child(_button("Выйти в меню", _to_menu))

	# --- настройки
	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 12)
	box.add_child(_settings)
	_settings.add_child(_title("НАСТРОЙКИ"))

	_sens_label = _label("")
	_settings.add_child(_sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = Settings.mouse_sensitivity
	sens.value_changed.connect(func(v): Settings.set_mouse_sensitivity(v); _update_labels())
	_settings.add_child(sens)

	_vol_label = _label("")
	_settings.add_child(_vol_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.master_volume
	vol.value_changed.connect(func(v): Settings.set_master_volume(v); _update_labels())
	_settings.add_child(vol)

	_settings.add_child(_label("Управление: WASD — ходьба, Shift — бег, Ctrl — присед,\nSpace — прыжок, F — фонарик, E — действие, Esc — пауза"))
	_settings.add_child(_button("Назад", _show_main))
	_update_labels()


func _update_labels() -> void:
	_sens_label.text = "Чувствительность мыши: %d%%" % int(round(Settings.mouse_sensitivity / 0.002 * 100.0))
	_vol_label.text = "Громкость: %d%%" % int(round(Settings.master_volume * 100.0))


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	return l


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b
