extends Area3D
## Зона в холле: когда игрок заходит в дом, парадная дверь захлопывается и запирается.

@export var door_path: NodePath
@export_multiline var message := "Дверь захлопнулась! Заперто..."

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _done or not (body.name == "Player" or body.is_in_group("player")):
		return
	_done = true
	var door := get_node_or_null(door_path)
	if door:
		door.slam_and_lock()
	var game := get_tree().get_first_node_in_group("game")
	if game:
		game.set_flag("front_locked")
		game.show_message(message, 4.0)
