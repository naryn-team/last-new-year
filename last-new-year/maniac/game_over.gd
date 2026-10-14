extends Control
## Экран «Тебя поймали»: начать заново или выйти в меню.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/Box/Retry.pressed.connect(func(): get_tree().change_scene_to_file("res://world.tscn"))
	$Center/Box/Menu.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
