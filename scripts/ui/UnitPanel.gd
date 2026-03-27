## UnitPanel.gd
## Panel shown when an army is selected. Displays all units and movement points.
extends CanvasLayer

@onready var panel: PanelContainer = $UnitPanelContainer
@onready var title_label: Label = $UnitPanelContainer/VBox/TitleLabel
@onready var units_list: VBoxContainer = $UnitPanelContainer/VBox/UnitsList
@onready var move_label: Label = $UnitPanelContainer/VBox/MoveLabel
@onready var deselect_button: Button = $UnitPanelContainer/VBox/DeselectButton

var _current_army: Army = null

func _ready() -> void:
	hide()

func show_army(army: Army) -> void:
	show()
	_current_army = army
	_refresh(army)

func _refresh(army: Army) -> void:
	var owner: Player = GameManager.find_player(army.owner_id)
	title_label.text = "%s's Army" % (owner.player_name if owner else "?")
	if owner:
		title_label.modulate = owner.color

	# Clear old entries
	for child in units_list.get_children():
		child.queue_free()

	for i in range(army.units.size()):
		var u: Unit = army.units[i]
		var lbl := Label.new()
		var hero_tag: String = " (Hero Lv.%d)" % (u as Hero).level if u.is_hero() else ""
		lbl.text = "%s) %s  Str:%d/%d%s" % [
			_letter(i),
			u.get_name(),
			u.current_strength,
			u.max_strength,
			hero_tag,
		]
		lbl.theme_override_font_sizes = {"font_size": 14}
		units_list.add_child(lbl)

	move_label.text = "Move Points: %d" % army.get_move_points()

func _on_deselect_pressed() -> void:
	hide()
	_current_army = null
	GameManager.selected_army_id = -1

func _letter(idx: int) -> String:
	return char(65 + idx)
