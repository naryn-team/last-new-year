extends Node3D
## Камера сзади машины (узел Cameras/ChaseCamRig, дочерний Camera3D).
## Не наследует движение машины (top_level): плавно догоняет точку сзади-сверху
## и смотрит на дорогу впереди — в поворотах заглядывает в поворот.

@export var distance := 6.5          ## сзади машины, м
@export var height := 2.3            ## над землёй, м
@export var follow_speed := 5.0      ## чем больше — тем жёстче следует
@export var look_speed := 4.0

var _look := Vector3.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var _car = get_node("../..")   # vehicle/car.gd


func _ready() -> void:
	top_level = true
	snap()


## Сразу встать на место (без догоняния)
func snap() -> void:
	global_position = _desired()
	_look = _look_target()
	_apply_look()


func _process(delta: float) -> void:
	# следуем всегда, даже когда камера не текущая: из катсцены в неё плавно переходят
	global_position = global_position.lerp(_desired(), 1.0 - exp(-follow_speed * delta))
	_look = _look.lerp(_look_target(), 1.0 - exp(-look_speed * delta))
	_apply_look()


func _desired() -> Vector3:
	return _car.global_transform * Vector3(0, height, distance)


func _look_target() -> Vector3:
	if _car.has_method("get_look_target"):
		return _car.get_look_target()
	return _car.global_position - _car.global_basis.z * 10.0


func _apply_look() -> void:
	if global_position.distance_to(_look) > 0.1:
		look_at(_look, Vector3.UP)
