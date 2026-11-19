extends CharacterBody3D
## Игрок: ходьба (WASD), бег (Shift, тратит выносливость), присед (Ctrl, тихо),
## прыжок (Space), фонарик (F), покачивание камеры при ходьбе.
## Клавиши — действия InputMap (project.godot → [input]), по физическим клавишам.
## noise_radius — на каком расстоянии маньяк слышит шаги (читает maniac.gd).
##
## Управление игроком извне — ТОЛЬКО через API ниже (шкаф, скример, катсцены):
##   set_control_enabled(), set_hidden(), set_dead(), set_body_enabled(),
##   set_flashlight(), teleport_to(), get_camera(), get_head().

signal control_changed(enabled: bool)

@export_group("Скорость")
@export var walk_speed := 4.0
@export var sprint_speed := 6.5           ## маньяк в погоне идёт 4.5 — шагом еле уходишь, бегом отрываешься
@export var crouch_speed := 2.0
@export var jump_velocity := 4.5

@export_group("Выносливость")
@export var stamina_max := 100.0
@export var stamina_drain := 22.0         ## в секунду при беге (~4.5 секунды бега)
@export var stamina_regen := 15.0         ## в секунду при отдыхе
@export var stamina_regen_delay := 1.0    ## пауза перед восстановлением
@export var exhausted_until := 30.0       ## выдохся — бежать снова можно только с этого уровня

@export_group("Присед")
@export var stand_height := 1.8
@export var crouch_height := 1.1
@export var stand_eye := 1.6
@export var crouch_eye := 0.95

@export_group("Шум (для маньяка)")
@export var noise_walk := 6.0
@export var noise_sprint := 13.0
@export var noise_crouch := 1.5

@export_group("Покачивание камеры")
@export var bob_amount := 0.04
@export var bob_speed := 9.0

@export_group("Звук шагов")
@export var footstep_snow: AudioStream   ## снаружи (снег)
@export var footstep_wood: AudioStream   ## в доме (пол узла в группе "surface_wood")
@export var step_length_walk := 1.5      ## шаг каждые N метров
@export var step_length_sprint := 2.0
@export var step_length_crouch := 0.9
@export var step_volume_walk := -10.0    ## дБ
@export var step_volume_sprint := -5.0
@export var step_volume_crouch := -20.0

var stamina := 100.0
var exhausted := false
var is_sprinting := false
var is_crouching := false
var noise_radius := 0.0

## Игрок сидит в шкафу (менять через set_hidden)
var is_hidden := false
## В каком шкафу сидит игрок (null — не прячется)
var hide_spot: Node = null
## Игрока поймали (скример): управление отключено навсегда (менять через set_dead)
var is_dead := false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var _control_enabled := true
var _regen_wait := 0.0
var _bob_t := 0.0
var _step_dist := 0.0
var _shape: CapsuleShape3D

@onready var head = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight = $Head/Camera3D/Flashlight
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var footsteps: AudioStreamPlayer = get_node_or_null("Footsteps")


func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	flashlight.visible = false
	stamina = stamina_max
	_shape = collision.shape.duplicate()   # своя копия, чтобы менять высоту при приседе
	collision.shape = _shape


# ---------------------------------------------------------------- API управления

## Включить/выключить управление (ходьба, взгляд мышью, фонарик). Для катсцен.
func set_control_enabled(enabled: bool) -> void:
	if enabled == _control_enabled:
		return
	_control_enabled = enabled
	if not enabled:
		_stop()
	_refresh_processing()
	control_changed.emit(enabled)


func is_control_enabled() -> bool:
	return _control_enabled


## Игрок залез в шкаф (spot) или вылез из него (null).
## Внутри: тело стоит на месте, смотреть можно только в щель (лимиты берутся у шкафа).
func set_hidden(spot: Node) -> void:
	if spot:
		is_hidden = true
		hide_spot = spot
		_stop()
		# в шкафу стоим в полный рост и смотрим прямо
		head.rotation = Vector3.ZERO
		head.position.y = stand_eye
		is_crouching = false
	else:
		is_hidden = false
		hide_spot = null
		# выходим: поворот головы переносим на тело
		rotation.y += head.rotation.y
		head.rotation.y = 0.0
	_refresh_processing()


## Игрока поймали: управление отключается насовсем
func set_dead() -> void:
	is_dead = true
	_stop()
	_refresh_processing()


## Коллизия тела вкл/выкл (шкаф, позже — сиденье машины)
func set_body_enabled(enabled: bool) -> void:
	collision.set_deferred("disabled", not enabled)


func set_flashlight(on: bool) -> void:
	flashlight.visible = on


func is_flashlight_on() -> bool:
	return flashlight.visible


## Переставить игрока (поворот тела — только по Y, как при обычном управлении)
func teleport_to(xform: Transform3D) -> void:
	global_transform = xform
	velocity = Vector3.ZERO


func get_camera() -> Camera3D:
	return camera


func get_head() -> Node3D:
	return head


func _can_move() -> bool:
	return _control_enabled and not is_hidden and not is_dead


