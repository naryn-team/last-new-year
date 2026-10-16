extends Node3D
## Дверь на петле. Этот узел — петля (точка вращения), дочерний CSGBox3D — полотно.
## Может быть заперта: тогда открывается предметом key_id из инвентаря.

@export var open_angle := 95.0        ## угол открытия (знак — в какую сторону)
@export var start_open := false
@export var locked := false
@export var key_id := ""              ## id предмета-ключа (пусто — ключом не открыть)
@export var key_name := ""
@export_multiline var locked_message := "Заперто."
@export var unlock_flag := ""         ## какой сюжетный флаг поставить при отпирании
@export var open_time := 0.6

var is_open := false
var _closed_yaw := 0.0
var _tween: Tween


func _ready() -> void:
	_closed_yaw = rotation_degrees.y
	if start_open:
		is_open = true
		rotation_degrees.y = _closed_yaw + open_angle


func get_prompt(game) -> String:
	if locked:
		if key_id != "" and game.has_item(key_id):
			return "E — отпереть (%s)" % key_name
		return "Заперто"
	return "E — закрыть" if is_open else "E — открыть"


func interact(game) -> void:
	if locked:
		if key_id != "" and game.has_item(key_id):
			locked = false
			if unlock_flag != "":
				game.set_flag(unlock_flag)
			game.show_message("Дверь отперта.")
			set_open(true)
		else:
			game.show_message(locked_message)
		return
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", _closed_yaw + (open_angle if value else 0.0), open_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Захлопнуть и запереть (парадная за спиной героя)
func slam_and_lock() -> void:
	locked = true
	is_open = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", _closed_yaw, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
