extends Node3D
## Зеркало заднего вида (узел Model/Interior/RearMirror).
## Камера в маленьком SubViewport смотрит назад из точки Eye; картинка, отражённая
## по горизонтали, ложится на стекло Glass. Работает, только пока active = true
## (машина включает его, когда текущая камера — камера водителя).

@export var resolution := Vector2i(320, 96)
@export var fov := 38.0

var active := false: set = set_active

var _vp: SubViewport
var _cam: Camera3D
var _mat: StandardMaterial3D

@onready var _eye: Node3D = $Eye
@onready var _glass: MeshInstance3D = $Glass


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = resolution
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = fov
	_cam.near = 0.05
	_cam.far = 200.0
	_vp.add_child(_cam)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_texture = _vp.get_texture()
	_mat.uv1_scale = Vector3(-1, 1, 1)    # зеркало: лево и право меняются местами
	_mat.uv1_offset = Vector3(1, 0, 0)
	_glass.material_override = _mat
	set_active(false)


func set_active(v: bool) -> void:
	active = v
	if _vp == null:
		return
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED
	_mat.albedo_color = Color(0.85, 0.85, 0.85) if v else Color(0.05, 0.05, 0.06)


func _process(_delta: float) -> void:
	if active:
		_cam.global_transform = _eye.global_transform
