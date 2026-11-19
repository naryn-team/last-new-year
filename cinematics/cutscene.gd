extends Node3D
class_name Cutscene
## Катсцена — отдельная сцена с этим скриптом на корне. Внутри:
##   • AnimationPlayer с анимацией "main" (дорожки трансформов камеры/объектов,
##     Call Method на корень — например close_eyes / open_eyes / blink / play_sound);
##   • один или несколько Camera3D (по умолчанию используется узел "Camera3D");
##   • якоря Marker3D.
##
## play():
##   1. отключает управление игроком, HUD и взаимодействие; ставит ИИ маньяка на паузу
##      (всё null-safe: в сцене ритуала нет ни Game, ни игрока);
##   2. включает свою камеру; 3. проигрывает "main";
##   4. удержание cutscene_skip (Space / Esc) — перемотка в конец: значения дорожек
##      применяются на последнем кадре. ВАЖНО: Call Method при перемотке НЕ вызываются —
##      в них только эффекты (звук, вспышка), а итоговое состояние — в дорожках значений
##      или в обработчике сигнала finished;
##   5. в конце (restore_on_finish) плавно возвращает камеру игрока, включает всё обратно
##      и шлёт finished.
## Пока катсцена идёт, узел в группе "cutscene_playing" (меню паузы не открывается).

signal started
signal finished

@export var animation := &"main"
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var camera_path: NodePath = ^"Camera3D"
@export var autoplay := false            ## начать сразу при появлении в дереве
@export var letterbox := true            ## чёрные полосы на время катсцены
@export var blend_in_time := 0.0         ## плавно перейти из прежней камеры в первый кадр (0 — сразу)
@export_group("Пропуск")
@export var skippable := true
@export var skip_hold_time := 0.8        ## сколько держать cutscene_skip
@export_group("Окончание")
@export var restore_on_finish := true    ## вернуть игроку камеру и управление
@export var blend_back_time := 0.6       ## плавный переход к камере игрока (0 — сразу)
@export var return_to_player := false    ## в конце — к камере игрока, а не к камере, что была до катсцены
@export var free_on_finish := false

var is_playing := false
var overlay: CinematicOverlay

var _anim: AnimationPlayer
var _cam: Camera3D
var _prev_cam: Camera3D
var _skip_t := 0.0
var _skipped := false
var _restore := {}   ## что выключили — то и включим обратно
var _blend_tween: Tween
var _shake := 0.0


func _ready() -> void:
	_anim = get_node_or_null(animation_player_path) as AnimationPlayer
	_cam = get_node_or_null(camera_path) as Camera3D
	if _anim:
		_anim.animation_finished.connect(_on_animation_finished)
	if autoplay:
		play.call_deferred()


func play() -> void:
	if is_playing:
		return
	is_playing = true
	_skipped = false
	_skip_t = 0.0
	add_to_group("cutscene_playing")
	_take_control()
	_prev_cam = get_viewport().get_camera_3d()
	if letterbox:
		_ensure_overlay().set_letterbox(true)
	started.emit()
	if _anim == null or not _anim.has_animation(animation):
		push_warning("Cutscene %s: нет анимации «%s»" % [name, animation])
		if _cam:
			_cam.make_current()
		_finish()
		return
	_anim.play(animation)
	if blend_in_time > 0.0 and _cam and is_instance_valid(_prev_cam) and _prev_cam != _cam:
		# первый кадр анимации — цель; камера плавно приходит в него из прежней камеры
		_anim.seek(0.0, true)
		_anim.pause()
		var target := _cam.global_transform
		var fov := _cam.fov
		_cam.global_transform = _prev_cam.global_transform
		_cam.fov = _prev_cam.fov
		_cam.make_current()
		_blend_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_blend_tween.tween_property(_cam, "global_transform", target, blend_in_time)
		_blend_tween.tween_property(_cam, "fov", fov, blend_in_time)
		await _blend_tween.finished
		if is_playing and not _skipped:
			_anim.play()
	elif _cam:
		_cam.make_current()


## Перемотать в конец (то же, что удержание cutscene_skip)
func skip() -> void:
	if not is_playing or _skipped:
		return
	_skipped = true
	if _blend_tween:
		_blend_tween.kill()
	if _anim and _anim.current_animation == animation:
		_anim.seek(_anim.current_animation_length, true)
		_anim.pause()
	_finish()


