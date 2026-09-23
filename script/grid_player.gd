extends CharacterBody2D

const tile_size = 32
var moving = false
var input_dir

@export var tween_speed = 0.1
@onready var follow_point: Marker2D = $FollowPoint
@onready var follow_sprite: Sprite2D = $FollowSprite

@export var follow_distance = 50

func _physics_process(delta: float) -> void:
	
	if Input.is_action_pressed("left"):
		input_dir = Vector2(-1,0)
		move()
	if Input.is_action_pressed("right"):
		input_dir = Vector2(1,0)
		move()
	if Input.is_action_pressed("down"):
		input_dir = Vector2(0,1)
		move()
	if Input.is_action_pressed("up"):
		input_dir = Vector2(0,-1)
		move()
	# move follow sprte to follow point
	follow_sprite.position = follow_sprite.position.lerp(follow_point.position, delta * 20)
	move_and_slide()
	
func move():
	if input_dir and moving == false:
		moving = true
		# set the following point
		follow_point.position = -input_dir * follow_distance
		#tween between tiles
		var tween = create_tween()
		tween.tween_property(self, "position", position + input_dir*tile_size, tween_speed)
		await tween.finished
		
		moving = false
