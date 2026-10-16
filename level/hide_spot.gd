extends CSGBox3D
## Укрытие (шкаф). Наведись и нажми E — спрятаться. Ещё раз E — выйти.
## Пока игрок в шкафу, маньяк его не видит и не слышит,
## если только не видел, как тот залезал (см. maniac.gd).
## Нажатие E обрабатывает game.gd — здесь только что происходит.

static var hidden_in: Node = null  ## в каком шкафу сейчас игрок (один на всю игру)

var _overlay: CanvasLayer
var _flashlight_was_on := false


func get_prompt(_game) -> String:
	return "E — спрятаться в шкаф"


func interact(game) -> void:
	var player: CharacterBody3D = game.player
	if hidden_in == self:
		_exit(player)
	elif hidden_in == null:
		_enter(player)


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
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_left = side[0]
		r.anchor_right = side[1]
		r.anchor_top = 0.0
		r.anchor_bottom = 1.0
		_overlay.add_child(r)
	var l := Label.new()
	l.text = "Ты прячешься.  E — выйти"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.9
	l.anchor_bottom = 0.95
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_overlay.add_child(l)
