extends Node2D

signal cutscene_started
signal cutscene_finished


@export var actors: Array[Node2D]
## Parent whose descendants are targeted by dialogue scene effects.
## Defaults to this controller's parent when unassigned.
@export var dialogue_effects_parent: Node

@export_group("Scene Startup")
@export var play_on_scene_start := false
@export var startup_animation: StringName = &"Door"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var actor_proxies: Node = $Actors

var active := false
var current_animation: StringName = &""
var positioning_actors := false
var _pending_actors := 0
var _cutscene_run := 0
var _proxy_start_transforms: Array = []
var _startup_pending := false


func _ready() -> void:
	# AnimationPlayer normally processes at priority 0.
	# We want this controller to copy its results afterward.
	process_priority = 100

	animation_player.animation_finished.connect(_on_animation_finished)

	if _validate_actor_setup():
		for i in actors.size():
			_proxy_start_transforms.append(_get_proxy(i).transform)

	# Defer until the rest of the scene has completed its ready callbacks.
	_arm_startup.call_deferred()


func _arm_startup() -> void:
	_startup_pending = play_on_scene_start and _cutscene_run == 0
	if _startup_pending and not animation_player.has_animation(startup_animation):
		push_error("Startup cutscene animation does not exist: %s" % startup_animation)
		_startup_pending = false


func _try_startup() -> void:
	if not play_on_scene_start:
		_startup_pending = false
		return
	if Narrative.is_busy():
		return
	for actor in actors:
		if not is_instance_valid(actor) or not actor.is_node_ready():
			return
	_startup_pending = false
	play_cutscene(startup_animation, false)


func _process(_delta: float) -> void:
	if _startup_pending and not active:
		_try_startup()
	if not active:
		return
	if positioning_actors:
		if _pending_actors == 0:
			positioning_actors = false
			animation_player.play(current_animation)
		return

	_apply_proxy_transforms()


# ===========================================================================
# CUTSCENE START / END
# ===========================================================================

func play_cutscene(animation_name: StringName = &"cutscene", walk_to_start: bool = true) -> void:
	if active:
		push_warning("Tried to start a cutscene while one was already active.")
		return

	if not animation_player.has_animation(animation_name):
		push_error("Cutscene animation does not exist: %s" % animation_name)
		return

	if not _validate_actor_setup():
		return
	if walk_to_start:
		for actor in actors:
			if not actor.has_method("walk_to_cutscene_position"):
				push_warning("Walking actors need walk_to_cutscene_position(target).")
				return

	# A successful manual start also consumes the pending startup request.
	_startup_pending = false

	# Restore the authored spots, including when replaying a cutscene.
	if _proxy_start_transforms.size() != actors.size():
		_proxy_start_transforms.clear()
		for i in actors.size():
			_proxy_start_transforms.append(_get_proxy(i).transform)
	for i in actors.size():
		_get_proxy(i).transform = _proxy_start_transforms[i]

	# Tell the real actors to stop their normal gameplay behavior.
	for actor in actors:
		if not is_instance_valid(actor):
			continue

		if actor.has_method("enter_cutscene_mode"):
			actor.enter_cutscene_mode()

	active = true
	current_animation = animation_name
	positioning_actors = walk_to_start
	_cutscene_run += 1
	_pending_actors = actors.size()
	var run_id := _cutscene_run

	cutscene_started.emit()

	if not active or run_id != _cutscene_run:
		return
	if not walk_to_start:
		# Opening scenes start at their own first frame, not the shared walk-in marker.
		_pending_actors = 0
		animation_player.play(current_animation)
		animation_player.advance(0.0)
		_apply_proxy_transforms()
		return

	for i in actors.size():
		if not active or run_id != _cutscene_run:
			return
		_walk_actor_to_spot(actors[i], _get_proxy(i).global_position, run_id)


func _walk_actor_to_spot(actor: Node, target: Variant, run_id: int) -> void:
	# Actors own their movement and return only once they have arrived.
	await actor.call("walk_to_cutscene_position", target)
	if active and run_id == _cutscene_run:
		_pending_actors -= 1


func finish_cutscene() -> void:
	stop_screen_shake()
	if not active:
		return

	# Make sure actors receive the final frame of their proxy transforms.
	if not positioning_actors:
		_apply_proxy_transforms()
	# Preserve the final pose of scene props, including the closed door.
	animation_player.stop(true)

	active = false
	positioning_actors = false
	_cutscene_run += 1
	current_animation = &""

	for actor in actors:
		if not is_instance_valid(actor):
			continue

		if actor.has_method("exit_cutscene_mode"):
			actor.exit_cutscene_mode()

	cutscene_finished.emit()


func _on_animation_finished(animation_name: StringName) -> void:
	if not active:
		return

	if animation_name != current_animation:
		return

	finish_cutscene()


# ===========================================================================
# ACTOR BINDING
# ===========================================================================

