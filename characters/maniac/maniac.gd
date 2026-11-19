extends CharacterBody3D
## Маньяк. «Мозг» из 6 состояний:
##   PATROL      — ходит по точкам патруля (узлы в группе "patrol_point")
##   INVESTIGATE — услышал шум, идёт проверить
##   CHASE       — видит игрока и бежит за ним
##   SEARCH      — потерял игрока, ищет там, где видел последний раз
##   CHECK_HIDE  — проверяет шкаф: подходит, открывает, смотрит,
##                 потом либо убивает (скример), либо закрывает и уходит
##   TRAPPED     — игрок запер его в комнате на засов; через N секунд выломает дверь
##
## В начале игры Хранителя в доме «нет»: он появляется через start_delay секунд
## после того, как за игроком захлопнулась парадная дверь (флаг start_flag).
## Ходит по NavigationRegion3D (карта навигации уровня).

signal state_changed(new_state: int)
signal player_caught

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, CHECK_HIDE, TRAPPED }

@export_group("Появление")
@export var start_flag := "front_locked"  ## после какого события начинает охоту (пусто — сразу)
@export var start_delay := 25.0           ## и ещё столько секунд даёт игроку осмотреться

@export_group("Скорость")
@export var walk_speed := 2.0
@export var chase_speed := 4.5            ## «быстрый шаг»: чуть быстрее шага игрока (4), медленнее бега (6.5)
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
@export var game_over_scene := "res://ui/game_over.tscn"

@export_group("Шкафы")
@export_range(0.0, 1.0) var kill_chance_seen := 0.95    ## видел, как игрок залез — почти наверняка убьёт
@export_range(0.0, 1.0) var kill_chance_suspect := 0.7  ## просто проверяет шкаф рядом с местом, где потерял
@export_range(0.0, 1.0) var search_check_chance := 0.6  ## потеряв игрока, проверит ближайший шкаф
@export_range(0.0, 1.0) var patrol_check_chance := 0.2  ## на патруле иногда заглядывает в шкаф рядом
@export var check_radius := 7.0          ## шкафы в этом радиусе от места поиска
@export var stare_time := 2.5            ## сколько смотрит на игрока в открытом шкафу

@export_group("Скример")
@export var jumpscare_sound: AudioStream ## пусто — возьмёт characters/maniac/jumpscare.wav
@export var jumpscare_volume_db := 6.0
@export var debug := false

@export_group("Звук шагов")
@export var step_length_walk := 1.4      ## шаг каждые N метров при обычной ходьбе
@export var step_length_chase := 2.0     ## при погоне шаги реже, но громче
@export var step_volume_walk := -6.0     ## дБ
@export var step_volume_chase := 0.0     ## дБ

@onready var agent: NavigationAgent3D = $NavigationAgent3D
## Узел AudioStreamPlayer3D с именем «Footsteps» внутри Maniac (необязательный)
@onready var footsteps: AudioStreamPlayer3D = get_node_or_null("Footsteps")
## Точка лица в модели (characters/maniac/maniac_model.tscn) — по ней ставится скример
@onready var face_anchor: Node3D = get_node_or_null("Model/FaceAnchor")

