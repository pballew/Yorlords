## GameWorld.gd
## Main game scene that hosts the map view, HUD, and all panels.
## Coordinates input events between the map and the UI panels.
extends Node2D

# ---------------------------------------------------------------------------
# Child node references
# ---------------------------------------------------------------------------

@onready var map_view: Node2D = $MapView
@onready var hud: CanvasLayer = $HUD
@onready var city_panel: CanvasLayer = $CityPanel
@onready var unit_panel: CanvasLayer = $UnitPanel
@onready var combat_log: CanvasLayer = $CombatLog
@onready var turn_summary: CanvasLayer = $TurnSummary
@onready var game_over_panel: CanvasLayer = $GameOverPanel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _selected_army: Army = null
var _selected_city: City = null

const CELL_SIZE: int = 40  ## Pixel size of each map tile

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Connect GameManager signals
	GameManager.map_updated.connect(_on_map_updated)
	GameManager.army_moved.connect(_on_army_moved)
	GameManager.combat_occurred.connect(_on_combat_occurred)
	GameManager.city_captured.connect(_on_city_captured)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.game_over.connect(_on_game_over)

	# Hide panels
	city_panel.hide()
	unit_panel.hide()
	combat_log.hide()
	turn_summary.hide()
	game_over_panel.hide()

	# Build map visuals
	_rebuild_map()
	_update_hud()

# ---------------------------------------------------------------------------
# Map building
# ---------------------------------------------------------------------------

func _rebuild_map() -> void:
	if map_view == null:
		return
	# Clear old children except camera
	for child in map_view.get_children():
		if not child is Camera2D:
			child.queue_free()

	# Draw tiles
	for cell in GameManager.cells:
		var rect := ColorRect.new()
		rect.color = cell.get_terrain_color()
		rect.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
		rect.position = Vector2(cell.grid_position.x * CELL_SIZE, cell.grid_position.y * CELL_SIZE)
		rect.name = "Cell_%d_%d" % [cell.grid_position.x, cell.grid_position.y]
		map_view.add_child(rect)

		# Add terrain label shorthand
		if cell.terrain != GameData.Terrain.PLAINS and cell.terrain != GameData.Terrain.WATER:
			var lbl := Label.new()
			lbl.text = _terrain_char(cell.terrain)
			lbl.position = Vector2(2, 2)
			lbl.theme_override_font_sizes = {"font_size": 10}
			rect.add_child(lbl)

	# Draw cities
	for city in GameManager.cities:
		_draw_city(city)

	# Draw armies
	for army in GameManager.armies:
		_draw_army(army)

func _draw_city(city: City) -> void:
	var marker := Label.new()
	marker.text = "▣"
	marker.theme_override_font_sizes = {"font_size": 22}
	var owner := GameManager.find_player(city.owner_id)
	marker.modulate = owner.color if owner else Color.WHITE
	marker.position = Vector2(city.grid_position.x * CELL_SIZE + 2, city.grid_position.y * CELL_SIZE + 2)
	marker.name = "CityMarker_%d" % city.city_id
	map_view.add_child(marker)

func _draw_army(army: Army) -> void:
	if army.is_empty():
		return
	var marker := Label.new()
	var unit_count_str: String = str(army.unit_count())
	marker.text = "⚔" + unit_count_str
	marker.theme_override_font_sizes = {"font_size": 16}
	var owner := GameManager.find_player(army.owner_id)
	marker.modulate = owner.color if owner else Color.WHITE
	marker.position = Vector2(army.grid_position.x * CELL_SIZE + 10, army.grid_position.y * CELL_SIZE + 14)
	marker.name = "ArmyMarker_%d" % army.army_id
	map_view.add_child(marker)

# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)

func _handle_tap(screen_pos: Vector2) -> void:
	# Convert screen position to map position (accounting for camera offset)
	var map_pos: Vector2 = map_view.get_local_mouse_position() if Engine.has_singleton("Engine") else screen_pos
	# Use global transform of map_view
	var local_pos: Vector2 = map_view.get_global_transform().affine_inverse() * screen_pos
	var grid_pos := Vector2i(int(local_pos.x) / CELL_SIZE, int(local_pos.y) / CELL_SIZE)

	if grid_pos.x < 0 or grid_pos.y < 0 or grid_pos.x >= GameData.MAP_WIDTH or grid_pos.y >= GameData.MAP_HEIGHT:
		return

	_on_tile_tapped(grid_pos)

