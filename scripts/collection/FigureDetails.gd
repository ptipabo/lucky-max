extends Control

signal back_from_figure_details()

var selected_character: Dictionary
var selected_figure: Dictionary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_interface()
	
func configure(character: Dictionary, figure: Dictionary) -> void:
	selected_character = character
	selected_figure = figure

func _build_interface() -> void:
	# Organisation verticale.
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	# En-tête.
	var header := VBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 85)
	header.add_theme_constant_override("separation", 4)
	layout.add_child(header)
	
	header.add_child(
		GameManager.create_title_header(
			str(selected_character.get("name", "Inconnu")),
			24
		)
	)
	
	# Zone réservée à l'image : elle ne peut pas empiéter sur le titre
	var image_area := Control.new()
	image_area.name = "ImageArea"
	image_area.custom_minimum_size = Vector2(0, 520)
	image_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(image_area)
	
	# Illustration du personnage
	var character_image := TextureRect.new()
	character_image.name = "CharacterImage"
	character_image.custom_minimum_size = Vector2(480, 480)
	character_image.size = Vector2(480, 480)
	character_image.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	character_image.position = Vector2(-240, -230)
	character_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	character_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var image_path: String = GameManager.CHARACTERS_IMAGE_PATH + str(selected_character.get("image", ""))
	if image_path != "":
		var texture := load(image_path) as Texture2D
		if texture != null:
			character_image.texture = texture
		else:
			push_warning("Image introuvable : " + image_path)

	image_area.add_child(character_image)
	
	# Animation de flottement
	var float_tween := create_tween()
	float_tween.set_loops(0)
	float_tween.set_trans(Tween.TRANS_SINE)
	float_tween.set_ease(Tween.EASE_IN_OUT)

	float_tween.tween_property(
		character_image,
		"position:y",
		10.0,
		1.0
	)

	float_tween.tween_property(
		character_image,
		"position:y",
		22.0,
		1.0
	)
	
	float_tween.bind_node(character_image)

	var rarity_label := Label.new()
	rarity_label.name = "RarityLabel"
	rarity_label.text = "Rareté : " + GameManager._get_rarity_label(selected_character.get("rarity", 0))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_SUBTITLE)
	rarity_label.add_theme_color_override("font_color", GameManager._get_rarity_color(selected_character.get("rarity", 0)))
	layout.add_child(rarity_label)

	var desc_container := PanelContainer.new()
	desc_container.name = "DescriptionContainer"
	desc_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(desc_container)
	
	var desc_margins := MarginContainer.new()
	desc_margins.name = "DescriptionMargins"
	desc_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desc_margins.add_theme_constant_override("margin_left", 20)
	desc_margins.add_theme_constant_override("margin_right", 20)
	desc_margins.add_theme_constant_override("margin_top", 20)
	desc_margins.add_theme_constant_override("margin_bottom", 16)
	desc_container.add_child(desc_margins)

	var character_description := Label.new()
	character_description.name = "CharacterDescription"
	character_description.text = str(selected_character.get("description", "Aucune description."))
	character_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_description.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
	desc_margins.add_child(character_description)

	var sell_value := int(selected_character.get("sell_value", 0))

	var sell_button := Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "Vendre pour " + str(sell_value) + " points"
	sell_button.custom_minimum_size = Vector2(0, 50)
	sell_button.pressed.connect(
		_sell_figurine.bind(
			int(selected_figure.get("instance_id", -1)),
			sell_value
		)
	)
	GameManager.apply_button_skin(sell_button)
	layout.add_child(sell_button)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "← Retour à la collection"
	back_button.custom_minimum_size = Vector2(0, 45)
	back_button.pressed.connect(
		_on_back_button_pressed
	)
	#back_button.pressed.connect(_show_collection)
	GameManager.apply_button_skin(back_button)
	layout.add_child(back_button)

# Permet de revendre une figurine et de regagner des points
func _sell_figurine(instance_id: int, sell_value: int) -> void:
	if sell_value < 0:
		return

	var removed: Dictionary = GameManager.remove_figurine(instance_id)

	if removed.is_empty():
		return

	GameManager.add_points(sell_value)
	back_from_figure_details.emit()

func _on_back_button_pressed() -> void:
	back_from_figure_details.emit()
