extends Control

signal swap_requested(painting_id: String, target_id: String)
signal dialogue_finished

enum AdvanceMode {
	PLAYER_INPUT,
	AUTO
}

# --- CSV HEADER REFERENCE ---
# ID                : Unique identifier for this row.
# TYPE              : start, line, choice, option, end
# NEXT              : ID to automatically jump to after this row finishes.
# SPEAKER           : Display name of the speaker.
# PORTRAIT          : Portrait/emotion/card key for this speaker.
# TEXT              : The text shown to the player. Supports {variables} passed via context!
# TEXT SPEED        : Optional characters-per-second override.
# EMOTE             : Optional emote to play on the speaker.
# CONDITIONS        : Expression that must be true (e.g., flag.met_guard == 1).
# EFFECTS           : Semicolon-separated list of variable changes or events to apply.
#                     Commands and context are documented in res://docs/dialogue-usability.md.
# CHOICE GROUP      : Group identifier for options belonging to a choice menu.
# CHOICE NEXT       : ID to jump to when this option is selected.
# CHOICE CONDITIONS : Expression that controls whether this option appears.
# ----------------------------

var rows: Array[Dictionary] = []
var by_id: Dictionary = {}
var current_id := ""
var active := false
var current_context: Dictionary = {}

@onready var label = $RichTextLabel
@onready var player_deck = $PlayerDeck

var waiting_for_choice := false
var choices_box: VBoxContainer

@export var default_chars_per_second: float = 40.0
@export var base_char_delay: float = 0.05
@export var default_auto_advance_delay: float = 0.8

@export_group("Voices")
@export var voices_enabled := true
@export var default_voice: DialogueVoice = preload("res://dialogue/Voices/default.tres")
@export var character_voices: Dictionary[String, DialogueVoice] = {}
@export var silent_speakers: PackedStringArray = ["", "Narrator"]
var voice_player: DialogueSounds
var current_voice: DialogueVoice
var voice_character_count := 0
var character_delay := 0.05

var full_text: String = ""
var visible_chars: int = 0
var typing := false

var type_timer: Timer
var auto_advance_timer: Timer

var advance_mode: AdvanceMode = AdvanceMode.PLAYER_INPUT
var auto_advance_delay: float = 0.8
var cancellable := true

var special := false
var add_tween: Tween


func _ready() -> void:
	Narrative.dialogue_manager = self
	visible = false
	_ensure_choices_box()

	voice_player = DialogueSounds.new()
	voice_player.name = "DialogueVoicePlayer"
	add_child(voice_player)

	type_timer = Timer.new()
	type_timer.one_shot = true
	add_child(type_timer)
	type_timer.timeout.connect(_on_type_tick)

	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	add_child(auto_advance_timer)
	auto_advance_timer.timeout.connect(_on_auto_advance_timeout)


func _ensure_choices_box() -> void:
	if choices_box != null:
		return

	choices_box = VBoxContainer.new()
	choices_box.name = "Choices"
	add_child(choices_box)
	choices_box.visible = false


func _position_choices_box() -> void:
	var bottom_y = label.position.y - 10
	var box_height := choices_box.get_combined_minimum_size().y
	choices_box.position = Vector2(label.position.x, bottom_y - box_height)


func _unhandled_input(event: InputEvent) -> void:
	if not active or event.is_echo():
		return

	# Escape cancels ordinary dialogue.
	if cancellable and not special:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			stop_dialogue()
			return

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if not waiting_for_choice:
			get_viewport().set_input_as_handled()
		if typing:
			finish_typewriter()
			return

		if waiting_for_choice:
			return

		_advance()


func _advance() -> void:
	if current_id == "" or not by_id.has(current_id):
		stop_dialogue()
		return

	var row: Dictionary = by_id[current_id]
	var type := str(row.get("TYPE", "")).strip_edges().to_lower()

	if type == "line":
		var next_id := str(row.get("NEXT", "")).strip_edges()
		if next_id == "":
			stop_dialogue()
		else:
			dialogue_loop(next_id)

	elif type == "end":
		stop_dialogue()


