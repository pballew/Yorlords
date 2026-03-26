## Player.gd
## Represents a single player (human or AI placeholder).
class_name Player
extends Resource

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

@export var player_id: int = 0
@export var player_name: String = "Player"
@export var race: GameData.Race = GameData.Race.HUMAN
@export var color: Color = Color.WHITE
@export var gold: int = GameData.STARTING_GOLD
@export var is_eliminated: bool = false
@export var is_local: bool = false  ## True if this player runs on the local machine
@export var peer_id: int = 1        ## ENet peer ID for network sync

## IDs of cities owned by this player
@export var city_ids: Array[int] = []
## IDs of armies owned by this player
@export var army_ids: Array[int] = []

# ---------------------------------------------------------------------------
# Convenience
# ---------------------------------------------------------------------------

func city_count() -> int:
	return city_ids.size()

func army_count() -> int:
	return army_ids.size()

func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true

func can_afford(amount: int) -> bool:
	return gold >= amount

func eliminate() -> void:
	is_eliminated = true

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"player_name": player_name,
		"race": race,
		"color": {"r": color.r, "g": color.g, "b": color.b},
		"gold": gold,
		"is_eliminated": is_eliminated,
		"peer_id": peer_id,
		"city_ids": city_ids.duplicate(),
		"army_ids": army_ids.duplicate(),
	}

static func from_dict(data: Dictionary) -> Player:
	var p := Player.new()
	p.player_id = data["player_id"]
	p.player_name = data["player_name"]
	p.race = data["race"]
	p.color = Color(data["color"]["r"], data["color"]["g"], data["color"]["b"])
	p.gold = data["gold"]
	p.is_eliminated = data["is_eliminated"]
	p.peer_id = data["peer_id"]
	p.city_ids = data["city_ids"].duplicate()
	p.army_ids = data["army_ids"].duplicate()
	return p
