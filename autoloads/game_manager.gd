extends Node
## Run state machine (PLAYING / CAUGHT / ESCAPED), lockdown timer, carried loot,
## level chaining via LevelConfig.next_level.
## Must NOT touch UI nodes or actor internals.

enum RunState { PLAYING, CAUGHT, ESCAPED }

const RESTART_DELAY := 1.5   # seconds to let the caught moment land

var run_state: RunState = RunState.PLAYING
var carried_loot: int = 0
var seconds_left: float = 0.0
var current_level: LevelConfig

func _ready() -> void:
	EventBus.contraband_collected.connect(_on_contraband_collected)
	EventBus.player_caught.connect(_on_player_caught)

func _on_contraband_collected(item: ItemData) -> void:
	if run_state != RunState.PLAYING:
		return
	carried_loot += item.value

func _on_player_caught() -> void:
	if run_state == RunState.CAUGHT:
		return
	run_state = RunState.CAUGHT
	carried_loot = 0   # confiscation: the story's caught mechanic
	EventBus.run_failed.emit()
	await get_tree().create_timer(RESTART_DELAY).timeout
	run_state = RunState.PLAYING
	get_tree().reload_current_scene()
