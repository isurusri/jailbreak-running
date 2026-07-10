extends Node
## Root scene: instantiates the current level from its LevelConfig and swaps
## levels in response to EventBus facts. Retry on fail, results -> next on
## escape. Knows nothing about gameplay beyond LevelConfig.

const RETRY_DELAY := 1.5
const RESULTS_SCENE := preload("res://scenes/ui/results.tscn")
const FALLBACK_LEVEL_SCENE := "res://scenes/levels/test_level.tscn"

var _level: Node = null

func _ready() -> void:
	EventBus.run_failed.connect(_on_run_failed)
	EventBus.level_completed.connect(_on_level_completed)
	var start_id := StringName(str(SaveManager.profile.unlocked_level))
	var config: LevelConfig = Registry.levels.get(start_id)
	if config == null and not Registry.levels.is_empty():
		config = Registry.levels.values()[0]
	_load_level(config)

func _load_level(config: LevelConfig) -> void:
	if _level:
		_level.free()
	GameManager.current_level = config
	var scene_path := config.scene_path if config else FALLBACK_LEVEL_SCENE
	var packed: PackedScene = load(scene_path)
	_level = packed.instantiate()
	add_child(_level)

func _on_run_failed() -> void:
	await get_tree().create_timer(RETRY_DELAY).timeout
	_load_level(GameManager.current_level)   # same level, fresh run

func _on_level_completed(config: LevelConfig) -> void:
	var results: CanvasLayer = RESULTS_SCENE.instantiate()
	add_child(results)
	get_tree().paused = true
	results.continue_pressed.connect(func():
		get_tree().paused = false
		results.queue_free()
		var next: LevelConfig = config.next_level if config else null
		_load_level(next if next else config)   # no next yet: replay the last level
	)
