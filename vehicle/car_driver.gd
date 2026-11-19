extends Node
## Вождение машины по дороге (дочерний узел Driver машины, vehicle/car.tscn).
##
## Аркадная, но «честная» модель: машина имеет свой курс и руль (кинематика «велосипеда»
## в координатах дороги — расстояние по дороге s, смещение от оси x, угол к дороге psi).
## В поворот машину нужно вести рулём: не повернёшь — вынесет к внешнему краю.
## Руль крутится плавно (скорость поворота ограничена), на скорости — острее.
## Сцепление ограничено (grip): на крутом повороте нужно тормозить, иначе машину сносит.
## С дороги не вылететь и не застрять: на краю машина скользит вдоль отвала, теряя скорость;
## задним ходом не ездит, без газа катится на холостом ходу.
## За fuel_out_distance до конца дороги кончается бензин: управление забирается, машина
## накатом останавливается РОВНО в конце дороги (место стоянки).
##
## Для приборов: speed, rpm, gear, fuel; для руля и камеры: steer (угол колёс).

const CarScript = preload("res://vehicle/car.gd")

signal fuel_out              ## бензин кончился (управление уже забрано, машина катится)
signal stopped               ## машина встала на место стоянки
signal bumped(strength: float)   ## удар об отвал (для тряски камеры)

@export_group("Скорость (м/с)")
@export var cruise_speed := 14.0       ## ≈ 50 км/ч — скорость автопилота во вступлении
@export var max_speed := 25.0          ## 90 км/ч
@export var accel := 4.5               ## разгон с места, к максимальной скорости слабеет
@export var brake_decel := 10.0
@export var handbrake_decel := 14.0
@export var engine_brake := 1.2        ## замедление без газа
@export var creep_speed := 2.5         ## холостой ход: машина не встанет сама
@export_group("Руль")
@export var wheelbase := 2.35          ## меньше — машина поворачивает круче при том же угле руля
@export var max_steer_slow := 0.7      ## угол колёс на малой скорости, рад
@export var max_steer_fast := 0.3      ## на максимальной скорости, рад
@export var steer_rate := 2.6          ## скорость поворота колёс, рад/с
@export var return_rate := 3.0         ## возврат руля, когда клавиши отпущены
@export var grip := 12.5               ## предел бокового ускорения, м/с² (дальше — снос)
@export var steering_ratio := 7.0      ## руль поворачивается во столько раз сильнее колёс
@export_group("Края дороги")
@export var car_half_width := 0.9
@export var edge_margin := 0.15
@export var scrape_decel := 5.0        ## трение об отвал, м/с²
@export_group("Кузов")
@export var max_roll_deg := 3.5
@export var max_pitch_deg := 2.0
@export var wheel_radius := 0.35
@export_group("Бензин")
@export var fuel_out_distance := 85.0  ## за сколько метров до конца дороги глохнет мотор
@export var min_coast_speed := 6.0     ## даже если игрок полз — докатится до места
@export var fuel_start := 0.12         ## бак почти пуст (доля), к месту остановки — ноль
@export_group("Двигатель (для тахометра)")
@export var gear_tops := PackedFloat32Array([8.0, 14.0, 20.0, 26.0])   ## до какой скорости тянет передача
@export var idle_rpm := 850.0
@export var red_rpm := 6000.0

var distance := 0.0          ## пройдено по дороге, м
var speed := 0.0             ## м/с
var offset := 0.0            ## смещение от оси дороги, м (+ — вправо)
var heading := 0.0           ## угол машины к дороге, рад (+ — нос влево)
var steer := 0.0             ## угол передних колёс, рад (+ — влево)
var throttle := 0.0
var braking := false
var rpm := 0.0
var gear := 1
var fuel := 0.12             ## 0..1
var player_control := false  ## управляет игрок
var autopilot := false       ## едет сама (вступление)

var _road   # levels/world/exterior_road.gd
var _yaw_rate := 0.0
var _roll := 0.0
var _pitch := 0.0
var _prev_speed := 0.0
var _bump_cd := 0.0
var _coast_t := 0.0
var _coast_d0 := 0.0
var _coast_v0 := 0.0
var _coast_a := 1.0
var _coast_x0 := 0.0
var _coast_h0 := 0.0

@onready var car: CarScript = get_parent()
@onready var _model: Node3D = car.get_node("Model")
@onready var _front: Array[Node3D] = [car.get_node("Wheels/FL"), car.get_node("Wheels/FR")]
@onready var _spins: Array[Node3D] = [car.get_node("Wheels/FL/Spin"), car.get_node("Wheels/FR/Spin"),
		car.get_node("Wheels/RL/Spin"), car.get_node("Wheels/RR/Spin")]
