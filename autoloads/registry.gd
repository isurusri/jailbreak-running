extends Node
## Indexes all definition .tres files by id. Adding a file = adding content.
## Must NOT hold mutable state.

var items: Dictionary[StringName, ItemData] = {}
var levels: Dictionary[StringName, LevelConfig] = {}

func _ready() -> void:
	_scan("res://data/items/", items)
	_scan("res://data/levels/", levels)

func _scan(dir_path: String, into: Dictionary) -> void:
	for file in ResourceLoader.list_directory(dir_path):
		var res := load(dir_path + file)
		if res and "id" in res:
			into[res.id] = res
