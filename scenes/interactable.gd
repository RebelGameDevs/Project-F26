extends Area2D
class_name Interactable

@export var interaction_script: Script # this script must have the interact method, type of script is not relevant
@export var sprite: Texture2D
# collision shape is default size

@onready var interact_script: Object = interaction_script.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Sprite2D.texture = sprite


func interact() -> void:
	RuntimeState.current_game_state = RuntimeState.GameState.INTERACTING
	interact_script.call("interact")
