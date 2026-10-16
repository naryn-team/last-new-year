extends Node3D
## Машина героя. Бак пустой — нужна канистра.
## Финальная сцена (убийца на заднем сиденье → ritual.tscn) — следующий шаг.

func get_prompt(game) -> String:
	if game.has_flag("car_fueled"):
		return "E — сесть в машину"
	if game.has_item("canister"):
		return "E — заправить машину"
	return "Бак пуст"


func interact(game) -> void:
	if game.has_flag("car_fueled"):
		game.show_message("Двигатель заводится... (финальная сцена — следующий шаг)")
		return
	if game.has_item("canister"):
		game.remove_item("canister")
		game.set_flag("car_fueled")
		game.show_message("Бак заправлен. Скорее в машину!")
		return
	game.show_message("Бензин кончился у самого дома. Нужна канистра.")
