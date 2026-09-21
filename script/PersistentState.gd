# This handles all data that needs to persist between scenes and will be
# referenced when swapping between scenes or interacting with objects that
# have persistent data that needs to be stored.
# Autoloaded - referrable globally without class_name
extends Object

var current_level: int # which level the player is in?
var level_entrance: int # levels with multiple exits: where did the player enter from last?

var acquired_clue1: bool
var acquired_clue2: bool

var defeated_x: bool

func default_initialize() -> void:
	current_level = -1
	level_entrance = -1

# save all persistent data to a file
func save() -> void:
	pass

# load all persistent data from a save file
func load(save_id: int) -> void:
	pass
