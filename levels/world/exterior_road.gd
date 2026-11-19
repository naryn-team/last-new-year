extends Node3D
## Лесная дорога к дому.
##   RoadPath (Path3D) — ось дороги: по ней едет машина (vehicle/car_driver.gd),
##   из неё же выдавлено полотно Road (CSGPolygon3D), так что дорога и путь не расходятся.
## Вне игровой зоны 100×100 м при запуске расставляются деревья и столбики вдоль дороги
## (MultiMesh — дёшево и всегда совпадает с кривой), снежные отвалы по обочинам и пунктир
## по центру (меши из той же кривой). Внутри зоны — обычный лес уровня.
## Узел должен стоять в начале координат уровня (как и RoadPath внутри него).

@export var tree_scene: PackedScene                ## откуда брать меши ёлки (levels/world/tree.tscn)
@export var half_width := 3.5                      ## половина ширины полотна, м
@export_group("Обочина")
@export var tree_spacing := 5.0                    ## шаг вдоль дороги, м
@export var tree_rows := 3                         ## рядов с каждой стороны
@export var tree_min_offset := 7.0                 ## от оси дороги
@export var tree_max_offset := 38.0
@export var post_spacing := 15.0                   ## столбики вдоль обочины
@export var post_offset := 4.9
@export var bank_profile := PackedVector2Array([Vector2(3.55, 0.0), Vector2(3.9, 0.3), Vector2(4.5, 0.55), Vector2(5.6, 0.3), Vector2(7.2, -0.02)])  ## сечение отвала: (от оси, высота)
@export var dash_length := 3.0                     ## пунктир по центру
@export var dash_gap := 6.0
@export var play_area_half := 52.0                 ## внутри |x|,|z| < этого — лес уровня, не трогаем
@export var rng_seed := 1231

@onready var road_path: Path3D = $RoadPath


func _ready() -> void:
	_build_trees()
	_build_posts()
	_build_banks()
	_build_dashes()


# ---------------------------------------------------------------- API для машины

func get_length() -> float:
	return road_path.curve.get_baked_length()


## Точка дороги на расстоянии d от начала (глобально): origin на оси, -Z — вперёд по ходу, +X — вправо
func get_frame(d: float) -> Transform3D:
	var c := road_path.curve
	var length := c.get_baked_length()
	d = clamp(d, 0.0, length)
	var p := c.sample_baked(d, true)
	var a := c.sample_baked(max(d - 0.25, 0.0), true)
	var b := c.sample_baked(min(d + 0.25, length), true)
	var t := b - a
	t.y = 0.0
	return road_path.global_transform * Transform3D(Basis.looking_at(t.normalized(), Vector3.UP), p)


## Кривизна в точке d (1/м): > 0 — дорога поворачивает налево, < 0 — направо
func get_curvature(d: float) -> float:
	var t1 := -get_frame(d - 2.0).basis.z
	var t2 := -get_frame(d + 2.0).basis.z
	return t1.signed_angle_to(t2, Vector3.UP) / 4.0


# ---------------------------------------------------------------- обочина

func _build_trees() -> void:
	if tree_scene == null:
		return
	# части ёлки: [меш, материал, положение в сцене ёлки]
	var tree := tree_scene.instantiate()
	var parts := []
	for c in tree.get_children():
		if c is MeshInstance3D:
			parts.append([c.mesh, c.material_override, c.transform])
	tree.free()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var curve := road_path.curve
	var xforms: Array[Transform3D] = []
	var d := 0.0
	while d < get_length():
		var f := _local_frame(d)
		for side in [-1.0, 1.0]:
			for r in tree_rows:
				var off := rng.randf_range(tree_min_offset, tree_max_offset)
				var along := rng.randf_range(-tree_spacing * 0.5, tree_spacing * 0.5)
				var p: Vector3 = f.origin + f.basis.x * side * off - f.basis.z * along
				var s := rng.randf_range(0.8, 1.35)
				var yaw := rng.randf_range(0.0, TAU)
				if _in_play_area(p):
					continue
				# на внутренней стороне поворота точка может оказаться у самой дороги
				if curve.get_closest_point(p).distance_to(p) < tree_min_offset - 0.5:
					continue
				xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), p))
		d += tree_spacing
	for part in parts:
		var local: Transform3D = part[2]
		var all: Array[Transform3D] = []
		for x in xforms:
			all.append(x * local)
		_add_multimesh("RoadsideTrees", part[0], part[1], all)


