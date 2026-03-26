## LobbyMenu.gd
## The lobby screen where the host waits for players and everyone picks their race.
## Options:
##   A) Start Game (host only)
##   B) Copy Invite Code (IP)
##   C) Kick Player (host only)
##   D) Back to Main Menu
extends Control

@onready var players_list: VBoxContainer = $LobbyPanel/PlayersList
@onready var start_button: Button = $LobbyPanel/StartButton
@onready var invite_label: Label = $LobbyPanel/InviteLabel
@onready var status_label: Label = $LobbyPanel/StatusLabel

func _ready() -> void:
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.game_started.connect(_on_game_started)

	start_button.visible = NetworkManager.is_host
	start_button.disabled = true

	if NetworkManager.is_host:
		# Display local IP for others to connect
		var all_addresses: Array = IP.get_local_addresses()
		var lan_addresses: Array = all_addresses.filter(
			func(a: String) -> bool: return a.begins_with("192.") or a.begins_with("10.")
		)
		var local_ip: String = lan_addresses.front() if not lan_addresses.is_empty() else "127.0.0.1"
		invite_label.text = "Your IP: " + local_ip + "  Port: " + str(GameData.DEFAULT_PORT)
	else:
		invite_label.text = "Waiting for host to start the game…"

	_refresh_list()

func _refresh_list() -> void:
	for child in players_list.get_children():
		child.queue_free()

	for lp in NetworkManager.lobby_players:
		var label := Label.new()
		label.text = "%s  [%s]%s" % [
			lp["player_name"],
			GameData.get_race_name(lp["race"]),
			"  (Host)" if lp["peer_id"] == 1 else "",
		]
		label.theme_override_font_sizes = {"font_size": 18}
		players_list.add_child(label)

	# Enable Start only when 1-4 players connected (host can start alone for solo-network test)
	if NetworkManager.is_host:
		start_button.disabled = NetworkManager.lobby_players.size() < 1

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_lobby_updated(_info: Array) -> void:
	_refresh_list()

func _on_game_started() -> void:
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func _on_start_pressed() -> void:
	if NetworkManager.is_host:
		NetworkManager.start_game_from_lobby()

func _on_back_pressed() -> void:
	NetworkManager.lobby_players.clear()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
