class_name ExitDoor
extends Interactable
## The way out. Click -> walk over -> escape with everything you carry.

func _ready() -> void:
	interacted.connect(_on_interacted)

func _on_interacted(_by: Node2D) -> void:
	EventBus.escape_reached.emit()
