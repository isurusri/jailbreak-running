extends Node
## Run state machine (PLAYING / CAUGHT / ESCAPED), lockdown timer, carried loot,
## level chaining via LevelConfig.next_level.
## Must NOT touch UI nodes or actor internals.

enum RunState { PLAYING, CAUGHT, ESCAPED }

const RESTART_DELAY := 1.5              # let the caught/escaped moment land
const FALLBACK_LOCKDOWN_SECONDS := 180.0   # until LevelConfig chain (Milestone 6)

var run_state: RunState = RunState.PLAYING
var carried_loot: int = 0
var carried_ids: Array[StringName] = []
var seconds_left: float = 0.0
var current_level: LevelConfig

func _ready() -> void:
	set_process(false)
	EventBus.contraband_collected.connect(_on_contraband_collected)
	EventBus.player_caught.connect(_on_player_caught)
	EventBus.escape_reached.connect(_on_escape_reached)

## Called by the level when it is ready to play.
func start_run() -> void:
	run_state = RunState.PLAYING
	carried_loot = 0
	carried_ids.clear()
	seconds_left = current_level.lockdown_seconds if current_level \
			else FALLBACK_LOCKDOWN_SECONDS
	set_process(true)

func _process(delta: float) -> void:
	seconds_left = maxf(seconds_left - delta, 0.0)
	EventBus.lockdown_tick.emit(seconds_left)
	if seconds_left <= 0.0:
		set_process(false)
		run_state = RunState.CAUGHT   # sealed in counts as caught
		EventBus.lockdown_sealed.emit()
		_fail_run()

func _on_contraband_collected(item: ItemData) -> void:
	if run_state != RunState.PLAYING:
		return
	carried_loot += item.value
	carried_ids.append(item.id)

func _on_player_caught() -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.CAUGHT
	_fail_run()

func _on_escape_reached() -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.ESCAPED
	set_process(false)
	SaveManager.bank_loot(carried_loot, carried_ids)
	EventBus.level_completed.emit(current_level)
	_restart_soon()

func _fail_run() -> void:
	set_process(false)
	carried_loot = 0   # confiscation: the story's caught mechanic
	carried_ids.clear()
	EventBus.run_failed.emit()
	_restart_soon()

func _restart_soon() -> void:
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
