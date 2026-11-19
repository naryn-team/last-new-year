extends Node
## Центральный узел игры (группа "game"):
##   • взаимодействие: луч из камеры игрока, подсказка «E — …», нажатие E (действие interact);
##   • инвентарь (предметы по id) и сюжетные флаги;
##   • записки, рисунки, сейф; текущая цель.
## Отображение (прицел, подсказка, сообщения, инвентарь, цель) — в HUD (ui/hud.gd).
##
## Любой объект становится интерактивным, если у него (или у его родителя) есть методы:
##   get_prompt(game) -> String   — текст подсказки
##   interact(game)               — что происходит по нажатию E

const HideSpot = preload("res://interactables/hide_spot.gd")

@export var interact_distance := 2.3

var items := {}          # id -> название
var flags := {}          # "front_locked", "safe_seen", "safe_open", "basement_open", "boards_removed", "car_fueled"
var notes_read := {}     # note_id -> true
var drawings := {}       # цвет -> цифра (найденные детские рисунки)
var drawings_total := 4
var hud: CanvasLayer
var _note_window: CanvasLayer
var _keypad: CanvasLayer
var _keypad_safe: Node = null
var _interaction_enabled := true
var player: CharacterBody3D
var camera: Camera3D
var target: Node = null  # на что сейчас смотрит игрок


func _ready() -> void:
	add_to_group("game")
	HideSpot.hidden_in = null   # сброс после «Заново»
	hud = preload("res://ui/hud.gd").new()
	add_child(hud)
	add_child(preload("res://ui/pause_menu.gd").new())
	_note_window = preload("res://ui/note_window.gd").new()
	add_child(_note_window)
	_keypad = preload("res://ui/keypad_window.gd").new()
	add_child(_keypad)
	_keypad.solved.connect(_on_keypad_solved)
	# рисунки встают в группу в своём _ready, а узел Notes идёт после Game —
	# считаем их в конце кадра, когда все узлы уровня уже готовы
	_count_drawings.call_deferred()
	_update_inventory()
	_update_objective()


## Сколько всего детских рисунков на уровне (для «x из N»)
func _count_drawings() -> void:
	var n := get_tree().get_nodes_in_group("note_drawing").size()
	if n > 0:
		drawings_total = n
	_update_objective()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	if player:
		camera = player.get_camera()


# ---------------------------------------------------------------- HUD / взаимодействие вкл-выкл

## Показать/спрятать весь HUD (катсцены)
func set_hud_visible(v: bool) -> void:
	hud.visible = v


func is_hud_visible() -> bool:
	return hud.visible


## Показать/спрятать текущую цель (во время поездки цели ещё нет)
func set_objective_visible(v: bool) -> void:
	hud.set_objective_visible(v)


## Включить/выключить взаимодействие (луч, подсказка, E). Для катсцен.
func set_interaction_enabled(v: bool) -> void:
	_interaction_enabled = v
	if not v:
		target = null
		hud.set_prompt("")


func is_interaction_enabled() -> bool:
	return _interaction_enabled


# ---------------------------------------------------------------- взаимодействие

func _physics_process(_delta: float) -> void:
	_find_player()
	if camera == null:
		return
	var hidden: bool = player.is_hidden
	var can_use := _interaction_enabled and not hidden
	target = _raycast_interactable() if can_use else null
	hud.set_prompt(target.get_prompt(self) if target else "")
	hud.set_crosshair_visible(can_use)
	_update_stamina()


func _update_stamina() -> void:
	var st = player.get("stamina")
	if st == null:
		hud.hide_stamina()
		return
	hud.set_stamina(st / player.stamina_max, player.exhausted)


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
	if event is InputEventMouseButton and event.pressed and not get_tree().paused \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not _interaction_enabled:
		return
	if player and player.is_dead:
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


# ---------------------------------------------------------------- записки и сейф

## Открыть записку (вызывает note.gd)
func read_note(note: Node) -> void:
	if note.note_id != "":
		notes_read[note.note_id] = true
	if note.kind == "drawing":
		var first: bool = not drawings.has(note.drawing_color)
		drawings[note.drawing_color] = note.drawing_digit
		if first:
			show_message("Рисунок с цифрой: %d из %d" % [drawings.size(), drawings_total], 4.0)
	_note_window.show_note(note.title, note.text, note.kind, note.drawing_color, note.drawing_digit)
	_update_objective()


## Показать текст без объекта в мире (например, письмо из сейфа)
func read_text(title: String, text: String, kind := "hand") -> void:
	_note_window.show_note(title, text, kind)


func open_keypad(safe: Node) -> void:
	_keypad_safe = safe
	_keypad.open(safe.code, safe.color_order, drawings)


func _on_keypad_solved() -> void:
	if _keypad_safe and is_instance_valid(_keypad_safe):
		_keypad_safe.open_safe(self)
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


func set_flag(flag_name: String, value := true) -> void:
	flags[flag_name] = value
	_update_objective()


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func show_message(text: String, seconds := 3.0) -> void:
	hud.show_message(text, seconds)


# ---------------------------------------------------------------- инвентарь и цель в HUD

func _update_inventory() -> void:
	if hud == null:
		return
	hud.set_inventory("" if items.is_empty() else "С собой: " + ", ".join(items.values()))


## Подсказка «что делать дальше» в левом верхнем углу
func _update_objective() -> void:
	if hud == null:
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
	elif has_flag("safe_seen"):
		t = "Найти код от сейфа: детские рисунки (%d из %d)" % [drawings.size(), drawings_total]
	elif has_flag("front_locked"):
		t = "Найти способ выбраться. Осмотреть кабинет отца"
	hud.set_objective("Цель: " + t)
