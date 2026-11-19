extends Node3D
## Машина героя (vehicle/car.tscn).
##   • взаимодействие (протокол get_prompt/interact): «Бак пуст» → заправить канистрой → «сесть в машину»;
##   • состояние DRIVING / STOPPING / PARKED; по дороге её ведёт дочерний узел Driver (car_driver.gd);
##   • езда от первого лица: камера водителя DriverHead (cockpit_camera.gd); C — вид сзади (ChaseCamRig);
##   • салон: руль, щиток приборов (car_dashboard.gd), зеркало заднего вида (car_mirror.gd), часы;
##   • свет: фары, задние/стоп-огни, свет в салоне; дверь водителя; пустые слоты для звуков (Audio/*);
##   • снег вокруг машины (Snowfall) — виден в свете фар, пока едем.
## Все размеры — в сцене (Model, Marker3D DriverSeat / DriverExit); код опирается только на якоря.
## Финальная сцена (убийца на заднем сиденье → levels/ritual/ritual.tscn) — Шаг 2.

enum State { DRIVING, STOPPING, PARKED }

@export var road: NodePath                    ## узел дороги (levels/world/exterior_road.gd)
@export_group("Свет")
@export var headlight_energy := 4.0
@export var tail_energy := 0.25
@export var brake_energy := 1.4
@export_group("Дверь")
@export var door_open_angle := -68.0          ## градусы; минус — дверь открывается наружу (влево)
@export var door_time := 0.7

var state: State = State.PARKED
var engine_running := false
var headlights_on := false
var is_door_open := false
var ignition := false

var _brake := false
var _door_tween: Tween

@onready var driver = $Driver                 ## car_driver.gd
@onready var chase_camera: Camera3D = $Cameras/ChaseCamRig/Camera3D
@onready var cockpit_camera: Camera3D = $DriverHead/Camera3D
@onready var _dashboard = $Model/Interior/Dashboard     ## car_dashboard.gd
@onready var _mirror = $Model/Interior/RearMirror       ## car_mirror.gd
@onready var _snow: GPUParticles3D = $Snowfall
@onready var _rig = $Cameras/ChaseCamRig      ## car_camera.gd
@onready var _door: Node3D = $Model/DoorFL_Pivot
@onready var _headlights: Array[SpotLight3D] = [$Lights/HeadlightL, $Lights/HeadlightR]
@onready var _head_glow: Array[Node3D] = [$Lights/HeadlightGlowL, $Lights/HeadlightGlowR]
@onready var _tail_lights: Array[OmniLight3D] = [$Lights/TailLightL, $Lights/TailLightR]
@onready var _tail_glow: Array[MeshInstance3D] = [$Lights/TailGlowL, $Lights/TailGlowR]
@onready var _interior: OmniLight3D = $Lights/InteriorLight
@onready var _engine: AudioStreamPlayer3D = $Audio/Engine
@onready var _door_sound: AudioStreamPlayer3D = $Audio/Door


func _ready() -> void:
	add_to_group("car")
	_interior.visible = false
	set_headlights(false)
	set_engine_running(false)
	_snow.emitting = false


func _process(_delta: float) -> void:
	# зеркало рисуем, только когда смотрим из кабины
	var in_cockpit := cockpit_camera.current
	if _mirror.active != in_cockpit:
		_mirror.active = in_cockpit


func _unhandled_input(event: InputEvent) -> void:
	# C — вид из кабины / вид сзади (только пока игрок ведёт машину)
	if event.is_action_pressed("car_camera") and state == State.DRIVING and driver.player_control:
		if cockpit_camera.current:
			_rig.snap()
			chase_camera.make_current()
		else:
			cockpit_camera.make_current()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- взаимодействие

func get_prompt(game) -> String:
	if game.has_flag("car_fueled"):
		return "E — сесть в машину"
	if game.has_item("canister"):
		return "E — заправить машину"
	return "Бак пуст"