func _validate_actor_setup() -> bool:
	var proxy_count := actor_proxies.get_child_count()

	if actors.size() != proxy_count:
		push_error(
			"Cutscene actor count does not match proxy count. "
			+ "Actors: %s | Proxies: %s"
			% [actors.size(), proxy_count]
		)
		return false

	for i in actors.size():
		if not is_instance_valid(actors[i]):
			push_error("Cutscene actor %s is invalid." % i)
			return false

		var proxy := _get_proxy(i)

		if not (actors[i] is Node2D and proxy is Node2D):
			push_error(
				"Cutscene proxy %s must match its actor (Node2D)."
				% i
			)
			return false

	return true


func _get_proxy(index: int) -> Node:
	if index < 0 or index >= actor_proxies.get_child_count():
		return null

	return actor_proxies.get_child(index)


func _apply_proxy_transforms() -> void:
	for i in actors.size():
		var actor := actors[i]
		var proxy := _get_proxy(i)

		if not is_instance_valid(actor) or proxy == null:
			continue

		actor.global_transform = proxy.global_transform


# ===========================================================================
# ACTOR ANIMATIONS
# ===========================================================================

func play_actor_animation(
	actor_index: int,
	animation_name: StringName
) -> void:
	if not _valid_actor_index(actor_index):
		return

	var actor := actors[actor_index]

	if actor.has_method("play_cutscene_animation"):
		actor.play_cutscene_animation(animation_name)
	else:
		push_warning(
			"Actor %s has no play_cutscene_animation() method."
			% actor_index
		)


func _valid_actor_index(index: int) -> bool:
	if index < 0 or index >= actors.size():
		push_warning(
			"Invalid cutscene actor index: %s"
			% index
		)
		return false

	if not is_instance_valid(actors[index]):
		push_warning(
			"Cutscene actor %s is invalid."
			% index
		)
		return false

	return true


# ===========================================================================
# DIALOGUE
# ===========================================================================

func dialogue_event(
	csv_path: String,
	start_id: String = "",
	pause_timeline: bool = true,
	auto_advance: bool = false,
	auto_delay: float = 0.8
) -> void:
	if not active:
		return

	if not is_instance_valid(Narrative.dialogue_manager):
		push_warning("Add a dialogue manager before playing dialogue events.")
		return
	if Narrative.dialogue_manager.active:
		push_warning(
			"Cutscene tried to start dialogue while dialogue was already active."
		)
		return

	var advance_mode = Narrative.dialogue_manager.AdvanceMode.PLAYER_INPUT

	if auto_advance:
		advance_mode = Narrative.dialogue_manager.AdvanceMode.AUTO

	# Stop the cutscene exactly where the dialogue event occurred.
	if pause_timeline:
		animation_player.pause()

	Narrative.dialogue_manager.start_dialogue(
		csv_path,
		{"effects_parent": dialogue_effects_parent if is_instance_valid(dialogue_effects_parent) else get_parent(), "source": self},
		start_id,
		{
			"cancellable": false,
			"advance_mode": advance_mode,
			"auto_delay": auto_delay
		}
	)

	if not Narrative.dialogue_manager.active:
		if pause_timeline:
			animation_player.play()
		return

	# Moving dialogue doesn't wait at all.
	if not pause_timeline:
		return

	await Narrative.dialogue_manager.dialogue_finished

	# The cutscene may have ended or been removed while dialogue was open.
	if not active:
		return

	if not is_instance_valid(animation_player):
		return

	# Resume the same animation from its paused position.
	animation_player.play()


# ===========================================================================
# OPTIONAL GENERAL EVENTS
# ===========================================================================

# Existing AnimationPlayer method tracks remain valid.
func screen_shake(duration: float = 0.5, strength: float = 0.15, frequency: float = 20.0, fade_out: bool = true, horizontal: float = 1.0, vertical: float = 1.0) -> void:
	if active:
		Effects.screen_shake(duration, strength, frequency, fade_out, horizontal, vertical, self)


func stop_screen_shake() -> void:
	Effects.stop_screen_shake(self)


func _exit_tree() -> void:
	stop_screen_shake()


func apply_effects(effects: String) -> void:
	Effects.apply_effects(effects, {
		"effects_parent": dialogue_effects_parent if is_instance_valid(dialogue_effects_parent) else get_parent(),
		"source": self,
	})


func set_actor_visible(actor_index: int, value: bool) -> void:
	if not _valid_actor_index(actor_index):
		return

	actors[actor_index].visible = value


# Call these from AnimationPlayer method tracks, using the controller as target.
func play_sound(id: StringName, volume_offset_db: float = 0.0, pitch_multiplier: float = 1.0) -> void:
	Effects.play_sound(id, volume_offset_db, pitch_multiplier)


func stop_sound(id: StringName) -> void:
	Effects.stop_sound(id)


func call_actor_method(
	actor_index: int,
	method_name: StringName
) -> void:
	if not _valid_actor_index(actor_index):
		return

	var actor := actors[actor_index]

	if not actor.has_method(method_name):
		push_warning(
			"Actor %s does not have method '%s'."
			% [actor_index, method_name]
		)
		return

	actor.call(method_name)
