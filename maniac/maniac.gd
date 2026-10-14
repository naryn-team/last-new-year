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
@export var chase_speed := 4.5            ## игрок ходит 5 — маньяк чуть медленнее, иначе не убежать
@export var turn_speed := 8.0

@export_group("Зрение и слух")
@export var sight_range := 14.0
@export var sight_range_flashlight := 22.0 ## включённый фонарик видно издалека
@export var fov_degrees := 110.0
@export var hear_range := 6.0             ## слышит шаги игрока в этом радиусе (даже через стену)

@export_group("Поведение")
@export var catch_distance := 1.3
@export var lose_sight_time := 3.0        ## сколько секунд гонится «вслепую», потеряв игрока
@export var search_time := 6.0            ## сколько ищет на месте, прежде чем вернуться к патрулю
@export var patrol_wait := 2.0            ## пауза на каждой точке патруля
@export_range(0.0, 1.0) var prefer_player_floor := 0.6  ## шанс выбрать точку на этаже игрока
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
	elif (state == State.PATROL or state == State.SEARCH) and can_hear_player():
		hear_noise(player.global_position)

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
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
	var dy: float = abs(player.global_position.y - global_position.y)
	return moving and dy < 2.5 and global_position.distance_to(player.global_position) < hear_range


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
	var pool := patrol_points
	if randf() < prefer_player_floor:
		var same_floor: Array[Node3D] = []
		for p in patrol_points:
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
	if agent.is_navigation_finished():
		timer += delta
		rotation.y += delta * 1.2
		if timer >= wait:
			set_state(State.PATROL)
			_has_target = false


# ---------------------------------------------------------------- движение

func _go_to(pos: Vector3) -> void:
	agent.target_position = pos
	_has_target = true


func _move(delta: float, speed: float) -> void:
	var dir := Vector3.ZERO
	if _has_target and not agent.is_navigation_finished():
		dir = agent.get_next_path_position() - global_position
		dir.y = 0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()


func _catch() -> void:
	caught = true
	player_caught.emit()
	if debug:
		print("[Maniac] CAUGHT")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", game_over_scene)
