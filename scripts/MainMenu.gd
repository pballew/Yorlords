## MainMenu.gd
## Entry point scene. Lets the player choose:
##   A. Single Player
##   B. Multiplayer - Host a Game
##   C. Multiplayer - Join a Game
##   D. Quit
extends Control

@onready var menu_panel: VBoxContainer = $MenuPanel
@onready var name_input: LineEdit = $SetupPanel/NameInput
@onready var race_option: OptionButton = $SetupPanel/RaceOption
@onready var setup_panel: VBoxContainer = $SetupPanel
@onready var mp_join_panel: VBoxContainer = $JoinPanel
@onready var ip_input: LineEdit = $JoinPanel/IPInput
@onready var status_label: Label = $StatusLabel

var _pending_mode: String = ""  # "solo", "host", "join"

func _ready() -> void:
	_populate_race_options()
	setup_panel.hide()
	mp_join_panel.hide()
	status_label.hide()

func _populate_race_options() -> void:
	race_option.clear()
	var races: Array = [
		GameData.Race.HUMAN,
		GameData.Race.ELF,
		GameData.Race.DWARF,
		GameData.Race.ORC,
		GameData.Race.UNDEAD,
		GameData.Race.DEMON,
	]
	for r in races:
		race_option.add_item(GameData.get_race_name(r), r)

# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

func _on_solo_pressed() -> void:
	_pending_mode = "solo"
	menu_panel.hide()
	mp_join_panel.hide()
	setup_panel.show()

func _on_host_pressed() -> void:
	_pending_mode = "host"
	menu_panel.hide()
	mp_join_panel.hide()
	setup_panel.show()

func _on_join_pressed() -> void:
	_pending_mode = "join"
	menu_panel.hide()
	setup_panel.show()
	mp_join_panel.show()

func _on_confirm_setup_pressed() -> void:
	var player_name: String = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Adventurer"
	var race_idx: int = race_option.get_selected_id()
	var race: GameData.Race = race_idx as GameData.Race

	match _pending_mode:
		"solo":
			NetworkManager.start_solo_game(player_name, race)
			get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")
		"host":
			_show_status("Starting server…")
			var err: Error = NetworkManager.host_game(player_name, race)
			if err == OK:
				get_tree().change_scene_to_file("res://scenes/LobbyMenu.tscn")
			else:
				_show_status("Failed to start server (error %d)" % err)
		"join":
			var host_ip: String = ip_input.text.strip_edges()
			if host_ip.is_empty():
				host_ip = "127.0.0.1"
			_show_status("Connecting to " + host_ip + "…")
			NetworkManager.connected_to_host.connect(_on_connected)
			NetworkManager.connection_failed.connect(_on_connection_failed)
			var err: Error = NetworkManager.join_game(player_name, race, host_ip)
			if err != OK:
				_show_status("Failed to connect (error %d)" % err)

func _on_back_pressed() -> void:
	setup_panel.hide()
	mp_join_panel.hide()
	menu_panel.show()
	status_label.hide()

func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------------------------------------------------------------------------
# Network callbacks
# ---------------------------------------------------------------------------

func _on_connected() -> void:
	get_tree().change_scene_to_file("res://scenes/LobbyMenu.tscn")

func _on_connection_failed() -> void:
	_show_status("Connection failed. Check the IP address and try again.")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _show_status(msg: String) -> void:
	status_label.text = msg
	status_label.show()
