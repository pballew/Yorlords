## TurnManager.gd
## Manages turn order and the flow of each player's turn.
## Turn structure mirrors Warlords II:
##   1. Collect income for all owned cities.
##   2. Advance city production queues (new units spawned if complete).
##   3. Reset movement for all armies.
##   4. Offer hero hire (if available at cities).
##   5. Player acts: move armies, set production, end turn.
##   6. Advance to next living player.
class_name TurnManager
extends RefCounted

signal turn_started(player_id: int, turn_number: int)
signal turn_ended(player_id: int)
signal round_completed(round_number: int)
signal game_over(winner_id: int)

# ---------------------------------------------------------------------------
# State (managed by GameManager)
# ---------------------------------------------------------------------------

var current_player_index: int = 0
var turn_number: int = 1   ## Full round count
var active_player_id: int = 0

# ---------------------------------------------------------------------------
# Reference to shared game state (set by GameManager)
# ---------------------------------------------------------------------------

var players: Array[Player] = []
var cities: Array[City] = []
var armies: Array[Army] = []

# ---------------------------------------------------------------------------
# Turn flow
# ---------------------------------------------------------------------------

## Call this to begin the game (sets up first turn).
func start_game() -> void:
	current_player_index = 0
	turn_number = 1
	active_player_id = players[0].player_id
	_begin_turn()

## Called when the active player clicks "End Turn".
func end_turn() -> void:
	emit_signal("turn_ended", active_player_id)

	# Advance to next living player
	var start_index: int = current_player_index
	var advanced: bool = false
	for _i in range(players.size()):
		current_player_index = (current_player_index + 1) % players.size()
		if not players[current_player_index].is_eliminated:
			advanced = true
			break

	if not advanced:
		# Everyone else is eliminated - should not happen, game should have ended
		return

	# Check if we completed a full round
	if current_player_index <= start_index:
		turn_number += 1
		emit_signal("round_completed", turn_number - 1)

	active_player_id = players[current_player_index].player_id
	_begin_turn()

## Called at the start of a player's turn.
func _begin_turn() -> void:
	var player: Player = players[current_player_index]

	# 1. Collect income
	_collect_income(player)

	# 2. Advance production
	_advance_production(player)

	# 3. Reset army movement
	_reset_armies(player)

	# 4. Check victory
	if _check_victory():
		return

	emit_signal("turn_started", active_player_id, turn_number)

## Collect gold from all owned cities.
func _collect_income(player: Player) -> void:
	for city_id in player.city_ids:
		var city := _find_city(city_id)
		if city:
			player.add_gold(city.get_income())

## Advance production in all owned cities; spawn new units.
func _advance_production(player: Player) -> void:
	for city_id in player.city_ids:
		var city := _find_city(city_id)
		if city and city.is_producing():
			var new_unit := city.advance_production(player.race)
			if new_unit:
				new_unit.owner_id = player.player_id
				# Try to place in an army at the city, or create a new army
				_spawn_unit_at_city(new_unit, city, player)

## Place a newly produced unit at a city.
func _spawn_unit_at_city(unit: Unit, city: City, player: Player) -> void:
	# Look for an existing army at this city position owned by this player
	for army in armies:
		if army.owner_id == player.player_id and army.grid_position == city.grid_position and not army.is_full():
			army.add_unit(unit)
			return
	# Create new army
	var new_army := Army.new()
	new_army.army_id = _next_army_id()
	new_army.owner_id = player.player_id
	new_army.grid_position = city.grid_position
	new_army.add_unit(unit)
	armies.append(new_army)
	player.army_ids.append(new_army.army_id)

## Reset movement points for all armies owned by the active player.
func _reset_armies(player: Player) -> void:
	for army_id in player.army_ids:
		var army := _find_army(army_id)
		if army:
			army.reset_movement()

## Returns true if the game is over.
func _check_victory() -> bool:
	var alive_players: Array[Player] = players.filter(func(p: Player) -> bool: return not p.is_eliminated)
	if alive_players.size() == 1:
		emit_signal("game_over", alive_players[0].player_id)
		return true
	# Check if a player has no cities AND no armies -> eliminate them
	for p in players:
		if not p.is_eliminated and p.city_ids.is_empty() and p.army_ids.is_empty():
			p.eliminate()
	alive_players = players.filter(func(p: Player) -> bool: return not p.is_eliminated)
	if alive_players.size() == 1:
		emit_signal("game_over", alive_players[0].player_id)
		return true
	return false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _find_city(id: int) -> City:
	for c in cities:
		if c.city_id == id:
			return c
	return null

func _find_army(id: int) -> Army:
	for a in armies:
		if a.army_id == id:
			return a
	return null

func _next_army_id() -> int:
	var max_id: int = -1
	for a in armies:
		if a.army_id > max_id:
			max_id = a.army_id
	return max_id + 1

func get_active_player() -> Player:
	if current_player_index < players.size():
		return players[current_player_index]
	return null