func _on_tile_tapped(grid_pos: Vector2i) -> void:
	# Only the active player can act
	if GameManager.get_active_player_id() != GameManager.local_player_id:
		hud.show_message("It's not your turn!")
		return

	if _selected_army != null:
		# Try to move selected army to this tile
		_try_move_army(grid_pos)
	else:
		# Try to select an army or open city
		_try_select(grid_pos)

func _try_select(grid_pos: Vector2i) -> void:
	# Priority: army owned by local player > city
	var army := GameManager.select_army_at(grid_pos)
	if army != null:
		_selected_army = army
		unit_panel.show_army(army)
		city_panel.hide()
		hud.show_message("Selected: %d units  MP: %d" % [army.unit_count(), army.get_move_points()])
		return

	# Check city
	var city := GameManager.find_city_at(grid_pos)
	if city != null:
		_selected_city = city
		_selected_army = null
		city_panel.show_city(city)
		unit_panel.hide()
		return

	# Deselect
	_selected_army = null
	_selected_city = null
	unit_panel.hide()
	city_panel.hide()
	GameManager.selected_army_id = -1

func _try_move_army(target_pos: Vector2i) -> void:
	if _selected_army == null:
		return
	# Use NetworkManager for multiplayer-aware move (validates, executes, and syncs)
	NetworkManager.local_move(_selected_army.army_id, target_pos)
	# After the move the army reference may be stale (combat may have destroyed it); re-fetch
	_selected_army = GameManager.find_army(_selected_army.army_id)
	if _selected_army:
		unit_panel.show_army(_selected_army)
		hud.show_message("MP remaining: %d" % _selected_army.get_move_points())
	else:
		unit_panel.hide()
		_selected_army = null

# ---------------------------------------------------------------------------
# Signal handlers from GameManager
# ---------------------------------------------------------------------------

func _on_map_updated() -> void:
	_rebuild_map()
	_update_hud()

func _on_army_moved(_army_id: int, _new_pos: Vector2i) -> void:
	_rebuild_map()

func _on_combat_occurred(_attacker_id: int, _defender_id: int, report_log: Array, round_count: int) -> void:
	combat_log.show_log(report_log, round_count)

func _on_city_captured(city_id: int, new_owner: int) -> void:
	_rebuild_map()
	var city := GameManager.find_city(city_id)
	var player := GameManager.find_player(new_owner)
	if city and player:
		hud.show_message("%s captured %s!" % [player.player_name, city.city_name])

func _on_turn_changed(player_id: int, turn_number: int) -> void:
	_selected_army = null
	_selected_city = null
	unit_panel.hide()
	city_panel.hide()
	GameManager.selected_army_id = -1
	_rebuild_map()
	_update_hud()

	var player := GameManager.find_player(player_id)
	var name: String = player.player_name if player else "Unknown"
	if player_id == GameManager.local_player_id:
		turn_summary.show_summary("Your Turn (Round %d)" % turn_number, player)
	else:
		hud.show_message("%s's Turn" % name)

func _on_game_over(winner_id: int) -> void:
	var winner := GameManager.find_player(winner_id)
	var name: String = winner.player_name if winner else "Unknown"
	game_over_panel.show_winner(name)

# ---------------------------------------------------------------------------
# HUD button handlers
# ---------------------------------------------------------------------------

func _on_end_turn_pressed() -> void:
	NetworkManager.local_end_turn()

func _on_deselect_pressed() -> void:
	_selected_army = null
	GameManager.selected_army_id = -1
	unit_panel.hide()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_hud() -> void:
	if hud == null:
		return
	var player := GameManager.get_active_player()
	if player:
		hud.update_status(player, GameManager.turn_manager.turn_number if GameManager.turn_manager else 1)

func _terrain_char(terrain: GameData.Terrain) -> String:
	match terrain:
		GameData.Terrain.FOREST: return "F"
		GameData.Terrain.MOUNTAIN: return "M"
		GameData.Terrain.SWAMP: return "S"
		GameData.Terrain.ROAD: return "R"
		GameData.Terrain.RUINS: return "★"
		GameData.Terrain.CITY: return ""
		_: return ""
