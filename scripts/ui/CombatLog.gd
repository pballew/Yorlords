## CombatLog.gd
## Shows a scrollable combat report after a battle.
extends CanvasLayer

@onready var log_container: VBoxContainer = $CombatLogContainer/ScrollContainer/LogLines
@onready var result_label: Label = $CombatLogContainer/ResultLabel
@onready var close_button: Button = $CombatLogContainer/CloseButton

func _ready() -> void:
	hide()

func show_log(lines: Array, round_count: int = -1) -> void:
	show()
	# Clear old lines
	for child in log_container.get_children():
		child.queue_free()

	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.theme_override_font_sizes = {"font_size": 13}
		log_container.add_child(lbl)

	var rounds: int = round_count if round_count > 0 else lines.size()
	result_label.text = "Battle ended after %d rounds." % rounds

func _on_close_pressed() -> void:
	hide()
