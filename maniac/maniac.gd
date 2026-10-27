extends CharacterBody3D
## Маньяк. Простой «мозг» из 4 состояний:
##   PATROL      — ходит по точкам патруля (узлы в группе "patrol_point")
##   INVESTIGATE — услышал шум, идёт проверить
##   CHASE       — видит игрока и бежит за ним
##   SEARCH      — потерял игрока, ищет там, где видел последний раз
## Ходит по NavigationRegion3D (карта навигации уровня).

signal state_changed(new_state: int)
signal player_caught

enum State { PATROL, INVESTIGATE, CHASE, SEARCH }

@export_group("Скорость")
@export var walk_speed := 2.0
@export var chase_speed := 5.0            ## быстрее шага игрока (4), медленнее бега (6.5): спасает только бег
@export var turn_speed := 8.0

@export_group("Зрение и слух")
@export var sight_range := 14.0
@export var sight_range_flashlight := 22.0 ## включённый фонарик видно издалека
@export var fov_degrees := 110.0
@export var hear_range := 6.0             ## запасной радиус слуха, если у игрока нет noise_radius

@export_group("Поведение")
@export var catch_distance := 1.3
@export var lose_sight_time := 3.0        ## сколько секунд гонится «вслепую», потеряв игрока
@export var search_time := 6.0            ## сколько ищет на месте, прежде чем вернуться к патрулю
@export var patrol_wait := 2.0            ## пауза на каждой точке патруля
@export_range(0.0, 1.0) var prefer_player_floor := 0.6  ## шанс выбрать точку на этаже игрока
@export var give_up_time := 4.0          ## не может приблизиться к цели столько секунд — бросает её
@export var game_over_scene := "res://maniac/game_over.tscn"
@export var debug := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var state: State = State.PATROL
var player: CharacterBody3D
var patrol_points: Array[Node3D] = []
var last_seen_pos := Vector3.ZERO
var time_since_seen := 999.0
var timer := 0.0
var caught := false
var _has_target := false
var _stuck_time := 0.0
var _unstick_time := 0.0
var _unstick_dir := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _best_dist := INF          # ближе всего, насколько подходил к текущей цели
var _no_progress := 0.0        # сколько секунд не приближается к цели
var _hear_cooldown := 0.0
var _door_check := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	for n in get_tree().get_nodes_in_group("patrol_point"):
		patrol_points.append(n)
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D


func _physics_process(delta: float) -> void:
	if caught or player == null:
		return
	# карта навигации готова не в первый кадр
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return

	time_since_seen += delta
	if can_see_player():
		time_since_seen = 0.0
		last_seen_pos = player.global_position
		if state != State.CHASE:
			set_state(State.CHASE)
	elif state != State.CHASE and _hear_cooldown <= 0.0 and can_hear_player():
		# слышит и во время проверки шума: идёт на новый звук (не чаще раза в секунду)
		_hear_cooldown = 1.0
		hear_noise(player.global_position)
	_hear_cooldown -= delta
	_open_doors_nearby(delta)

	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_wait_then_patrol(delta, 3.0)
		State.CHASE:
			_chase()
		State.SEARCH:
			_wait_then_patrol(delta, search_time)

	var speed := chase_speed if state == State.CHASE else walk_speed
	_move(delta, speed)

	if state == State.CHASE and _close_to_player():
		_catch()


# ---------------------------------------------------------------- органы чувств

func can_see_player() -> bool:
	if player.get_meta("hidden", false):
		# игрок в шкафу: найдёт, только если видел, как тот прятался
		return state == State.CHASE and time_since_seen < 1.0
	var eye := global_position + Vector3(0, 1.6, 0)
	var target := player.global_position + Vector3(0, 1.4, 0)
	var to := target - eye
	var dist := to.length()
	var max_range := sight_range_flashlight if _flashlight_on() else sight_range
	if dist > max_range:
		return false
	var flat := Vector3(to.x, 0, to.z)
	var forward := -global_basis.z
	if dist > 1.5 and rad_to_deg(forward.angle_to(flat)) > fov_degrees * 0.5:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == player


func can_hear_player() -> bool:
	if player.get_meta("hidden", false):
		return false
	var dy: float = abs(player.global_position.y - global_position.y)
	if dy >= 2.5:
		return false
	# радиус шума задаёт игрок: присед ~1.5 м, шаг ~6 м, бег ~13 м
	var noise = player.get("noise_radius")
	var radius: float
	if noise == null:
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
		radius = hear_range if moving else 0.0
	else:
		radius = noise
	return radius > 0.0 and global_position.distance_to(player.global_position) < radius


## Можно вызывать из других скриптов: упала вещь, хлопнула дверь и т.п.
func hear_noise(pos: Vector3) -> void:
	if state == State.CHASE:
		return
	set_state(State.INVESTIGATE)
	_go_to(pos)


func _flashlight_on() -> bool:
	var f := player.get_node_or_null("Head/Camera3D/Flashlight") as Light3D
	return f != null and f.visible


func _close_to_player() -> bool:
	var d := player.global_position - global_position
	return abs(d.y) < 1.5 and Vector2(d.x, d.z).length() < catch_distance


# ---------------------------------------------------------------- состояния

func set_state(s: State) -> void:
	if s == state:
		return
	state = s
	timer = 0.0
	if s == State.SEARCH:
		_go_to(last_seen_pos)
	if debug:
		print("[Maniac] -> ", State.keys()[s])
	state_changed.emit(s)


