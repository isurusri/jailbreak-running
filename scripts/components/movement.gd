class_name MovementComponent
extends Node
## Drives a CharacterBody2D along a NavigationAgent2D path. Reusable by player and guards.

signal destination_reached
signal moving(velocity: Vector2)   # for animation

@export var body: CharacterBody2D
@export var agent: NavigationAgent2D
@export var data: CharacterData    # speed comes from data, not code

func _ready() -> void:
	set_physics_process(false)     # idle components cost nothing

func move_to(world_pos: Vector2) -> void:
	agent.target_position = world_pos   # NavigationServer computes the path
	set_physics_process(true)

func stop() -> void:
	body.velocity = Vector2.ZERO
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if agent.is_navigation_finished():
		stop()
		destination_reached.emit()
		return
	var next := agent.get_next_path_position()   # the "breadcrumb"
	body.velocity = body.global_position.direction_to(next) * data.move_speed
	body.move_and_slide()
	moving.emit(body.velocity)
