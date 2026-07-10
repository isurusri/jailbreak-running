class_name VisionCone
extends Area2D
## Gameplay-truth detection: cone area + line-of-sight ray + suspicion timer.
## The visual flashlight (Milestone 4) is separate and must match this cone.
## Emits a local signal only — the owning actor decides what it means.

signal target_spotted(target: Node2D)

@export var data: CharacterData
@export var ray: RayCast2D

var _target: Node2D = null
var _suspicion := 0.0

func _ready() -> void:
	var poly := CollisionPolygon2D.new()
	poly.polygon = _build_cone_points()
	add_child(poly)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _build_cone_points() -> PackedVector2Array:
	var points: PackedVector2Array = [Vector2.ZERO]
	var half := deg_to_rad(data.vision_angle_deg) * 0.5
	const ARC_STEPS := 8
	for i in ARC_STEPS + 1:
		var angle := -half + (half * 2.0) * i / ARC_STEPS
		points.append(Vector2.from_angle(angle) * data.vision_range)
	return points

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_target = body
		_suspicion = 0.0
		set_physics_process(true)

func _on_body_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _has_line_of_sight():
		_suspicion = 0.0   # behind cover: suspicion resets
		return
	_suspicion += delta
	if _suspicion >= data.suspicion_seconds:
		set_physics_process(false)
		target_spotted.emit(_target)

func _has_line_of_sight() -> bool:
	ray.target_position = ray.to_local(_target.global_position)
	ray.force_raycast_update()
	return ray.get_collider() == _target