func _build_posts() -> void:
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 1.0, 0.12)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.12, 0.11, 0.1)
	post_mat.roughness = 0.9
	var cap := BoxMesh.new()
	cap.size = Vector3(0.13, 0.14, 0.13)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(1.0, 0.55, 0.15)   # оранжевый отражатель — вспыхивает в свете фар
	cap_mat.roughness = 0.2
	cap_mat.metallic_specular = 1.0
	var posts: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var d := 0.0
	while d < get_length():
		var f := _local_frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = f.origin + f.basis.x * side * post_offset
			if not _in_play_area(p):
				posts.append(Transform3D(f.basis, p + Vector3(0, 0.5, 0)))
				caps.append(Transform3D(f.basis, p + Vector3(0, 0.88, 0)))
		d += post_spacing
	_add_multimesh("RoadPosts", post, post_mat, posts)
	_add_multimesh("RoadPostCaps", cap, cap_mat, caps)


func _add_multimesh(base_name: String, mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = base_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi, true)


## Снежные отвалы вдоль обеих обочин (вне игровой зоны)
func _build_banks() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.94, 0.96)
	mat.roughness = 0.85
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2.0
	var d := 0.0
	while d < get_length() - step:
		var a := _local_frame(d)
		var b := _local_frame(d + step)
		if not _in_play_area(a.origin) and not _in_play_area(b.origin):
			for side in [-1.0, 1.0]:
				for i in bank_profile.size() - 1:
					var p0 := _profile_point(a, bank_profile[i], side)
					var p1 := _profile_point(a, bank_profile[i + 1], side)
					var q0 := _profile_point(b, bank_profile[i], side)
					var q1 := _profile_point(b, bank_profile[i + 1], side)
					_quad(st, p0, p1, q1, q0, side > 0.0)
		d += step
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "SnowBanks"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## Пунктир по оси дороги (вне игровой зоны) — по нему в свете фар видно скорость
func _build_dashes() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.7)
	mat.roughness = 0.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.07
	var d := 0.0
	while d < get_length() - dash_length:
		var a := _local_frame(d)
		var b := _local_frame(d + dash_length)
		if not _in_play_area(a.origin) and not _in_play_area(b.origin):
			var y := Vector3(0, 0.03, 0)
			_quad(st, a.origin - a.basis.x * w + y, a.origin + a.basis.x * w + y,
				b.origin + b.basis.x * w + y, b.origin - b.basis.x * w + y, true)
		d += dash_length + dash_gap
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "CenterDashes"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func _profile_point(f: Transform3D, pr: Vector2, side: float) -> Vector3:
	return f.origin + f.basis.x * pr.x * side + Vector3(0, pr.y, 0)


## Четырёхугольник a-b-c-d двумя треугольниками. Лицевая грань в Godot — по часовой стрелке,
## если смотреть на неё; flip меняет порядок (сверху дорога видна так, что a-b-c идёт против часовой)
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, flip: bool) -> void:
	var tris := [a, c, b, a, d, c] if flip else [a, b, c, a, c, d]
	for v in tris:
		st.add_vertex(v)


## То же, что get_frame, но в координатах этого узла (RoadPath стоит в начале координат)
func _local_frame(d: float) -> Transform3D:
	return global_transform.affine_inverse() * get_frame(d)


func _in_play_area(p: Vector3) -> bool:
	return absf(p.x) < play_area_half and absf(p.z) < play_area_half
