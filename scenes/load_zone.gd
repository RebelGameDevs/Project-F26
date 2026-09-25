extends Area2D

const TRANSITION = preload("res://scenes/transition.tscn")
@export var next_scene_file: String

func _on_body_entered(body: Node2D) -> void:
	# if the player enters load scene
	if body.is_in_group("player"):
		switch_level()

func switch_level():
	# create transition animation
	var transition = TRANSITION.instantiate()
	get_tree().root.add_child(transition)
	
	# switch scene and wait for transition to finish
	await transition.fade_in()
	get_tree().change_scene_to_file(next_scene_file)
	await  transition.fade_out()
	
	# destroy transition
	transition.queue_free()
