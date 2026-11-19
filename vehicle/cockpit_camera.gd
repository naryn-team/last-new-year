extends Node3D
## Голова водителя (узел DriverHead машины, в точке DriverSeat; дочерний Camera3D).
##   • мышью можно оглядываться (в пределах yaw/pitch); через look_return_delay секунд
##     без движения мыши взгляд плавно возвращается вперёд;
##   • взгляд сам не поворачивается и не кренится: камера поворачивается только вместе с машиной;
##   • голову чуть смещает перегрузкой (без поворота): в повороте — наружу, при торможении — вперёд;
##   • лёгкая дрожь от скорости, толчок при ударе об отвал (сигнал driver.bumped).

@export_group("Обзор мышью")
@export var yaw_limit_deg := 110.0
@export var pitch_up_deg := 35.0
@export var pitch_down_deg := 50.0
@export var look_return_delay := 1.5
@export_group("Движение головы")
@export var lean_per_g := 0.05         ## м смещения головы на 1 g
@export var vibration := 0.0012        ## дрожь на максимальной скорости, м

var _yaw := 0.0
var _pitch := 0.0
var _idle := 0.0
var _lean := Vector3.ZERO
var _shake := 0.0
var _prev_speed := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var _car = get_parent()                   # vehicle/car.gd
@onready var _driver = _car.get_node("Driver")     # vehicle/car_driver.gd (у машины driver ещё не готов)


func _ready() -> void:
	_driver.bumped.connect(func(s: float) -> void: _shake = max(_shake, s))


func _unhandled_input(event: InputEvent) -> void:
	if not camera.current or not (event is InputEventMouseMotion):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sens: float = Settings.mouse_sensitivity
	_yaw = clamp(_yaw - event.relative.x * sens, -deg_to_rad(yaw_limit_deg), deg_to_rad(yaw_limit_deg))
	_pitch = clamp(_pitch - event.relative.y * sens, -deg_to_rad(pitch_down_deg), deg_to_rad(pitch_up_deg))
	_idle = 0.0


## Взгляд прямо вперёд (перед катсценой выхода и т. п.)
func reset_look() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_lean = Vector3.ZERO
	camera.transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	if not camera.current:
		return
	var d = _driver
	_idle += delta
	if _idle > look_return_delay:
		var k := 1.0 - exp(-1.5 * delta)
		_yaw = lerpf(_yaw, 0.0, k)
		_pitch = lerpf(_pitch, 0.0, k)
	# перегрузки: боковая (м/с², + — тянет вправо) и продольная
	var a_lat: float = d.get_lateral_accel()
	var a_long: float = (d.speed - _prev_speed) / max(delta, 0.0001)
	_prev_speed = d.speed
	# поворот налево — голову тянет вправо; торможение (a_long < 0) — вперёд (-Z)
	var target := Vector3(a_lat / 9.8 * lean_per_g, 0.0, a_long / 9.8 * lean_per_g)
	target.x = clamp(target.x, -0.07, 0.07)
	target.z = clamp(target.z, -0.06, 0.06)
	_lean = _lean.lerp(target, 1.0 - exp(-4.0 * delta))
	# дрожь от дороги и толчки
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	var amp: float = vibration * clamp(d.speed / d.max_speed, 0.0, 1.0) + 0.03 * _shake
	var jitter := Vector3(randf_range(-amp, amp), randf_range(-amp, amp), 0.0)
	camera.position = _lean + jitter
	camera.rotation = Vector3(_pitch, _yaw, 0.0)
