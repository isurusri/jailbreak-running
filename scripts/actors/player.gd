class_name Player
extends CharacterBody2D

enum State { IDLE, WALKING, INTERACTING, CAUGHT }
var state: State = State.IDLE

@export var data: CharacterData
@onready var movement: MovementComponent = $Movement
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _interact_target: Interactable = null

func _ready() -> void:
	sprite.sprite_frames = data.sprite_frames
	EventBus.move_requested.connect(_on_move_requested)
	EventBus.interact_requested.connect(_on_interact_requested)
	EventBus.player_caught.connect(func(): _enter_state(State.CAUGHT))
	movement.destination_reached.connect(_on_destination_reached)
	movement.moving.connect(_update_facing)
	sprite.play(&"idle")

func _on_move_requested(world_pos: Vector2) -> void:
	if state == State.CAUGHT or state == State.INTERACTING:
		return
	_interact_target = null
	movement.move_to(world_pos)   # re-clicking mid-walk just retargets: Slick darts
	_enter_state(State.WALKING)

func _on_interact_requested(target: Interactable) -> void:
	if state == State.CAUGHT or state == State.INTERACTING:
		return
	_interact_target = target
	movement.move_to(target.global_position)
	_enter_state(State.WALKING)

func _on_destination_reached() -> void:
	var target := _interact_target
	_interact_target = null
	if target and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) \
			<= target.interact_radius + 24.0:
		_interact(target)
	else:
		_enter_state(State.IDLE)

func _interact(target: Interactable) -> void:
	_enter_state(State.INTERACTING)
	if target.hold_seconds > 0.0:
		await get_tree().create_timer(target.hold_seconds).timeout
		if state != State.INTERACTING:   # caught mid-hold
			return
	target.interacted.emit(self)
	if state == State.INTERACTING:
		_enter_state(State.IDLE)

func _enter_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	match state:
		State.IDLE:
			sprite.play(&"idle")
		State.WALKING:
			sprite.play(&"walk")
		State.INTERACTING:
			sprite.play(&"idle")
		State.CAUGHT:
			movement.stop()
			sprite.play(&"caught")

func _update_facing(vel: Vector2) -> void:
	if absf(vel.x) > 0.01:
		sprite.flip_h = vel.x < 0.0
