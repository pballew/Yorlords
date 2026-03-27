## Hero.gd
## A Hero unit with levels, experience, items, and a leadership bonus
## that boosts the combat strength of all units in the same army.
class_name Hero
extends Unit

# ---------------------------------------------------------------------------
# Hero-specific properties
# ---------------------------------------------------------------------------

@export var hero_name: String = "Unnamed Hero"
@export var level: int = 1
@export var leadership_bonus: int = 1  ## Extra strength added to all army units per adjacent hero
@export var items: Array[String] = []  ## Item names (simple string-based for now)

const EXP_PER_LEVEL: int = 10
const MAX_LEVEL: int = 10
const MAX_ITEMS: int = 4

# ---------------------------------------------------------------------------
# Hero hire cost scales with market availability
# ---------------------------------------------------------------------------
static func hire_cost(level: int) -> int:
	return GameData.HERO_HIRE_BASE_COST + (level - 1) * 50

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init(name: String = "Hero", owner: int = -1) -> void:
	super._init(GameData.UnitType.HERO, owner)
	hero_name = name
	level = 1
	leadership_bonus = 1
	max_strength = GameData.UNIT_DATA[GameData.UnitType.HERO]["strength"]
	current_strength = max_strength

# ---------------------------------------------------------------------------
# Experience and levelling
# ---------------------------------------------------------------------------

## Award experience from winning combat.  Returns true if a level-up occurred.
func award_experience(amount: int) -> bool:
	experience += amount
	if level < MAX_LEVEL and experience >= level * EXP_PER_LEVEL:
		_level_up()
		return true
	return false

func _level_up() -> void:
	level += 1
	max_strength += 1
	current_strength = max_strength
	leadership_bonus = 1 + (level // 3)  # Bonus increases every 3 levels

# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

func can_pick_up_item() -> bool:
	return items.size() < MAX_ITEMS

func pick_up_item(item_name: String) -> bool:
	if not can_pick_up_item():
		return false
	items.append(item_name)
	return true

# ---------------------------------------------------------------------------
# Overrides
# ---------------------------------------------------------------------------

func get_name() -> String:
	return hero_name + " (Lv." + str(level) + ")"

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["hero_name"] = hero_name
	d["level"] = level
	d["leadership_bonus"] = leadership_bonus
	d["items"] = items.duplicate()
	return d

static func from_dict(data: Dictionary) -> Hero:
	var h := Hero.new(data["hero_name"], data["owner_id"])
	h.unit_id = data["unit_id"]
	h.current_strength = data["current_strength"]
	h.max_strength = data["max_strength"]
	h.move_points_remaining = data["move_points_remaining"]
	h.experience = data["experience"]
	h.level = data["level"]
	h.leadership_bonus = data["leadership_bonus"]
	h.items = data["items"].duplicate()
	return h
