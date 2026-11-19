extends Node
## Смена сцен с затемнением (автозагрузка «SceneFlow»).
##   SceneFlow.change_scene("res://…tscn")      — затемнить, сменить сцену, проявить
##   await SceneFlow.fade_out() / fade_in()      — просто затемнение / проявление
##   SceneFlow.session                           — словарь, переживает смену сцен
##                                                 (arrived — игрок уже приехал к дому, ending — финал)
##   SceneFlow.set_muffle(500.0, 2.0)            — звук «как сквозь вату» (фильтр на шине Master);
##                                                 переживает смену сцен; set_muffle(OFF) — снять

const DEFAULT_FADE := 0.6
const MUFFLE_OFF := 20500.0

var session := {}

var _layer: CanvasLayer
var _black: ColorRect
var _tween: Tween
var _busy := false
var _lowpass: AudioEffectLowPassFilter
var _muffle_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # работает и на паузе
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)


## Идёт ли сейчас смена сцены
func is_busy() -> bool:
	return _busy


## Затемнить → сменить сцену → проявить. Повторный вызов во время смены игнорируется.
func change_scene(path: String, out_time := DEFAULT_FADE, in_time := DEFAULT_FADE) -> void:
	if _busy:
		return
	_busy = true
	await fade_out(out_time)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneFlow: не удалось открыть сцену %s (%d)" % [path, err])
	else:
		await get_tree().scene_changed
	_busy = false
	await fade_in(in_time)


## Приглушить звук: срез частот cutoff_hz (Гц) за time секунд. MUFFLE_OFF — звук обычный, фильтр снимается.
func set_muffle(cutoff_hz: float, time := 1.0) -> void:
	if _lowpass == null:
		if cutoff_hz >= MUFFLE_OFF:
			return
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = MUFFLE_OFF
		AudioServer.add_bus_effect(0, _lowpass)
	if _muffle_tween:
		_muffle_tween.kill()
	_muffle_tween = create_tween()
	_muffle_tween.tween_property(_lowpass, "cutoff_hz", cutoff_hz, max(time, 0.01))
	if cutoff_hz >= MUFFLE_OFF:
		_muffle_tween.tween_callback(_remove_muffle)


func _remove_muffle() -> void:
	if _lowpass == null:
		return
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _lowpass:
			AudioServer.remove_bus_effect(0, i)
			break
	_lowpass = null


## Экран плавно чернеет (time = 0 — сразу)
func fade_out(time := DEFAULT_FADE) -> void:
	_black.mouse_filter = Control.MOUSE_FILTER_STOP   # пока темно — клики не проходят
	await _fade_to(1.0, time)


## Экран плавно проявляется из чёрного (time = 0 — сразу)
func fade_in(time := DEFAULT_FADE) -> void:
	await _fade_to(0.0, time)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fade_to(alpha: float, time: float) -> void:
	if _tween:
		_tween.kill()
	if time <= 0.0:
		_black.color.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(_black, "color:a", alpha, time)
	await _tween.finished
