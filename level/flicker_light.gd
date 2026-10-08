extends OmniLight3D
## Простое мерцание: раз в 0.05–0.2 секунды выбираем случайную яркость.
## Для "сломанной лампы" поставь min_energy = 0.

@export var min_energy := 0.6
@export var max_energy := 1.4

var timer := 0.0


func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		light_energy = randf_range(min_energy, max_energy)
		timer = randf_range(0.05, 0.2)