@onready var _wheel_spin: Node3D = car.get_node_or_null("Model/Interior/SteeringWheel/Spin")


func _ready() -> void:
	_road = car.get_road()
	fuel = fuel_start


func _process(delta: float) -> void:
	if _road == null:
		return
	match car.state:
		CarScript.State.DRIVING:
			_drive(delta)
		CarScript.State.STOPPING:
			_coast(delta)
		_:
			return
	_update_engine(delta)
	_place(delta)


# ---------------------------------------------------------------- начало / конец

func place_at_start() -> void:
	if _road == null:
		return
	distance = 0.0
	speed = cruise_speed
	offset = 0.0
	_reset_pose()
	fuel = fuel_start
	car.state = CarScript.State.DRIVING
	_update_engine(0.0)
	_place(0.0)


func place_at_end() -> void:
	if _road == null:
		return
	distance = _road.get_length()
	speed = 0.0
	offset = 0.0
	_reset_pose()
	fuel = 0.0
	rpm = 0.0
	car.state = CarScript.State.PARKED
	_place(0.0)


## Точка на дороге впереди машины (для камеры сзади)
func look_target() -> Vector3:
	if _road == null:
		return car.global_position - car.global_basis.z * 10.0
	var p: Vector3 = _road.get_frame(distance + 14.0).origin
	return p + Vector3(0, 0.8, 0)


func get_speed_kmh() -> float:
	return speed * 3.6


## Боковая перегрузка (м/с², + — всё в машине тянет вправо, т. е. поворот налево): крен и камера водителя
func get_lateral_accel() -> float:
	return speed * _yaw_rate


func _reset_pose() -> void:
	heading = 0.0
	steer = 0.0
	throttle = 0.0
	_yaw_rate = 0.0
	_roll = 0.0
	_pitch = 0.0
	_prev_speed = speed
	braking = false


# ---------------------------------------------------------------- езда

func _drive(delta: float) -> void:
	var brake := false
	var handbrake := false
	var steer_in := 0.0   # + — вправо
	throttle = 0.0
	if player_control:
		throttle = Input.get_action_strength("car_accelerate")
		brake = Input.is_action_pressed("car_brake")
		handbrake = Input.is_action_pressed("car_handbrake")
		steer_in = Input.get_action_strength("car_steer_right") - Input.get_action_strength("car_steer_left")
	elif autopilot:
		throttle = 0.6 if speed < cruise_speed else 0.0

	# --- скорость
	braking = brake or handbrake
	if handbrake:
		speed = move_toward(speed, 0.0, handbrake_decel * delta)
	elif brake:
		speed = move_toward(speed, 0.0, brake_decel * delta)
	elif throttle > 0.0:
		var k := 1.0 - pow(speed / max_speed, 2.0)
		speed += accel * throttle * max(k, 0.0) * delta
	elif speed > creep_speed:
		speed = move_toward(speed, creep_speed, engine_brake * delta)
	else:
		speed = move_toward(speed, creep_speed, 1.5 * delta)
	speed = clamp(speed, 0.0, max_speed)

	# --- руль: плавно, на скорости — меньше
	var k_road: float = _road.get_curvature(distance)
	var max_steer: float = lerpf(max_steer_slow, max_steer_fast, clamp(speed / max_speed, 0.0, 1.0))
	var target := -steer_in * max_steer
	var rate := steer_rate if steer_in != 0.0 else return_rate
	if autopilot and not player_control:
		target = _autopilot_steer(k_road)
		rate = steer_rate
	steer = move_toward(steer, target, rate * delta)

	_integrate(delta, k_road)
	car.set_brake_lights(braking)
	if distance >= _road.get_length() - fuel_out_distance:
		_begin_stop()


## Автопилот вступления: держит середину своей полосы движения и следует изгибу дороги
func _autopilot_steer(k_road: float) -> float:
	var want_heading: float = clamp(0.25 * offset, -0.25, 0.25)   # правее оси — повернуть левее
	return atan(wheelbase * k_road) + 1.8 * (want_heading - heading)


