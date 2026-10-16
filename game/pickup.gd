extends Node3D
## Предмет, который можно взять (E). Попадает в инвентарь, сам объект исчезает.

@export var item_id := ""
@export var item_name := ""
@export_multiline var pickup_message := ""


func get_prompt(_game) -> String:
	return "E — взять: " + item_name


func interact(game) -> void:
	game.add_item(item_id, item_name)
	game.show_message(pickup_message if pickup_message != "" else "Взято: " + item_name)
	queue_free()
