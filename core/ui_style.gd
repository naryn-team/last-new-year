extends RefCounted
class_name UIStyle
## Общие цвета и шрифты интерфейса.

const NIGHT := Color("151d27")
const RED := Color("d0021b")
const UMBER := Color("4f4330")
const BONE := Color("c0b8ad")
const PAPER := Color("d9cfbb")
const INK := Color("2a2118")

const CRAYON := {
	"red": Color("c8372d"),
	"green": Color("3f8f4a"),
	"blue": Color("2f62b5"),
	"yellow": Color("d9a514"),
}
const CRAYON_NAME := {"red": "красный", "green": "зелёный", "blue": "синий", "yellow": "жёлтый"}


static func title_font() -> Font:
	return _load("res://ui/fonts/amatic_sc_bold.ttf")


static func hand_font() -> Font:
	return _load("res://ui/fonts/caveat.ttf")


static func _load(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font


## Плоская кнопка меню: без рамки, текст краснеет при наведении
static func menu_button(text: String, size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", RED)
	b.add_theme_color_override("font_pressed_color", RED.darkened(0.3))
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	return b


static func box(color: Color, radius := 4, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	return sb
