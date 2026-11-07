extends Control

signal team_confirmed(enemy_data: Dictionary, selected_instance_ids: Array)

const CHARACTER_IMAGE_PATH := "res://assets/characters/"
const CHARACTER_PREVIEW_PATH := "res://assets/characters/previews/"

const SORT_OPTIONS := [
	{"label": "Rareté", "key": "rarity"},
	{"label": "Niveau", "key": "level"},
	{"label": "Points de vie", "key": "lifepoints"},
	{"label": "Vitesse", "key": "moves"},
	{"label": "Force", "key": "attack"},
	{"label": "Esquive", "key": "escape"},
	{"label": "Défense", "key": "defense"},
	{"label": "Chance", "key": "chance"}
]

const MAX_SELECTION := 3

var enemy_data: Dictionary = {}
var collection_data: Array[Dictionary] = []
var selected_instances: Array[int] = []

var current_sort_index: int = 0
var ascending: bool = false

var main_layout: VBoxContainer
var sort_option: OptionButton
var direction_button: Button
var selection_label: Label
var start_button: Button
var grid: GridContainer
var details_dialog: AcceptDialog


func _ready() -> void:
	_build_interface()
	_load_collection()


func configure(opponent: Dictionary) -> void:
	enemy_data = opponent.duplicate(true)


# --------------------------------------------------
# INTERFACE
# --------------------------------------------------

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#183C32")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	main_layout = VBoxContainer.new()
	main_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.add_theme_constant_override("separation", 10)
	add_child(main_layout)

	# Titre.
	var title := Label.new()
	title.text = "Choisis tes combattants"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#F2D58B"))
	main_layout.add_child(title)

	# Barre de tri.
	var sort_container := HBoxContainer.new()
	sort_container.add_theme_constant_override("separation", 6)
	main_layout.add_child(sort_container)

	sort_option = OptionButton.new()
	sort_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for option in SORT_OPTIONS:
		sort_option.add_item(option["label"])

	sort_option.selected = 0
	sort_option.item_selected.connect(_on_sort_changed)
	sort_container.add_child(sort_option)
	GameManager.apply_button_skin(sort_option)

	direction_button = Button.new()
	direction_button.text = "Décroissant ↓"
	direction_button.pressed.connect(_on_direction_pressed)
	sort_container.add_child(direction_button)
	GameManager.apply_button_skin(direction_button)

	# Barre de sélection.
	selection_label = Label.new()
	selection_label.text = "Combattants sélectionnés : 0 / 3"
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_layout.add_child(selection_label)

	# Collection défilante.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.custom_minimum_size = Vector2.ZERO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_layout.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	start_button = Button.new()
	start_button.text = "Démarrer le duel"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.disabled = true
	start_button.visible = false
	start_button.pressed.connect(_on_start_pressed)
	main_layout.add_child(start_button)
	GameManager.apply_button_skin(start_button)

	# Fenêtre de détails.
	details_dialog = AcceptDialog.new()
	details_dialog.title = "Statistiques du personnage"
	details_dialog.ok_button_text = "Fermer"
	details_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_dialog.get_label().custom_minimum_size.x = 280
	GameManager.apply_button_skin(details_dialog.get_ok_button())
	add_child(details_dialog)


# --------------------------------------------------
# COLLECTION
# --------------------------------------------------

func _load_collection() -> void:
	collection_data.clear()

	var collection = GameManager.get_collection()

	for figurine in collection:
		var character_id: String = str(figurine.get("character_id", ""))
		var character: Dictionary = GameManager.get_character_data(character_id)

		if character.is_empty():
			continue

		collection_data.append({
			"figurine": figurine,
			"character": character
		})
	
	_sort_collection()
	_refresh_grid()

func _refresh_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	_sort_collection()
	
	for entry in collection_data:
		_create_character_card(entry)
	
	_update_selection_display()

# --------------------------------------------------
# TRI
# --------------------------------------------------