func load_dialogue_csv(path: String) -> Dictionary:
	rows.clear()
	by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open CSV: %s" % path)
		return {}

	var headers: PackedStringArray = file.get_csv_line(",")
	for i in headers.size():
		headers[i] = headers[i].strip_edges()

	while not file.eof_reached():
		var columns: PackedStringArray = file.get_csv_line(",")
		if columns.size() == 0:
			continue

		var any_text := false
		for column in columns:
			if column.strip_edges() != "":
				any_text = true
				break

		if not any_text:
			continue

		var row: Dictionary = {}

		for i in headers.size():
			var key := headers[i]
			var value := ""

			if i < columns.size():
				value = columns[i].strip_edges()

			if value == "EMPTY":
				value = ""

			row[key] = value

		var id := str(row.get("ID", "")).strip_edges()

		if id == "":
			push_warning("CSV row missing ID")
			continue

		rows.append(row)
		by_id[id] = row

	file.close()

	return {
		"rows": rows,
		"by_id": by_id
	}


func start_dialogue(
	csv_path: String,
	context: Dictionary = {},
	explicit_start_id: String = "",
	options: Dictionary = {}
) -> void:
	if active:
		push_warning("Attempted to start dialogue while another dialogue was active.")
		return

	cancellable = bool(options.get("cancellable", true))
	advance_mode = int(options.get("advance_mode", AdvanceMode.PLAYER_INPUT))
	auto_advance_delay = maxf(
		float(options.get("auto_delay", default_auto_advance_delay)),
		0.0
	)

	if advance_mode not in [AdvanceMode.PLAYER_INPUT, AdvanceMode.AUTO]:
		push_warning("Unknown advance mode. Falling back to PLAYER_INPUT.")
		advance_mode = AdvanceMode.PLAYER_INPUT

	current_context = context.duplicate()

	load_dialogue_csv(csv_path)

	if rows.is_empty():
		push_error("Dialogue CSV had no rows: %s" % csv_path)
		return

	active = true
	visible = true

	var start_next := ""

	if explicit_start_id != "":
		start_next = explicit_start_id
	else:
		for row in rows:
			if str(row.get("TYPE", "")).strip_edges().to_lower() != "start":
				continue

			if conditions_true(str(row.get("CONDITIONS", ""))):
				start_next = str(row.get("NEXT", "")).strip_edges()
				break

		if start_next == "":
			start_next = str(rows[0].get("ID", "")).strip_edges()

	if start_next == "" or not by_id.has(start_next):
		push_error("Invalid start node '%s' in %s" % [start_next, csv_path])
		active = false
		visible = false
		return

	Narrative.open_dialogue()

	current_id = start_next
	dialogue_loop(start_next)


func conditions_true(expr: String) -> bool:
	expr = expr.strip_edges()

	if expr == "" or expr.to_upper() == "TRUE":
		return true

	if expr.to_upper() == "FALSE":
		return false

	if "!=" in expr:
		var parts := expr.split("!=")

		if parts.size() == 2:
			var left := parts[0].strip_edges()
			var right := parts[1].strip_edges()

			if left.begins_with("flag."):
				var flag_name := left.replace("flag.", "")
				return int(Narrative.flags.get(flag_name, 0)) != int(right)

			return str(current_context.get(left, "")) != right

	if "==" in expr:
		var parts := expr.split("==")

		if parts.size() == 2:
			var left := parts[0].strip_edges()
			var right := parts[1].strip_edges()

			if left.begins_with("flag."):
				var flag_name := left.replace("flag.", "")
				return int(Narrative.flags.get(flag_name, 0)) == int(right)

			return str(current_context.get(left, "")) == right

	push_warning("Unknown condition: %s" % expr)
	return false


func dialogue_loop(id: String) -> void:
	auto_advance_timer.stop()

	if not by_id.has(id):
		stop_dialogue()
		return

	var row: Dictionary = by_id[id]

	if not conditions_true(str(row.get("CONDITIONS", ""))):
		var next_row_id := ""

		for i in range(rows.size()):
			if str(rows[i].get("ID", "")) == id:
				if i + 1 < rows.size():
					next_row_id = str(rows[i + 1].get("ID", ""))
				break

		if next_row_id != "":
			dialogue_loop(next_row_id)
		else:
			stop_dialogue()

		return

	current_id = id

	var type := str(row.get("TYPE", "")).strip_edges().to_lower()

	clear_text()

	if type != "option":
		apply_effects(str(row.get("EFFECTS", "")))

	match type:
		"start":
			var next_id := str(row.get("NEXT", "")).strip_edges()

			if next_id == "":
				stop_dialogue()
			else:
				dialogue_loop(next_id)

		"line":
			waiting_for_choice = false
			clear_choices()
			make_line(row)

		"choice":
			waiting_for_choice = true
			make_line(row)
			build_choice_options(row)

		"end":
			waiting_for_choice = false
			clear_choices()
			make_line(row)

		_:
			push_warning("Unknown TYPE '%s' at ID %s" % [type, id])
			stop_dialogue()


