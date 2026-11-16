extends Control

signal card_selected(figurine: Dictionary)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_interface()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _build_interface() -> void:
	# Organisation verticale.
	var collection_layout := VBoxContainer.new()
	collection_layout.name = "CollectionLayout"
	collection_layout.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	collection_layout.add_theme_constant_override("separation", 8)
	add_child(collection_layout)

	# En-tête.
	var collection_header := VBoxContainer.new()
	collection_header.name = "CollectionHeader"
	collection_header.custom_minimum_size = Vector2(0, 85)
	collection_header.add_theme_constant_override("separation", 4)
	collection_layout.add_child(collection_header)
	
	collection_header.add_child(GameManager.create_title_header("Collection", GameManager.FONT_SIZE_TITLE))

	var figurines: Array = GameManager.get_collection()

	var collection_count_label := Label.new()
	collection_count_label.name = "CollectionCountLabel"
	collection_count_label.text = str(figurines.size()) + " figurine(s) possédée(s)"
	collection_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_count_label.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
	collection_layout.add_child(collection_count_label)

	if figurines.is_empty():
		var empty_collection_label := Label.new()
		empty_collection_label.name = "EmptyCollectionLabel"
		empty_collection_label.text = "Ta collection est vide !\nVa dans la Boutique pour obtenir ta première figurine."
		empty_collection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_collection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_collection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_collection_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_collection_label.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
		collection_layout.add_child(empty_collection_label)
		return

	var collection_scroll_container := ScrollContainer.new()
	collection_scroll_container.name = "CollectionScrollContainer"
	collection_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_layout.add_child(collection_scroll_container)

	var collection_grid := GridContainer.new()
	collection_grid.name = "CollectionGrid"
	collection_grid.columns = 4
	collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_grid.add_theme_constant_override("h_separation", 6)
	collection_grid.add_theme_constant_override("v_separation", 8)
	collection_scroll_container.add_child(collection_grid)

	for figurine in figurines:
		var character_id := str(figurine.get("character_id", ""))
		var character: Dictionary = GameManager.get_character_data(character_id)

		if character.is_empty():
			continue
		
		# Carte du personnage
		var collection_card := Button.new()
		collection_card.name = "CollectionCard"
		collection_card.custom_minimum_size = Vector2(0, 145)
		collection_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		collection_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		collection_card.focus_mode = Control.FOCUS_NONE

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#29483B")
		card_style.border_color = GameManager._get_rarity_color(character.get("rarity", 0))
		card_style.set_corner_radius_all(8)
		card_style.set_border_width_all(3)
		card_style.set_content_margin_all(6)
		collection_card.add_theme_stylebox_override("normal", card_style)
		var hover_style: StyleBoxFlat = card_style.duplicate()
		hover_style.bg_color = Color("#365C49")
		collection_card.add_theme_stylebox_override("hover", hover_style)
		var pressed_style: StyleBoxFlat = card_style.duplicate()
		pressed_style.bg_color = Color("#1F3B2F")
		collection_card.add_theme_stylebox_override("pressed", pressed_style)
		GameManager.apply_button_skin(collection_card)

		# Contenu vertical de la carte
		var card_content := VBoxContainer.new()
		card_content.name = "CardContent"
		card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_content.offset_top = 22
		card_content.add_theme_constant_override("separation", 3)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		collection_card.add_child(card_content)

		# Image du personnage
		var character_image := TextureRect.new()
		character_image.name = "CharacterImage"
		character_image.custom_minimum_size = Vector2(0, 110)
		character_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		character_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		character_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		character_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var image_path := _get_character_preview_path(character)
		if image_path != "":
			var texture := load(image_path) as Texture2D
			if texture != null:
				character_image.texture = texture
			else:
				push_warning("Image introuvable : " + image_path)
		
		card_content.add_child(character_image)

		## Nom du personnage
		#var name_label := Label.new()
		#name_label.text = str(character.get("name", "Inconnu"))
		#name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		#name_label.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_TITLE)
		#name_label.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
		#name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		#name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		#card_content.add_child(name_label)
#
		## Rareté
		#var rarity_label := Label.new()
		#rarity_label.text = "Rareté : " + GameManager._get_rarity_label(character.get("rarity", 0))
		#rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		#rarity_label.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_TEXT)
		#rarity_label.add_theme_color_override("font_color", Color("#F2D58B"))
		#rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		#card_content.add_child(rarity_label)
		
		collection_card.pressed.connect(
			_on_card_pressed.bind(figurine)
		)

		collection_grid.add_child(collection_card)

func _get_character_preview_path(character: Dictionary) -> String:
	var image_name := str(character.get("image", ""))
	var image_stem := image_name.get_basename()
	var preview_name := image_stem + "_preview.png"

	var preview_path := GameManager.CHARACTER_PREVIEW_PATH + preview_name
	if ResourceLoader.exists(preview_path):
		return preview_path
	return GameManager.CHARACTERS_IMAGE_PATH + image_name

func _on_card_pressed(figurine: Dictionary) -> void:
	card_selected.emit(figurine)
	return
