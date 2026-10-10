extends Node

enum EnemyType {
	GRUNT = 0,
	CAPO = 1,
}

@export var enemy_data_refs: Array[String] = [
	#"res://scenes/grunt.tscn"
	#preload(capo.tscn)
]

# reference to the resource string in enemy_data_refs
var enemy_data_names: Dictionary[String, String] = {
	#str(EnemyType.GRUNT) : enemy_data_refs[sd
}

# loads PackedScenes from memory at runtime
# does not handle spawning them in, should request the PackedScene
# and use the PackedScene to instance the enemies themselves
func get_enemy_packed_scene(enemy_enum: EnemyType) -> PackedScene:
	assert(enemy_enum >= 0 && enemy_enum < enemy_data_refs.size())
	return load(enemy_data_refs[enemy_enum])
