## GameManager.gd  (Autoload singleton)
## Central game state authority. On the host this drives all logic.
## Clients receive state updates via RPC calls from NetworkManager.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal state_changed(new_state: GameData.GamePhase)
signal map_updated()
signal army_moved(army_id: int, new_pos: Vector2i)
signal combat_occurred(attacker_id: int, defender_id: int, report_log: Array, round_count: int)
signal city_captured(city_id: int, new_owner: int)
signal turn_changed(player_id: int, turn_number: int)
signal player_eliminated(player_id: int)
signal game_over(winner_id: int)
signal hero_available(city_id: int, hero_name: String, cost: int)

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------

var phase: GameData.GamePhase = GameData.GamePhase.MENU
var players: Array[Player] = []
var cells: Array[MapCell] = []        ## Flat array: index = y*MAP_WIDTH + x
var cities: Array[City] = []
var armies: Array[Army] = []
var turn_manager: TurnManager = null

var selected_army_id: int = -1        ## ID of the army the local player has selected
var local_player_id: int = -1         ## player_id of the local player
var _next_unit_id: int = 0
var _next_army_id: int = 0

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass

## Called by LobbyMenu once all players are confirmed.
func start_new_game(player_configs: Array[Dictionary], map_seed: int = 0) -> void:
	phase = GameData.GamePhase.PLAYING

	# Build player list
	players.clear()
	for cfg in player_configs:
		var p := Player.new()
		p.player_id = cfg["player_id"]
		p.player_name = cfg["player_name"]
		p.race = cfg["race"]
		p.color = GameData.RACE_DATA[cfg["race"]]["color"]
		p.peer_id = cfg.get("peer_id", 1)
		p.gold = GameData.STARTING_GOLD
		players.append(p)

	# Generate map
	var map_data: Dictionary = MapGenerator.generate(players.size(), map_seed)
	cells = map_data["cells"]
	cities = map_data["cities"]
	armies.clear()
	_next_unit_id = 0
	_next_army_id = 0

	# Assign starting cities to players and create starting armies
	for i in range(players.size()):
		var player: Player = players[i]
		# Find city assigned to this player index
		for city in cities:
			if city.owner_id == i:
				# Re-map city owner from index to player_id
				city.owner_id = player.player_id
				player.city_ids.append(city.city_id)
				# Set default production
				var buildable: Array = GameData.RACE_DATA[player.race]["buildable_units"]
				city.set_production(buildable[0])
				break

		# Create starting army
		var starting_city: City = _get_player_starting_city(player)
		if starting_city:
			var army := Army.new()
			army.army_id = _alloc_army_id()
			army.owner_id = player.player_id
			army.grid_position = starting_city.grid_position
			var start_units: Array = GameData.RACE_DATA[player.race]["starting_units"]
			for utype in start_units:
				var u := Unit.new(utype, player.player_id)
				u.unit_id = _alloc_unit_id()
				army.add_unit(u)
			armies.append(army)
			player.army_ids.append(army.army_id)
			_get_cell(starting_city.grid_position).army_id = army.army_id

	# Set up turn manager
	turn_manager = TurnManager.new()
	turn_manager.players = players
	turn_manager.cities = cities
	turn_manager.armies = armies
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.round_completed.connect(_on_round_completed)
	turn_manager.game_over.connect(_on_game_over)
	turn_manager.start_game()

	emit_signal("state_changed", phase)
	emit_signal("map_updated")

# ---------------------------------------------------------------------------
# Player actions (called by the local player; host validates and syncs)
# ---------------------------------------------------------------------------

## Select an army at a grid position (returns army or null).
func select_army_at(pos: Vector2i) -> Army:
	var cell := _get_cell(pos)
	if cell == null or cell.army_id == -1:
		selected_army_id = -1
		return null
	var army := find_army(cell.army_id)
	if army and army.owner_id == local_player_id:
		selected_army_id = army.army_id
		return army
	selected_army_id = -1
	return null

## Move the selected army to target_pos. Returns false if move is illegal.
func move_selected_army(target_pos: Vector2i) -> bool:
	if selected_army_id == -1:
		return false
	var army := find_army(selected_army_id)
	if army == null:
		return false
	if army.owner_id != local_player_id:
		return false
	return _execute_move(army, target_pos)

