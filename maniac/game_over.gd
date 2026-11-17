extends Control
## Экран «Тебя поймали»: начать заново или выйти в меню.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var title: Label = $Center/Box/Title
	title.add_theme_font_override("font", UIStyle.title_font())
	var sub := Label.new()
	sub.text = "Он не убивает в доме. Ты нужен ему живым — к полуночи, у камня."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UIStyle.hand_font())
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68, 0.7))
	$Center/Box.add_child(sub)
	$Center/Box.move_child(sub, 1)
	for b in [$Center/Box/Retry, $Center/Box/Menu]:
		b.custom_minimum_size = Vector2(260, 46)
		b.add_theme_font_size_override("font_size", 20)
	$Center/Box/Retry.pressed.connect(func(): get_tree().change_scene_to_file("res://world.tscn"))
	$Center/Box/Menu.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