func _sort_collection() -> void:
	var sort_key: String = SORT_OPTIONS[current_sort_index]["key"]

	collection_data.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var value_a: float = _get_sort_value(a, sort_key)
			var value_b: float = _get_sort_value(b, sort_key)

			if value_a == value_b:
				return int(a["figurine"]["instance_id"]) < int(
					b["figurine"]["instance_id"]
				)

			if ascending:
				return value_a < value_b

			return value_a > value_b
	)


func _get_sort_value(entry: Dictionary, key: String) -> float:
	var character: Dictionary = entry["character"]
	var figurine: Dictionary = entry["figurine"]
	var stats: Dictionary = character.get("stats", {})

	if key == "rarity":
		return float(character.get("rarity", 0))

	if key == "level":
		return float(figurine.get("level", 1))

	return float(stats.get(key, 0))


func _on_sort_changed(index: int) -> void:
	current_sort_index = index
	_refresh_grid()


func _on_direction_pressed() -> void:
	ascending = not ascending

	if ascending:
		direction_button.text = "Croissant ↑"
	else:
		direction_button.text = "Décroissant ↓"

	GameManager.apply_button_skin(direction_button)
	_refresh_grid()


# --------------------------------------------------
# CARTES DES PERSONNAGES
# --------------------------------------------------

func _create_character_card(entry: Dictionary) -> void:
	var figurine: Dictionary = entry["figurine"]
	var character: Dictionary = entry["character"]

	var instance_id: int = int(figurine["instance_id"])
	var character_name: String = str(character.get("name", "Inconnu"))

	var stats: Dictionary = character.get("stats", {})
	var sort_key: String = SORT_OPTIONS[current_sort_index]["key"]
	var is_selected := selected_instances.has(instance_id)

	var card_item := VBoxContainer.new()
	card_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_item.add_theme_constant_override("separation", 4)
	grid.add_child(card_item)

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 145)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = "Sélectionner " + character_name
	card.pressed.connect(_on_character_pressed.bind(instance_id))

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#29483B")
	card_style.set_corner_radius_all(8)
	card_style.set_border_width_all(3)
	if is_selected:
		card_style.border_color = Color("#FFD65A")

	card.add_theme_stylebox_override("normal", card_style)
	var hover_style: StyleBoxFlat = card_style.duplicate()
	hover_style.bg_color = Color("#365C49")
	card.add_theme_stylebox_override("hover", hover_style)
	var pressed_style: StyleBoxFlat = card_style.duplicate()
	pressed_style.bg_color = Color("#1F3B2F")
	card.add_theme_stylebox_override("pressed", pressed_style)
	GameManager.apply_button_skin(card)
	card_item.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 6)
	card_margin.add_theme_constant_override("margin_right", 6)
	card_margin.add_theme_constant_override("margin_top", 4)
	card_margin.add_theme_constant_override("margin_bottom", 4)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(layout)

	var selection_frame := Panel.new()
	selection_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_frame.z_index = 10
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.set_corner_radius_all(8)
	frame_style.set_border_width_all(3)
	frame_style.border_color = (
		Color("#FFD65A")
		if is_selected
		else _get_rarity_color(int(character.get("rarity", 0)))
	)
	if is_selected:
		frame_style.shadow_color = Color(1.0, 0.75, 0.15, 0.85)
		frame_style.shadow_size = 9
	selection_frame.add_theme_stylebox_override("panel", frame_style)
	card.add_child(selection_frame)

	# Illustration.
	var image_container := CenterContainer.new()
	image_container.custom_minimum_size = Vector2(0, 76)
	image_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(image_container)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(72, 72)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var image_path := _get_character_preview_path(character)

	if ResourceLoader.exists(image_path):
		image.texture = load(image_path) as Texture2D

	image_container.add_child(image)

	# Nom.
	var name_label := Label.new()
	name_label.text = character_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(name_label)

	# Caractéristique correspondant au tri.
	var value: float = _get_sort_value(entry, sort_key)

	var attribute_label := Label.new()
	attribute_label.text = (
		SORT_OPTIONS[current_sort_index]["label"]
		+ " : "
		+ str(int(value))
	)
	attribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attribute_label.add_theme_font_size_override("font_size", 10)
	attribute_label.add_theme_color_override(
		"font_color",
		Color("#F2D58B")
	)
	attribute_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(attribute_label)

	# Bouton d'informations sous la carte.
	var info_container := CenterContainer.new()
	info_container.custom_minimum_size = Vector2(0, 32)
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_item.add_child(info_container)

	var info_button := Button.new()
	info_button.text = "ⓘ"
	info_button.custom_minimum_size = Vector2(32, 30)
	info_button.pressed.connect(
		_show_character_details.bind(entry)
	)
	GameManager.apply_button_skin(info_button)
	info_container.add_child(info_button)

