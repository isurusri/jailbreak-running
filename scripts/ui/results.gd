extends CanvasLayer
## Post-escape results: haul vs par, banked total, best time.
## Reads EventBus + GameManager/SaveManager only. Shown paused.

signal continue_pressed

@onready var title_label: Label = %TitleLabel
@onready var haul_label: Label = %HaulLabel
@onready var par_label: Label = %ParLabel
@onready var banked_label: Label = %BankedLabel
@onready var time_label: Label = %TimeLabel
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
	var config := GameManager.current_level
	var haul := GameManager.carried_loot
	var par := config.par_loot_value if config else 0
	title_label.text = "ESCAPED RICH" if haul >= par else "OUT... BUT BROKE"
	haul_label.text = "THE HAUL      %d" % haul
	par_label.text = "THE PLAN      %d" % par
	banked_label.text = "RETIREMENT FUND  %d" % SaveManager.profile.banked_loot
	var best: float = SaveManager.profile.best_times.get(
			String(config.id) if config else "", 0.0)
	time_label.text = "BEST TIME     %d:%02d" % [int(best) / 60, int(best) % 60]
	continue_button.pressed.connect(func(): continue_pressed.emit())
	continue_button.grab_focus()
