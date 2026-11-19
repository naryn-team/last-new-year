extends Node3D
## Сцена ритуала «у камня»: при загрузке играет финал (узел Finale, cinematics/cutscene.gd),
## потом — финальный экран. Вокруг поляны расставляется лес.

@export_file("*.tscn") var end_screen := "res://ui/end_screen.tscn"
@export var tree_scene: PackedScene      ## ёлка (levels/world/tree.tscn)
@export var tree_count := 60
@export var forest_inner := 11.0         ## радиус поляны, м
@export var forest_outer := 22.0

@onready var _finale = $Finale


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_finale.close_eyes(0.0)             # начинаем в темноте: герой без сознания
	if not SceneFlow.session.get("ending", false):
		SceneFlow.set_muffle(500.0, 0.0)  # сцену открыли напрямую — звук как после удара
	_build_forest()
	_finale.play()
	await _finale.finished
	SceneFlow.change_scene(end_screen, 0.0, 2.0)


func _build_forest() -> void:
	if tree_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in tree_count:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(forest_inner, forest_outer)
		var t: Node3D = tree_scene.instantiate()
		t.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		t.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(0.9, 1.5)
		t.scale = Vector3(s, s, s)
		add_child(t)
