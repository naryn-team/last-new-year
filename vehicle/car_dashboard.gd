extends Node3D
## Щиток приборов машины (узел Model/Interior/Dashboard).
## Приборы рисуются кодом во внутренний SubViewport, его картинка ложится на квадрат Cluster:
##   тахометр, спидометр (км/ч) с одометром и передачей, указатель топлива и температуры,
##   контрольные лампы (бензин, аккумулятор, масло, ручник, фары).
## Часы на магнитоле — Label3D Clock (новогодняя ночь: время идёт от start_time).
## Данные берёт у машины: car.driver (speed, rpm, gear, fuel, braking), car.engine_running,
## car.headlights_on. Питание — set_powered() (зажигание).

@export var start_time := "23:31"          ## время на часах в начале поездки
@export var odometer_km := 187412.0
@export var backlight := Color(1.0, 0.78, 0.45)   ## цвет подсветки шкал
@export var needle_color := Color(1.0, 0.32, 0.1)

const SIZE := Vector2i(768, 320)

var powered := false

var _vp: SubViewport
var _canvas: Control
var _mat: StandardMaterial3D
var _speed := 0.0      # показания (сглаженные стрелки)
var _rpm := 0.0
var _fuel := 0.0
var _temp := 0.0
var _minutes := 0.0
var _font: Font

@onready var _car = get_node("../../..")              # vehicle/car.gd
@onready var _driver = _car.get_node("Driver")        # vehicle/car_driver.gd
@onready var _cluster: MeshInstance3D = $Cluster
@onready var _clock: Label3D = get_node_or_null("../Radio/Clock")
@onready var _glow: OmniLight3D = get_node_or_null("../DashGlow")


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_canvas = Control.new()
	_canvas.size = Vector2(SIZE)
	_canvas.draw.connect(_draw_cluster)
	_vp.add_child(_canvas)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_texture = _vp.get_texture()
	_cluster.material_override = _mat
	var p := start_time.split(":")
	_minutes = int(p[0]) * 60.0 + int(p[1]) if p.size() == 2 else 0.0
	set_powered(false)


## Зажигание: подсветка приборов, часов и слабый свет от щитка
func set_powered(on: bool) -> void:
	powered = on
	_mat.albedo_color = Color(1, 1, 1) if on else Color(0.12, 0.12, 0.12)
	if _glow:
		_glow.visible = on
	if _clock:
		_clock.visible = on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_ONCE
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if not powered:
		return
	var d = _driver
	var k := 1.0 - exp(-8.0 * delta)
	_speed = lerpf(_speed, d.get_speed_kmh(), k)
	_rpm = lerpf(_rpm, d.rpm if _car.engine_running else 0.0, k)
	_fuel = lerpf(_fuel, d.fuel, 1.0 - exp(-1.5 * delta))
	_temp = lerpf(_temp, 0.5 if _car.engine_running else 0.45, 1.0 - exp(-0.5 * delta))
	_minutes += delta / 60.0
	if _clock:
		var m := int(_minutes) % (24 * 60)
		_clock.text = "%02d:%02d" % [floori(m / 60.0), m % 60]
	_canvas.queue_redraw()


# ---------------------------------------------------------------- рисование

func _draw_cluster() -> void:
	var c := _canvas
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Color(0.025, 0.025, 0.03))
	if not powered:
		return
	var d = _driver
	# тахометр (×1000 об/мин)
	_gauge(Vector2(150, 168), 112, 0.0, 7.0, 1.0, 0.5, _rpm / 1000.0, 6.0, "×1000")
	# спидометр
	_gauge(Vector2(384, 160), 138, 0.0, 180.0, 20.0, 10.0, _speed, -1.0, "км/ч")
	# одометр и передача
	var odo := "%07d" % int(odometer_km + d.distance / 1000.0)
	c.draw_rect(Rect2(326, 228, 116, 26), Color(0.07, 0.06, 0.05))
	c.draw_string(_font, Vector2(334, 248), odo, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, backlight)
	var gear_txt := "D%d" % d.gear if _car.engine_running and d.speed > 0.3 else "N"
	c.draw_string(_font, Vector2(370, 216), gear_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.9, 1.0))
	# топливо и температура
	_small_gauge(Vector2(640, 118), 62, _fuel, "E", "F", 0.12)
	_small_gauge(Vector2(640, 250), 62, _temp, "C", "H", -1.0)
	# контрольные лампы
	var y := 296.0
	_lamp(Vector2(226, y), "ТОПЛИВО", Color(1.0, 0.6, 0.0), _fuel < 0.15)
	_lamp(Vector2(330, y), "АКБ", Color(1.0, 0.15, 0.1), not _car.engine_running)
	_lamp(Vector2(400, y), "МАСЛО", Color(1.0, 0.15, 0.1), not _car.engine_running)
	_lamp(Vector2(486, y), "(P)", Color(1.0, 0.15, 0.1), Input.is_action_pressed("car_handbrake") and d.player_control)
	_lamp(Vector2(540, y), "ФАРЫ", Color(0.3, 1.0, 0.45), _car.headlights_on)


