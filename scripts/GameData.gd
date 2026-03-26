## GameData.gd
## Static game data: unit types, races, terrain, and game constants.
## Implements Warlords II-style rules adapted for Yorlords.
class_name GameData

# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

enum Race {
	HUMAN,
	ELF,
	DWARF,
	ORC,
	UNDEAD,
	DEMON,
	NEUTRAL
}

enum UnitType {
	# Common
	INFANTRY,
	CAVALRY,
	ARCHER,
	CATAPULT,
	HERO,
	# Human
	KNIGHT,
	WIZARD,
	# Elf
	RANGER,
	DRAGON,
	# Dwarf
	AXEMAN,
	BALLISTA,
	# Orc
	WOLF_RIDER,
	TROLL,
	# Undead
	SKELETON,
	GHOST,
	# Demon
	IMP,
	DEMON_LORD,
}

enum Terrain {
	PLAINS,
	FOREST,
	MOUNTAIN,
	SWAMP,
	WATER,
	ROAD,
	CITY,
	RUINS,
}

enum GamePhase {
	MENU,
	LOBBY,
	PLAYING,
	COMBAT,
	GAME_OVER,
}

enum CombatResult {
	ATTACKER_WINS,
	DEFENDER_WINS,
	DRAW,
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MAX_UNITS_PER_ARMY: int = 8
const MAX_PLAYERS: int = 4
const DEFAULT_PORT: int = 7777
const MAP_WIDTH: int = 24
const MAP_HEIGHT: int = 16
const MOVE_POINTS_PER_TURN: int = 4
const HERO_HIRE_BASE_COST: int = 100
const STARTING_GOLD: int = 200

# ---------------------------------------------------------------------------
# Unit Definitions
# Each unit: { strength, movement, production_cost, turns_to_produce, terrain_bonuses, description }
# strength: combat power (1–10)
# movement: base move points per turn
# terrain_bonuses: dict of Terrain -> combat modifier (+/-)
# ---------------------------------------------------------------------------

const UNIT_DATA: Dictionary = {
	UnitType.INFANTRY: {
		"name": "Infantry",
		"strength": 3,
		"movement": 2,
		"production_cost": 30,
		"turns_to_produce": 2,
		"terrain_bonuses": { Terrain.FOREST: 1, Terrain.MOUNTAIN: 1 },
		"description": "Versatile foot soldiers.",
		"race": Race.NEUTRAL,
	},
	UnitType.CAVALRY: {
		"name": "Cavalry",
		"strength": 4,
		"movement": 4,
		"production_cost": 60,
		"turns_to_produce": 3,
		"terrain_bonuses": { Terrain.PLAINS: 2, Terrain.ROAD: 1 },
		"description": "Fast mounted warriors.",
		"race": Race.NEUTRAL,
	},
	UnitType.ARCHER: {
		"name": "Archer",
		"strength": 3,
		"movement": 2,
		"production_cost": 40,
		"turns_to_produce": 2,
		"terrain_bonuses": { Terrain.FOREST: 2 },
		"description": "Ranged attackers with forest affinity.",
		"race": Race.NEUTRAL,
	},
	UnitType.CATAPULT: {
		"name": "Catapult",
		"strength": 6,
		"movement": 1,
		"production_cost": 120,
		"turns_to_produce": 5,
		"terrain_bonuses": { Terrain.CITY: 3 },
		"description": "Devastating siege weapon.",
		"race": Race.NEUTRAL,
	},
	UnitType.HERO: {
		"name": "Hero",
		"strength": 5,
		"movement": 3,
		"production_cost": 0,
		"turns_to_produce": 0,
		"terrain_bonuses": {},
		"description": "Powerful champion who leads armies.",
		"race": Race.NEUTRAL,
	},
	UnitType.KNIGHT: {
		"name": "Knight",
		"strength": 5,
		"movement": 3,
		"production_cost": 80,
		"turns_to_produce": 4,
		"terrain_bonuses": { Terrain.PLAINS: 1, Terrain.ROAD: 2 },
		"description": "Armored Human warrior.",
		"race": Race.HUMAN,
	},
	UnitType.WIZARD: {
		"name": "Wizard",
		"strength": 7,
		"movement": 2,
		"production_cost": 150,
		"turns_to_produce": 6,
		"terrain_bonuses": { Terrain.RUINS: 2 },
		"description": "Powerful Human spellcaster.",
		"race": Race.HUMAN,
	},
	UnitType.RANGER: {
		"name": "Ranger",
		"strength": 4,
		"movement": 4,
		"production_cost": 70,
		"turns_to_produce": 3,
		"terrain_bonuses": { Terrain.FOREST: 3, Terrain.MOUNTAIN: 1 },
		"description": "Swift Elven scout-warrior.",
		"race": Race.ELF,
	},
	UnitType.DRAGON: {
		"name": "Dragon",
		"strength": 9,
		"movement": 5,
		"production_cost": 250,
		"turns_to_produce": 8,
		"terrain_bonuses": { Terrain.MOUNTAIN: 2 },
		"description": "Ancient Elven-bonded dragon.",
		"race": Race.ELF,
	},
	UnitType.AXEMAN: {
		"name": "Axeman",
		"strength": 4,
		"movement": 2,
		"production_cost": 50,
		"turns_to_produce": 2,
		"terrain_bonuses": { Terrain.MOUNTAIN: 2, Terrain.FOREST: 1 },
		"description": "Tough Dwarven fighter.",
		"race": Race.DWARF,
	},
	UnitType.BALLISTA: {
		"name": "Ballista",
		"strength": 5,
		"movement": 1,
		"production_cost": 100,
		"turns_to_produce": 4,
		"terrain_bonuses": { Terrain.CITY: 2, Terrain.MOUNTAIN: 1 },
		"description": "Dwarven siege crossbow.",
		"race": Race.DWARF,
	},
	UnitType.WOLF_RIDER: {
		"name": "Wolf Rider",
		"strength": 4,
		"movement": 4,
		"production_cost": 65,
		"turns_to_produce": 3,
		"terrain_bonuses": { Terrain.SWAMP: 1, Terrain.FOREST: 1 },
		"description": "Orcish cavalry on dire wolves.",
		"race": Race.ORC,
	},
	UnitType.TROLL: {
		"name": "Troll",
		"strength": 6,
		"movement": 2,
		"production_cost": 110,
		"turns_to_produce": 4,
		"terrain_bonuses": { Terrain.SWAMP: 2, Terrain.MOUNTAIN: 1 },
		"description": "Regenerating Orcish brute.",
		"race": Race.ORC,
	},
	UnitType.SKELETON: {
		"name": "Skeleton",
		"strength": 3,
		"movement": 2,
		"production_cost": 25,
		"turns_to_produce": 1,
		"terrain_bonuses": { Terrain.RUINS: 3 },
		"description": "Undead foot soldier. Cheap but weak.",
		"race": Race.UNDEAD,
	},
	UnitType.GHOST: {
		"name": "Ghost",
		"strength": 6,
		"movement": 5,
		"production_cost": 130,
		"turns_to_produce": 5,
		"terrain_bonuses": { Terrain.RUINS: 2, Terrain.SWAMP: 2 },
		"description": "Spectral Undead warrior. Ignores terrain.",
		"race": Race.UNDEAD,
	},
	UnitType.IMP: {
		"name": "Imp",
		"strength": 3,
		"movement": 3,
		"production_cost": 35,
		"turns_to_produce": 2,
		"terrain_bonuses": {},
		"description": "Small demonic scout.",
		"race": Race.DEMON,
	},
	UnitType.DEMON_LORD: {
		"name": "Demon Lord",
		"strength": 10,
		"movement": 3,
		"production_cost": 300,
		"turns_to_produce": 10,
		"terrain_bonuses": { Terrain.RUINS: 2 },
		"description": "Supreme Demon commander. Most powerful unit.",
		"race": Race.DEMON,
	},
}

# ---------------------------------------------------------------------------
# Terrain Definitions
# movement_cost: how many move points to enter this tile (0 = impassable)
# ---------------------------------------------------------------------------

const TERRAIN_DATA: Dictionary = {
	Terrain.PLAINS: {
		"name": "Plains",
		"movement_cost": 1,
		"defense_bonus": 0,
		"color": Color(0.6, 0.85, 0.4),
	},
	Terrain.FOREST: {
		"name": "Forest",
		"movement_cost": 2,
		"defense_bonus": 1,
		"color": Color(0.2, 0.5, 0.2),
	},
	Terrain.MOUNTAIN: {
		"name": "Mountains",
		"movement_cost": 3,
		"defense_bonus": 2,
		"color": Color(0.6, 0.6, 0.6),
	},
	Terrain.SWAMP: {
		"name": "Swamp",
		"movement_cost": 3,
		"defense_bonus": 0,
		"color": Color(0.4, 0.5, 0.3),
	},
	Terrain.WATER: {
		"name": "Water",
		"movement_cost": 0,
		"defense_bonus": 0,
		"color": Color(0.2, 0.4, 0.8),
	},
	Terrain.ROAD: {
		"name": "Road",
		"movement_cost": 1,
		"defense_bonus": 0,
		"color": Color(0.7, 0.65, 0.5),
	},
	Terrain.CITY: {
		"name": "City",
		"movement_cost": 1,
		"defense_bonus": 2,
		"color": Color(0.85, 0.8, 0.5),
	},
	Terrain.RUINS: {
		"name": "Ruins",
		"movement_cost": 2,
		"defense_bonus": 1,
		"color": Color(0.5, 0.45, 0.35),
	},
}

# ---------------------------------------------------------------------------
# Race Definitions
# ---------------------------------------------------------------------------

const RACE_DATA: Dictionary = {
	Race.HUMAN: {
		"name": "Human",
		"color": Color(0.9, 0.8, 0.6),
		"starting_units": [UnitType.INFANTRY, UnitType.CAVALRY, UnitType.INFANTRY],
		"buildable_units": [UnitType.INFANTRY, UnitType.CAVALRY, UnitType.ARCHER, UnitType.CATAPULT, UnitType.KNIGHT, UnitType.WIZARD],
		"description": "Balanced kingdom with strong knights and arcane power.",
	},
	Race.ELF: {
		"name": "Elf",
		"color": Color(0.5, 0.9, 0.5),
		"starting_units": [UnitType.ARCHER, UnitType.RANGER, UnitType.ARCHER],
		"buildable_units": [UnitType.INFANTRY, UnitType.ARCHER, UnitType.CATAPULT, UnitType.RANGER, UnitType.DRAGON],
		"description": "Forest masters with powerful dragons.",
	},
	Race.DWARF: {
		"name": "Dwarf",
		"color": Color(0.7, 0.5, 0.3),
		"starting_units": [UnitType.AXEMAN, UnitType.AXEMAN, UnitType.BALLISTA],
		"buildable_units": [UnitType.INFANTRY, UnitType.AXEMAN, UnitType.CATAPULT, UnitType.BALLISTA],
		"description": "Mountain lords with formidable siege weapons.",
	},
	Race.ORC: {
		"name": "Orc",
		"color": Color(0.4, 0.7, 0.2),
		"starting_units": [UnitType.INFANTRY, UnitType.WOLF_RIDER, UnitType.TROLL],
		"buildable_units": [UnitType.INFANTRY, UnitType.CAVALRY, UnitType.WOLF_RIDER, UnitType.TROLL, UnitType.CATAPULT],
		"description": "Savage raiders with powerful trolls.",
	},
	Race.UNDEAD: {
		"name": "Undead",
		"color": Color(0.6, 0.6, 0.8),
		"starting_units": [UnitType.SKELETON, UnitType.SKELETON, UnitType.GHOST],
		"buildable_units": [UnitType.SKELETON, UnitType.ARCHER, UnitType.CATAPULT, UnitType.GHOST],
		"description": "Cheap masses of skeleton warriors and fearsome ghosts.",
	},
	Race.DEMON: {
		"name": "Demon",
		"color": Color(0.9, 0.2, 0.2),
		"starting_units": [UnitType.IMP, UnitType.IMP, UnitType.IMP],
		"buildable_units": [UnitType.IMP, UnitType.INFANTRY, UnitType.CATAPULT, UnitType.DEMON_LORD],
		"description": "Infernal forces building toward the ultimate Demon Lord.",
	},
}

# ---------------------------------------------------------------------------
# City income by city type (level)
# ---------------------------------------------------------------------------
const CITY_INCOME: Array[int] = [0, 20, 30, 50]  # level 0-3
const CITY_NAMES: Array[String] = [
	"Ironhold", "Ashenveil", "Stonewatch", "Brightmere", "Shadowfen",
	"Goldspire", "Thornwall", "Crystalmoor", "Duskgate", "Embertide",
	"Frostpeak", "Gloomhaven", "Highcastle", "Ironcrest", "Jadekeep",
	"Kingspire", "Lostford", "Moonridge", "Northgate", "Oldmere",
	"Peakwatch", "Queenshold", "Ravenscar", "Silvermark", "Thornvale",
	"Umberfall", "Valorkeep", "Westmarch", "Xarthon", "Yewdale", "Zephyrport",
]

# ---------------------------------------------------------------------------
# Helper: get unit display name
# ---------------------------------------------------------------------------
static func get_unit_name(type: UnitType) -> String:
	return UNIT_DATA[type]["name"]

static func get_terrain_name(terrain: Terrain) -> String:
	return TERRAIN_DATA[terrain]["name"]

static func get_race_name(race: Race) -> String:
	if race == Race.NEUTRAL:
		return "Neutral"
	return RACE_DATA[race]["name"]

static func get_movement_cost(terrain: Terrain) -> int:
	return TERRAIN_DATA[terrain]["movement_cost"]

static func is_passable(terrain: Terrain) -> bool:
	return TERRAIN_DATA[terrain]["movement_cost"] > 0
