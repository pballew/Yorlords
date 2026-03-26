## City.gd
## A city on the map. Cities produce units, provide gold income,
## and can be captured by walking an army into them.
class_name City
extends Resource

signal production_complete(city: City, unit: Unit)
signal city_captured(city: City, new_owner_id: int, old_owner_id: int)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

@export var city_id: int = -1
@export var city_name: String = "Unknown"
@export var owner_id: int = -1           ## -1 = neutral
@export var grid_position: Vector2i = Vector2i.ZERO
@export var level: int = 1               ## 1-3 (larger = more income & production speed)
@export var production_type: GameData.UnitType = GameData.UnitType.INFANTRY
@export var production_turns_remaining: int = 0
@export var garrison: Array[Unit] = []   ## Units defending this city when unoccupied by an army

# ---------------------------------------------------------------------------
# Computed
# ---------------------------------------------------------------------------

func get_income() -> int:
	return GameData.CITY_INCOME[level]

func is_neutral() -> bool:
	return owner_id == -1

func is_producing() -> bool:
	return production_turns_remaining > 0

# ---------------------------------------------------------------------------
# Production
# ---------------------------------------------------------------------------

## Set the unit type this city will produce next.
func set_production(type: GameData.UnitType) -> void:
	production_type = type
	var data: Dictionary = GameData.UNIT_DATA[type]
	production_turns_remaining = max(1, data["turns_to_produce"] - (level - 1))

## Called at the start of each player's turn for each owned city.
## Returns the newly produced unit, or null if not done yet.
func advance_production(owner_race: GameData.Race) -> Unit:
	if production_turns_remaining <= 0:
		return null
	production_turns_remaining -= 1
	if production_turns_remaining == 0:
		var new_unit := Unit.new(production_type, owner_id)
		return new_unit
	return null

# ---------------------------------------------------------------------------
# Capture
# ---------------------------------------------------------------------------

func capture(new_owner_id: int) -> void:
	var old_owner := owner_id
	owner_id = new_owner_id
	garrison.clear()
	production_turns_remaining = 0
	emit_signal("city_captured", self, new_owner_id, old_owner)

# ---------------------------------------------------------------------------
# Garrison management
# ---------------------------------------------------------------------------

func add_garrison_unit(unit: Unit) -> bool:
	if garrison.size() >= GameData.MAX_UNITS_PER_ARMY:
		return false
	garrison.append(unit)
	return true

func clear_garrison() -> void:
	garrison.clear()

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var garrison_data: Array = []
	for u in garrison:
		garrison_data.append(u.to_dict())
	return {
		"city_id": city_id,
		"city_name": city_name,
		"owner_id": owner_id,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"level": level,
		"production_type": production_type,
		"production_turns_remaining": production_turns_remaining,
		"garrison": garrison_data,
	}

static func from_dict(data: Dictionary) -> City:
	var c := City.new()
	c.city_id = data["city_id"]
	c.city_name = data["city_name"]
	c.owner_id = data["owner_id"]
	c.grid_position = Vector2i(data["grid_position"]["x"], data["grid_position"]["y"])
	c.level = data["level"]
	c.production_type = data["production_type"]
	c.production_turns_remaining = data["production_turns_remaining"]
	for ud in data["garrison"]:
		c.garrison.append(Unit.from_dict(ud))
	return c
