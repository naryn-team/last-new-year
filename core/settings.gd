extends Node
## Настройки игры (автозагрузка «Settings» — доступна из любого скрипта как Settings.xxx).
## Сохраняются в user://settings.cfg и загружаются при запуске.
## F11 — переключить полный экран.

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity := 0.002    ## радиан на пиксель движения мыши
var master_volume := 0.8          ## 0..1
var fullscreen := true            ## игра запускается на весь экран


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		set_fullscreen(not fullscreen)


func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = v
	save_settings()
	changed.emit()


func set_master_volume(v: float) -> void:
	master_volume = clamp(v, 0.0, 1.0)
	_apply_volume()
	save_settings()
	changed.emit()


func set_fullscreen(v: bool) -> void:
	fullscreen = v
	_apply_fullscreen()
	save_settings()
	changed.emit()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
		master_volume = cfg.get_value("audio", "master_volume", master_volume)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	_apply_volume()
	_apply_fullscreen()