## Internal: validate and execute a move.
func _execute_move(army: Army, target_pos: Vector2i) -> bool:
	# Path check: direct adjacent move (one step at a time like Warlords II)
	var target_cell := _get_cell(target_pos)
	if target_cell == null or not target_cell.is_passable():
		return false

	var move_cost: int = target_cell.movement_cost()
	if army.get_move_points() < move_cost:
		return false

	# Check if there's an enemy army here - fight first
	if target_cell.has_army():
		var defender := find_army(target_cell.army_id)
		if defender and defender.owner_id != army.owner_id:
			_do_combat(army, defender, target_pos)
			# After combat, if attacker survived and there's a now-undefended city, capture it
			if not army.is_empty() and target_cell.has_city():
				var city_here := find_city_at(target_pos)
				if city_here and city_here.owner_id != army.owner_id:
					_capture_city(army, city_here)
			return true

	# Check for a city on the target tile
	if target_cell.has_city():
		var city := find_city_at(target_pos)
		if city and city.owner_id != army.owner_id:
			# Enemy or neutral city - attempt capture
			if city.garrison.is_empty():
				_capture_city(army, city)
			else:
				# Garrison defends the city
				var garrison_army := Army.new()
				garrison_army.army_id = -999  # Temporary ID for garrison battle
				garrison_army.owner_id = city.owner_id
				garrison_army.grid_position = target_pos
				garrison_army.units = city.garrison.duplicate()
				_do_combat(army, garrison_army, target_pos)
				if army.is_empty():
					return true  # Attacker was defeated
				city.clear_garrison()
				_capture_city(army, city)
			return true
		# Friendly city - fall through to regular move below

	# Regular move
	var old_cell := _get_cell(army.grid_position)
	if old_cell:
		old_cell.army_id = -1

	army.spend_move_points(move_cost)
	army.grid_position = target_pos

	# Merge with friendly army at destination if present
	if target_cell.army_id != -1:
		var other := find_army(target_cell.army_id)
		if other and other.owner_id == army.owner_id:
			_merge_armies(army, other)
			return true

	target_cell.army_id = army.army_id
	emit_signal("army_moved", army.army_id, target_pos)
	return true

func _do_combat(attacker: Army, defender: Army, at_pos: Vector2i) -> void:
	var terrain := _get_cell(at_pos).terrain
	var report := CombatResolver.resolve(attacker, defender, terrain)

	emit_signal("combat_occurred", attacker.army_id, defender.army_id, report.round_log, report.rounds)

	if report.result == GameData.CombatResult.ATTACKER_WINS:
		if not defender.is_empty():
			defender.remove_dead_units()
		if defender.is_empty():
			_remove_army(defender)
		# Move attacker to target
		var old_cell := _get_cell(attacker.grid_position)
		if old_cell:
			old_cell.army_id = -1
		attacker.spend_move_points(_get_cell(at_pos).movement_cost())
		attacker.grid_position = at_pos
		_get_cell(at_pos).army_id = attacker.army_id
		emit_signal("army_moved", attacker.army_id, at_pos)

		# Award hero experience
		var hero := attacker.get_hero()
		if hero:
			hero.award_experience(report.defender_losses * 3)
	elif report.result == GameData.CombatResult.DEFENDER_WINS:
		if attacker.is_empty():
			_remove_army(attacker)
	else:
		# Draw - both armies stagger back / both weakened
		if attacker.is_empty():
			_remove_army(attacker)
		if defender.is_empty():
			_remove_army(defender)

func _capture_city(army: Army, city: City) -> void:
	var old_owner: int = city.owner_id
	if old_owner != -1:
		var old_player := find_player(old_owner)
		if old_player:
			old_player.city_ids.erase(city.city_id)

	city.capture(army.owner_id)

	var new_player := find_player(army.owner_id)
	if new_player and not new_player.city_ids.has(city.city_id):
		new_player.city_ids.append(city.city_id)

	# Move army to city
	var old_cell := _get_cell(army.grid_position)
	if old_cell:
		old_cell.army_id = -1
	army.grid_position = city.grid_position
	_get_cell(city.grid_position).army_id = army.army_id
	army.spend_move_points(_get_cell(city.grid_position).movement_cost())

	emit_signal("city_captured", city.city_id, army.owner_id)
	emit_signal("army_moved", army.army_id, city.grid_position)

func _merge_armies(incoming: Army, resident: Army) -> void:
	# Move as many units as possible from incoming into resident
	var to_transfer: Array[Unit] = incoming.units.duplicate()
	for u in to_transfer:
		if not resident.is_full():
			resident.add_unit(u)
			incoming.remove_unit(u)
	if incoming.is_empty():
		_remove_army(incoming)
	else:
		incoming.grid_position = resident.grid_position

