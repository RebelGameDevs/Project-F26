extends Node
class_name LevelPassages

enum LevelEnum {
	DETECTIVES_OFFICE = 0,
	STREET = 1,
	BAR = 2,
	MAFIA_HQ = 3
}

# passageway nodes, should be added in editor based on per-scene
@export var passageways: Array[Passageway]
