extends CharacterBody2D

@export var interact_area: Area2D

const SPEED = 200.0
var current_velocity: Vector2 = Vector2.ZERO
#const JUMP_VELOCITY = -400.0

func _process(delta: float) -> void:
	pass
	#if is_in_group("interactable")


func _physics_process(delta: float) -> void:
	# damp velocity toward 0
	# don't have the denominator go 0 and having the term go to inf!
	current_velocity.x = lerpf(current_velocity.x, 0, 1 / max(1, current_velocity.x))
	current_velocity.y = lerpf(current_velocity.y, 0, 1 / max(1, current_velocity.y))
	
	var dv: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("left"):
		dv += Vector2.LEFT
	if Input.is_action_pressed("right"):
		dv += Vector2.RIGHT
	if Input.is_action_pressed("up"):
		dv += Vector2.UP
	if Input.is_action_pressed("down"):
		dv += Vector2.DOWN

	current_velocity += dv
	# only cap velocity, not grow from len < 1 to 1
	if current_velocity.length() > 1:
		current_velocity = current_velocity.normalized()
	velocity = current_velocity
	velocity *= SPEED
	
	var collision := move_and_collide(velocity * delta)
