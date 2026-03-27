## MapGenerator.gd
## Procedurally generates the game world map.
## Creates a grid with terrain, cities, and starting positions.
class_name MapGenerator

# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

## Generate a map for `num_players` players.
## Returns { "cells": Array[MapCell], "cities": Array[City] }
static func generate(num_players: int, seed_value: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()

	var width: int = GameData.MAP_WIDTH
	var height: int = GameData.MAP_HEIGHT

	var cells: Array[MapCell] = _build_terrain(width, height, rng)
	var cities: Array[City] = _place_cities(cells, num_players, width, height, rng)

	return {"cells": cells, "cities": cities}

# ---------------------------------------------------------------------------
# Terrain generation
# ---------------------------------------------------------------------------

static func _build_terrain(w: int, h: int, rng: RandomNumberGenerator) -> Array[MapCell]:
	var cells: Array[MapCell] = []

	# First pass: fill with noise-based terrain
	for y in range(h):
		for x in range(w):
			var cell := MapCell.new()
			cell.grid_position = Vector2i(x, y)
			cell.terrain = _pick_terrain(x, y, w, h, rng)
			cells.append(cell)

	# Second pass: add some roads connecting center to edges
	_place_roads(cells, w, h)

	return cells

static func _pick_terrain(x: int, y: int, w: int, h: int, rng: RandomNumberGenerator) -> GameData.Terrain:
	# Simple noise approximation using rng
	var roll: int = rng.randi_range(0, 99)

	# Water borders
	if x == 0 or x == w - 1 or y == 0 or y == h - 1:
		return GameData.Terrain.WATER

	# Inner area weighted distribution
	if roll < 5:
		return GameData.Terrain.WATER
	elif roll < 20:
		return GameData.Terrain.MOUNTAIN
	elif roll < 35:
		return GameData.Terrain.FOREST
	elif roll < 40:
		return GameData.Terrain.SWAMP
	elif roll < 45:
		return GameData.Terrain.RUINS
	else:
		return GameData.Terrain.PLAINS

static func _place_roads(cells: Array[MapCell], w: int, h: int) -> void:
	# Horizontal road through middle
	var mid_y: int = h / 2
	for x in range(1, w - 1):
		var cell := _get_cell(cells, x, mid_y, w)
		if cell and cell.terrain == GameData.Terrain.PLAINS:
			cell.terrain = GameData.Terrain.ROAD

	# Vertical road through middle
	var mid_x: int = w / 2
	for y in range(1, h - 1):
		var cell := _get_cell(cells, mid_x, y, w)
		if cell and cell.terrain == GameData.Terrain.PLAINS:
			cell.terrain = GameData.Terrain.ROAD

# ---------------------------------------------------------------------------
# City placement
# ---------------------------------------------------------------------------

static func _place_cities(cells: Array[MapCell], num_players: int, w: int, h: int, rng: RandomNumberGenerator) -> Array[City]:
	var cities: Array[City] = []
	var city_id_counter: int = 0
	var name_pool: Array[String] = GameData.CITY_NAMES.duplicate()
	name_pool.shuffle()

	# Player starting cities - placed in corners/spread positions
	var starting_positions: Array[Vector2i] = _get_starting_positions(num_players, w, h)

	for i in range(num_players):
		var pos := starting_positions[i]
		var cell := _get_cell(cells, pos.x, pos.y, w)
		if cell:
			cell.terrain = GameData.Terrain.CITY
			var city := City.new()
			city.city_id = city_id_counter
			city_id_counter += 1
			city.city_name = name_pool.pop_front() if not name_pool.is_empty() else ("City" + str(city_id_counter))
			city.grid_position = pos
			city.level = 2  # Starting cities are level 2
			city.owner_id = i  # Assigned to player i; GameManager will adjust
			cell.city_id = city.city_id
			cities.append(city)

	# Neutral cities scattered around
	var neutral_count: int = 6 + num_players * 2
	var attempts: int = 0
	while cities.size() - num_players < neutral_count and attempts < 500:
		attempts += 1
		var x: int = rng.randi_range(2, w - 3)
		var y: int = rng.randi_range(2, h - 3)
		var cell := _get_cell(cells, x, y, w)
		if cell == null or not _can_place_city(cell, cells, w, cities):
			continue
		cell.terrain = GameData.Terrain.CITY
		var city := City.new()
		city.city_id = city_id_counter
		city_id_counter += 1
		city.city_name = name_pool.pop_front() if not name_pool.is_empty() else ("Ruins" + str(city_id_counter))
		city.grid_position = Vector2i(x, y)
		city.level = 1
		city.owner_id = -1  # Neutral
		cell.city_id = city.city_id
		cities.append(city)

	return cities

## Returns good starting positions spread around the map for each player.
static func _get_starting_positions(num_players: int, w: int, h: int) -> Array[Vector2i]:
	var margin: int = 3
	var positions: Array[Vector2i] = [
		Vector2i(margin, margin),
		Vector2i(w - margin - 1, h - margin - 1),
		Vector2i(w - margin - 1, margin),
		Vector2i(margin, h - margin - 1),
	]
	return positions.slice(0, num_players)

static func _can_place_city(cell: MapCell, cells: Array[MapCell], w: int, existing_cities: Array[City]) -> bool:
	if not cell.is_passable() and cell.terrain != GameData.Terrain.CITY:
		return false
	if cell.has_city():
		return false
	# Ensure minimum distance from other cities
	for c in existing_cities:
		var dist: int = (abs(c.grid_position.x - cell.grid_position.x) + abs(c.grid_position.y - cell.grid_position.y))
		if dist < 3:
			return false
	return true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _get_cell(cells: Array[MapCell], x: int, y: int, w: int) -> MapCell:
	var idx: int = y * w + x
	if idx < 0 or idx >= cells.size():
		return null
	return cells[idx]
