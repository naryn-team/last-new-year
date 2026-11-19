extends CanvasLayer
## HUD игры: прицел, подсказка «E — …», сообщения, инвентарь, текущая цель, полоска выносливости.
## Только отображение — что показывать, решает Game (gameplay/game.gd).

var _prompt: Label
var _message: Label
var _inventory: Label
var _objective: Label
var _crosshair: ColorRect
var _stamina_bg: ColorRect
var _stamina_bar: ColorRect
var _message_time := 0.0


func _ready() -> void:
	layer = 5
	_build()


func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	_message_time = seconds


func set_inventory(text: String) -> void:
	_inventory.text = text


func set_objective(text: String) -> void:
	_objective.text = text


func set_crosshair_visible(v: bool) -> void:
	_crosshair.visible = v


## k — доля выносливости 0..1; полоска видна, только пока она не полная
func set_stamina(k: float, exhausted: bool) -> void:
	_stamina_bg.visible = k < 0.999
	_stamina_bar.size.x = 240.0 * k
	_stamina_bar.color = Color(0.75, 0.2, 0.15) if exhausted else Color(0.8, 0.78, 0.7)


func hide_stamina() -> void:
	_stamina_bg.visible = false


func _build() -> void:
	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.7)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE   # не перехватывать мышь (иначе камера не крутится)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -2
	_crosshair.offset_right = 2
	_crosshair.offset_top = -2
	_crosshair.offset_bottom = 2
	add_child(_crosshair)

	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0, 0, 0, 0.45)
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.anchor_left = 0.5
	_stamina_bg.anchor_right = 0.5
	_stamina_bg.anchor_top = 1.0
	_stamina_bg.anchor_bottom = 1.0
	_stamina_bg.offset_left = -122
	_stamina_bg.offset_right = 122
	_stamina_bg.offset_top = -34
	_stamina_bg.offset_bottom = -26
	add_child(_stamina_bg)
	_stamina_bar = ColorRect.new()
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.position = Vector2(2, 2)
	_stamina_bar.size = Vector2(240, 4)
	_stamina_bg.add_child(_stamina_bar)
	_stamina_bg.visible = false

	_prompt = _label(18, Color(1, 1, 1))
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 24
	_prompt.offset_bottom = 50

	_message = _label(22, Color(0.95, 0.85, 0.7))
	_message.anchor_top = 0.18
	_message.anchor_bottom = 0.18
	_message.offset_bottom = 40

	_inventory = _label(16, Color(0.8, 0.8, 0.8))
	_inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_inventory.anchor_top = 1.0
	_inventory.anchor_bottom = 1.0
	_inventory.offset_left = 20
	_inventory.offset_top = -40
	_inventory.offset_bottom = -14

	_objective = _label(16, Color(0.75, 0.75, 0.75))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective.offset_left = 20
	_objective.offset_top = 14
	_objective.offset_bottom = 40


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l
