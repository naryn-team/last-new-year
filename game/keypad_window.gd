extends CanvasLayer
## Кодовый замок сейфа: 4 цифры. Мышью или клавиатурой (цифры, Backspace, Enter).
## Над ячейками — цветные метки: в каком порядке идут цифры с детских рисунков.

signal solved
signal closed

var code := ""
var color_order: Array = []

var _root: Control
var _panel: PanelContainer
var _slots: Array[Label] = []
var _dots: Array[ColorRect] = []
var _status: Label
var _hints: Label
var _entered := ""
var _open_frame := 0
var _busy := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


## found — словарь {цвет: цифра} уже найденных рисунков
func open(p_code: String, p_colors: Array, found: Dictionary) -> void:
	code = p_code
	color_order = p_colors
	_entered = ""
	_busy = false
	_status.text = "Введите код"
	_status.add_theme_color_override("font_color", UIStyle.BONE)
	for i in _dots.size():
		_dots[i].color = UIStyle.CRAYON.get(color_order[i], UIStyle.BONE) if i < color_order.size() else UIStyle.BONE
	var parts: Array[String] = []
	for c in color_order:
		if found.has(c):
			parts.append("%s — %d" % [UIStyle.CRAYON_NAME.get(c, c), found[c]])
	_hints.text = "Найденные рисунки: " + (", ".join(parts) if not parts.is_empty() else "пока нет") \
		+ "\n(%d из %d)" % [parts.size(), color_order.size()]
	_refresh()
	_root.visible = true
	_open_frame = Engine.get_process_frames()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _root.visible or Engine.get_process_frames() == _open_frame:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ESCAPE or k == KEY_E:
			close()
		elif k >= KEY_0 and k <= KEY_9:
			_press(str(k - KEY_0))
		elif k >= KEY_KP_0 and k <= KEY_KP_9:
			_press(str(k - KEY_KP_0))
		elif k == KEY_BACKSPACE or k == KEY_DELETE:
			_press("C")
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			_press("OK")
		get_viewport().set_input_as_handled()


func _press(key: String) -> void:
	if _busy:
		return
	if key == "C":
		_entered = _entered.substr(0, max(0, _entered.length() - 1))
	elif key == "OK":
		_check()
		return
	elif _entered.length() < code.length():
		_entered += key
	_refresh()
	if _entered.length() == code.length():
		_check()


func _check() -> void:
	if _entered.length() < code.length():
		return
	_busy = true
	if _entered == code:
		_status.text = "Открыто"
		_status.add_theme_color_override("font_color", UIStyle.CRAYON["green"])
		await get_tree().create_timer(0.6, true).timeout
		close()
		solved.emit()
	else:
		_status.text = "Неверный код"
		_status.add_theme_color_override("font_color", UIStyle.RED)
		var x := _panel.position.x
		var tw := create_tween()
		for dx in [-12, 12, -8, 8, 0]:
			tw.tween_property(_panel, "position:x", x + dx, 0.05)
		await get_tree().create_timer(0.7, true).timeout
		_entered = ""
		_status.text = "Введите код"
		_status.add_theme_color_override("font_color", UIStyle.BONE)
		_refresh()
		_busy = false


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].text = _entered[i] if i < _entered.length() else "–"


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	var sb := UIStyle.box(Color("1b1f24"), 6, Color("3a3f46"), 2)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "СЕЙФ ОТЦА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyle.title_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UIStyle.BONE)
	box.add_child(title)

	# цветные метки + ячейки
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 12)
	box.add_child(slots)
	for i in 4:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		slots.add_child(col)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(64, 8)
		col.add_child(dot)
		_dots.append(dot)
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(64, 76)
		cell.add_theme_stylebox_override("panel", UIStyle.box(Color("0c0e10"), 3, Color("2c3036"), 1))
		col.add_child(cell)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 44)
		l.add_theme_color_override("font_color", Color("e6dfd2"))
		cell.add_child(l)
		_slots.append(l)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	box.add_child(_status)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	box.add_child(gc)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var b := Button.new()
		b.text = "⌫" if key == "C" else key
		b.custom_minimum_size = Vector2(88, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_stylebox_override("normal", UIStyle.box(Color("2a2f36"), 4))
		b.add_theme_stylebox_override("hover", UIStyle.box(Color("3a4048"), 4))
		b.add_theme_stylebox_override("pressed", UIStyle.box(Color("15181c"), 4))
		b.pressed.connect(_press.bind(key))
		grid.add_child(b)

	_hints = Label.new()
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints.add_theme_font_size_override("font_size", 15)
	_hints.add_theme_color_override("font_color", Color(UIStyle.BONE, 0.75))
	box.add_child(_hints)

	var hint := Label.new()
	hint.text = "Esc — закрыть"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(UIStyle.BONE, 0.45))
	box.add_child(hint)
