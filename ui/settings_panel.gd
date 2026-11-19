extends VBoxContainer
## Блок настроек (чувствительность, громкость, полный экран).
## Используется и в меню паузы, и в главном меню.

var _sens_label: Label
var _vol_label: Label
var _full: CheckButton


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_sens_label = _label("")
	add_child(_sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = Settings.mouse_sensitivity
	sens.value_changed.connect(func(v): Settings.set_mouse_sensitivity(v); _update())
	add_child(sens)

	_vol_label = _label("")
	add_child(_vol_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.master_volume
	vol.value_changed.connect(func(v): Settings.set_master_volume(v); _update())
	add_child(vol)

	_full = CheckButton.new()
	_full.text = "Полный экран (F11)"
	_full.focus_mode = Control.FOCUS_NONE
	_full.add_theme_font_size_override("font_size", 18)
	_full.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	_full.button_pressed = Settings.fullscreen
	_full.toggled.connect(func(v): Settings.set_fullscreen(v))
	add_child(_full)
	Settings.changed.connect(_update)

	add_child(_label("Управление: WASD — ходьба, Shift — бег, Ctrl — присед,\nSpace — прыжок, F — фонарик, E — действие, Esc — пауза"))
	_update()


func _update() -> void:
	_sens_label.text = "Чувствительность мыши: %d%%" % int(round(Settings.mouse_sensitivity / 0.002 * 100.0))
	_vol_label.text = "Громкость: %d%%" % int(round(Settings.master_volume * 100.0))
	_full.set_pressed_no_signal(Settings.fullscreen)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	return l
