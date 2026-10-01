extends Node
## Integration boundary: connect signals instead of depending on a player class.
signal dialogue_opened
signal dialogue_closed
signal item_requested(item_id: int)

var flags: Dictionary = {}
var dialogue_manager: Control
var interaction_locked := false

func open_dialogue() -> void:
	dialogue_opened.emit()

func close_dialogue() -> void:
	dialogue_closed.emit()

func add_item_by_id(item_id: int) -> void:
	item_requested.emit(item_id)

func is_busy() -> bool:
	return interaction_locked or (is_instance_valid(dialogue_manager) and dialogue_manager.active)
