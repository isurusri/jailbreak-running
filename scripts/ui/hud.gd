extends CanvasLayer
## In-run HUD: carried loot, lockdown countdown, status flashes.
## Reads EventBus + GameManager only — never touches gameplay nodes.

const LOW_TIME_SECONDS := 30.0

@onready var loot_label: Label = %LootLabel
@onready var timer_label: Label = %TimerLabel
@onready var status_label: Label = %StatusLabel
@onready var cover_label: Label = %CoverLabel

func _ready() -> void:
	EventBus.contraband_collected.connect(_on_contraband_collected)
	EventBus.lockdown_tick.connect(_on_lockdown_tick)
	EventBus.player_caught.connect(func(): _flash("CAUGHT! CONTRABAND CONFISCATED"))
	EventBus.lockdown_sealed.connect(func(): _flash("LOCKDOWN. SEALED IN."))
	EventBus.level_completed.connect(func(_c): _flash("ESCAPED WITH THE GOODS"))
	EventBus.player_entered_cover.connect(func(): cover_label.visible = true)
	EventBus.player_left_cover.connect(func(): cover_label.visible = false)
	# Children ready before parents: the level's start_run() hasn't reset
	# GameManager yet, so defer the first read past the full tree setup.
	_update_loot.call_deferred()

func _on_contraband_collected(_item: ItemData) -> void:
	_update_loot()

func _update_loot() -> void:
	loot_label.text = "LOOT %d" % GameManager.carried_loot

func _on_lockdown_tick(seconds_left: float) -> void:
	var total := int(ceilf(seconds_left))
	@warning_ignore("integer_division")
	timer_label.text = "%d:%02d" % [total / 60, total % 60]
	timer_label.self_modulate = Color(1.0, 0.35, 0.35) \
			if seconds_left < LOW_TIME_SECONDS else Color.WHITE

func _flash(message: String) -> void:
	status_label.text = message
	status_label.visible = true