var state: State = State.PATROL
var player: CharacterBody3D
var patrol_points: Array[Node3D] = []
var last_seen_pos := Vector3.ZERO
var time_since_seen := 999.0
var timer := 0.0
var caught := false
var active := false            # false — ещё не появился в доме
var ai_paused := false         # катсцена: стоит на месте, ничего не видит и не слышит (set_ai_paused)
var _start_timer := -1.0
var _trap_door: Node = null
var _trap_time := 0.0
var _has_target := false
var _stuck_time := 0.0
var _unstick_time := 0.0
var _unstick_dir := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _best_dist := INF          # ближе всего, насколько подходил к текущей цели
var _no_progress := 0.0        # сколько секунд не приближается к цели
var _hear_cooldown := 0.0
var _door_check := 0.0
var _step_dist := 0.0
var _check_spot: Node3D = null
var _check_kill := 0.0
var _check_phase := 0          # 0 — идёт к шкафу, 1 — стоит и смотрит
var _check_cooldown := {}      # шкаф -> когда можно проверять снова (сек)
var _search_checked := false
var _face_light: OmniLight3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("maniac")
	# свет на лицо: чтобы маску было видно, когда он открывает шкаф и при скримере
	_face_light = OmniLight3D.new()
	_face_light.light_color = Color(1.0, 0.85, 0.75)
	_face_light.light_energy = 0.9
	_face_light.omni_range = 2.2
	_face_light.position = Vector3(0, 1.9, -0.7)
	_face_light.visible = false
	add_child(_face_light)
	if jumpscare_sound == null and ResourceLoader.exists("res://characters/maniac/jumpscare.wav"):
		jumpscare_sound = load("res://characters/maniac/jumpscare.wav")
	for n in get_tree().get_nodes_in_group("patrol_point"):
		patrol_points.append(n)
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null and get_tree().current_scene:
		player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	if start_flag == "" or get_tree().get_first_node_in_group("game") == null:
		active = true
	else:
		_set_present(false)


## Убрать маньяка из игры (финал у машины): невидим, ничего не делает
func vanish() -> void:
	active = false
	ai_paused = true
	velocity = Vector3.ZERO
	if footsteps:
		footsteps.stop()
	_face_light.visible = false
	_set_present(false)


## Пока не появился — невидим и не мешает
func _set_present(v: bool) -> void:
	visible = v
	$CollisionShape3D.set_deferred("disabled", not v)


func _wait_for_start(delta: float) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if _start_timer < 0.0:
		if game == null or game.has_flag(start_flag):
			_start_timer = start_delay
		return
	_start_timer -= delta
	if _start_timer <= 0.0:
		active = true
		_set_present(true)
		if debug:
			print("[Maniac] starts hunting")


## Катсцена ставит ИИ на паузу: состояние сохраняется, после паузы он продолжит с того же места
func set_ai_paused(paused: bool) -> void:
	ai_paused = paused
	if paused:
		velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if caught or player == null or ai_paused:
		return
	if not active:
		_wait_for_start(delta)
		return
	if state == State.TRAPPED:
		_trapped(delta)
		return
	# карта навигации готова не в первый кадр
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return

	time_since_seen += delta
	for k in _check_cooldown.keys():
		_check_cooldown[k] -= delta
	if can_see_player():
		time_since_seen = 0.0
		last_seen_pos = player.global_position
		if state != State.CHASE:
			set_state(State.CHASE)
	elif state != State.CHASE and state != State.CHECK_HIDE and _hear_cooldown <= 0.0 and can_hear_player():
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
			_search(delta)
		State.CHECK_HIDE:
			_check_hide(delta)

	var speed := walk_speed
	if state == State.CHASE or (state == State.CHECK_HIDE and _check_kill >= 0.5):
		speed = chase_speed
	_move(delta, speed)

	if state == State.CHASE and _close_to_player():
		_catch()


# ---------------------------------------------------------------- органы чувств

func can_see_player() -> bool:
	if player.is_hidden:
		return false   # в шкафу не видно — но может проверить шкаф (CHECK_HIDE)
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
	if player.is_hidden:
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
	return player.is_flashlight_on()


func _close_to_player() -> bool:
	if player.is_hidden:
		return false
	var d := player.global_position - global_position
	return abs(d.y) < 1.5 and Vector2(d.x, d.z).length() < catch_distance


# ---------------------------------------------------------------- состояния

func set_state(s: State) -> void:
	if s == state:
		return
	if state == State.CHECK_HIDE and _face_light:
		_face_light.visible = false
	state = s
	timer = 0.0
	if s == State.SEARCH:
		_search_checked = false
		_go_to(last_seen_pos)
	if debug:
		print("[Maniac] -> ", State.keys()[s])
	state_changed.emit(s)


