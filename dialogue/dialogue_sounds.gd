class_name DialogueSounds
extends AudioStreamPlayer
# Character playback is driven by the dialogue typewriter, never a second timer.
var main_pitch_scale := 1.0
var random_pitch := 1.08

func set_sub_stream(sound: AudioStream) -> void:
	stream = sound

func stop_saying() -> void:
	stop()

func play_character(_character: String) -> void:
	if stream == null:
		return
	var variation := maxf(random_pitch, 1.0)
	pitch_scale = maxf(0.01, main_pitch_scale * randf_range(1.0 / variation, variation))
	play()
