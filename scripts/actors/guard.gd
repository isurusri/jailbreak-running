class_name Guard
extends CharacterBody2D

enum State { PATROLLING, WAITING, ALERTED }
var state: State = State.PATROLLING
var _wp_index := 0

@export var data: CharacterData
@export var waypoints: Node2D   # children (Marker2D) define the patrol route, walked in order

@onready var movement: MovementComponent = $Movement
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cone: VisionCone = $VisionCone

func _ready() -> void:
	sprite.sprite_frames = data.sprite_frames
	sprite.play(&"idle")
	movement.destination_reached.connect(_on_waypoint_reached)
	movement.moving.connect(_update_facing)
	cone.target_spotted.connect(_on_target_spotted)
	_start_patrol()

func _start_patrol() -> void:
	# The level bakes its navmesh on load; wait a beat so paths exist.
	await get_tree().create_timer(0.5).timeout
	if state != State.ALERTED:
		_go_to_next_waypoint()

func _go_to_next_waypoint() -> void:
	if waypoints == null or waypoints.get_child_count() == 0:
		return
	state = State.PATROLLING
	sprite.play(&"walk")
	var wp := waypoints.get_child(_wp_index) as Node2D
	_wp_index = (_wp_index + 1) % waypoints.get_child_count()
	movement.move_to(wp.global_position)

func _on_waypoint_reached() -> void:
	if state == State.ALERTED:
		return
	state = State.WAITING
	sprite.play(&"idle")
	await get_tree().create_timer(data.patrol_wait_time).timeout
	if state == State.WAITING:
		_go_to_next_waypoint()

func _update_facing(vel: Vector2) -> void:
	if vel.length_squared() > 1.0:
		cone.rotation = vel.angle()
		if absf(vel.x) > 0.01:
			sprite.flip_h = vel.x < 0.0

func _on_target_spotted(_target: Node2D) -> void:
	if state == State.ALERTED:
		return
	state = State.ALERTED
	movement.stop()
	EventBus.player_spotted.emit(self)
	EventBus.player_caught.emit()
