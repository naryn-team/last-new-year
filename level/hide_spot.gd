extends CSGBox3D
## Укрытие (шкаф). Подойди вплотную и нажми E — спрятаться. Ещё раз E — выйти.
## Пока игрок в шкафу, маньяк его не видит и не слышит,
## если только не видел, как тот залезал (см. maniac.gd).

@export var use_distance := 0.9   ## насколько близко надо стоять к шкафу

static var hidden_in: Node = null  ## в каком шкафу сейчас игрок (один на всю игру)

var _overlay: CanvasLayer
var _flashlight_was_on := false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		return
	var player := _player()
	if player == null:
		return
	if hidden_in == self:
		_exit(player)
		get_viewport().set_input_as_handled()
	elif hidden_in == null and _distance_to(player) < use_distance:
		_enter(player)
		get_viewport().set_input_as_handled()


func _player() -> CharacterBody3D:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null and get_tree().current_scene:
		p = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	return p


## Расстояние от игрока до поверхности шкафа (по горизонтали)
func _distance_to(player: Node3D) -> float:
	var local := to_local(player.global_position)
	var half := size * 0.5
	var closest := Vector3(clamp(local.x, -half.x, half.x), 0, clamp(local.z, -half.z, half.z))
	return Vector2(local.x - closest.x, local.z - closest.z).length()


func _enter(player: CharacterBody3D) -> void:
	hidden_in = self
	player.set_meta("hidden", true)
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	var f := player.get_node_or_null("Head/Camera3D/Flashlight") as Light3D
	if f:
		_flashlight_was_on = f.visible
		f.visible = false
	_show_overlay()


func _exit(player: CharacterBody3D) -> void:
	hidden_in = null
	player.set_meta("hidden", false)
	player.set_physics_process(true)
	var f := player.get_node_or_null("Head/Camera3D/Flashlight") as Light3D
	if f:
		f.visible = _flashlight_was_on
	if _overlay:
		_overlay.queue_free()
		_overlay = null


## Вид «через щель в дверцах шкафа»
func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	for side in [[0.0, 0.47], [0.53, 1.0]]:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 0.97)
		r.anchor_left = side[0]
		r.anchor_right = side[1]
		r.anchor_top = 0.0
		r.anchor_bottom = 1.0
		_overlay.add_child(r)
	var l := Label.new()
	l.text = "Ты прячешься.  E — выйти"
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.9
	l.anchor_bottom = 0.95
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_overlay.add_child(l)
