## HUD.gd
## Heads-up display: shows current player info, turn, gold, and End Turn button.
extends CanvasLayer

@onready var player_label: Label = $HUDPanel/PlayerLabel
@onready var gold_label: Label = $HUDPanel/GoldLabel
@onready var turn_label: Label = $HUDPanel/TurnLabel
@onready var message_label: Label = $HUDPanel/MessageLabel
@onready var end_turn_button: Button = $HUDPanel/EndTurnButton

var _message_timer: float = 0.0
const MESSAGE_DURATION: float = 3.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""

func update_status(player: Player, turn_number: int) -> void:
	player_label.text = "%s  [%s]" % [player.player_name, GameData.get_race_name(player.race)]
	player_label.modulate = player.color
	gold_label.text = "Gold: %d" % player.gold
	turn_label.text = "Round %d" % turn_number
	end_turn_button.disabled = (player.player_id != GameManager.local_player_id)

func show_message(msg: String) -> void:
	message_label.text = msg
	_message_timer = MESSAGE_DURATION
