extends CharacterBody2D

@export var interaction_ray: RayCast2D
@export_range(1.0, 256.0) var interaction_distance := 64.0
@export var speed := 200.0
@onready var interaction_prompt: Label = $InteractionPrompt
var interaction_target: Node2D
var _cutscene_locked := false
var facing_direction := Vector2.DOWN

func _physics_process(_delta: float) -> void:
	if _controls_locked():
		velocity = Vector2.ZERO
	else:
		var direction := Input.get_vector("left", "right", "up", "down")
		if not direction.is_zero_approx():
			facing_direction = direction.normalized()
		velocity = direction * speed
		move_and_slide()
	_update_interaction_target()

func _controls_locked() -> bool:
	return _cutscene_locked or Narrative.is_busy() or RuntimeState.current_game_state != RuntimeState.GameState.WORLD

func _update_interaction_target() -> void:
	interaction_target = null
	if not _controls_locked() and is_instance_valid(interaction_ray):
		interaction_ray.target_position = facing_direction * interaction_distance
		interaction_ray.force_raycast_update()
		# Only the first hit is eligible; world bodies block interaction through walls.
		var candidate = interaction_ray.get_collider()
		if candidate is Node2D and candidate.is_in_group("interactable") and candidate.has_method("interact"):
			if not candidate.has_method("can_interact") or candidate.can_interact(self):
				interaction_target = candidate
	interaction_prompt.visible = is_instance_valid(interaction_target)
	if interaction_prompt.visible:
		var action = interaction_target.get("interaction_label")
		interaction_prompt.text = "[F] " + (str(action) if action != null else "Interact")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and not _controls_locked():
		_update_interaction_target()
		if is_instance_valid(interaction_target):
			get_viewport().set_input_as_handled()
			interaction_target.interact(self)
			_update_interaction_target()

func enter_cutscene_mode() -> void:
	_cutscene_locked = true
	velocity = Vector2.ZERO

func exit_cutscene_mode() -> void:
	_cutscene_locked = false
