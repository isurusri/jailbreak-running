extends Node2D
## Gray-box test level. Bakes the navmesh from obstacle colliders at load so
## the authored rectangle gets carved around StaticBody2D obstacles.
## Authored levels should bake in-editor instead and drop this script.

@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

func _ready() -> void:
	var poly := nav_region.navigation_polygon
	poly.agent_radius = 14.0   # matches the player's collision radius
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.bake_navigation_polygon()
