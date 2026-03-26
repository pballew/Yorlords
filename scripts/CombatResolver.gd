## CombatResolver.gd
## Implements Warlords II-style combat:
##   - Each side picks its strongest unit each round.
##   - Units fight until one side is wiped out.
##   - Terrain defense bonus and hero leadership are applied.
##   - A small random factor adds unpredictability.
class_name CombatResolver

# ---------------------------------------------------------------------------
# Combat result data
# ---------------------------------------------------------------------------

class CombatReport:
	var result: GameData.CombatResult = GameData.CombatResult.ATTACKER_WINS
	var rounds: int = 0
	var attacker_losses: int = 0
	var defender_losses: int = 0
	var round_log: Array[String] = []

# ---------------------------------------------------------------------------
# Main resolve method
# ---------------------------------------------------------------------------

## Resolve combat between two armies.
## terrain is the terrain of the DEFENDER'S tile.
## Returns a CombatReport.
static func resolve(attacker: Army, defender: Army, terrain: GameData.Terrain) -> CombatReport:
	var report := CombatReport.new()

	# Work on copies to avoid modifying real unit state until confirmed
	var att_units: Array[Unit] = _copy_units(attacker.units)
	var def_units: Array[Unit] = _copy_units(defender.units)

	var att_hero_bonus: int = attacker.get_leadership_bonus()
	var def_hero_bonus: int = defender.get_leadership_bonus()
	var terrain_bonus: int = GameData.TERRAIN_DATA[terrain]["defense_bonus"]

	var max_rounds: int = (att_units.size() + def_units.size()) * 6
	var round_num: int = 0

	while not att_units.is_empty() and not def_units.is_empty() and round_num < max_rounds:
		round_num += 1

		# Pick best attacker and defender for this round
		var att_unit: Unit = _pick_best(att_units, GameData.Terrain.PLAINS, att_hero_bonus)
		var def_unit: Unit = _pick_best(def_units, terrain, def_hero_bonus + terrain_bonus)

		var att_str: int = att_unit.get_effective_strength(GameData.Terrain.PLAINS) + att_hero_bonus
		var def_str: int = def_unit.get_effective_strength(terrain) + def_hero_bonus + terrain_bonus

		# Random factor: each side rolls a d6, add to strength
		var att_roll: int = randi() % 6 + 1
		var def_roll: int = randi() % 6 + 1

		var att_total: int = att_str + att_roll
		var def_total: int = def_str + def_roll

		var log_line := "Round %d: %s(%d+%d) vs %s(%d+%d)" % [
			round_num,
			att_unit.get_name(), att_str, att_roll,
			def_unit.get_name(), def_str, def_roll,
		]

		if att_total >= def_total:
			# Attacker wins this round - defender loses 1 strength
			def_unit.current_strength -= 1
			if not def_unit.is_alive():
				def_units.erase(def_unit)
				report.defender_losses += 1
				log_line += " -> Defender unit slain!"
			else:
				log_line += " -> Attacker wins round."
		else:
			# Defender wins this round - attacker loses 1 strength
			att_unit.current_strength -= 1
			if not att_unit.is_alive():
				att_units.erase(att_unit)
				report.attacker_losses += 1
				log_line += " -> Attacker unit slain!"
			else:
				log_line += " -> Defender wins round."

		report.round_log.append(log_line)

	report.rounds = round_num

	if att_units.is_empty() and def_units.is_empty():
		report.result = GameData.CombatResult.DRAW
	elif att_units.is_empty():
		report.result = GameData.CombatResult.DEFENDER_WINS
	else:
		report.result = GameData.CombatResult.ATTACKER_WINS

	# Apply damage back to real units (kill units that died, reduce strength of survivors)
	_apply_damage(attacker.units, att_units)
	_apply_damage(defender.units, def_units)
	attacker.remove_dead_units()
	defender.remove_dead_units()

	return report

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Pick the unit with the highest effective strength from a list.
static func _pick_best(units: Array[Unit], terrain: GameData.Terrain, bonus: int) -> Unit:
	var best: Unit = units[0]
	var best_str: int = best.get_effective_strength(terrain) + bonus
	for u in units:
		var s: int = u.get_effective_strength(terrain) + bonus
		if s > best_str:
			best_str = s
			best = u
	return best

## Create shallow copies of units so we can apply damage tentatively.
static func _copy_units(original: Array[Unit]) -> Array[Unit]:
	var copies: Array[Unit] = []
	for u in original:
		var copy := Unit.new(u.unit_type, u.owner_id)
		copy.unit_id = u.unit_id
		copy.current_strength = u.current_strength
		copy.max_strength = u.max_strength
		copies.append(copy)
	return copies

## Apply damage from combat copies back to original units.
## A unit is dead if its copy's current_strength <= 0 or it no longer exists in the result list.
static func _apply_damage(original: Array[Unit], survivors: Array[Unit]) -> void:
	for orig in original:
		var found := false
		for surv in survivors:
			if surv.unit_id == orig.unit_id:
				orig.current_strength = surv.current_strength
				found = true
				break
		if not found:
			orig.current_strength = 0  # Mark as dead
