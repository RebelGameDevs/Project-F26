extends Area2D
@export var cutscene_controller: Node
@export var animation_name: StringName = &"cutscene"
@export var player_group: StringName = &"player"
@export var one_shot := true
@export var walk_to_start := false
var triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group):
		activate()

func activate() -> bool:
	if Narrative.is_busy() or (one_shot and triggered):
		return false
	if not is_instance_valid(cutscene_controller) or cutscene_controller.active:
		return false
	cutscene_controller.play_cutscene(animation_name, walk_to_start)
	triggered = cutscene_controller.active
	return triggered