## Движение в координатах дороги (s, x, psi)
func _integrate(delta: float, k_road: float) -> void:
	var yaw := speed * tan(steer) / wheelbase
	var limit := grip / maxf(speed, 0.5)
	yaw = clamp(yaw, -limit, limit)          # снос: руль повёрнут сильнее, чем держат шины
	_yaw_rate = yaw
	var s_dot := speed * cos(heading) / maxf(1.0 + k_road * offset, 0.2)
	var x_dot := -speed * sin(heading)
	distance += s_dot * delta
	offset += x_dot * delta
	heading += (yaw - k_road * s_dot) * delta
	heading = clamp(heading, -1.1, 1.1)
	_bump_cd -= delta

	var lim: float = _road.half_width - car_half_width - edge_margin
	if absf(offset) > lim:
		var side := signf(offset)
		offset = side * lim
		# нос смотрит наружу — машину разворачивает вдоль отвала
		var outward := -sin(heading) * side
		if outward > 0.0:
			var hit := outward * speed
			heading = lerpf(heading, 0.0, 1.0 - exp(-10.0 * delta))
			if hit > 1.5 and _bump_cd <= 0.0:
				_bump_cd = 0.5
				speed *= 0.85
				bumped.emit(clamp(hit / 8.0, 0.0, 1.0))
		if speed > creep_speed:
			speed = move_toward(speed, creep_speed, scrape_decel * delta)


# ---------------------------------------------------------------- бензин кончился

func _begin_stop() -> void:
	car.state = CarScript.State.STOPPING
	player_control = false
	autopilot = false
	braking = false
	throttle = 0.0
	car.set_brake_lights(false)
	var remaining: float = _road.get_length() - distance
	_coast_d0 = distance
	_coast_v0 = max(speed, min_coast_speed)
	_coast_a = _coast_v0 * _coast_v0 / (2.0 * max(remaining, 0.5))
	_coast_t = 0.0
	_coast_x0 = offset
	_coast_h0 = heading
	fuel = 0.0
	fuel_out.emit()


## Равнозамедленный накат: скорость падает до нуля ровно в конце дороги,
## машина плавно выравнивается по оси дороги
func _coast(delta: float) -> void:
	_coast_t += delta
	var t_end := _coast_v0 / _coast_a
	var t: float = min(_coast_t, t_end)
	var length: float = _road.get_length()
	distance = min(_coast_d0 + _coast_v0 * t - 0.5 * _coast_a * t * t, length)
	speed = max(_coast_v0 - _coast_a * t, 0.0)
	var f: float = (length - distance) / max(length - _coast_d0, 0.001)
	offset = _coast_x0 * f
	heading = _coast_h0 * f * f
	steer = move_toward(steer, 0.0, return_rate * 0.5 * delta)
	_yaw_rate = 0.0
	if _coast_t >= t_end:
		place_at_end()
		stopped.emit()


# ---------------------------------------------------------------- приборы

func _update_engine(delta: float) -> void:
	if car.state == CarScript.State.DRIVING and car.engine_running:
		fuel = fuel_start * clamp((_road.get_length() - fuel_out_distance - distance) / max(_road.get_length() - fuel_out_distance, 1.0), 0.0, 1.0)
		gear = 1
		while gear < gear_tops.size() and speed > gear_tops[gear - 1] * 0.92:
			gear += 1
		var top: float = gear_tops[gear - 1]
		var target_rpm: float = idle_rpm + (speed / top) * (red_rpm - idle_rpm - 600.0) + throttle * 400.0
		rpm = lerpf(rpm, target_rpm, 1.0 - exp(-6.0 * delta)) if delta > 0.0 else target_rpm
	else:
		rpm = lerpf(rpm, 0.0, 1.0 - exp(-3.0 * delta)) if delta > 0.0 else 0.0


# ---------------------------------------------------------------- положение машины

func _place(delta: float) -> void:
	var f: Transform3D = _road.get_frame(distance)
	car.global_transform = Transform3D(f.basis * Basis(Vector3.UP, heading), f.origin + f.basis.x * offset)
	# крен в повороте и «клевок» при торможении
	if delta > 0.0:
		var a_long := (speed - _prev_speed) / delta
		_prev_speed = speed
		var max_roll := deg_to_rad(max_roll_deg)
		var max_pitch := deg_to_rad(max_pitch_deg)
		var roll_t: float = clamp(-get_lateral_accel() * 0.009, -max_roll, max_roll)
		var pitch_t: float = clamp(a_long * 0.004, -max_pitch, max_pitch)
		_roll = lerpf(_roll, roll_t, 1.0 - exp(-5.0 * delta))
		_pitch = lerpf(_pitch, pitch_t, 1.0 - exp(-5.0 * delta))
	_model.rotation = Vector3(_pitch, 0.0, _roll)
	for s in _spins:
		s.rotation.x -= speed / wheel_radius * delta
	for w in _front:
		w.rotation.y = steer
	if _wheel_spin:
		_wheel_spin.rotation.z = steer * steering_ratio
