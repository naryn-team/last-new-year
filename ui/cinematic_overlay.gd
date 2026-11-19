extends CanvasLayer
class_name CinematicOverlay
## Кинематографичный слой поверх игры: чёрные полосы (letterbox), затемнение
## и «веки» — две чёрные шторки сверху и снизу, как щель шкафа в hide_spot.gd.
## Все методы с time можно ждать через await. time = 0 — сразу.
## Обычно им управляет Cutscene (cinematics/cutscene.gd).

const BAR := 0.11   ## высота полосы letterbox (доля экрана)

var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _lid_top: ColorRect
var _lid_bottom: ColorRect
var _black: ColorRect
var _tweens := {}   ## "bars" / "lids" / "fade" -> Tween


func _ready() -> void:
	layer = 15   # выше HUD (5) и шкафа (10), ниже паузы (20) и окон (30)
	_black = _rect(0.0, 1.0)
	_black.color.a = 0.0
	_lid_top = _rect(0.0, 0.0)
	_lid_bottom = _rect(1.0, 1.0)
	_bar_top = _rect(0.0, 0.0)
	_bar_bottom = _rect(1.0, 1.0)


## Чёрные полосы сверху и снизу
func set_letterbox(on: bool, time := 0.5) -> void:
	await _slide("bars", _bar_top, _bar_bottom, BAR if on else 0.0, time)


## Закрыть глаза (веки сходятся к середине экрана)
func close_eyes(time := 1.0) -> void:
	await _slide("lids", _lid_top, _lid_bottom, 0.5, time)


## Открыть глаза
func open_eyes(time := 0.6) -> void:
	await _slide("lids", _lid_top, _lid_bottom, 0.0, time)


## Моргнуть: закрыть, подержать, открыть
func blink(close_time := 0.12, hold := 0.08, open_time := 0.2) -> void:
	await close_eyes(close_time)
	if hold > 0.0:
		await get_tree().create_timer(hold, false).timeout
	await open_eyes(open_time)


func is_eyes_closed() -> bool:
	return _lid_top.anchor_bottom >= 0.499


func fade_to_black(time := 0.6) -> void:
	await _fade(1.0, time)


func fade_from_black(time := 0.6) -> void:
	await _fade(0.0, time)


# ---------------------------------------------------------------- внутреннее

func _rect(top: float, bottom: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = top
	r.anchor_bottom = bottom
	add_child(r)
	return r


## Новый твин вместо прежнего с тем же именем (старый останавливается)
func _new_tween(key: String) -> Tween:
	if _tweens.has(key) and _tweens[key]:
		_tweens[key].kill()
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens[key] = t
	return t


## Верхняя шторка растёт вниз до edge, нижняя — вверх до 1 - edge
func _slide(key: String, top: ColorRect, bottom: ColorRect, edge: float, time: float) -> void:
	if time <= 0.0:
		if _tweens.has(key) and _tweens[key]:
			_tweens[key].kill()
		top.anchor_bottom = edge
		bottom.anchor_top = 1.0 - edge
		return
	var t := _new_tween(key)
	t.tween_property(top, "anchor_bottom", edge, time)
	t.tween_property(bottom, "anchor_top", 1.0 - edge, time)
	await t.finished


func _fade(alpha: float, time: float) -> void:
	if time <= 0.0:
		if _tweens.has("fade") and _tweens["fade"]:
			_tweens["fade"].kill()
		_black.color.a = alpha
		return
	var t := _new_tween("fade")
	t.tween_property(_black, "color:a", alpha, time)
	await t.finished
