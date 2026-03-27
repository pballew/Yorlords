## MapCell.gd
## Represents a single tile on the game map.
class_name MapCell
extends Resource

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

@export var grid_position: Vector2i = Vector2i.ZERO
@export var terrain: GameData.Terrain = GameData.Terrain.PLAINS
@export var city_id: int = -1      ## -1 = no city on this tile
@export var army_id: int = -1      ## -1 = no army on this tile
@export var item: String = ""      ## Item on this tile ("" = none)
@export var is_explored: bool = false  ## For future fog of war

# ---------------------------------------------------------------------------
# Computed
# ---------------------------------------------------------------------------

func has_city() -> bool:
	return city_id != -1

func has_army() -> bool:
	return army_id != -1

func is_passable() -> bool:
	return GameData.is_passable(terrain)

func movement_cost() -> int:
	return GameData.get_movement_cost(terrain)

func defense_bonus() -> int:
	return GameData.TERRAIN_DATA[terrain]["defense_bonus"]

func get_terrain_color() -> Color:
	return GameData.TERRAIN_DATA[terrain]["color"]

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"terrain": terrain,
		"city_id": city_id,
		"army_id": army_id,
		"item": item,
		"is_explored": is_explored,
	}

static func from_dict(data: Dictionary) -> MapCell:
	var c := MapCell.new()
	c.grid_position = Vector2i(data["grid_position"]["x"], data["grid_position"]["y"])
	c.terrain = data["terrain"]
	c.city_id = data["city_id"]
	c.army_id = data["army_id"]
	c.item = data["item"]
	c.is_explored = data["is_explored"]
	return c
