extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func fade_in():
	animation_player.play("fade")
	await animation_player.animation_finished

func fade_out():
	animation_player.play_backwards("fade")
	await  animation_player.animation_finished
