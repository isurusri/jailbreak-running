class_name ItemData
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
@export var value: int = 10          # retirement-fund credits
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var flavor_text: String = ""
