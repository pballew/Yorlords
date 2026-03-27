## GameOver.gd
## Shown when the game ends, announcing the winner.
extends CanvasLayer

@onready var title_label: Label = $GameOverContainer/TitleLabel
@onready var winner_label: Label = $GameOverContainer/WinnerLabel
@onready var main_menu_button: Button = $GameOverContainer/MainMenuButton

func _ready() -> void:
	hide()

func show_winner(winner_name: String) -> void:
	show()
	title_label.text = "Victory!"
	winner_label.text = "%s has conquered the realm!" % winner_name

func _on_main_menu_pressed() -> void:
	GameManager.players.clear()
	GameManager.cities.clear()
	GameManager.armies.clear()
	GameManager.cells.clear()
	GameManager.turn_manager = null
	GameManager.phase = GameData.GamePhase.MENU
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
