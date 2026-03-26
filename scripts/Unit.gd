## Unit.gd
## Represents a single unit in the game (infantry, cavalry, hero, etc.)
class_name Unit
extends Resource

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

@export var unit_type: GameData.UnitType = GameData.UnitType.INFANTRY
@export var current_strength: int = 1   ## Current combat strength (can be reduced by combat)
@export var max_strength: int = 1       ## Maximum strength from unit data
@export var move_points_remaining: int = 0
@export var owner_id: int = -1          ## Player ID who owns this unit
@export var experience: int = 0         ## Accumulated experience (heroes only use this fully)
@export var unit_id: int = -1           ## Unique ID for network sync

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init(type: GameData.UnitType = GameData.UnitType.INFANTRY, owner: int = -1) -> void:
	unit_type = type
	owner_id = owner
	var data: Dictionary = GameData.UNIT_DATA[type]
	max_strength = data["strength"]
	current_strength = max_strength
	move_points_remaining = data["movement"]

# ---------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------

func get_name() -> String:
	return GameData.UNIT_DATA[unit_type]["name"]

func get_base_movement() -> int:
	return GameData.UNIT_DATA[unit_type]["movement"]

func get_terrain_bonus(terrain: GameData.Terrain) -> int:
	var bonuses: Dictionary = GameData.UNIT_DATA[unit_type]["terrain_bonuses"]
	return bonuses.get(terrain, 0)

func get_effective_strength(terrain: GameData.Terrain = GameData.Terrain.PLAINS) -> int:
	return current_strength + get_terrain_bonus(terrain)

func is_alive() -> bool:
	return current_strength > 0

func is_hero() -> bool:
	return unit_type == GameData.UnitType.HERO

func reset_movement() -> void:
	move_points_remaining = get_base_movement()

# ---------------------------------------------------------------------------
# Serialization for network sync
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"unit_id": unit_id,
		"unit_type": unit_type,
		"current_strength": current_strength,
		"max_strength": max_strength,
		"move_points_remaining": move_points_remaining,
		"owner_id": owner_id,
		"experience": experience,
	}

static func from_dict(data: Dictionary) -> Unit:
	var u := Unit.new(data["unit_type"], data["owner_id"])
	u.unit_id = data["unit_id"]
	u.current_strength = data["current_strength"]
	u.max_strength = data["max_strength"]
	u.move_points_remaining = data["move_points_remaining"]
	u.experience = data["experience"]
	return u
