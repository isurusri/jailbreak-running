class_name InputHandler
extends Node2D
## Translates clicks/taps into world-space move requests. Knows nothing about the player.

func _unhandled_input(event: InputEvent) -> void:
	var pressed_at := Vector2.INF
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed_at = event.position

	if pressed_at != Vector2.INF:
		var world_pos := get_canvas_transform().affine_inverse() * pressed_at
		EventBus.move_requested.emit(world_pos)
		get_viewport().set_input_as_handled()
