extends Node2D
# Interactive coverage of every supported CSV effect command.
const COMMANDS: Array[String] = [
	"hide_gate", "show_node:Gate", "gate_open", "show_node:Gate; enable_collision:Gate",
	"toggle_lights", "lights_off", "lights_on",
	"hide_node:Artifact", "show_node:Artifact", "disable_collision:Gate", "enable_collision:Gate",
	"play_animation:AnimationPlayer,pulse",
	"fade_out", "fade_in:0.4", "fade_out:0.3", "reset_fade", "flash:0.2",
	"screen_shake", "screen_shake:2,8,20", "stop_screen_shake",
	"play_sound:test_tone", "stop_sound:test_tone", "play_sound:test_tone; stop_all_sounds",
	"flag.dialogue_test=1", "add_item:7", "add_item:context", "swap_with:Artifact", "emit_event:effects_test"
]
@onready var manager = $HUD/DialogueManager
@onready var controller = $CutsceneController
@onready var player = $WorldPlayer
var status: Label
var activity: Label
var buttons: Array[Button] = []
var _run := 0
var _running_all := false
var _previous_lock := false
var _previous_state: int
var _dialogue_state: int
var _library: SoundLibrary
var _had_flag := false
var _previous_flag: Variant
var _items: Array[int] = []

func _ready() -> void:
	_previous_lock = Narrative.interaction_locked
	_previous_state = RuntimeState.current_game_state
	_had_flag = Narrative.flags.has("dialogue_test")
	_previous_flag = Narrative.flags.get("dialogue_test")
	RuntimeState.current_game_state = RuntimeState.GameState.WORLD
	player.facing_direction = Vector2.RIGHT
	_build_ui()
	_register_sound()
	Narrative.dialogue_opened.connect(_dialogue_opened)
	Narrative.dialogue_closed.connect(_dialogue_closed)
	Narrative.item_requested.connect(_item_requested)
	Effects.event_requested.connect(_event_requested)
	Effects.swap_requested.connect(_swap_requested)
	controller.cutscene_started.connect(_cutscene_started)
	controller.cutscene_finished.connect(_cutscene_finished)

func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 12)
	$HUD.add_child(panel)
	var title := Label.new()
	title.text = "Dialogue Test — WASD/arrows to move, face the guide + F to talk"
	panel.add_child(title)
	var actions := HBoxContainer.new()
	panel.add_child(actions)
	_add_button(actions, "Run all effects", run_all_effects)
	_add_button(actions, "Play cutscene", play_cutscene)
	_add_button(actions, "Reset / stop", reset_demo, false)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 170)
	panel.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	scroll.add_child(grid)
	for command in COMMANDS:
		_add_button(grid, command, run_effect.bind(command))
	status = Label.new()
	status.text = "Choose an effect or run the complete sequence. Reset restores the stage."
	panel.add_child(status)
	activity = Label.new()
	activity.text = "Events and inventory requests appear here."
	panel.add_child(activity)

func _add_button(parent: Node, text: String, callback: Callable, lockable := true) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	if lockable:
		buttons.append(button)

func _register_sound() -> void:
	# A looping tone makes stop_sound and stop_all_sounds audible and repeatable.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	var data := PackedByteArray()
	data.resize(44100)
	for i in 22050:
		data.encode_s16(i * 2, int(sin(TAU * 330.0 * i / 22050.0) * 3000))
	stream.data = data
	var entry := SoundEntry.new()
	entry.id = &"test_tone"
	entry.stream = stream
	_library = SoundLibrary.new()
	_library.sounds.append(entry)
	Audio.libraries.append(_library)
	Audio.reload_libraries()

func _context() -> Dictionary:
	return {"effects_parent": $Stage, "source": self, "name": "Guide", "item_object": 42}

