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

@export_group("Засов (запереть Хранителя в комнате)")
@export var has_bolt := false           ## у двери есть засов снаружи
@export var bolt_time := 15.0           ## сколько секунд выдержит дверь
@export var room_path: NodePath         ## Area3D с BoxShape3D — комната за дверью

var bolted := false

var is_open := false
var _closed_yaw := 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group("door")
	_closed_yaw = rotation_degrees.y
	if start_open:
		is_open = true
		rotation_degrees.y = _closed_yaw + open_angle


func get_prompt(game) -> String:
	if bolted:
		return "Засов задвинут"
	if _can_trap(game):
		return "E — захлопнуть и задвинуть засов"
	if locked:
		if key_id != "" and game.has_item(key_id):
			return "E — отпереть (%s)" % key_name
		return "Заперто"
	return "E — закрыть" if is_open else "E — открыть"


func interact(game) -> void:
	if bolted:
		game.show_message("Он ломится изнутри. Беги!")
		return
	if _can_trap(game):
		_trap(game)
		return
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


# ---------------------------------------------------------------- засов

## Запереть можно, когда Хранитель внутри комнаты, а игрок — снаружи
func _can_trap(game) -> bool:
	if not has_bolt or bolted:
		return false
	var m := _maniac()
	if m == null or m.get("caught") or not m.get("active"):
		return false
	return _in_room(m.global_position) and not _in_room(game.player.global_position)


func _trap(game) -> void:
	bolted = true
	slam_and_lock()
	var m := _maniac()
	if m and m.has_method("trap"):
		m.trap(self, bolt_time)
	game.show_message("Засов задвинут! Это задержит его секунд на %d…" % int(bolt_time), 4.0)


## Хранитель выломал дверь (вызывает maniac.gd): засов сломан, второй раз не запереть
func break_open() -> void:
	bolted = false
	locked = false
	has_bolt = false
	open_time = 0.15
	set_open(true)
	var game := get_tree().get_first_node_in_group("game")
	if game:
		game.show_message("Он выломал дверь!", 3.0)


func _maniac() -> Node3D:
	return get_tree().get_first_node_in_group("maniac") as Node3D


func _in_room(pos: Vector3) -> bool:
	var area := get_node_or_null(room_path) as Node3D
	if area == null:
		return false
	for c in area.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			var local: Vector3 = c.global_transform.affine_inverse() * pos
			var half: Vector3 = c.shape.size / 2.0
			return abs(local.x) <= half.x and abs(local.y) <= half.y and abs(local.z) <= half.z
	return false
