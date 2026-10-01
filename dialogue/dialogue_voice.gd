extends Resource
class_name DialogueVoice

# Shared voice settings. Assign these by CSV SPEAKER in the dialogue manager.
@export var enabled := true
@export var sound: AudioStream = preload("res://dialogue/Voices/blip.wav")
@export_range(0.1, 4.0, 0.01) var pitch := 1.0
@export_range(1.0, 2.0, 0.01) var pitch_variation := 1.08
@export_range(-40.0, 6.0, 0.5) var volume_db := -12.0
# Play once per this many letters/digits. Spaces and punctuation stay silent.
@export_range(1, 10) var characters_per_sound := 2
