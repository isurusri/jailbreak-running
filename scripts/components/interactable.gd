class_name Interactable
extends Area2D
## "Walk here, then interact." Subclass or connect to `interacted` for behavior.

signal interacted(by: Node2D)

@export var interact_radius: float = 24.0
@export var hold_seconds: float = 0.0      # 0 = instant; >0 = lockpick-style hold

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)

func _on_input_event(_vp: Node, event: InputEvent, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		EventBus.interact_requested.emit(self)
		get_viewport().set_input_as_handled()
