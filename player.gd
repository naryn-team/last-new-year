extends CharacterBody3D
## Игрок: ходьба (WASD), бег (Shift, тратит выносливость), присед (Ctrl, тихо),
## прыжок (Space), фонарик (F), покачивание камеры при ходьбе.
## noise_radius — на каком расстоянии маньяк слышит шаги (читает maniac.gd).

@export_group("Скорость")
@export var walk_speed := 4.0
@export var sprint_speed := 6.5           ## маньяк в погоне бегает 5.0 — без бега не убежать
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

var stamina := 100.0
var exhausted := false
var is_sprinting := false
var is_crouching := false
var noise_radius := 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var _regen_wait := 0.0
var _bob_t := 0.0
var _shape: CapsuleShape3D

@onready var head = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight = $Head/Camera3D/Flashlight
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	flashlight.visible = false
	stamina = stamina_max
	_shape = collision.shape.duplicate()   # своя копия, чтобы менять высоту при приседе
	collision.shape = _shape


func _unhandled_input(event):
	# Esc теперь обрабатывает меню паузы (game/pause_menu.gd)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			flashlight.visible = not flashlight.visible

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.mouse_sensitivity
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-event.relative.y * sens)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	input_dir = input_dir.normalized()
	var moving: bool = input_dir != Vector2.ZERO

	_update_crouch(delta)
	_update_sprint(delta, moving, input_dir)

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
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


func _update_sprint(delta: float, moving: bool, input_dir: Vector2) -> void:
	var wants := Input.is_key_pressed(KEY_SHIFT) and moving and input_dir.y < 0 and not is_crouching
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
	var wants := Input.is_key_pressed(KEY_CTRL)
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


func _update_head_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		var k := 1.4 if is_sprinting else (0.6 if is_crouching else 1.0)
		_bob_t += delta * bob_speed * k
		camera.position.y = sin(_bob_t) * bob_amount * k
		camera.position.x = cos(_bob_t * 0.5) * bob_amount * 0.5 * k
	else:
		camera.position.y = move_toward(camera.position.y, 0.0, delta * 0.3)
		camera.position.x = move_toward(camera.position.x, 0.0, delta * 0.3)
