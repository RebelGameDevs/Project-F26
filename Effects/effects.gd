extends Node
# Shared effect commands for dialogue, cutscene method tracks, and gameplay.
signal event_requested(event_name: StringName, context: Dictionary)

signal swap_requested(painting_id: String, target_id: String)

var _shake_camera: Camera2D
var _shake_base := Vector2.ZERO
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_frequency := 0.0
var _shake_fade := true
var _shake_axes := Vector2.ONE
var _shake_seed := 0.0

var _shake_owner: Node

func _process(delta: float) -> void:
	_update_screen_shake(delta)


func fade_out(duration: float = 1.0) -> void:
	ScreenFade.fade_out(duration)


func reset_fade() -> void:
	ScreenFade.reset()


func play_sound(id: StringName, volume_offset_db: float = 0.0, pitch_multiplier: float = 1.0) -> void:
	Audio.play(id, volume_offset_db, pitch_multiplier)


func stop_sound(id: StringName) -> void:
	Audio.stop_sound(id)


func apply_effects(effects: String, context: Dictionary = {}) -> void:
	effects = effects.strip_edges()

	if effects == "" or effects.to_upper() == "EMPTY":
		return

	for command in effects.split(";"):
		command = command.strip_edges()

		if command == "":
			continue

		if _apply_extended_effect(command, context):
			continue

		if command.to_lower() == "hide_gate":
			_hide_receiver_gate(context)
			continue

		if command.to_lower() == "gate_open":
			_hide_receiver_gate(context, true)
			continue

		if command.to_lower() == "toggle_lights":
			_toggle_receiver_lights(context)
			continue

		if command.to_lower() == "lights_off":
			_toggle_receiver_lights(context, true)
			continue

		if command.to_lower() == "reset_fade":
			reset_fade()
			continue

		if command.to_lower() == "screen_shake":
			screen_shake(0.5, 0.15, 20.0, true, 1.0, 1.0, context.get("source"))
			continue

		if command.to_lower() == "stop_screen_shake":
			stop_screen_shake(context.get("source"))
			continue

		if command.to_lower() == "fade_out":
			fade_out()
			continue

		if "=" in command:
			var parts := command.replace("==", "=").split("=", true, 1)

			if parts.size() >= 2:
				var left := parts[0].strip_edges()
				var right := parts[1].strip_edges()

				if left.begins_with("flag."):
					var key := left.replace("flag.", "")
					if key.is_empty() or not right.is_valid_int():
						push_warning("Flag assignment requires a name and integer: %s" % command)
					else:
						Narrative.flags[key] = int(right)
					continue

		elif ":" in command:
			var parts := command.split(":")

			if parts.size() >= 2:
				var action := parts[0].strip_edges().to_lower()
				var argument := parts[1].strip_edges()

				if action == "fade_out":
					if argument.is_valid_float() and is_finite(argument.to_float()) and argument.to_float() >= 0.0:
						fade_out(argument.to_float())
					else:
						push_warning("fade_out duration must be a non-negative number: %s" % argument)
					continue

				if action == "play_sound":
					play_sound(StringName(argument))
					continue
				if action == "stop_sound":
					stop_sound(StringName(argument))
					continue

				if action == "add_item":
					if argument == "context":
						if context.has("item_object"):
							var id = context["item_object"]
							Narrative.add_item_by_id(id)
						else:
							push_warning(
								"CSV called 'add_item:context', but no 'item_object' was passed!"
							)

					elif argument.is_valid_int():
						Narrative.add_item_by_id(argument.to_int())

					else:
						push_warning(
							"Procedural fallback triggered for argument: " + argument
						)

					continue

				if action == "swap_with":
					var callback: Callable = context.get("swap_requested", Callable())
					if callback.is_valid():
						callback.call(context.get("name", ""), argument)
					swap_requested.emit(
						context.get("name", ""),
						argument
					)
					continue

		push_warning("Unknown effect or format: %s" % command)


func _get_effects_parent(context: Dictionary) -> Node:
	var explicit_parent = context.get("effects_parent")
	if is_instance_valid(explicit_parent) and explicit_parent is Node:
		return explicit_parent
	var receiver = context.get("receiver")
	if not is_instance_valid(receiver) or not receiver is Node:
		push_warning("Scene effect requires a receiver or effects_parent context.")
		return null
	return receiver.get_parent()


func _hide_receiver_gate(context: Dictionary, disable_collision: bool = false) -> void:
	var receiver_parent := _get_effects_parent(context)
	if receiver_parent == null:
		return

	var gate := receiver_parent.get_node_or_null("Gate")
	if gate is CanvasItem:
		gate.hide()
		if disable_collision:
			_disable_gate_collision(gate)