func _get_character_preview_path(character: Dictionary) -> String:
	var image_name := str(character.get("image", ""))
	var image_stem := image_name.get_basename()
	var preview_name := image_stem + "_preview.png"

	var preview_path := CHARACTER_PREVIEW_PATH + preview_name
	if ResourceLoader.exists(preview_path):
		return preview_path
	return CHARACTER_IMAGE_PATH + image_name

func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		1:
			return Color("#A0E3FF")
		2:
			return Color("#7CDC85")
		3:
			return Color("#C27FD3")
		4:
			return Color("#FFAA6B")
		5:
			return Color("#FFEF80")
		6:
			return Color("#4A27B5")
		_:
			return Color("#806D4A")


# --------------------------------------------------
# SELECTION
# --------------------------------------------------

func _on_character_pressed(instance_id: int) -> void:
	if selected_instances.has(instance_id):
		selected_instances.erase(instance_id)

	elif selected_instances.size() < MAX_SELECTION:
		selected_instances.append(instance_id)

	else:
		return

	_refresh_grid()


func _update_selection_display() -> void:
	selection_label.text = (
        "Combattants sélectionnés : "
		+ str(selected_instances.size())
		+ " / "
		+ str(MAX_SELECTION)
	)

	start_button.visible = selected_instances.size() == MAX_SELECTION
	start_button.disabled = selected_instances.size() != MAX_SELECTION


# --------------------------------------------------
# DETAILS
# --------------------------------------------------

func _show_character_details(entry: Dictionary) -> void:
	var character: Dictionary = entry["character"]
	var figurine: Dictionary = entry["figurine"]
	var stats: Dictionary = character.get("stats", {})

	var text := ""

	text += str(character.get("name", "Inconnu")) + "\n\n"
	text += str(character.get("description", "")) + "\n\n"

	text += "Rareté : " + str(character.get("rarity", 0)) + "\n"
	text += "Niveau : " + str(figurine.get("level", 1)) + " / 10\n\n"

	text += "Points de vie : " + str(stats.get("lifepoints", 0)) + "\n"
	text += "Magie : " + str(stats.get("magic", 0)) + "\n"
	text += "Force : " + str(stats.get("attack", 0)) + "\n"
	text += "Défense : " + str(stats.get("defense", 0)) + "\n"
	text += "Esquive : " + str(stats.get("escape", 0)) + "\n"
	text += "Vitesse : " + str(stats.get("moves", 0)) + "\n"
	text += "Chance : " + str(stats.get("chance", 0)) + "\n\n"

	text += "Techniques :\n"

	for technique in stats.get("techniques", []):
		text += "• " + str(technique) + "\n"

	details_dialog.dialog_text = text
	details_dialog.popup_centered(Vector2i(340, 500))


# --------------------------------------------------
# LANCEMENT DU DUEL
# --------------------------------------------------

func _on_start_pressed() -> void:
	if selected_instances.size() != MAX_SELECTION:
		return

	team_confirmed.emit(
		enemy_data.duplicate(true),
		selected_instances.duplicate()
	)
