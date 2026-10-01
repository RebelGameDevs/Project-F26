extends CanvasLayer

var _overlay: ColorRect
var _tween: Tween

func _ready() -> void:
	# World presentation is on layer 0; dialogue/HUD is on layer 2.
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fade_out(duration: float = 1.0) -> void:
	fade_to(1.0, duration)

func fade_in(duration: float = 1.0) -> void:
	fade_to(0.0, duration)

func fade_to(opacity: float, duration: float) -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_overlay.color = Color(0, 0, 0, _overlay.color.a)
	if duration <= 0.0:
		_overlay.color.a = opacity
		return
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", opacity, duration)

func flash(duration: float = 0.2) -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_overlay.color = Color.WHITE
	if duration <= 0.0:
		reset()
		return
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 0.0, duration)

# Explicitly restore the screen when starting a new scene or sequence.
func reset() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_overlay.color = Color(0, 0, 0, 0)