func _patrol(delta: float) -> void:
	if not _has_target or agent.is_navigation_finished():
		timer -= delta
		if timer <= 0.0:
			timer = patrol_wait
			# иногда заглядывает в шкаф рядом с точкой патруля
			if _has_target and randf() < patrol_check_chance:
				var spot := _nearest_hide_spot(global_position, 4.0)
				if spot:
					start_check(spot, kill_chance_suspect)
					return
			_next_patrol_point()


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


## Поиск: дошёл до места, где потерял игрока — может проверить ближайший шкаф
func _search(delta: float) -> void:
	if (not _has_target or agent.is_navigation_finished()) and not _search_checked:
		_search_checked = true
		if randf() < search_check_chance:
			var spot := _nearest_hide_spot(last_seen_pos, check_radius)
			if spot:
				start_check(spot, kill_chance_suspect)
				return
	_wait_then_patrol(delta, search_time)


# ---------------------------------------------------------------- засов

## Игрок запер его в комнате (вызывает door.gd)
func trap(door: Node, seconds: float) -> void:
	_trap_door = door
	_trap_time = seconds
	_has_target = false
	_check_spot = null
	set_state(State.TRAPPED)


## Стоит у двери и ломится; время вышло — выламывает и идёт за игроком
func _trapped(delta: float) -> void:
	_trap_time -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if _trap_door and is_instance_valid(_trap_door):
		var to: Vector3 = _trap_door.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), turn_speed * delta)
	if _trap_time <= 0.0:
		if _trap_door and is_instance_valid(_trap_door) and _trap_door.has_method("break_open"):
			_trap_door.break_open()
		_trap_door = null
		state = State.PATROL
		hear_noise(player.global_position)   # знает, куда побежал игрок


# ---------------------------------------------------------------- шкафы

## Вызывает hide_spot.gd, когда игрок залезает в шкаф (ещё до того, как он спрятался)
func on_player_hid(spot: Node3D) -> void:
	if caught or not active or ai_paused or state == State.TRAPPED:
		return
	var saw := can_see_player() or (state == State.CHASE and time_since_seen < 0.6)
	if saw:
		if debug:
			print("[Maniac] saw player hide in ", spot.name)
		start_check(spot, kill_chance_seen)


func start_check(spot: Node3D, kill_chance: float) -> void:
	_check_spot = spot
	_check_kill = kill_chance
	_check_phase = 0
	_check_cooldown[spot] = 25.0
	state = State.PATROL   # чтобы set_state сработал, даже если уже CHECK_HIDE
	set_state(State.CHECK_HIDE)
	_go_to(spot.front_point(0.9))


func _nearest_hide_spot(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for s in get_tree().get_nodes_in_group("hide_spot"):
		if _check_cooldown.get(s, 0.0) > 0.0:
			continue
		var fp: Vector3 = s.front_point(0.9)
		if abs(fp.y - pos.y) > 1.5:
			continue
		var d := fp.distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	return best


func _check_hide(delta: float) -> void:
	if _check_spot == null or not is_instance_valid(_check_spot):
		set_state(State.PATROL)
		return
	var player_inside: bool = player.hide_spot == _check_spot
	if _check_phase == 0:
		var fp: Vector3 = _check_spot.front_point(0.9)
		var flat := Vector2(fp.x - global_position.x, fp.z - global_position.z).length()
		if flat < 0.35 or agent.is_navigation_finished():
			_check_phase = 1
			timer = 0.0
			_has_target = false
		return
	# встаёт ровно напротив дверец и поворачивается к шкафу лицом
	var target: Vector3 = _check_spot.front_point(0.9)
	var off := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if off.length() > 0.03:
		global_position += off * min(1.0, delta * 3.0)   # плавно подшагивает к центру
	var to: Vector3 = _check_spot.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), turn_speed * delta)
	timer += delta
	if timer >= 0.7 and timer - delta < 0.7:
		# открывает дверцы
		if player_inside:
			_check_spot.open_doors()
			_face_light.visible = true
		if debug:
			print("[Maniac] opens ", _check_spot.name, " player inside: ", player_inside)
	if not player_inside:
		if timer >= 2.0:
			_check_spot = null
			set_state(State.PATROL)
		return
	if timer >= 0.7 + stare_time:
		if randf() < _check_kill:
			_catch()
		else:
			# посмотрел… и ушёл
			_check_spot.close_doors()
			_check_cooldown[_check_spot] = 40.0
			_check_spot = null
			set_state(State.PATROL)
			_has_target = false
			timer = patrol_wait


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
	_play_footsteps(delta)


