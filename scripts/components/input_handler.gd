class_name InputHandler
extends Node2D
## Translates clicks/taps into world-space move or interact requests.
## Knows nothing about the player. Routes clicks centrally: Godot processes
## _unhandled_input BEFORE physics picking, so Interactables can't see clicks
## themselves — we point-query for them here instead.

func _unhandled_input(event: InputEvent) -> void:
	var pressed_at := Vector2.INF
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed_at = event.position

	if pressed_at == Vector2.INF:
		return

	var world_pos := get_canvas_transform().affine_inverse() * pressed_at
	var target := _interactable_at(world_pos)
	if target:
		EventBus.interact_requested.emit(target)
	else:
		EventBus.move_requested.emit(world_pos)
	get_viewport().set_input_as_handled()

func _interactable_at(world_pos: Vector2) -> Interactable:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_point(params, 4):
		if hit.collider is Interactable:
			return hit.collider
	return null
