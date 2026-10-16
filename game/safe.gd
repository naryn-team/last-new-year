extends Node3D
## Сейф отца. Внутри — ключ от подвала.
## Пока code пустой, сейф открывается сразу. Когда сделаем головоломку,
## впишем сюда код и добавим окно ввода цифр.

@export var code := ""
@export var reward_id := "basement_key"
@export var reward_name := "Ключ от подвала"

var opened := false


func get_prompt(_game) -> String:
	return "Сейф пуст" if opened else "E — открыть сейф"


func interact(game) -> void:
	if opened:
		game.show_message("Сейф пуст.")
		return
	if code != "":
		game.show_message("Сейф заперт на кодовый замок.")
		return
	opened = true
	game.add_item(reward_id, reward_name)
	game.show_message("В сейфе лежал %s." % reward_name.to_lower())
