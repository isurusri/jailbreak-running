extends Node
## Global signal hub. Declares signals only — no state, no logic.

# Input → movement / interaction
signal move_requested(world_pos: Vector2)
signal interact_requested(target: Interactable)

# Stealth
signal player_spotted(guard: Node2D)
signal player_caught
signal player_entered_cover
signal player_left_cover

# Loot
signal contraband_collected(item: ItemData)

# Run flow
signal lockdown_tick(seconds_left: float)
signal lockdown_sealed
signal level_completed(config: LevelConfig)
signal run_failed          # caught or sealed in → loot confiscated
