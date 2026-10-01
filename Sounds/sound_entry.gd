extends Resource
class_name SoundEntry

@export var id: StringName
@export var stream: AudioStream
@export var bus: StringName = &"Master"
@export_range(-80.0, 24.0) var volume_db := 0.0
@export_range(0.01, 4.0) var pitch_scale := 1.0
