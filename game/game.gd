extends Node
## Центральный узел игры (группа "game"):
##   • взаимодействие: луч из камеры игрока, подсказка «E — …», нажатие E;
##   • инвентарь (предметы по id) и сюжетные флаги;
##   • HUD: прицел, подсказка, сообщения, инвентарь, текущая цель.
##
## Любой объект становится интерактивным, если у него (или у его родителя) есть методы:
##   get_prompt(game) -> String   — текст подсказки
##   interact(game)               — что происходит по нажатию E

const HideSpot = preload("res://level/hide_spot.gd")

@export var interact_distance := 2.3

var items := {}          # id -> название
var flags := {}          # "front_locked", "basement_open", "boards_removed", "car_fueled"
var player: CharacterBody3D
var camera: Camera3D
var target: Node = null  # на что сейчас смотрит игрок

var _prompt: Label
var _message: Label
var _inventory: Label
var _objective: Label
var _crosshair: ColorRect
var _message_time := 0.0


func _ready() -> void:
	add_to_group("game")
	HideSpot.hidden_in = null   # сброс после «Заново»
	_build_hud()
	_update_inventory()
	_update_objective()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	if player:
		camera = player.get_node_or_null("Head/Camera3D") as Camera3D


# ---------------------------------------------------------------- взаимодействие

func _physics_process(delta: float) -> void:
	_find_player()
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""
	if camera == null:
		return
	var hidden: bool = player.get_meta("hidden", false)
	target = null if hidden else _raycast_interactable()
	if hidden:
		_prompt.text = ""
	else:
		_prompt.text = target.get_prompt(self) if target else ""
	_crosshair.visible = not hidden


func _raycast_interactable() -> Node:
	var from := camera.global_position
	var to := from - camera.global_basis.z * interact_distance
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var n: Node = hit.collider
	# поднимаемся по дереву, пока не найдём узел с interact()
	while n and n != get_tree().root:
		if n.has_method("interact") and n.has_method("get_prompt"):
			return n
		n = n.get_parent()
	return null


func _input(event: InputEvent) -> void:
	# клик по окну игры снова захватывает мышь (после Esc или если окно было не в фокусе)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		return
	# если игрок в шкафу — E выводит из шкафа
	if HideSpot.hidden_in:
		HideSpot.hidden_in.interact(self)
		get_viewport().set_input_as_handled()
	elif target and is_instance_valid(target):
		target.interact(self)
		get_viewport().set_input_as_handled()
	_update_inventory()
	_update_objective()


# ---------------------------------------------------------------- инвентарь и флаги

func add_item(id: String, title: String) -> void:
	items[id] = title
	_update_inventory()
	_update_objective()


func has_item(id: String) -> bool:
	return items.has(id)


func remove_item(id: String) -> void:
	items.erase(id)
	_update_inventory()


func set_flag(name: String, value := true) -> void:
	flags[name] = value
	_update_objective()


func has_flag(name: String) -> bool:
	return flags.get(name, false)


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	_message_time = seconds


# ---------------------------------------------------------------- HUD

func _update_inventory() -> void:
	if _inventory == null:
		return
	_inventory.text = "" if items.is_empty() else "С собой: " + ", ".join(items.values())


## Подсказка «что делать дальше» в левом верхнем углу
func _update_objective() -> void:
	if _objective == null:
		return
	var t := "Дойти до дома"
	if has_flag("car_fueled"):
		t = "Сесть в машину и уехать"
	elif has_item("canister") and has_flag("boards_removed"):
		t = "Добраться до машины и заправить её"
	elif has_item("canister"):
		t = "Выбраться из дома: задняя дверь заколочена"
	elif has_flag("basement_open"):
		t = "Найти бензин в подвале"
	elif has_item("basement_key"):
		t = "Открыть дверь в подвал (кладовая)"
	elif has_flag("front_locked"):
		t = "Найти способ выбраться. Бензин — в подвале"
	_objective.text = "Цель: " + t


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.7)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE   # не перехватывать мышь (иначе камера не крутится)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -2
	_crosshair.offset_right = 2
	_crosshair.offset_top = -2
	_crosshair.offset_bottom = 2
	layer.add_child(_crosshair)

	_prompt = _label(layer, 18, Color(1, 1, 1))
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 24
	_prompt.offset_bottom = 50

	_message = _label(layer, 22, Color(0.95, 0.85, 0.7))
	_message.anchor_top = 0.18
	_message.anchor_bottom = 0.18
	_message.offset_bottom = 40

	_inventory = _label(layer, 16, Color(0.8, 0.8, 0.8))
	_inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_inventory.anchor_top = 1.0
	_inventory.anchor_bottom = 1.0
	_inventory.offset_left = 20
	_inventory.offset_top = -40
	_inventory.offset_bottom = -14

	_objective = _label(layer, 16, Color(0.75, 0.75, 0.75))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective.offset_left = 20
	_objective.offset_top = 14
	_objective.offset_bottom = 40


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l