## Звук шагов: копим пройденное расстояние, каждые ~1.4 м — один шаг
func _play_footsteps(delta: float) -> void:
	if footsteps == null or footsteps.stream == null:
		return
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horizontal < 0.3:
		return
	_step_dist += horizontal * delta
	var chasing := state == State.CHASE
	var step_len := step_length_chase if chasing else step_length_walk
	if _step_dist >= step_len:
		_step_dist = 0.0
		footsteps.pitch_scale = randf_range(0.9, 1.08)   # чтобы шаги не звучали одинаково
		footsteps.volume_db = step_volume_chase if chasing else step_volume_walk
		footsteps.play()


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
	if caught:
		return
	caught = true
	player_caught.emit()
	if debug:
		print("[Maniac] CAUGHT")
	_jumpscare()


## Скример: маньяк резко бросается в камеру, крик, тряска, темнота → экран поимки
func _jumpscare() -> void:
	var cam: Camera3D = player.get_camera()
	var head: Node3D = player.get_head()
	player.set_dead()   # управление выключено, игрок замер
	$CollisionShape3D.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if footsteps:
		footsteps.stop()
	if head:
		head.rotation.x = 0.0          # взгляд резко выравнивается — прямо ему в лицо
	_face_light.visible = false
	if cam:
		# свет от камеры, чтобы маску было видно даже в полной темноте
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.7)
		l.light_energy = 0.9
		l.omni_range = 3.0
		l.position = Vector3(0, 0.25, 0)
		cam.add_child(l)

	# звук
	if jumpscare_sound:
		var snd := AudioStreamPlayer.new()
		snd.stream = jumpscare_sound
		snd.volume_db = jumpscare_volume_db
		snd.bus = &"SFX"
		add_child(snd)
		snd.play()

	# красная вспышка и затемнение поверх всего
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.6, 0.0, 0.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)

	if cam == null:
		_finish_catch()
		return
	await get_tree().process_frame
	var eye := cam.global_position
	var fwd := -cam.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	rotation = Vector3(0, atan2(fwd.x, fwd.z), 0)   # лицом к игроку
	# где лицо относительно корня маньяка (уже с учётом поворота)
	var face_local := to_local(face_anchor.global_position) if face_anchor else Vector3(0, 1.57, -0.31)
	var face_offset := global_basis * face_local

	# бросок: с 1.3 м до 0.25 м за 0.15 секунды
	var t := 0.0
	var total := 1.3
	while t < total:
		var dt := get_process_delta_time()
		t += dt
		var k: float = clamp(t / 0.15, 0.0, 1.0)
		var dist: float = lerp(1.3, 0.25, 1.0 - pow(1.0 - k, 3.0))
		# лицо (FaceAnchor) встаёт прямо перед камерой
		global_position = eye + fwd * dist - face_offset
		# тряска камеры
		var shake: float = 0.08 * (1.0 - t / total)
		cam.h_offset = randf_range(-shake, shake)
		cam.v_offset = randf_range(-shake, shake)
		flash.color.a = 0.35 * (1.0 - clamp(t / 0.4, 0.0, 1.0)) if t < 0.4 else 0.0
		black.color.a = clamp((t - 0.8) / 0.4, 0.0, 1.0)
		await get_tree().process_frame
	_finish_catch()


func _finish_catch() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# экран уже чёрный (скример) — сразу меняем сцену и проявляем экран поимки
	SceneFlow.change_scene(game_over_scene, 0.0, 0.6)
