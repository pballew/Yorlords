## CityPanel.gd
## Panel shown when a city is selected.
## Lets the owning player set production and view city details.
extends CanvasLayer

@onready var panel: PanelContainer = $CityPanelContainer
@onready var city_name_label: Label = $CityPanelContainer/VBox/CityNameLabel
@onready var owner_label: Label = $CityPanelContainer/VBox/OwnerLabel
@onready var income_label: Label = $CityPanelContainer/VBox/IncomeLabel
@onready var production_label: Label = $CityPanelContainer/VBox/ProductionLabel
@onready var production_option: OptionButton = $CityPanelContainer/VBox/ProductionOption
@onready var set_production_button: Button = $CityPanelContainer/VBox/SetProductionButton
@onready var garrison_label: Label = $CityPanelContainer/VBox/GarrisonLabel
@onready var close_button: Button = $CityPanelContainer/VBox/CloseButton

var _current_city: City = null

func _ready() -> void:
	hide()

func show_city(city: City) -> void:
	show()
	_current_city = city
	_refresh(city)

func _refresh(city: City) -> void:
	city_name_label.text = city.city_name + "  (Lv.%d)" % city.level

	var owner: Player = GameManager.find_player(city.owner_id)
	owner_label.text = "Owner: " + (owner.player_name if owner else "Neutral")
	if owner:
		owner_label.modulate = owner.color

	income_label.text = "Income: %d gold/turn" % city.get_income()

	if city.is_producing():
		var unit_name: String = GameData.get_unit_name(city.production_type)
		production_label.text = "Producing: %s (%d turns left)" % [unit_name, city.production_turns_remaining]
	else:
		production_label.text = "Producing: (none)"

	garrison_label.text = "Garrison: %d units" % city.garrison.size()

	# Populate production options if this is our city and it's our turn
	var is_our_city: bool = city.owner_id == GameManager.local_player_id
	var is_our_turn: bool = GameManager.get_active_player_id() == GameManager.local_player_id
	production_option.visible = is_our_city and is_our_turn
	set_production_button.visible = is_our_city and is_our_turn

	if is_our_city and is_our_turn:
		production_option.clear()
		var player: Player = GameManager.find_player(city.owner_id)
		if player:
			var buildable: Array = GameData.RACE_DATA[player.race]["buildable_units"]
			for i in range(buildable.size()):
				var ut: GameData.UnitType = buildable[i]
				var data: Dictionary = GameData.UNIT_DATA[ut]
				var label_text: String = "%s) %s  (Str:%d, %d turns)" % [
					_letter(i),
					data["name"],
					data["strength"],
					data["turns_to_produce"],
				]
				production_option.add_item(label_text, ut)

func _on_set_production_pressed() -> void:
	if _current_city == null:
		return
	var selected_id: int = production_option.get_selected_id()
	NetworkManager.local_set_production(_current_city.city_id, selected_id as GameData.UnitType)
	_refresh(_current_city)

func _on_close_pressed() -> void:
	hide()
	_current_city = null

func _letter(idx: int) -> String:
	return char(65 + idx)  # A, B, C, ...
