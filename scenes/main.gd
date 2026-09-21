extends Node

@export var dbranch_1: String = "main1"

# as this depends on an export value, must be onready
@onready var dialogue_funcs: Dictionary[String, Callable] = {
	dbranch_1: dialogue_execute
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _input(event: InputEvent) -> void:
	#if Input.is_action_just_pressed('forward') and Dialogic.current_timeline == null:
		#Dialogic.start('main')
		#get_viewport().set_input_as_handled()
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_dialogic_signal(argument: String) -> void:
	#print_debug("Dialogic signal argument: ", argument)
	#print_debug(dialogue_branch_1_name)
	
	if not dialogue_funcs.has(argument):
		push_error("failed to find key for dialogue: ", argument)
		assert(false)
	
	var function: Callable = dialogue_funcs[argument]
	function.call()

func dialogue_execute() -> void:
	print("Dialogue execute: hello there!")