func _remove_army(army: Army) -> void:
	var player := find_player(army.owner_id)
	if player:
		player.army_ids.erase(army.army_id)
	_get_cell(army.grid_position).army_id = -1
	armies.erase(army)

## Set city production (called by UI).
func set_city_production(city_id: int, unit_type: GameData.UnitType) -> bool:
	var city := find_city(city_id)
	if city == null or city.owner_id != local_player_id:
		return false
	city.set_production(unit_type)
	return true

## End the local player's turn.
func end_turn() -> void:
	if get_active_player_id() != local_player_id:
		return
	selected_army_id = -1
	if turn_manager:
		turn_manager.end_turn()

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_turn_started(player_id: int, turn_num: int) -> void:
	emit_signal("turn_changed", player_id, turn_num)

func _on_turn_ended(_player_id: int) -> void:
	pass

func _on_round_completed(_round_num: int) -> void:
	pass

func _on_game_over(winner_id: int) -> void:
	phase = GameData.GamePhase.GAME_OVER
	emit_signal("game_over", winner_id)

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func get_active_player_id() -> int:
	if turn_manager:
		var p := turn_manager.get_active_player()
		return p.player_id if p else -1
	return -1

func get_active_player() -> Player:
	if turn_manager:
		return turn_manager.get_active_player()
	return null

func find_player(id: int) -> Player:
	for p in players:
		if p.player_id == id:
			return p
	return null

func find_army(id: int) -> Army:
	for a in armies:
		if a.army_id == id:
			return a
	return null

func find_city(id: int) -> City:
	for c in cities:
		if c.city_id == id:
			return c
	return null

func find_city_at(pos: Vector2i) -> City:
	for c in cities:
		if c.grid_position == pos:
			return c
	return null

func get_armies_at(pos: Vector2i) -> Array[Army]:
	var result: Array[Army] = []
	for a in armies:
		if a.grid_position == pos:
			result.append(a)
	return result

func _get_cell(pos: Vector2i) -> MapCell:
	if pos.x < 0 or pos.x >= GameData.MAP_WIDTH or pos.y < 0 or pos.y >= GameData.MAP_HEIGHT:
		return null
	var idx: int = pos.y * GameData.MAP_WIDTH + pos.x
	if idx >= cells.size():
		return null
	return cells[idx]

func _get_player_starting_city(player: Player) -> City:
	for city_id in player.city_ids:
		var city := find_city(city_id)
		if city:
			return city
	return null

func _alloc_unit_id() -> int:
	var id: int = _next_unit_id
	_next_unit_id += 1
	return id

func _alloc_army_id() -> int:
	var id: int = _next_army_id
	_next_army_id += 1
	return id

# ---------------------------------------------------------------------------
# Full state serialization (for network sync)
# ---------------------------------------------------------------------------

func serialize_state() -> Dictionary:
	var players_data: Array = []
	for p in players:
		players_data.append(p.to_dict())
	var cities_data: Array = []
	for c in cities:
		cities_data.append(c.to_dict())
	var armies_data: Array = []
	for a in armies:
		armies_data.append(a.to_dict())
	var cells_data: Array = []
	for cell in cells:
		cells_data.append(cell.to_dict())
	return {
		"players": players_data,
		"cities": cities_data,
		"armies": armies_data,
		"cells": cells_data,
		"turn_player_index": turn_manager.current_player_index if turn_manager else 0,
		"turn_number": turn_manager.turn_number if turn_manager else 1,
	}

func load_state(data: Dictionary) -> void:
	players.clear()
	for pd in data["players"]:
		players.append(Player.from_dict(pd))
	cities.clear()
	for cd in data["cities"]:
		cities.append(City.from_dict(cd))
	armies.clear()
	for ad in data["armies"]:
		armies.append(Army.from_dict(ad))
	cells.clear()
	for ced in data["cells"]:
		cells.append(MapCell.from_dict(ced))

	if turn_manager == null:
		turn_manager = TurnManager.new()
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.turn_ended.connect(_on_turn_ended)
		turn_manager.round_completed.connect(_on_round_completed)
		turn_manager.game_over.connect(_on_game_over)

	turn_manager.players = players
	turn_manager.cities = cities
	turn_manager.armies = armies
	turn_manager.current_player_index = data["turn_player_index"]
	turn_manager.turn_number = data["turn_number"]
	if turn_manager.current_player_index < players.size():
		turn_manager.active_player_id = players[turn_manager.current_player_index].player_id

	emit_signal("map_updated")
