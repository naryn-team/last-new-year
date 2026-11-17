extends Node3D
## Сейф отца. Внутри — ключ от подвала и письмо отца.
## Код из 4 цифр: цифры спрятаны на детских рисунках, порядок — по цветным меткам
## (color_order). Если code пустой — сейф открывается сразу.

@export var code := ""
@export var color_order: Array[String] = ["red", "green", "blue", "yellow"]
@export var reward_id := "basement_key"
@export var reward_name := "Ключ от подвала"
@export var letter_title := "Письмо отца"
@export_multiline var letter_text := ""

var opened := false


func get_prompt(_game) -> String:
	return "Сейф пуст" if opened else "E — открыть сейф"


func interact(game) -> void:
	if opened:
		game.show_message("Сейф пуст.")
		return
	if code != "":
		game.set_flag("safe_seen")
		game.open_keypad(self)
		return
	open_safe(game)


func open_safe(game) -> void:
	opened = true
	game.set_flag("safe_open")
	game.add_item(reward_id, reward_name)
	game.show_message("В сейфе лежал %s." % reward_name.to_lower(), 4.0)
	if letter_text != "":
		game.read_text(letter_title, letter_text, "hand")
