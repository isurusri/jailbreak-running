extends Node
## Run state machine (PLAYING / CAUGHT / ESCAPED), lockdown timer, carried loot,
## level chaining via LevelConfig.next_level.
## Must NOT touch UI nodes, actor internals, or the scene tree — it emits
## facts on EventBus; Main owns level swaps.

enum RunState { PLAYING, CAUGHT, ESCAPED }

const FALLBACK_LOCKDOWN_SECONDS := 180.0   # when a level runs without a config

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
	if current_level:
		var run_seconds := current_level.lockdown_seconds - seconds_left
		SaveManager.record_best_time(String(current_level.id), run_seconds)
		if current_level.next_level:
			SaveManager.set_unlocked_level(String(current_level.next_level.id))
	SaveManager.bank_loot(carried_loot, carried_ids)
	EventBus.level_completed.emit(current_level)

func _fail_run() -> void:
	set_process(false)
	carried_loot = 0   # confiscation: the story's caught mechanic
	carried_ids.clear()
	EventBus.run_failed.emit()
