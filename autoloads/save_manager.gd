extends Node
## Persistence: user://save.json with version migration. JSON, never .tres
## (loading .tres from user:// can execute embedded scripts).
## Must NOT know about gameplay rules.

const SAVE_PATH := "user://save.json"
const CURRENT_VERSION := 1

var profile := {
	"version": 1,
	"unlocked_level": "level_01_deep_blocks",
	"banked_loot": 0,                 # value extracted on successful escapes
	"best_times": {},                 # level_id -> seconds
	"collected_ids": [],              # ItemData ids ever collected (for a "ledger" UI)
	"settings": {"sfx": 1.0, "music": 1.0},
}

func _ready() -> void:
	load_profile()

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(profile, "\t"))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		profile = _migrate(parsed)

func bank_loot(amount: int, ids: Array[StringName]) -> void:
	profile.banked_loot += amount
	for id in ids:
		if not profile.collected_ids.has(String(id)):
			profile.collected_ids.append(String(id))
	save()

func _migrate(data: Dictionary) -> Dictionary:
	var v: int = data.get("version", 0)
	while v < CURRENT_VERSION:
		match v:
			0: data["banked_loot"] = data.get("banked_loot", 0)
			# 1: data["upgrades"] = []          # future: meta-progression
			# 2: data["achievements"] = {}      # future: achievements
		v += 1
		data["version"] = v
	return data
