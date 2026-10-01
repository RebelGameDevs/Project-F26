extends Area2D
# Use play() from an interaction system or trigger automatically by group.
@export_file("*.csv") var dialogue_csv_path := ""
@export var start_id := ""
@export var character_name := ""
@export var context: Dictionary = {}
@export var effects_parent: Node
@export var trigger_on_player_enter := false
@export var player_group: StringName = &"player"
@export var one_shot := false
var triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if trigger_on_player_enter and body.is_in_group(player_group):
		play(body)

func play(_player: Node = null) -> bool:
	if Narrative.is_busy() or (one_shot and triggered):
		return false
	if not is_instance_valid(Narrative.dialogue_manager) or dialogue_csv_path.is_empty():
		return false
	var data := context.duplicate()
	data["name"] = character_name
	data["receiver"] = self
	if is_instance_valid(effects_parent):
		data["effects_parent"] = effects_parent
	Narrative.dialogue_manager.start_dialogue(dialogue_csv_path, data, start_id)
	triggered = Narrative.dialogue_manager.active
	return triggered

@export var interaction_label := "Talk"

func can_interact(_player: Node = null) -> bool:
	return not Narrative.is_busy() and not (one_shot and triggered) and not dialogue_csv_path.is_empty()

func interact(player: Node) -> bool:
	return play(player)
