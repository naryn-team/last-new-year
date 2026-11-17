extends CanvasLayer
## Окно чтения записки. Пока открыто — игра на паузе. E / Esc / клик — закрыть.

signal closed

var _root: Control
var _paper: PanelContainer
var _title: Label
var _body: Label
var _drawing: Control
var _draw_color := Color.RED
var _draw_digit := 0
var _open_frame := 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func show_note(title: String, text: String, kind: String, color_id := "red", digit := 0) -> void:
	_title.text = title
	_body.text = text
	var hand := kind != "print"
	_body.add_theme_font_override("font", UIStyle.hand_font() if hand else ThemeDB.fallback_font)
	_body.add_theme_font_size_override("font_size", 30 if hand else 20)
	_drawing.visible = kind == "drawing"
	_draw_color = UIStyle.CRAYON.get(color_id, Color.RED)
	_draw_digit = digit
	_drawing.queue_redraw()
	_root.visible = true
	_open_frame = Engine.get_process_frames()
	get_tree().paused = true
	_paper.pivot_offset = _paper.size / 2.0
	_paper.scale = Vector2(0.92, 0.92)
	_paper.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_paper, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_paper, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	# не закрывать тем же нажатием E, которым открыли
	if Engine.get_process_frames() == _open_frame:
		return
	var close_it := false
	if event is InputEventKey and event.pressed and not event.echo:
		close_it = event.keycode in [KEY_E, KEY_ESCAPE, KEY_SPACE, KEY_ENTER]
	elif event is InputEventMouseButton and event.pressed:
		close_it = true
	if close_it:
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(620, 0)
	var sb := UIStyle.box(UIStyle.PAPER, 2, UIStyle.UMBER, 1)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 34
	sb.content_margin_bottom = 30
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	_paper.add_theme_stylebox_override("panel", sb)
	center.add_child(_paper)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_paper.add_child(box)

	_title = Label.new()
	_title.add_theme_font_override("font", UIStyle.title_font())
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", UIStyle.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_drawing = Control.new()
	_drawing.custom_minimum_size = Vector2(530, 330)
	_drawing.draw.connect(_draw_drawing)
	box.add_child(_drawing)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(530, 0)
	_body.add_theme_color_override("font_color", UIStyle.INK)
	_body.add_theme_constant_override("line_spacing", 2)
	box.add_child(_body)

	var hint := Label.new()
	hint.text = "E — закрыть"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(UIStyle.INK, 0.55))
	box.add_child(hint)


## Детский рисунок мелком: домик, солнце, человечки — и большая цифра
func _draw_drawing() -> void:
	var c := _draw_color
	var d := _drawing
	var w := d.size.x
	var h := d.size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = _draw_digit * 77 + int(c.r * 255.0)
	var wob := func(p: Vector2) -> Vector2:
		return p + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
	var line := func(a: Vector2, b: Vector2, col: Color, width := 4.0) -> void:
		# «дрожащая» линия, как от детской руки
		var prev: Vector2 = wob.call(a)
		for i in range(1, 7):
			var p: Vector2 = wob.call(a.lerp(b, i / 6.0))
			d.draw_line(prev, p, col, width, true)
			prev = p
	var ink := Color(UIStyle.INK, 0.8)
	# земля (снег)
	line.call(Vector2(10, h - 30), Vector2(w - 10, h - 34), ink, 3.0)
	# домик
	var hx := 40.0
	var hy := h - 32.0
	line.call(Vector2(hx, hy), Vector2(hx, hy - 110), ink)
	line.call(Vector2(hx, hy - 110), Vector2(hx + 150, hy - 110), ink)
	line.call(Vector2(hx + 150, hy - 110), Vector2(hx + 150, hy), ink)
	line.call(Vector2(hx - 14, hy - 106), Vector2(hx + 75, hy - 180), ink)
	line.call(Vector2(hx + 75, hy - 180), Vector2(hx + 164, hy - 106), ink)
	d.draw_rect(Rect2(hx + 22, hy - 82, 34, 34), Color(UIStyle.CRAYON["yellow"], 0.8), true)
	d.draw_rect(Rect2(hx + 95, hy - 60, 30, 60), Color(UIStyle.INK, 0.35), true)
	# солнце / луна
	d.draw_arc(Vector2(w - 70, 60), 30, 0, TAU, 24, Color(UIStyle.CRAYON["yellow"], 0.9), 5.0, true)
	# человечки
	for i in 3:
		var px := 230.0 + i * 48.0
		var ph := 70.0 - i * 14.0
		d.draw_arc(Vector2(px, hy - ph - 12), 11, 0, TAU, 14, ink, 3.0, true)
		line.call(Vector2(px, hy - ph), Vector2(px, hy - 22), ink, 3.0)
		line.call(Vector2(px - 14, hy - ph * 0.6), Vector2(px + 14, hy - ph * 0.6), ink, 3.0)
		line.call(Vector2(px, hy - 22), Vector2(px - 10, hy), ink, 3.0)
		line.call(Vector2(px, hy - 22), Vector2(px + 10, hy), ink, 3.0)
	# большая цифра цветным мелком
	var f := UIStyle.hand_font()
	var fs := 230
	var s := str(_draw_digit)
	var pos := Vector2(w - 190, h - 60)
	for o in [Vector2(-2, 0), Vector2(2, 1), Vector2(0, -2), Vector2(0, 0)]:
		d.draw_string(f, pos + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
