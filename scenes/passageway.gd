extends Area2D # reference the position for where to spawn
class_name Passageway

@export var level_to: SceneMap.LevelEnum
@export var level_to_passageway: int
@export var enter_facing: SceneMap.Direction

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		SceneMap.load_level(level_to, level_to_passageway)
