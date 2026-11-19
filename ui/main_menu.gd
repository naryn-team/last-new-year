extends Control
## Главное меню: Играть / Настройки / Выйти.
## Фон — ночь, снег и силуэт дома с одним светящимся окном (рисуется кодом в узле House).

@onready var _fade: ColorRect = $Fade
@onready var _snow: CPUParticles2D = $Snow
@onready var _house: Control = $House
@onready var _settings_box: PanelContainer = $SettingsBox
@onready var _buttons: VBoxContainer = $MarginContainer/VBoxContainer

var _starting := false
var _flicker := 1.0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for b in _buttons.get_children():
		if b is Button:
			_style_button(b)
	_build_settings()
	_house.draw.connect(_draw_house)
	resized.connect(_layout)
	_layout()
	# плавное появление
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)


func _process(delta: float) -> void:
	# окно в доме слегка мерцает, как от свечи
	_flicker = lerp(_flicker, randf_range(0.75, 1.0), delta * 6.0)
	_house.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause", true) and _settings_box.visible:
		_settings_box.visible = false


func _layout() -> void:
	_snow.position = Vector2(size.x / 2.0, -10)
	_snow.emission_rect_extents = Vector2(size.x / 2.0 + 100, 1)
	_house.queue_redraw()


func _on_start_button_pressed() -> void:
	if _starting:
		return
	_starting = true
	SceneFlow.session.clear()   # новая игра
	SceneFlow.change_scene("res://levels/world/world.tscn", 0.8, 0.6)


func _on_settings_button_pressed() -> void:
	_settings_box.visible = not _settings_box.visible


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _style_button(b: Button) -> void:
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UIStyle.title_font())
	b.add_theme_font_size_override("font_size", 46)
	b.add_theme_color_override("font_color", UIStyle.BONE)
	b.add_theme_color_override("font_hover_color", UIStyle.RED)
	b.add_theme_color_override("font_pressed_color", UIStyle.RED.darkened(0.3))
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	# при наведении кнопка чуть сдвигается вправо
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "position:x", 14.0, 0.12))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "position:x", 0.0, 0.12))


func _build_settings() -> void:
	var sb := UIStyle.box(Color(0.03, 0.04, 0.06, 0.92), 4, Color(UIStyle.BONE, 0.25), 1)
	sb.set_content_margin_all(26)
	_settings_box.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_settings_box.add_child(box)
	var t := Label.new()
	t.text = "НАСТРОЙКИ"
	t.add_theme_font_override("font", UIStyle.title_font())
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", UIStyle.BONE)
	box.add_child(t)
	var panel := VBoxContainer.new()
	panel.set_script(preload("res://ui/settings_panel.gd"))
	box.add_child(panel)
	var back := UIStyle.menu_button("Назад", 30)
	back.pressed.connect(func(): _settings_box.visible = false)
	box.add_child(back)


## Силуэт дома на холме, лес и одно тёплое окно
func _draw_house() -> void:
	var w := _house.size.x
	var h := _house.size.y
	var dark := Color(0.012, 0.016, 0.024)
	var ground := h * 0.86
	# снежный холм
	var hill := PackedVector2Array([Vector2(w * 0.3, h), Vector2(w * 0.45, ground + 20), Vector2(w * 0.7, ground - 8),
		Vector2(w, ground + 6), Vector2(w, h)])
	_house.draw_colored_polygon(hill, Color(0.07, 0.09, 0.12))
	# ёлки
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var x := w * (0.4 + 0.6 * rng.randf())
		if x > w * 0.6 and x < w * 0.9:
			continue
		var th := h * rng.randf_range(0.16, 0.34)
		var base := ground + rng.randf_range(-4, 14)
		_house.draw_colored_polygon(PackedVector2Array([Vector2(x - th * 0.22, base), Vector2(x, base - th),
			Vector2(x + th * 0.22, base)]), dark.lightened(rng.randf_range(0.0, 0.03)))
	# дом
	var hw := w * 0.22
	var hh := h * 0.26
	var hx := w * 0.75 - hw / 2.0
	var hy := ground - 6 - hh
	_house.draw_rect(Rect2(hx, hy, hw, hh), dark)
	_house.draw_colored_polygon(PackedVector2Array([Vector2(hx - hw * 0.06, hy), Vector2(hx + hw * 0.5, hy - hh * 0.55),
		Vector2(hx + hw * 1.06, hy)]), dark)
	_house.draw_rect(Rect2(hx + hw * 0.72, hy - hh * 0.5, hw * 0.08, hh * 0.4), dark)
	# окна: все тёмные, одно светится
	var ww := hw * 0.09
	var wh := hh * 0.2
	for row in 2:
		for col in 5:
			var p := Vector2(hx + hw * (0.1 + col * 0.18), hy + hh * (0.16 + row * 0.42))
			var lit := row == 0 and col == 3
			var c := Color(0.95, 0.62, 0.25, 0.9 * _flicker) if lit else Color(0.03, 0.04, 0.06)
			_house.draw_rect(Rect2(p, Vector2(ww, wh)), c)
			if lit:
				# силуэт в окне
				_house.draw_rect(Rect2(p + Vector2(ww * 0.36, wh * 0.3), Vector2(ww * 0.28, wh * 0.7)), dark)
				_house.draw_circle(p + Vector2(ww * 0.5, wh * 0.28), ww * 0.16, dark)
