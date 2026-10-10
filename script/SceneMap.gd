extends Node

# refs to levels with string to the actual resource
# levels have:
# 
var map_levels: Array[String] = [
	
]

# returns array of level, and the corresponding requested exit data
func load_level(passageway_to: int, level_id: LevelEnum) -> void:
	var level_packed_scene: PackedScene = load(map_levels[level_id])
	var level: LevelPassages = level_packed_scene.instantiate()
	
	var passageway: Passageway = level.passageways[passageway_to]
	var passage_position: Vector2 = passageway.position
	
	var player = level.get_node("player")
	# set player position and facing based on passageway
	
	# then swap scene to level after setup is complete
	get_tree().change_scene_to_node(level)
	
	#return []
