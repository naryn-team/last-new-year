extends StaticBody3D
## Записка / письмо / детский рисунок. Наведись и нажми E — откроется окно чтения.
##
## kind:
##   "hand"    — написано от руки (письма, дневник)
##   "print"   — напечатано (чек, газета)
##   "drawing" — детский рисунок с цифрой для кода сейфа (drawing_color + drawing_digit)

@export var note_id := ""
@export var title := "Записка"
@export_multiline var text := ""
@export_enum("hand", "print", "drawing") var kind := "hand"
@export_enum("red", "green", "blue", "yellow") var drawing_color := "red"
@export_range(0, 9) var drawing_digit := 0


func _ready() -> void:
	if kind == "drawing":
		add_to_group("note_drawing")


func get_prompt(_game) -> String:
	return "E — посмотреть рисунок" if kind == "drawing" else "E — прочитать: " + title


func interact(game) -> void:
	game.read_note(self)