func make_line(row: Dictionary) -> void:
	var raw_text := str(row.get("TEXT", ""))
	var formatted_text := raw_text.format(current_context)

	var chars_per_second := default_chars_per_second
	var speed_string := str(row.get("TEXT SPEED", "")).strip_edges()

	if speed_string != "":
		chars_per_second = float(speed_string)

	var speaker := str(row.get("SPEAKER", "")).strip_edges()
	_select_voice(speaker)
	var portrait := str(row.get("PORTRAIT", "")).strip_edges()
	var emote := str(row.get("EMOTE", "")).strip_edges()

	if emote != "":
		_play_speaker_emote(speaker, emote)

	start_typewriter(formatted_text, chars_per_second)

	if speaker != "Narrator" and portrait != "":
		var texture_path := "res://dialogue/Sprites/" + speaker + "_" + portrait + ".png"
		var texture = load(texture_path) if ResourceLoader.exists(texture_path) else null

		if texture != null:
			var new_sprite := Sprite2D.new()
			new_sprite.texture = texture
			player_deck.add_child(new_sprite)

			var end_position := Vector2(40, 220)
			var start_position := Vector2(40, 320)

			new_sprite.position = start_position

			if is_instance_valid(add_tween):
				add_tween.kill()

			add_tween = create_tween()
			add_tween.tween_property(
				new_sprite,
				"position",
				end_position,
				0.2
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		else:
			push_warning("Dialogue portrait could not be loaded: %s" % texture_path)

	if speaker == "Narrator" and player_deck.get_child_count() > 0:
		if is_instance_valid(add_tween):
			add_tween.kill()

		add_tween = create_tween()
		add_tween.parallel()

		for child in player_deck.get_children():
			var end_position := Vector2(40, 320)

			add_tween.tween_property(
				child,
				"position",
				end_position,
				0.2
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _play_speaker_emote(speaker: String, emote: String) -> void:
	var actors = current_context.get("actors", {})

	if not actors is Dictionary:
		return

	if not actors.has(speaker):
		return

	var actor = actors[speaker]

	if not is_instance_valid(actor):
		return

	if actor.has_method("play_emote"):
		actor.play_emote(emote)


func clear_choices() -> void:
	if choices_box == null:
		return

	for child in choices_box.get_children():
		child.queue_free()

	choices_box.visible = false


func build_choice_options(choice_row: Dictionary) -> void:
	clear_choices()
	choices_box.visible = true

	var group := str(choice_row.get("CHOICE GROUP", "")).strip_edges()

	if group == "":
		group = str(choice_row.get("ID", "")).strip_edges()

	var options: Array[Dictionary] = []

	for row in rows:
		if str(row.get("TYPE", "")).strip_edges().to_lower() != "option":
			continue

		if str(row.get("CHOICE GROUP", "")).strip_edges() != group:
			continue

		if not conditions_true(str(row.get("CHOICE CONDITIONS", ""))):
			continue

		if not conditions_true(str(row.get("CONDITIONS", ""))):
			continue

		options.append(row)

	if options.is_empty():
		push_warning("No valid options for choice group: %s" % group)
		stop_dialogue()
		return

	for option in options:
		var button := Button.new()
		var raw_option_text := str(option.get("TEXT", ""))

		button.text = raw_option_text.format(current_context)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices_box.add_child(button)

		button.pressed.connect(
			func():
				_on_option_selected(option)
		)

	await get_tree().process_frame

	if active and waiting_for_choice:
		_position_choices_box()
		choices_box.get_child(0).grab_focus()


func _on_option_selected(option_row: Dictionary) -> void:
	if not active:
		return

	apply_effects(str(option_row.get("EFFECTS", "")))

	waiting_for_choice = false
	clear_choices()

	var next_id := str(option_row.get("CHOICE NEXT", "")).strip_edges()

	if next_id == "":
		push_error(
			"Option missing CHOICE NEXT at ID %s"
			% str(option_row.get("ID", ""))
		)
		stop_dialogue()
		return

	dialogue_loop(next_id)


func apply_effects(effects: String) -> void:
	var context := current_context.duplicate()
	context["source"] = context.get("source", context.get("receiver", context.get("effects_parent", self)))
	context["swap_requested"] = _forward_swap_requested
	Effects.apply_effects(effects, context)


func _forward_swap_requested(painting_id: String, target_id: String) -> void:
	swap_requested.emit(painting_id, target_id)


func stop_dialogue() -> void:
	voice_player.stop_saying()
	if not active:
		return

	active = false
	waiting_for_choice = false
	current_id = ""
	typing = false

	type_timer.stop()
	auto_advance_timer.stop()

	label.text = ""
	clear_choices()
	visible = false

	current_context.clear()

	Narrative.close_dialogue()

	if is_instance_valid(add_tween):
		add_tween.kill()

	for sprite in player_deck.get_children():
		sprite.queue_free()

	full_text = ""
	visible_chars = 0

	dialogue_finished.emit()


func clear_text() -> void:
	type_timer.stop()
	voice_player.stop_saying()
	typing = false
	label.clear()


func _select_voice(speaker: String) -> void:
	voice_player.stop_saying()
	current_voice = character_voices.get(speaker, default_voice)
	if speaker in silent_speakers:
		current_voice = null
	if current_voice == null:
		return
	voice_player.set_sub_stream(current_voice.sound)
	voice_player.main_pitch_scale = current_voice.pitch
	voice_player.random_pitch = current_voice.pitch_variation
	voice_player.volume_db = current_voice.volume_db


func _voice_character(character: String) -> void:
	if not voices_enabled or current_voice == null or not current_voice.enabled:
		return
	if character.strip_edges().is_empty() or character in ".,!?;:'\"…-—()[]{}":
		return
	if voice_character_count % maxi(current_voice.characters_per_sound, 1) == 0:
		voice_player.play_character(character)
	voice_character_count += 1


func start_typewriter(text: String, chars_per_second: float = -1.0) -> void:
	auto_advance_timer.stop()
	type_timer.stop()
	voice_player.stop_saying()
	voice_character_count = 0

	full_text = text
	visible_chars = 0
	typing = true
	label.text = ""

	if full_text.is_empty():
		typing = false
		_schedule_auto_advance()
		return

	var cps := chars_per_second if chars_per_second > 0.0 else default_chars_per_second
	character_delay = 1.0 / maxf(cps, 1.0)

	_start_next_tick(1.0 / maxf(cps, 1.0))


func finish_typewriter() -> void:
	if not typing:
		return

	typing = false
	type_timer.stop()
	voice_player.stop_saying()

	visible_chars = full_text.length()
	label.text = full_text

	_schedule_auto_advance()


func _on_type_tick() -> void:
	if not typing:
		return

	visible_chars += 1
	_voice_character(full_text[visible_chars - 1])

	if visible_chars >= full_text.length():
		visible_chars = full_text.length()
		label.text = full_text
		typing = false

		_schedule_auto_advance()
		return

	label.text = full_text.substr(0, visible_chars)

	var next_delay := character_delay

	if visible_chars >= 3 and full_text.substr(visible_chars - 3, 3) == "...":
		next_delay = character_delay * 6.0
	else:
		var last_character := full_text[visible_chars - 1]

		if last_character in [".", "!", "?"]:
			next_delay = character_delay * 4.0

		elif last_character in [",", ";", ":"]:
			next_delay = character_delay * 2.0

	type_timer.start(maxf(next_delay, 0.001))


func _start_next_tick(delay: float) -> void:
	type_timer.start(maxf(delay, 0.001))


func _schedule_auto_advance() -> void:
	if not active:
		return

	if advance_mode != AdvanceMode.AUTO:
		return

	if waiting_for_choice:
		return

	auto_advance_timer.stop()
	auto_advance_timer.start(auto_advance_delay)


func _on_auto_advance_timeout() -> void:
	if not active:
		return

	if typing:
		return

	if waiting_for_choice:
		return

	_advance()


func _exit_tree() -> void:
	if Narrative.dialogue_manager == self:
		Narrative.dialogue_manager = null
	if active:
		Narrative.close_dialogue()
