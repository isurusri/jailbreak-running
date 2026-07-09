class_name LevelConfig
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String
@export var lockdown_seconds: float = 180.0
@export var par_loot_value: int = 100        # "escape rich" threshold
@export var next_level: LevelConfig          # chain: Deep Blocks -> ... -> Warden's Office
