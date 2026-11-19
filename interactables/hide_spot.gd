extends CSGBox3D
## Укрытие (шкаф). Наведись и нажми E — спрятаться. Ещё раз E — выйти.
##
## Как это работает:
##   • игрок оказывается ВНУТРИ шкафа и смотрит наружу через щель;
##   • тело не поворачивается, смотреть можно только вверх-вниз (см. player.gd);
##   • маньяк может подойти и открыть шкаф (open_doors) — посмотреть на игрока,
##     а потом либо убить его, либо закрыть шкаф и уйти (см. maniac.gd).
## Нажатие E обрабатывает game.gd — здесь только что происходит.

static var hidden_in: Node = null  ## в каком шкафу сейчас игрок (один на всю игру)

@export var look_yaw_limit := 0.0      ## влево-вправо не поворачиваемся: смотрим в щель (0 — запрещено)
@export var look_pitch_limit := 20.0   ## вверх-вниз

var _overlay: CanvasLayer
var _left: ColorRect
var _right: ColorRect
var _hint: Label
var _flashlight_was_on := false
var _doors_tween: Tween
var doors_open := false


func _ready() -> void:
	add_to_group("hide_spot")


func get_prompt(_game) -> String:
	return "E — спрятаться в шкаф"


func interact(game) -> void:
	var player: CharacterBody3D = game.player
	if hidden_in == self:
		_exit(player)
	elif hidden_in == null:
		_enter(player)


# ---------------------------------------------------------------- геометрия шкафа

## Направление «наружу» — из лицевой стороны шкафа в комнату (вдоль короткой оси коробки).
## from_pos — с какой стороны стоит игрок.
func front_dir(from_pos: Vector3) -> Vector3:
	var axis := _short_axis()
	var to := from_pos - global_position
	return axis if to.dot(axis) >= 0.0 else -axis


func _short_axis() -> Vector3:
	var axis := global_basis.z if size.z < size.x else global_basis.x
	axis.y = 0
	return axis.normalized()


func _depth() -> float:
	return min(size.x, size.z)


func floor_y() -> float:
	return global_position.y - size.y / 2.0


## Точка перед шкафом на полу (куда встаёт маньяк / куда выходит игрок)
func front_point(dist := 0.9) -> Vector3:
	var f := _front()
	var p := global_position + f * (_depth() / 2.0 + dist)
	p.y = floor_y()
	return p


func _front() -> Vector3:
	if has_meta("front"):
		return get_meta("front")
	# лицевая сторона не известна (игрок ещё не прятался) — ищем сторону без стены
	var axis := _short_axis()
	var space := get_world_3d().direct_space_state
	for side in [1.0, -1.0]:
		var a: Vector3 = global_position
		var b: Vector3 = a + axis * side * (_depth() / 2.0 + 0.6)
		var q := PhysicsRayQueryParameters3D.create(a, b)
		if space.intersect_ray(q).is_empty():
			set_meta("front", axis * side)
			return axis * side
	return axis


# ---------------------------------------------------------------- войти / выйти

func _enter(player: CharacterBody3D) -> void:
	# лицевая сторона — та, с которой подошёл игрок
	set_meta("front", front_dir(player.global_position))
	# маньяк видел, как игрок залез? (спрашиваем ДО того, как игрок спрятался)
	for m in get_tree().get_nodes_in_group("maniac"):
		if m.has_method("on_player_hid"):
			m.on_player_hid(self)

	hidden_in = self
	player.set_hidden(self)   # стоп, полный рост, взгляд прямо
	player.set_body_enabled(false)

	# ставим игрока внутрь шкафа, лицом наружу
	var f := _front()
	var inside := global_position + f * (_depth() / 2.0 - 0.18)
	inside.y = floor_y()
	player.teleport_to(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.z)), inside))

	_flashlight_was_on = player.is_flashlight_on()
	player.set_flashlight(false)
	_show_overlay()


func _exit(player: CharacterBody3D) -> void:
	hidden_in = null
	doors_open = false
	# выходим из шкафа: поворот головы переносится на тело (player.set_hidden), встаём перед шкафом
	player.set_hidden(null)
	player.global_position = front_point(0.55)
	player.set_body_enabled(true)
	player.set_flashlight(_flashlight_was_on)
	if _overlay:
		_overlay.queue_free()
		_overlay = null


# ---------------------------------------------------------------- дверцы (для маньяка)

## Маньяк открывает дверцы: щель расширяется
func open_doors() -> void:
	doors_open = true
	_tween_doors(0.12, 0.6)
	if _hint:
		_hint.visible = false


## Маньяк закрывает дверцы и уходит
func close_doors() -> void:
	doors_open = false
	_tween_doors(0.47, 0.5)
	if _hint:
		_hint.visible = true


func _tween_doors(gap_edge: float, time: float) -> void:
	if _left == null:
		return
	if _doors_tween:
		_doors_tween.kill()
	_doors_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	_doors_tween.tween_property(_left, "anchor_right", gap_edge, time)
	_doors_tween.tween_property(_right, "anchor_left", 1.0 - gap_edge, time)


## Вид «через щель в дверцах шкафа»
func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_left = _panel(0.0, 0.47)
	_right = _panel(0.53, 1.0)
	_hint = Label.new()
	_hint.text = "Ты прячешься.  E — выйти"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.9
	_hint.anchor_bottom = 0.95
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_overlay.add_child(_hint)


func _panel(a: float, b: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.015, 0.012, 0.01, 0.98)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = a
	r.anchor_right = b
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0
	_overlay.add_child(r)
	return r