## Круглый прибор: шкала 270°, деления, цифры, стрелка
func _gauge(center: Vector2, r: float, vmin: float, vmax: float, major: float, minor: float,
		value: float, red_from: float, unit: String) -> void:
	var c := _canvas
	var a0 := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	c.draw_arc(center, r, a0, a0 + sweep, 64, Color(backlight, 0.35), 2.0, true)
	if red_from > 0.0:
		var ar := a0 + sweep * (red_from - vmin) / (vmax - vmin)
		c.draw_arc(center, r - 4.0, ar, a0 + sweep, 24, Color(0.9, 0.12, 0.08), 7.0, true)
	var v := vmin
	while v <= vmax + 0.001:
		var a := a0 + sweep * (v - vmin) / (vmax - vmin)
		var dir := Vector2(cos(a), sin(a))
		var is_major := is_equal_approx(fmod(v - vmin, major), 0.0) or is_equal_approx(fmod(v - vmin, major), major)
		var inner := r - (16.0 if is_major else 8.0)
		c.draw_line(center + dir * inner, center + dir * r, backlight, 3.0 if is_major else 1.5, true)
		if is_major:
			var txt := str(int(round(v)))
			var fs := 22 if r > 120.0 else 20
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			c.draw_string(_font, center + dir * (r - 34.0) + Vector2(-tw / 2.0, 7.0), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, backlight)
		v += minor
	var uw := _font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	c.draw_string(_font, center + Vector2(-uw / 2.0, r * 0.42), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(backlight, 0.7))
	_needle(center, r - 10.0, a0 + sweep * clamp((value - vmin) / (vmax - vmin), 0.0, 1.0))


## Маленький прибор (дуга 90° сверху): топливо, температура
func _small_gauge(center: Vector2, r: float, value: float, lo: String, hi: String, warn_below: float) -> void:
	var c := _canvas
	var a0 := deg_to_rad(225.0)
	var sweep := deg_to_rad(90.0)
	c.draw_arc(center, r, a0, a0 + sweep, 24, Color(backlight, 0.4), 2.0, true)
	if warn_below > 0.0:
		c.draw_arc(center, r - 4.0, a0, a0 + sweep * warn_below, 8, Color(0.9, 0.12, 0.08), 6.0, true)
	for i in 5:
		var a := a0 + sweep * i / 4.0
		var dir := Vector2(cos(a), sin(a))
		c.draw_line(center + dir * (r - (12.0 if i % 2 == 0 else 7.0)), center + dir * r, backlight, 2.0, true)
	var dl := Vector2(cos(a0), sin(a0))
	var dh := Vector2(cos(a0 + sweep), sin(a0 + sweep))
	c.draw_string(_font, center + dl * (r + 14.0) + Vector2(-6, 8), lo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, backlight)
	c.draw_string(_font, center + dh * (r + 14.0) + Vector2(-6, 8), hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, backlight)
	_needle(center, r - 6.0, a0 + sweep * clamp(value, 0.0, 1.0))


func _needle(center: Vector2, length: float, angle: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	_canvas.draw_line(center - dir * 14.0, center + dir * length, needle_color, 4.0, true)
	_canvas.draw_circle(center, 9.0, Color(0.12, 0.12, 0.13))


## Контрольная лампа: горит — цветная надпись в рамке, нет — едва видна
func _lamp(pos: Vector2, text: String, color: Color, on: bool) -> void:
	var col := color if on else Color(color, 0.08)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_canvas.draw_rect(Rect2(pos + Vector2(-4, -17), Vector2(tw + 8, 22)), Color(col, col.a * 0.25))
	_canvas.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
