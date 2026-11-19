extends Node3D
## Культист — актёр катсцен (не ИИ): стоит, поёт, ходит, тащит, замахивается ножом.
## Анимации по именам (в AnimationPlayer): idle, chant, walk, drag, carry, raise_knife, stab.
## Настоящая модель позже заменит Model, но должна дать анимации с теми же именами
## и якоря Head, Hand_L, Hand_R, KnifeSocket.

@export var animation := &"chant"     ## с какой анимации начинать
@export var has_knife := false
@export var random_start := true      ## сдвиг по времени, чтобы толпа не двигалась в такт

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _knife: Node3D = $Model/ArmR/KnifeSocket/Knife


func _ready() -> void:
	set_knife(has_knife)
	play_anim(animation)
	if random_start and _anim.current_animation != "":
		var a := _anim.get_animation(_anim.current_animation)
		if a.loop_mode != Animation.LOOP_NONE:
			_anim.seek(randf() * a.length, true)


## Сменить анимацию (вызывается из дорожек Call Method катсцен)
func play_anim(anim_name: StringName, blend := 0.25) -> void:
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, blend)


func set_knife(on: bool) -> void:
	has_knife = on
	if _knife:
		_knife.visible = on
