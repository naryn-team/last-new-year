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
var _flash: ColorRect
var _subtitle: Label
var _tweens := {}   ## "bars" / "lids" / "fade" -> Tween


func _ready() -> void:
	layer = 15   # выше HUD (5) и шкафа (10), ниже паузы (20) и окон (30)
	_black = _rect(0.0, 1.0)
	_black.color.a = 0.0
	_lid_top = _rect(0.0, 0.0)
	_lid_bottom = _rect(1.0, 1.0)
	_bar_top = _rect(0.0, 0.0)
	_bar_bottom = _rect(1.0, 1.0)
	_flash = _rect(0.0, 1.0)
	_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	_subtitle = Label.new()
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 0.8
	_subtitle.anchor_bottom = 0.86
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", UIStyle.hand_font())
	_subtitle.add_theme_font_size_override("font_size", 36)
	_subtitle.add_theme_color_override("font_color", UIStyle.BONE)
	_subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_subtitle.add_theme_constant_override("shadow_offset_x", 2)
	_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)


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


## Субтитр внизу экрана на seconds секунд (плавно появляется и гаснет)
func say(text: String, seconds := 2.5) -> void:
	_subtitle.text = text
	var t := _new_tween("subtitle")
	t.set_parallel(false)
	t.tween_property(_subtitle, "modulate:a", 1.0, 0.3)
	t.tween_interval(max(seconds - 0.6, 0.1))
	t.tween_property(_subtitle, "modulate:a", 0.0, 0.3)
	await t.finished


## Вспышка цветом поверх всего (удар, кровь)
func flash(color := Color(0.6, 0.0, 0.0), time := 0.5) -> void:
	_flash.color = Color(color, 0.55)
	var t := _new_tween("flash")
	t.tween_property(_flash, "color:a", 0.0, time)
	await t.finished


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
