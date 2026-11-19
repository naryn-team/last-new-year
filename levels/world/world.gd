extends Node3D
## Корень игрового мира: решает, с чего начинается игра, и ведёт приезд к дому.
##   Новая игра (SceneFlow.session пуст): игрок за рулём (вид из кабины) в начале дороги →
##     вступительный кадр → игрок ведёт машину → бензин кончился → машина докатывается
##     до стоянки → катсцена выхода от первого лица → обычная игра; session.arrived = true.
##   «Заново» после смерти (session.arrived): машина уже стоит, игрок рядом с дверью.
##   start_mode = ON_FOOT — игрок в точке появления из world.tscn (для проверок).
##   Финал: заправленная машина, «E — сесть в машину» → катсцена поимки (CaptureCutscene машины)
##     → темнота → сцена ритуала (ritual_scene).

enum StartMode { AUTO, DRIVE, ARRIVED, ON_FOOT }

@export var start_mode := StartMode.AUTO
@export_multiline var fuel_message := "Мотор закашлял… Стрелка бензина легла на ноль."
@export_file("*.tscn") var ritual_scene := "res://levels/ritual/ritual.tscn"
@export var black_hold := 1.5   ## сколько секунд темноты между поимкой и ритуалом

var _player
var _game
var _car
var _in_car := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_game = get_tree().get_first_node_in_group("game")
	_car = get_tree().get_first_node_in_group("car")
	var mode := start_mode
	if mode == StartMode.AUTO:
		mode = StartMode.ARRIVED if SceneFlow.session.get("arrived", false) else StartMode.DRIVE
	if _car == null or _player == null:
		return   # нет машины — игрок остаётся в точке появления
	_car.ending_requested.connect(_ending)
	match mode:
		StartMode.DRIVE:
			_drive()
		StartMode.ARRIVED:
			_car.park()
			_player.teleport_to(_car.get_exit_transform())
		StartMode.ON_FOOT:
			_car.park()


func _process(_delta: float) -> void:
	# пока игрок «в машине», его тело (без коллизии) едет на месте водителя
	if _in_car:
		var seat: Transform3D = _car.get_seat_transform()
		seat.origin.y -= _player.stand_eye
		_player.teleport_to(Transform3D(Basis(Vector3.UP, seat.basis.get_euler().y), seat.origin))


# ---------------------------------------------------------------- приезд

func _drive() -> void:
	_set_in_car(true)
	_car.start_drive()
	_car.driver.autopilot = true
	_car.driver.fuel_out.connect(_on_fuel_out, CONNECT_ONE_SHOT)

	# 1. вступительный кадр (машина едет сама), затем руль переходит к игроку
	var intro = _car.get_node_or_null("IntroCutscene")
	if intro:
		intro.play()
		await intro.finished
	_car.driver.autopilot = false
	if _car.state == _car.State.DRIVING:
		_car.driver.player_control = true

	# 2–3. бензин кончается (_on_fuel_out), машина накатом встаёт на место стоянки
	await _car.driver.stopped
	await get_tree().create_timer(0.6, false).timeout

	# 4. мотор заглох (на щитке загорелись лампы, стрелки упали), фары мигнули и погасли;
	#    водитель выключает зажигание — щиток гаснет; тишина и ветер
	_car.set_engine_running(false)
	await get_tree().create_timer(0.7, false).timeout
	await _car.flicker_off_headlights()
	await get_tree().create_timer(0.8, false).timeout
	_car.set_ignition(false)
	await get_tree().create_timer(0.4, false).timeout

	# 5. выход из машины от первого лица
	_set_in_car(false)
	_player.teleport_to(_car.get_exit_transform())   # камера катсцены в конце придёт к глазам игрока
	var exit_cs = _car.get_node_or_null("ExitCutscene")
	if exit_cs:
		exit_cs.play()
		await exit_cs.finished
	_on_foot()
	_car.set_snow(false)
	SceneFlow.session["arrived"] = true


# ---------------------------------------------------------------- финал

func _ending() -> void:
	var maniac := get_tree().get_first_node_in_group("maniac")
	if maniac and maniac.has_method("vanish"):
		maniac.vanish()
	_player.set_control_enabled(false)
	_player.set_flashlight(false)
	var capture = _car.get_node_or_null("CaptureCutscene")
	if capture:
		capture.play()
		await capture.finished
	_player.set_body_enabled(false)
	SceneFlow.session["ending"] = true
	await SceneFlow.fade_out(0.0)
	await get_tree().create_timer(black_hold).timeout
	SceneFlow.change_scene(ritual_scene, 0.0, 0.0)


func _on_fuel_out() -> void:
	if _game:
		_game.show_message(fuel_message, 4.0)
	_car.sputter()


## Игрок сидит в машине: тело выключено, управление у машины, HUD без цели и прицела
func _set_in_car(v: bool) -> void:
	_in_car = v
	if v:
		_player.set_control_enabled(false)
		_player.set_body_enabled(false)
		_player.set_flashlight(false)
		if _game:
			_game.set_interaction_enabled(false)
			_game.set_objective_visible(false)


## Игрок вышел: обычная игра, первая цель «Дойти до дома»
func _on_foot() -> void:
	_player.set_body_enabled(true)
	_player.set_control_enabled(true)
	if _game:
		_game.set_interaction_enabled(true)
		_game.set_objective_visible(true)
