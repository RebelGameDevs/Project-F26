extends Node

const Library = preload("res://Sounds/sound_library.gd")
@export var libraries: Array[Library] = []
@export_range(1, 128) var max_voices := 32

var _sounds: Dictionary = {}
var _voices: Dictionary = {}
var _next_handle := 1

func _ready() -> void:
	reload_libraries()

func reload_libraries() -> void:
	_sounds.clear()
	for library in libraries:
		if library == null:
			continue
		for entry in library.sounds:
			if entry == null or entry.id == &"" or entry.stream == null:
				push_warning("Audio library contains an empty sound entry.")
				continue
			if _sounds.has(entry.id):
				push_warning("Duplicate sound ID '%s'; keeping the first entry." % entry.id)
				continue
			_sounds[entry.id] = entry

func has_sound(id: StringName) -> bool:
	return _sounds.has(id)

# Returns a playback handle, or -1 for an unknown sound.
func play(id: StringName, volume_offset_db: float = 0.0, pitch_multiplier: float = 1.0) -> int:
	if not has_sound(id):
		push_warning("Unknown sound ID: %s" % id)
		return -1
	if _voices.size() >= maxi(max_voices, 1):
		stop(_voices.keys()[0])
	var entry = _sounds[id]
	var voice := AudioStreamPlayer.new()
	voice.stream = entry.stream
	voice.bus = entry.bus
	voice.volume_db = entry.volume_db + volume_offset_db
	voice.pitch_scale = maxf(0.01, entry.pitch_scale * pitch_multiplier)
	add_child(voice)
	var handle := _next_handle
	_next_handle += 1
	_voices[handle] = {"id": id, "player": voice}
	voice.finished.connect(stop.bind(handle))
	voice.play()
	return handle

func stop(handle: int) -> void:
	if not _voices.has(handle):
		return
	var voice: AudioStreamPlayer = _voices[handle]["player"]
	_voices.erase(handle)
	voice.stop()
	voice.queue_free()

func stop_sound(id: StringName) -> void:
	for handle in _voices.keys():
		if _voices[handle]["id"] == id:
			stop(handle)

func stop_all() -> void:
	for handle in _voices.keys():
		stop(handle)
