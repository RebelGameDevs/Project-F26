extends CharacterBody2D

@onready var follow_point: Marker2D = $FollowPoint
@onready var follow_sprite: AnimatedSprite2D = $Follower/FollowSprite
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@export var follow_distance = 50
@onready var wolf_sprite: AnimatedSprite2D = $WolfSprite
@onready var follower: CharacterBody2D = $Follower

var tween_speed = 0.15
const TILE_SIZE = 32
const JUST_PRESS_TIME = 0.07
var moving = false
var just_pressed = false

var last_dir: Vector2
var follow_last_dir: Vector2

func _physics_process(delta: float) -> void:
	if not moving:
		move()
	# lerp follower sprite to the follow point
	follower.position = follower.position.lerp(follow_point.position, delta * 20)
	
	# interaction perhap
	if Input.is_action_just_pressed("interact"):
		if ray_cast_2d.get_collider():
			print(ray_cast_2d.get_collider().name)
	
func move():
	# if key was just pressed, we only turn no move so return
	if(just_pressed):
		return

	# see if input was just pressed
	if (Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") or 
	Input.is_action_just_pressed("down") or Input.is_action_just_pressed("up")):
		just_pressed = true

	# get input direction
	var dir: Vector2;
	
	if Input.is_action_pressed("left"):
		dir = Vector2.LEFT
	if Input.is_action_pressed("right"):
		dir = Vector2.RIGHT
	if Input.is_action_pressed("down"):
		dir = Vector2.DOWN
	if Input.is_action_pressed("up"):
		dir = Vector2.UP
	
	# no input
	if !dir:
		# switch to idle version of whatever animation was playing
		wolf_sprite.play(wolf_sprite.animation.get_slice("_",0) + "_idle")
		follow_sprite.play(follow_sprite.animation.get_slice("_",0) + "_idle")
		return
	
	# move ray for interactions
	ray_cast_2d.target_position = dir * TILE_SIZE
	ray_cast_2d.force_raycast_update()
	
	# initial press just turns player no movement unless we already dacing in the direction
	if just_pressed and last_dir != dir:
		animate_dir(dir, wolf_sprite, "_idle") # turn using with animation
		await get_tree().create_timer(JUST_PRESS_TIME).timeout
		just_pressed = false
		last_dir = dir
		return
	
	just_pressed = false
	last_dir = dir
	follow_last_dir = dir
	
	# check for collision before moving
	if ray_cast_2d.is_colliding():
		var col = ray_cast_2d.get_collider()
		if (col is Node and col.is_in_group("obstacle")):
			return
	
	# otherwise we can start moving
	moving = true
	
	follow_point.position = -dir * TILE_SIZE
	
	animate_dir(dir, wolf_sprite, "_walk")
	animate_dir(dir, follow_sprite, "_walk")
	
	var tween = create_tween()
	tween.tween_property(self, "position", position + dir * TILE_SIZE, tween_speed)
	await tween.finished
	
	moving = false

func animate_dir(dir: Vector2, sprite: AnimatedSprite2D, anim_type: String):
	if(dir.x > 0):
		sprite.play("side" + anim_type)
		sprite.flip_h = false
	elif(dir.x < 0):
		sprite.play("side" + anim_type)
		sprite.flip_h = true
	elif(dir.y < 0):
		sprite.play("back" + anim_type)
	elif(dir.y > 0):
		sprite.play("front" + anim_type)
	
