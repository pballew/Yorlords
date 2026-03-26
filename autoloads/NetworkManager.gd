## NetworkManager.gd  (Autoload singleton)
## Handles ENet multiplayer: hosting a game, joining a game,
## and synchronising game state between host and clients.
##
## Architecture:
##   - Host = server + player 1 (peer ID 1).
##   - Clients connect and get a unique peer ID.
##   - All game logic runs on the host; clients send actions via RPC.
##   - After every action the host broadcasts the full state to all clients.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal connected_to_host()
signal lobby_updated(lobby_info: Array[Dictionary])
signal game_started()

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var is_host: bool = false
var local_peer_id: int = 1
var lobby_players: Array[Dictionary] = []  ## [{ peer_id, name, race, ready }]

const MAX_PLAYERS: int = GameData.MAX_PLAYERS
const DEFAULT_PORT: int = GameData.DEFAULT_PORT

# ---------------------------------------------------------------------------
# Hosting
# ---------------------------------------------------------------------------

## Start as host. Returns OK or an error code.
func host_game(player_name: String, race: GameData.Race, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		push_error("NetworkManager: Failed to create server: " + str(err))
		return err

	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Add self to lobby
	lobby_players.clear()
	lobby_players.append({
		"peer_id": 1,
		"player_name": player_name,
		"race": race,
		"ready": true,
		"player_id": 0,
	})
	emit_signal("lobby_updated", lobby_players)
	return OK

# ---------------------------------------------------------------------------
# Joining
# ---------------------------------------------------------------------------

## Connect to a host. Returns OK or an error code.
func join_game(player_name: String, race: GameData.Race, host_ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(host_ip, port)
	if err != OK:
		push_error("NetworkManager: Failed to connect: " + str(err))
		return err

	multiplayer.multiplayer_peer = peer
	is_host = false

	multiplayer.connected_to_server.connect(_on_connected_to_server.bind(player_name, race))
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK

# ---------------------------------------------------------------------------
# Lobby management (host only)
# ---------------------------------------------------------------------------

## Host: broadcast updated lobby info to all peers.
func _broadcast_lobby() -> void:
	if not is_host:
		return
	receive_lobby_update.rpc(lobby_players)

## Host: kick off the game once all players are ready.
func start_game_from_lobby() -> void:
	if not is_host:
		return
	# Assign sequential player IDs
	for i in range(lobby_players.size()):
		lobby_players[i]["player_id"] = i

	# Build player configs list
	var configs: Array[Dictionary] = []
	for lp in lobby_players:
		configs.append({
			"player_id": lp["player_id"],
			"player_name": lp["player_name"],
			"race": lp["race"],
			"peer_id": lp["peer_id"],
		})

	# Tell all clients to transition to the game
	_notify_game_start.rpc(configs)

## Client: tell the host our details.
@rpc("any_peer", "call_remote", "reliable")
func register_with_host(player_name: String, race: GameData.Race) -> void:
	if not is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	lobby_players.append({
		"peer_id": sender_id,
		"player_name": player_name,
		"race": race,
		"ready": true,
		"player_id": lobby_players.size(),
	})
	emit_signal("player_connected", sender_id, player_name)
	_broadcast_lobby()

# ---------------------------------------------------------------------------
# Game state sync
# ---------------------------------------------------------------------------

## Host: send full game state to all clients after every action.
func sync_state() -> void:
	if not is_host:
		return
	var state: Dictionary = GameManager.serialize_state()
	receive_state.rpc(state)

## Host -> All: receive serialised game state.
@rpc("authority", "call_local", "reliable")
func receive_state(state: Dictionary) -> void:
	if not is_host:
		GameManager.load_state(state)

## Client -> Host: request a move.
@rpc("any_peer", "call_remote", "reliable")
func request_move(army_id: int, target_pos_x: int, target_pos_y: int) -> void:
	if not is_host:
		return
	# Validate sender owns the army
	var sender_id: int = multiplayer.get_remote_sender_id()
	var army := GameManager.find_army(army_id)
	if army == null:
		return
	var player := GameManager.find_player(army.owner_id)
	if player == null or player.peer_id != sender_id:
		return
	if GameManager.get_active_player_id() != army.owner_id:
		return

	var target := Vector2i(target_pos_x, target_pos_y)
	GameManager.selected_army_id = army_id
	GameManager.move_selected_army(target)
	sync_state()

## Client -> Host: request end of turn.
@rpc("any_peer", "call_remote", "reliable")
func request_end_turn() -> void:
	if not is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var active_player := GameManager.get_active_player()
	if active_player == null or active_player.peer_id != sender_id:
		return
	GameManager.end_turn()
	sync_state()

## Client -> Host: set city production.
@rpc("any_peer", "call_remote", "reliable")
func request_set_production(city_id: int, unit_type: int) -> void:
	if not is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var city := GameManager.find_city(city_id)
	if city == null:
		return
	var player := GameManager.find_player(city.owner_id)
	if player == null or player.peer_id != sender_id:
		return
	if GameManager.get_active_player_id() != city.owner_id:
		return
	GameManager.set_city_production(city_id, unit_type as GameData.UnitType)
	sync_state()

# ---------------------------------------------------------------------------
# RPCs received by clients
# ---------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func receive_lobby_update(players_info: Array) -> void:
	lobby_players = players_info
	emit_signal("lobby_updated", lobby_players)

@rpc("authority", "call_local", "reliable")
func _notify_game_start(configs: Array) -> void:
	# Determine local player_id from our peer ID
	var my_peer: int = multiplayer.get_unique_id()
	for cfg in configs:
		if cfg["peer_id"] == my_peer:
			GameManager.local_player_id = cfg["player_id"]
			break

	if is_host:
		GameManager.start_new_game(configs)
	emit_signal("game_started")

# ---------------------------------------------------------------------------
# Connection callbacks
# ---------------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	print("NetworkManager: Peer connected: ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("NetworkManager: Peer disconnected: ", peer_id)
	# Remove from lobby
	for i in range(lobby_players.size()):
		if lobby_players[i]["peer_id"] == peer_id:
			lobby_players.remove_at(i)
			break
	emit_signal("player_disconnected", peer_id)
	if is_host:
		_broadcast_lobby()

func _on_connected_to_server(player_name: String, race: GameData.Race) -> void:
	local_peer_id = multiplayer.get_unique_id()
	emit_signal("connected_to_host")
	# Register with the host
	register_with_host.rpc_id(1, player_name, race)

func _on_connection_failed() -> void:
	emit_signal("connection_failed")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	emit_signal("connection_failed")

# ---------------------------------------------------------------------------
# Helpers for local (single-machine) actions
# ---------------------------------------------------------------------------

## For the local player on the host, move an army directly.
func local_move(army_id: int, target: Vector2i) -> void:
	if is_host:
		GameManager.selected_army_id = army_id
		GameManager.move_selected_army(target)
		sync_state()
	else:
		request_move.rpc_id(1, army_id, target.x, target.y)

## For the local player, end their turn.
func local_end_turn() -> void:
	if is_host:
		GameManager.end_turn()
		sync_state()
	else:
		request_end_turn.rpc_id(1)

## For the local player, set production.
func local_set_production(city_id: int, unit_type: GameData.UnitType) -> void:
	if is_host:
		GameManager.set_city_production(city_id, unit_type)
		sync_state()
	else:
		request_set_production.rpc_id(1, city_id, unit_type)

## Start a solo (single player) game directly.
func start_solo_game(player_name: String, race: GameData.Race) -> void:
	is_host = true
	local_peer_id = 1
	multiplayer.multiplayer_peer = null  # Offline mode

	var configs: Array[Dictionary] = [{
		"player_id": 0,
		"player_name": player_name,
		"race": race,
		"peer_id": 1,
	}]
	GameManager.local_player_id = 0
	GameManager.start_new_game(configs)
	emit_signal("game_started")
