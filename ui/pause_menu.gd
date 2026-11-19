extends CanvasLayer
## Меню паузы (Esc): Продолжить / Настройки / Выйти в меню.
## Работает, когда игра на паузе (process_mode = ALWAYS).

var _root: Control
var _main: VBoxContainer
var _settings: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if SceneFlow.is_busy():
			return   # уже уходим в меню
		if get_tree().get_first_node_in_group("cutscene_playing"):
			return   # в катсцене Esc — пропуск (cinematics/cutscene.gd)
		var p := get_tree().get_first_node_in_group("player")
		if p and p.is_dead:
			return   # во время скримера пауза не открывается
		if _root.visible:
			if _settings.visible:
				_show_main()
			else:
				resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	get_tree().paused = true
	_root.visible = true
	_show_main()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	get_tree().paused = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_menu() -> void:
	# игра остаётся на паузе, пока экран темнеет; главное меню само снимает паузу
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneFlow.change_scene("res://ui/main_menu.tscn", 0.4, 0.0)   # меню проявляется само


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

	var panel := VBoxContainer.new()
	panel.set_script(preload("res://ui/settings_panel.gd"))
	_settings.add_child(panel)
	_settings.add_child(_button("Назад", _show_main))


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
