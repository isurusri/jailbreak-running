class_name Player
extends CharacterBody2D

enum State { IDLE, WALKING, INTERACTING, CAUGHT }
var state: State = State.IDLE

@export var data: CharacterData
@onready var movement: MovementComponent = $Movement
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.sprite_frames = data.sprite_frames
	EventBus.move_requested.connect(_on_move_requested)
	EventBus.player_caught.connect(func(): _enter_state(State.CAUGHT))
	movement.destination_reached.connect(func(): _enter_state(State.IDLE))
	movement.moving.connect(_update_facing)
	sprite.play(&"idle")

func _on_move_requested(world_pos: Vector2) -> void:
	if state == State.CAUGHT or state == State.INTERACTING:
		return
	movement.move_to(world_pos)   # re-clicking mid-walk just retargets: Slick darts
	_enter_state(State.WALKING)

func _enter_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	match state:
		State.IDLE:
			sprite.play(&"idle")
		State.WALKING:
			sprite.play(&"walk")
		State.CAUGHT:
			movement.stop()
			sprite.play(&"caught")

func _update_facing(vel: Vector2) -> void:
	if absf(vel.x) > 0.01:
		sprite.flip_h = vel.x < 0.0
