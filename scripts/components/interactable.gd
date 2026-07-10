class_name Interactable
extends Area2D
## "Walk here, then interact." Subclass or connect to `interacted` for behavior.
## Clicks are routed here by InputHandler (via point query) -> EventBus.
## interact_requested -> the player walks within interact_radius and emits
## `interacted`. Needs a CollisionShape2D so the point query can find it.

signal interacted(by: Node2D)

@export var interact_radius: float = 24.0
@export var hold_seconds: float = 0.0      # 0 = instant; >0 = lockpick-style hold
