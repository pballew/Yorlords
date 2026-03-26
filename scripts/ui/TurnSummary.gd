## TurnSummary.gd
## Brief pop-up shown at the start of each player's turn summarising
## income collected and units produced.
extends CanvasLayer

@onready var title_label: Label = $TurnSummaryContainer/TitleLabel
@onready var summary_label: Label = $TurnSummaryContainer/SummaryLabel
@onready var ok_button: Button = $TurnSummaryContainer/OKButton

func _ready() -> void:
	hide()

func show_summary(title: String, player: Player) -> void:
	show()
	title_label.text = title
	if player:
		title_label.modulate = player.color
		var city_count: int = player.city_ids.size()
		var army_count: int = player.army_ids.size()
		summary_label.text = (
			"Cities: %d\n"
			+ "Armies: %d\n"
			+ "Gold: %d\n\n"
			+ "Tap OK or press E to begin your turn."
		) % [city_count, army_count, player.gold]

func _on_ok_pressed() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("end_turn"):
		hide()
