class_name CoverZone
extends Area2D
## Shadow pocket: standing here telegraphs "hidden" via EventBus.
## Pure feedback — actual detection blocking comes from geometry
## (LightOccluder2D visuals + the vision cone's line-of-sight ray).

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		EventBus.player_entered_cover.emit()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		EventBus.player_left_cover.emit()
