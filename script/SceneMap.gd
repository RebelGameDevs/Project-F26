extends Node

const TRANSITION: PackedScene = preload("res://scenes/transition.tscn") # from ryebread's test_world
# refs to levels with string to the actual resource
# levels are referred to by the global group "level" and have:
# child nodes:
# grid_player
# level_passages
#	passageways
# etc...
var map_levels: Array[String] = [
	"",
	"",
	"",
	"",
	"",
	"res://scenes/test_world.tscn",
	"res://scenes/maze_room_test.tscn"
]

enum LevelEnum {
	DETECTIVES_OFFICE = 0,
	STREET = 1,
	BAR = 2,
	TAILOR = 3,
	MAFIA_HQ = 4,
	TEST_WORLD = 5,
	MAZE_ROOM_TEST = 6,
}

enum Direction {
	Left = 0,
	Up = 1,
	Right = 2,
	Down = 3,
}

var dir_to_vec2: Array[Vector2] = [
	Vector2.LEFT,
	Vector2.UP,
	Vector2.RIGHT,
	Vector2.DOWN
]

# returns array of level, and the corresponding requested exit data
func load_level(level_id: LevelEnum, passageway_to: int) -> void:
	# create transition animation
	var transition = TRANSITION.instantiate() # from ryebread's test_world
	get_tree().root.add_child(transition)

	# switch scene and wait for transition to finish
	await transition.fade_in()

	var level_packed_scene: PackedScene = load(map_levels[level_id])
	var level: Node = level_packed_scene.instantiate()
	assert(level.is_in_group("level"))

	# then swap scene to level after setup is complete
	get_tree().change_scene_to_node(level)

	var level_passages: LevelPassages = level.get_node("LevelPassages")
	assert(level_passages != null)
	assert(passageway_to >= 0 and passageway_to < level_passages.passageways.size())
	var passageway: Passageway = level_passages.passageways[passageway_to]

	var player: GridPlayer = level.get_node("GridPlayer")
	player.set_process_input(false)
	var follower: CharacterBody2D = player.get_node("Follower")
	var follow_point: Marker2D = player.get_node("FollowPoint")
	var dir: Vector2 = dir_to_vec2[passageway.enter_facing]
	# set player position and facing based on passageway
	player.position = passageway.position + dir * 32 + Vector2.UP * 16 # offset from the entry + offset passageway tile pos and dir
	follower.position = -dir * 32
	follow_point.position = -dir * 32
	var player_sprite: AnimatedSprite2D = player.get_node("WolfSprite")
	var follower_sprite: AnimatedSprite2D = follower.get_node("FollowSprite")
	player.animate_dir(dir, player_sprite, "_idle")
	player.animate_dir(dir, follower_sprite, "_idle")

	await  transition.fade_out()
	player.set_process_input(true)
	# destroy transition
	transition.queue_free()
