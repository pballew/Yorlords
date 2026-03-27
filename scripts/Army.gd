## Army.gd
## An army is a stack of up to MAX_UNITS_PER_ARMY units occupying one map cell.
## Armies are the primary moving pieces, equivalent to Warlords II "stacks".
class_name Army
extends Resource

signal army_moved(from_pos: Vector2i, to_pos: Vector2i)
signal army_destroyed(army: Army)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

@export var army_id: int = -1
@export var owner_id: int = -1
@export var grid_position: Vector2i = Vector2i.ZERO
@export var units: Array[Unit] = []
@export var has_moved_this_turn: bool = false

# ---------------------------------------------------------------------------
# Computed
# ---------------------------------------------------------------------------

func unit_count() -> int:
	return units.size()

func is_full() -> bool:
	return units.size() >= GameData.MAX_UNITS_PER_ARMY

func is_empty() -> bool:
	return units.is_empty()

func has_hero() -> bool:
	for u in units:
		if u.is_hero():
			return true
	return false

func get_hero() -> Hero:
	for u in units:
		if u.is_hero():
			return u as Hero
	return null

## Total move points = minimum remaining across all units (slowest unit limits the stack).
func get_move_points() -> int:
	if units.is_empty():
		return 0
	var min_mp: int = units[0].move_points_remaining
	for u in units:
		min_mp = min(min_mp, u.move_points_remaining)
	return min_mp

## Leadership bonus from the hero in this army (0 if no hero).
func get_leadership_bonus() -> int:
	var h := get_hero()
	return h.leadership_bonus if h else 0

## Best combat strength in the stack (with optional terrain), used for battle.
func get_best_strength(terrain: GameData.Terrain = GameData.Terrain.PLAINS) -> int:
	var best: int = 0
	var bonus: int = get_leadership_bonus()
	for u in units:
		var s: int = u.get_effective_strength(terrain) + bonus
		if s > best:
			best = s
	return best

## Sum of all unit strengths (for display purposes).
func get_total_strength() -> int:
	var total: int = 0
	for u in units:
		total += u.current_strength
	return total

# ---------------------------------------------------------------------------
# Unit management
# ---------------------------------------------------------------------------

func add_unit(unit: Unit) -> bool:
	if is_full():
		return false
	units.append(unit)
	return true

func remove_unit(unit: Unit) -> bool:
	var idx := units.find(unit)
	if idx == -1:
		return false
	units.remove_at(idx)
	return true

func remove_dead_units() -> void:
	units = units.filter(func(u: Unit) -> bool: return u.is_alive())

## Consume move points for all units when moving into a terrain type.
func spend_move_points(cost: int) -> void:
	for u in units:
		u.move_points_remaining = max(0, u.move_points_remaining - cost)

func reset_movement() -> void:
	for u in units:
		u.reset_movement()
	has_moved_this_turn = false

## Split off some units into a new army at the same position.
func split(units_to_split: Array[Unit]) -> Army:
	var new_army := Army.new()
	new_army.owner_id = owner_id
	new_army.grid_position = grid_position
	for u in units_to_split:
		if remove_unit(u):
			new_army.add_unit(u)
	return new_army

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var units_data: Array = []
	for u in units:
		units_data.append(u.to_dict())
	return {
		"army_id": army_id,
		"owner_id": owner_id,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"has_moved_this_turn": has_moved_this_turn,
		"units": units_data,
	}

static func from_dict(data: Dictionary) -> Army:
	var a := Army.new()
	a.army_id = data["army_id"]
	a.owner_id = data["owner_id"]
	a.grid_position = Vector2i(data["grid_position"]["x"], data["grid_position"]["y"])
	a.has_moved_this_turn = data["has_moved_this_turn"]
	for ud in data["units"]:
		if ud.get("hero_name"):
			a.units.append(Hero.from_dict(ud))
		else:
			a.units.append(Unit.from_dict(ud))
	return a