func _process(delta: float) -> void:
	if _cam and (_shake > 0.0 or _cam.h_offset != 0.0):
		_shake = move_toward(_shake, 0.0, delta * 1.8)
		var a := 0.09 * _shake
		_cam.h_offset = randf_range(-a, a)
		_cam.v_offset = randf_range(-a, a)
	if not is_playing or not skippable or _skipped:
		return
	if Input.is_action_pressed("cutscene_skip"):
		_skip_t += delta
		if _skip_t >= skip_hold_time:
			skip()
	else:
		_skip_t = 0.0


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == animation:
		_finish()


func _finish() -> void:
	if not is_playing:
		return
	is_playing = false
	if letterbox and overlay:
		overlay.set_letterbox(false)
	if restore_on_finish:
		var to: Camera3D = _prev_cam if is_instance_valid(_prev_cam) else null
		var player := get_tree().get_first_node_in_group("player")
		if return_to_player and player and player.has_method("get_camera"):
			to = player.get_camera()
		await blend_camera(_cam, to, 0.0 if _skipped else blend_back_time)
		_give_back_control()
	remove_from_group("cutscene_playing")
	finished.emit()
	if free_on_finish:
		queue_free()


# ---------------------------------------------------------------- для Call Method дорожек

func close_eyes(time := 1.0) -> void:
	await _ensure_overlay().close_eyes(time)


func open_eyes(time := 0.6) -> void:
	await _ensure_overlay().open_eyes(time)


func blink(close_time := 0.12, hold := 0.08, open_time := 0.2) -> void:
	await _ensure_overlay().blink(close_time, hold, open_time)


func fade_to_black(time := 0.6) -> void:
	await _ensure_overlay().fade_to_black(time)


func fade_from_black(time := 0.6) -> void:
	await _ensure_overlay().fade_from_black(time)


## Субтитр внизу экрана
func say(text: String, seconds := 2.5) -> void:
	await _ensure_overlay().say(text, seconds)


## Удар: красная вспышка и тряска камеры катсцены
func hit(strength := 1.0) -> void:
	_shake = max(_shake, strength)
	_ensure_overlay().flash(Color(0.6, 0.0, 0.0), 0.6)


## Звук «как сквозь вату» (SceneFlow.set_muffle); cutoff_hz ≥ 20500 — обычный звук
func muffle(cutoff_hz := 500.0, time := 1.0) -> void:
	SceneFlow.set_muffle(cutoff_hz, time)


# ---------------------------------------------------------------- камеры

## Плавно перевести взгляд с камеры from на камеру to (положение и fov), затем сделать to текущей.
## Двигается сама камера from; камера to может в это время двигаться (например, за машиной).
## Без from или при time = 0 — просто переключение.
static func blend_camera(from: Camera3D, to: Camera3D, time: float) -> void:
	if to == null:
		return
	if from == null or time <= 0.0:
		to.make_current()
		return
	from.make_current()
	var start := from.global_transform
	var start_fov := from.fov
	var step := func(k: float) -> void:
		from.global_transform = start.interpolate_with(to.global_transform, k)
		from.fov = lerpf(start_fov, to.fov, k)
	var tw := from.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(step, 0.0, 1.0, time)
	await tw.finished
	to.make_current()


# ---------------------------------------------------------------- управление игрой

func _ensure_overlay() -> CinematicOverlay:
	if overlay == null:
		overlay = CinematicOverlay.new()
		add_child(overlay)
	return overlay


func _take_control() -> void:
	_restore.clear()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_control_enabled"):
		_restore["player"] = [player, player.is_control_enabled()]
		player.set_control_enabled(false)
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("set_hud_visible"):
		_restore["game"] = [game, game.is_hud_visible(), game.is_interaction_enabled()]
		game.set_hud_visible(false)
		game.set_interaction_enabled(false)
	var maniac := get_tree().get_first_node_in_group("maniac")
	if maniac and maniac.has_method("set_ai_paused"):
		_restore["maniac"] = [maniac, maniac.ai_paused]
		maniac.set_ai_paused(true)


func _give_back_control() -> void:
	if _restore.has("player") and is_instance_valid(_restore["player"][0]):
		_restore["player"][0].set_control_enabled(_restore["player"][1])
	if _restore.has("game") and is_instance_valid(_restore["game"][0]):
		_restore["game"][0].set_hud_visible(_restore["game"][1])
		_restore["game"][0].set_interaction_enabled(_restore["game"][2])
	if _restore.has("maniac") and is_instance_valid(_restore["maniac"][0]):
		_restore["maniac"][0].set_ai_paused(_restore["maniac"][1])
	_restore.clear()
