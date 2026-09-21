extends CharacterBody2D

@export var interact_area: Area2D

const SPEED = 20.0
#const JUMP_VELOCITY = -400.0

func _process(delta: float) -> void:
	pass
	#if is_in_group("interactable")


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("left"):
		print_debug("hello")
		velocity += Vector2.LEFT
	if Input.is_action_pressed("right"):
		velocity += Vector2.RIGHT
	if Input.is_action_pressed("up"):
		velocity += Vector2.UP
	if Input.is_action_pressed("down"):
		velocity += Vector2.DOWN
	if Input.is_anything_pressed():
		print_debug("hello??")
	#print_debug(velocity)
	velocity = velocity.normalized()
	velocity *= SPEED
	
	var collision := move_and_collide(velocity * delta)
