class_name Pickup
extends Interactable
## Contraband on the ground. Click -> walk over -> collect.
## Visual comes from the ItemData: swapping the .tres swaps the sprite.

@export var item: ItemData

func _ready() -> void:
	if item and has_node("Sprite2D"):
		$Sprite2D.texture = item.icon
	interacted.connect(_on_interacted)

func _on_interacted(_by: Node2D) -> void:
	EventBus.contraband_collected.emit(item)
	queue_free()
