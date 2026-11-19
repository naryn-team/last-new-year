extends Control
## Финальный экран: название, несколько строк, команда, «В главное меню».
## Тексты появляются по очереди; звук возвращается в норму, сессия игры очищается.

@export var lines: Array[String] = [
	"В новогоднюю ночь в долине пропал ещё один Лоун.",
	"Восемь мест у камня. Семья снова в сборе.",
]

var _items: Array[Control] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	SceneFlow.set_muffle(SceneFlow.MUFFLE_OFF, 2.0)
	SceneFlow.session.clear()
	_build()
	var tw := create_tween()
	tw.tween_interval(0.8)
	for c in _items:
		tw.tween_property(c, "modulate:a", 1.0, 1.4)
		tw.tween_interval(0.6)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.01, 0.012)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "THE LAST NEW YEAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyle.title_font())
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", UIStyle.BONE)
	_add(box, title)

	for t in lines:
		var l := Label.new()
		l.text = t
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", UIStyle.hand_font())
		l.add_theme_font_size_override("font_size", 32)
		l.add_theme_color_override("font_color", Color(UIStyle.BONE, 0.85))
		_add(box, l)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)

	var team := Label.new()
	team.text = "Команда NARYN"
	team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team.add_theme_font_override("font", UIStyle.title_font())
	team.add_theme_font_size_override("font_size", 40)
	team.add_theme_color_override("font_color", UIStyle.RED)
	_add(box, team)

	var menu := UIStyle.menu_button("В главное меню", 36)
	menu.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.pressed.connect(func(): SceneFlow.change_scene("res://ui/main_menu.tscn", 0.8, 0.0))
	_add(box, menu)


func _add(box: Container, c: Control) -> void:
	c.modulate.a = 0.0
	box.add_child(c)
	_items.append(c)
