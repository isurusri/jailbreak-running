extends Node
## Run state machine (PLAYING / CAUGHT / ESCAPED), lockdown timer, carried loot,
## level chaining via LevelConfig.next_level. Milestone 1 stub — state only.
## Must NOT touch UI nodes or actor internals.

enum RunState { PLAYING, CAUGHT, ESCAPED }

var run_state: RunState = RunState.PLAYING
var carried_loot: int = 0
var seconds_left: float = 0.0
var current_level: LevelConfig