func _disable_gate_collision(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", true)
	for child in node.get_children():
		_disable_gate_collision(child)


func _toggle_receiver_lights(context: Dictionary, force_off: bool = false) -> void:
	var receiver_parent := _get_effects_parent(context)
	if receiver_parent == null:
		return

	_toggle_lights_under(receiver_parent, force_off)


func _toggle_lights_under(parent: Node, force_off: bool = false) -> void:
	for child in parent.get_children():
		if child is Light2D:
			child.visible = false if force_off else not child.visible
		_toggle_lights_under(child, force_off)


# Strength is in pixels. Repeated calls replace the current shake.
# Optional source selects the viewport and owns cancellation.
func screen_shake(duration: float = 0.5, strength: float = 0.15, frequency: float = 20.0, fade_out: bool = true, horizontal: float = 1.0, vertical: float = 1.0, source: Node = null) -> void:
	stop_screen_shake()
	if duration <= 0.0 or strength <= 0.0:
		return
	_shake_owner = source
	var viewport := source.get_viewport() if is_instance_valid(source) else get_viewport()
	_shake_camera = viewport.get_camera_2d()
	if not is_instance_valid(_shake_camera):
		return
	_shake_base = _shake_camera.offset
	_shake_time = 0.0
	_shake_duration = duration
	_shake_strength = strength
	_shake_frequency = maxf(frequency, 0.01)
	_shake_fade = fade_out
	_shake_axes = Vector2(horizontal, vertical)
	_shake_seed = randf() * TAU


func _update_screen_shake(delta: float) -> void:
	if not is_instance_valid(_shake_camera):
		return
	_shake_time += delta
	if _shake_time >= _shake_duration:
		stop_screen_shake()
		return
	var envelope := 1.0 - _shake_time / _shake_duration if _shake_fade else 1.0
	var phase := _shake_time * _shake_frequency * TAU
	var offset := Vector2(sin(phase + _shake_seed), sin(phase * 1.37 + _shake_seed))
	offset *= _shake_axes * _shake_strength * envelope
	_set_shake_offset(_shake_base + offset)


func stop_screen_shake(source: Node = null) -> void:
	if source != null and source != _shake_owner:
		return
	if is_instance_valid(_shake_camera):
		_set_shake_offset(_shake_base)
	_shake_camera = null
	_shake_owner = null


func fade_in(duration: float = 1.0) -> void:
	ScreenFade.fade_in(duration)


func flash(duration: float = 0.2) -> void:
	ScreenFade.flash(duration)


func _apply_extended_effect(command: String, context: Dictionary) -> bool:
	var parts := command.split(":", true, 1)
	var action := parts[0].strip_edges().to_lower()
	var argument := parts[1].strip_edges() if parts.size() > 1 else ""
	match action:
		"fade_in", "flash":
			var duration := 0.2 if action == "flash" else 1.0
			if parts.size() > 1:
				if not argument.is_valid_float() or not is_finite(argument.to_float()) or argument.to_float() < 0.0:
					push_warning("%s requires non-negative seconds." % action)
					return true
				duration = argument.to_float()
			if action == "flash":
				flash(duration)
			else:
				fade_in(duration)
		"lights_on":
			var parent := _get_effects_parent(context)
			if parent != null:
				_set_lights_on(parent)
		"show_node", "hide_node", "enable_collision", "disable_collision", "play_animation":
			var args := argument.split(",", true, 1)
			var target := _resolve_target(args[0].strip_edges(), context)
			if target == null:
				return true
			match action:
				"show_node", "hide_node":
					if target is CanvasItem:
						target.visible = action == "show_node"
				"enable_collision", "disable_collision":
					_set_collision_disabled(target, action == "disable_collision")
				"play_animation":
					if target is AnimationPlayer and args.size() == 2 and target.has_animation(args[1].strip_edges()):
						target.play(args[1].strip_edges())
					else:
						push_warning("play_animation requires AnimationPlayer path,animation name.")
		"emit_event":
			if not argument.is_empty():
				event_requested.emit(StringName(argument), context.duplicate())
			else:
				push_warning("emit_event requires an event name.")
		"stop_all_sounds":
			Audio.stop_all()
		"screen_shake":
			if parts.size() == 1:
				return false
			var args := argument.split(",")
			if args.size() < 1 or args.size() > 3:
				push_warning("screen_shake expects seconds[,strength[,frequency]].")
				return true
			var values := [0.5, 0.15, 20.0]
			for i in args.size():
				var value := args[i].strip_edges()
				if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float() < 0.0:
					push_warning("screen_shake values must be non-negative numbers.")
					return true
				values[i] = value.to_float()
			screen_shake(values[0], values[1], values[2], true, 1.0, 1.0, context.get("source"))
		_:
			return false
	return true


func _resolve_target(path: String, context: Dictionary) -> Node:
	var parent := _get_effects_parent(context)
	if parent == null:
		return null
	# Targets stay inside the supplied scope, including when CSVs are reused.
	if path.is_empty() or path.begins_with("/") or ".." in path.split("/"):
		push_warning("Effect target must be a relative path within effects_parent: %s" % path)
		return null
	var target := parent.get_node_or_null(NodePath(path))
	if target == null or (target != parent and not parent.is_ancestor_of(target)):
		push_warning("Effect target was not found within effects_parent: %s" % path)
		return null
	return target


func _set_lights_on(parent: Node) -> void:
	for child in parent.get_children():
		if child is Light2D:
			child.visible = true
		_set_lights_on(child)


func _set_collision_disabled(node: Node, disabled: bool) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", disabled)
	for child in node.get_children():
		_set_collision_disabled(child, disabled)


func _set_shake_offset(value: Vector2) -> void:
	_shake_camera.offset = value