func interact(game) -> void:
	if game.has_flag("car_fueled"):
		game.show_message("Двигатель заводится... (финальная сцена — следующий шаг)")
		return
	if game.has_item("canister"):
		game.remove_item("canister")
		game.set_flag("car_fueled")
		game.show_message("Бак заправлен. Скорее в машину!")
		return
	game.show_message("Бензин кончился у самого дома. Нужна канистра.")


# ---------------------------------------------------------------- дорога

func get_road() -> Node:
	return get_node_or_null(road)


## Поставить машину в начало дороги: зажигание, мотор, фары; вид из кабины
func start_drive() -> void:
	set_ignition(true)
	set_engine_running(true)
	set_headlights(true)
	driver.place_at_start()
	_rig.snap()
	cockpit_camera.make_current()
	_snow.emitting = true


## Поставить машину на место стоянки (конец дороги): мотор и свет выключены
func park() -> void:
	driver.place_at_end()
	set_engine_running(false)
	set_headlights(false)
	set_brake_lights(false)
	set_ignition(false)
	_snow.emitting = false


func get_seat_transform() -> Transform3D:
	return $DriverSeat.global_transform


## Где стоит игрок, выйдя из машины (ноги на земле, лицом к дому)
func get_exit_transform() -> Transform3D:
	return $DriverExit.global_transform


## Куда смотрит камера сзади: точка на дороге впереди машины
func get_look_target() -> Vector3:
	return $Driver.look_target()   # $Driver, а не driver: камера спрашивает ещё до _ready машины


# ---------------------------------------------------------------- мотор и свет

## Зажигание: подсветка приборов и часов (мотор — отдельно, set_engine_running)
func set_ignition(on: bool) -> void:
	ignition = on
	_dashboard.set_powered(on)


## Снег вокруг машины
func set_snow(on: bool) -> void:
	_snow.emitting = on


func set_engine_running(on: bool) -> void:
	engine_running = on
	if _engine.stream:
		if on and not _engine.playing:
			_engine.play()
		elif not on:
			_engine.stop()
	_update_tail()


func set_headlights(on: bool) -> void:
	headlights_on = on
	for l in _headlights:
		l.visible = on
		l.light_energy = headlight_energy
	for g in _head_glow:
		g.visible = on


func set_brake_lights(on: bool) -> void:
	if on == _brake:
		return
	_brake = on
	_update_tail()


func _update_tail() -> void:
	for l in _tail_lights:
		l.visible = engine_running
		l.light_energy = brake_energy if _brake else tail_energy
	for g in _tail_glow:
		g.visible = engine_running
		var mat := g.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.0 if _brake else 1.0


## Мотор чихает (бензин кончается): фары проседают несколько раз
func sputter(times := 3, period := 0.7) -> void:
	for i in times:
		await get_tree().create_timer(period * randf_range(0.6, 1.2), false).timeout
		if not headlights_on:
			return
		_set_headlight_energy(headlight_energy * 0.25)
		if _engine.stream:
			_engine.pitch_scale = 0.6
		await get_tree().create_timer(0.12, false).timeout
		_set_headlight_energy(headlight_energy)
		if _engine.stream:
			_engine.pitch_scale = 1.0


## Фары мигают и гаснут (мотор заглох)
func flicker_off_headlights(times := 2) -> void:
	for i in times:
		_set_headlight_energy(headlight_energy * 0.15)
		await get_tree().create_timer(0.09, false).timeout
		_set_headlight_energy(headlight_energy * 0.7)
		await get_tree().create_timer(0.16, false).timeout
	set_headlights(false)


func _set_headlight_energy(e: float) -> void:
	for l in _headlights:
		l.light_energy = e


# ---------------------------------------------------------------- дверь (вызывается и из катсцены)

func open_door() -> void:
	is_door_open = true
	_interior.visible = true
	_swing_door(door_open_angle)


func close_door() -> void:
	is_door_open = false
	_swing_door(0.0)
	await _door_tween.finished
	if not is_door_open:
		_interior.visible = false


func _swing_door(angle: float) -> void:
	if _door_sound.stream:
		_door_sound.play()
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(_door, "rotation_degrees:y", angle, door_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
