extends Node3D
## Доски, которыми заколочена дверь. Снимаются инструментом (по умолчанию — ломом).

@export var tool_id := "crowbar"
@export var done_flag := "boards_removed"


func get_prompt(game) -> String:
	return "E — сорвать доски ломом" if game.has_item(tool_id) else "Дверь заколочена"


func interact(game) -> void:
	if not game.has_item(tool_id):
		game.show_message("Доски прибиты намертво. Нужен инструмент.")
		return
	game.set_flag(done_flag)
	game.show_message("Доски сорваны. Путь наружу свободен!")
	queue_free()
