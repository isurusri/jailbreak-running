class_name CharacterData
extends Resource

@export_group("Identity")
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames

@export_group("Movement")
@export var move_speed: float = 220.0

@export_group("Guard AI (ignored for player)")
@export var vision_range: float = 300.0
@export var vision_angle_deg: float = 45.0
@export var patrol_wait_time: float = 1.5
@export var suspicion_seconds: float = 0.4   # time in cone before caught