func _refresh_processing() -> void:
	set_physics_process(_can_move())


func _stop() -> void:
	velocity = Vector3.ZERO
	noise_radius = 0.0
	is_sprinting = false


# ---------------------------------------------------------------- ввод

func _unhandled_input(event):
	if is_dead or not _control_enabled:
		return   # скример / катсцена: управление отключено
	# Esc (pause) обрабатывает меню паузы (ui/pause_menu.gd)
	if event.is_action_pressed("flashlight") and not is_hidden:   # в шкафу фонарик не включить
		flashlight.visible = not flashlight.visible

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.mouse_sensitivity
		if is_hidden:
			# в шкафу смотрим в щель: только вверх-вниз, влево-вправо нельзя
			var yaw_lim := 0.0
			var pitch_lim := deg_to_rad(20.0)
			if hide_spot:
				yaw_lim = deg_to_rad(hide_spot.look_yaw_limit)
				pitch_lim = deg_to_rad(hide_spot.look_pitch_limit)
			head.rotation.y = clamp(head.rotation.y - event.relative.x * sens, -yaw_lim, yaw_lim)
			head.rotation.x = clamp(head.rotation.x - event.relative.y * sens, -pitch_lim, pitch_lim)
			return
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-event.relative.y * sens)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()
	var moving: bool = input_dir != Vector2.ZERO

	_update_crouch(delta)
	_update_sprint(delta, moving, input_dir)

	if Input.is_action_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# шум шагов: стоишь — тихо, присед — почти не слышно, бег — далеко
	if not moving or not is_on_floor():
		noise_radius = 0.0
	elif is_crouching:
		noise_radius = noise_crouch
	elif is_sprinting:
		noise_radius = noise_sprint
	else:
		noise_radius = noise_walk

	_update_head_bob(delta, moving)
	_play_footsteps(delta, moving)


func _update_sprint(delta: float, moving: bool, input_dir: Vector2) -> void:
	var wants := Input.is_action_pressed("sprint") and moving and input_dir.y < 0 and not is_crouching
	if exhausted and stamina >= exhausted_until:
		exhausted = false
	is_sprinting = wants and not exhausted and stamina > 0.0
	if is_sprinting:
		stamina = max(0.0, stamina - stamina_drain * delta)
		_regen_wait = stamina_regen_delay
		if stamina <= 0.0:
			exhausted = true
	else:
		if _regen_wait > 0.0:
			_regen_wait -= delta
		else:
			stamina = min(stamina_max, stamina + stamina_regen * delta)


func _update_crouch(delta: float) -> void:
	var wants := Input.is_action_pressed("crouch")
	if wants:
		is_crouching = true
	elif is_crouching and _can_stand_up():
		is_crouching = false
	var h := crouch_height if is_crouching else stand_height
	_shape.height = move_toward(_shape.height, h, delta * 4.0)
	collision.position.y = _shape.height / 2.0
	var eye := crouch_eye if is_crouching else stand_eye
	head.position.y = move_toward(head.position.y, eye, delta * 3.5)


## Нельзя встать, если над головой потолок (например, под лестницей)
func _can_stand_up() -> bool:
	var from := global_position + Vector3(0, crouch_height, 0)
	var to := global_position + Vector3(0, stand_height + 0.05, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Шаги: копим пройденное расстояние, каждые step_length — один шаг (как у маньяка)
func _play_footsteps(delta: float, moving: bool) -> void:
	if footsteps == null:
		return
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if not moving or not is_on_floor() or horizontal < 0.3:
		_step_dist = step_length_walk * 0.6   # первый шаг — почти сразу после старта
		return
	_step_dist += horizontal * delta
	var step_len := step_length_walk
	var vol := step_volume_walk
	if is_crouching:
		step_len = step_length_crouch
		vol = step_volume_crouch
	elif is_sprinting:
		step_len = step_length_sprint
		vol = step_volume_sprint
	if _step_dist < step_len:
		return
	_step_dist = 0.0
	var stream: AudioStream = footstep_wood if _on_wood() else footstep_snow
	if stream:
		footsteps.stream = stream
	if footsteps.stream == null:
		return
	footsteps.pitch_scale = randf_range(0.92, 1.08)   # чтобы шаги не звучали одинаково
	footsteps.volume_db = vol
	footsteps.play()


## Под ногами пол дома (узел из группы "surface_wood" или его потомок)?
func _on_wood() -> bool:
	var from := global_position + Vector3(0, 0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0.8, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var n: Node = hit.collider
	while n:
		if n.is_in_group("surface_wood"):
			return true
		n = n.get_parent()
	return false


func _update_head_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		var k := 1.4 if is_sprinting else (0.6 if is_crouching else 1.0)
		_bob_t += delta * bob_speed * k
		camera.position.y = sin(_bob_t) * bob_amount * k
		camera.position.x = cos(_bob_t * 0.5) * bob_amount * 0.5 * k
	else:
		camera.position.y = move_toward(camera.position.y, 0.0, delta * 0.3)
		camera.position.x = move_toward(camera.position.x, 0.0, delta * 0.3)