func run_effect(command: String) -> void:
	if controller.active or manager.active:
		return
	Effects.apply_effects(command, _context())
	status.text = "Effect: " + command
	if command.begins_with("flag."):
		activity.text = "Narrative.flags.dialogue_test = %s" % Narrative.flags.get("dialogue_test")

func run_all_effects() -> void:
	if Narrative.is_busy() or _running_all or controller.active:
		return
	reset_demo()
	_running_all = true
	Narrative.interaction_locked = true
	_set_buttons_disabled(true)
	var run_id := _run
	for command in COMMANDS:
		run_effect(command)
		await get_tree().create_timer(1.15).timeout
		if run_id != _run:
			return
	_running_all = false
	Narrative.interaction_locked = _previous_lock
	_set_buttons_disabled(false)
	status.text = "All %d effect cases completed. Inspect the result or Reset to repeat." % COMMANDS.size()

func play_cutscene() -> void:
	if Narrative.is_busy() or controller.active or _running_all:
		return
	reset_demo()
	controller.play_cutscene(&"cutscene", false)

func _cutscene_started() -> void:
	Narrative.interaction_locked = true
	player.enter_cutscene_mode()
	_set_buttons_disabled(true)
	status.text = "Cutscene: guide walks, pauses for dialogue, opens gate, then walks through."

func _cutscene_finished() -> void:
	Narrative.interaction_locked = _previous_lock
	player.exit_cutscene_mode()
	_set_buttons_disabled(manager.active)
	status.text = "Cutscene finished. Player control restored."

func _dialogue_opened() -> void:
	_dialogue_state = RuntimeState.current_game_state
	RuntimeState.current_game_state = RuntimeState.GameState.INTERACTING
	_set_buttons_disabled(true)

func _dialogue_closed() -> void:
	RuntimeState.current_game_state = _dialogue_state
	_set_buttons_disabled(controller.active or _running_all)

func _set_buttons_disabled(value: bool) -> void:
	for button in buttons:
		button.disabled = value

func _item_requested(id: int) -> void:
	_items.append(id)
	activity.text = "Inventory signal received: %s (demo only)" % str(_items)

func _event_requested(event_name: StringName, _context_data: Dictionary) -> void:
	activity.text = "Event received: " + str(event_name)

func _swap_requested(from: String, to: String) -> void:
	$Stage/Artifact.color = Color(0.6, 0.35, 1)
	activity.text = "Swap signal received: %s → %s (artifact recolored)" % [from, to]

func reset_demo() -> void:
	_run += 1
	_running_all = false
	controller.finish_cutscene()
	manager.stop_dialogue()
	Narrative.interaction_locked = _previous_lock
	RuntimeState.current_game_state = RuntimeState.GameState.WORLD
	player.exit_cutscene_mode()
	Effects.stop_screen_shake()
	ScreenFade.reset()
	Audio.stop_sound(&"test_tone")
	$Stage/AnimationPlayer.stop()
	$Stage/Guide.position = Vector2(300, 350)
	$Stage/Artifact.scale = Vector2.ONE
	$Stage/Artifact.color = Color(1, 0.7, 0.2)
	Effects.apply_effects("show_node:Artifact; show_node:Gate; enable_collision:Gate; lights_on", _context())
	player.position = Vector2(245, 350)
	player.facing_direction = Vector2.RIGHT
	_restore_flag()
	_items.clear()
	_set_buttons_disabled(false)
	status.text = "Stage reset. Ready."
	activity.text = "Events and inventory requests appear here."

func _restore_flag() -> void:
	if _had_flag:
		Narrative.flags["dialogue_test"] = _previous_flag
	else:
		Narrative.flags.erase("dialogue_test")

func _exit_tree() -> void:
	_run += 1
	Effects.stop_screen_shake()
	ScreenFade.reset()
	Audio.stop_sound(&"test_tone")
	Audio.libraries.erase(_library)
	Audio.reload_libraries()
	Narrative.interaction_locked = _previous_lock
	RuntimeState.current_game_state = _previous_state
	_restore_flag()