func _patrol(delta: float) -> void:
	if not _has_target or agent.is_navigation_finished():
		timer -= delta
		if timer <= 0.0:
			_next_patrol_point()
			timer = patrol_wait


func _next_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	# подвал заперт, пока игрок не откроет дверь ключом — туда не ходим
	var game := get_tree().get_first_node_in_group("game")
	var basement_open: bool = game == null or game.has_flag("basement_open")
	var pool: Array[Node3D] = []
	for p in patrol_points:
		if basement_open or not p.is_in_group("patrol_basement"):
			pool.append(p)
	if pool.is_empty():
		return
	if randf() < prefer_player_floor:
		var same_floor: Array[Node3D] = []
		for p in pool:
			if abs(p.global_position.y - player.global_position.y) < 2.0:
				same_floor.append(p)
		if not same_floor.is_empty():
			pool = same_floor
	var p: Node3D = pool.pick_random()
	_go_to(p.global_position)


func _chase() -> void:
	if time_since_seen < lose_sight_time:
		_go_to(player.global_position if time_since_seen < 0.1 else last_seen_pos)
	else:
		set_state(State.SEARCH)


## Дошёл до цели — постоять, осмотреться, вернуться к патрулю
func _wait_then_patrol(delta: float, wait: float) -> void:
	if not _has_target or agent.is_navigation_finished():
		timer += delta
		rotation.y += delta * 1.2
		if timer >= wait:
			set_state(State.PATROL)
			_has_target = false


# ---------------------------------------------------------------- движение

func _go_to(pos: Vector3) -> void:
	# новая цель (а не та же, чуть сдвинутая во время погони) — заново считаем прогресс
	if not _has_target or pos.distance_to(agent.target_position) > 2.0:
		_best_dist = INF
		_no_progress = 0.0
	agent.target_position = pos
	_has_target = true


## Не может дойти до цели (заперта дверь, цель снаружи) — бросает её
func _check_progress(delta: float) -> void:
	if not _has_target or agent.is_navigation_finished():
		_no_progress = 0.0
		return
	var d := _remaining_path_length()
	if d < _best_dist - 0.4:
		_best_dist = d
		_no_progress = 0.0
	else:
		_no_progress += delta
	if _no_progress > give_up_time:
		_no_progress = 0.0
		_best_dist = INF
		if debug:
			print("[Maniac] give up target ", agent.target_position)
		_has_target = false
		timer = 0.0
		if state == State.CHASE:
			set_state(State.SEARCH)
			_has_target = false   # искать на месте, а не снова ломиться к недоступной точке
		elif state != State.PATROL:
			set_state(State.PATROL)


## Длина оставшегося пути по карте навигации (а не по прямой: цель на другом этаже
## может быть «прямо под ногами», но идти к ней нужно через лестницу)
func _remaining_path_length() -> float:
	var path := agent.get_current_navigation_path()
	var i := agent.get_current_navigation_path_index()
	if path.is_empty() or i >= path.size():
		return global_position.distance_to(agent.target_position)
	var total := global_position.distance_to(path[i])
	for k in range(i + 1, path.size()):
		total += path[k - 1].distance_to(path[k])
	return total


## Открывает незапертые закрытые двери у себя на пути
func _open_doors_nearby(delta: float) -> void:
	_door_check -= delta
	if _door_check > 0.0:
		return
	_door_check = 0.2
	for d in get_tree().get_nodes_in_group("door"):
		if d.is_open or d.locked:
			continue
		var panel_center: Vector3 = d.global_transform * Vector3(0.5, 1.0, 0.0)
		if panel_center.distance_to(global_position + Vector3(0, 1.0, 0)) < 1.6:
			d.set_open(true)


func _move(delta: float, speed: float) -> void:
	var dir := Vector3.ZERO
	if _unstick_time > 0.0:
		# страховка от застревания: короткий шаг в сторону
		_unstick_time -= delta
		dir = _unstick_dir
	elif _has_target and not agent.is_navigation_finished():
		dir = agent.get_next_path_position() - global_position
		dir.y = 0
	var wants_move := dir.length() > 0.05
	if wants_move:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if _unstick_time <= 0.0:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_check_stuck(delta, speed, wants_move)
	_check_progress(delta)


## Если хочет идти, но почти не двигается — пересчитать путь и шагнуть вбок
func _check_stuck(delta: float, speed: float, wants_move: bool) -> void:
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	_last_pos = global_position
	if not wants_move or _unstick_time > 0.0:
		_stuck_time = 0.0
		return
	if moved < speed * delta * 0.25:
		_stuck_time += delta
	else:
		_stuck_time = max(0.0, _stuck_time - delta)
	if _stuck_time > 0.5:
		_stuck_time = 0.0
		agent.target_position = agent.target_position   # заставляет агента пересчитать путь
		var side := global_basis.x * (1.0 if randf() < 0.5 else -1.0)
		_unstick_dir = (side + global_basis.z * 0.7).normalized()   # вбок и немного назад
		_unstick_time = 0.35
		if debug:
			print("[Maniac] unstick at ", global_position)


func _catch() -> void:
	caught = true
	player_caught.emit()
	if debug:
		print("[Maniac] CAUGHT")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", game_over_scene)
