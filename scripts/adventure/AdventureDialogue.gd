extends Control

signal duel_requested(enemy_data: Dictionary)
signal dialogue_closed

var enemy_data: Dictionary = {}
var dialogue_lines: Array = []
var current_line: int = 0

var background: TextureRect
var portrait: TextureRect
var name_label: Label
var title_label: Label
var dialogue_label: Label
var next_button: Button
var back_button: Button


func _ready() -> void:
	_build_interface()


# --------------------------------------------------
# INITIALISATION
# --------------------------------------------------

func configure(data: Dictionary) -> void:
	enemy_data = data
	dialogue_lines = data.get("dialogue_lines", [])

	current_line = 0

	if is_node_ready():
		_update_character()
		_update_dialogue()


func _build_interface() -> void:

	# Fond.
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var background_texture = load(
		"res://assets/backgrounds/adventure_bg.jpg"
	) as Texture2D

	background.texture = background_texture
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Assombrissement du décor.
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.color = Color(0.02, 0.04, 0.03, 0.48)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Organisation principale.
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	layout.add_theme_constant_override("separation", 8)
	layout.add_theme_constant_override("margin_left", 20)
	layout.add_theme_constant_override("margin_right", 20)
	layout.add_theme_constant_override("margin_top", 20)
	layout.add_theme_constant_override("margin_bottom", 20)
	add_child(layout)

	# Bouton retour.
	back_button = Button.new()
	back_button.text = "← Retour à l'aventure"
	back_button.custom_minimum_size = Vector2(0, 45)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(_on_back_pressed)
	layout.add_child(back_button)

	# Présentation du personnage.
	var character_header := VBoxContainer.new()
	character_header.add_theme_constant_override("separation", 3)
	layout.add_child(character_header)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.add_theme_color_override(
		"font_color",
		Color("#E8C77B")
	)
	character_header.add_child(name_label)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override(
		"font_color",
		Color("#FFF0D0")
	)
	character_header.add_child(title_label)

	# Zone du portrait.
	var portrait_container := CenterContainer.new()
	portrait_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(portrait_container)

	portrait = TextureRect.new()

	# Taille maximale souhaitée pour le portrait.
	portrait.custom_minimum_size = Vector2(280, 320)
	portrait.size = Vector2(280, 320)

	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	portrait_container.add_child(portrait)

	# Boîte de dialogue.
	var dialogue_panel := PanelContainer.new()
	dialogue_panel.custom_minimum_size = Vector2(0, 190)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#293B32")
	panel_style.border_color = Color("#C5A45E")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(16)

	dialogue_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	layout.add_child(dialogue_panel)

	var dialogue_layout := VBoxContainer.new()
	dialogue_layout.add_theme_constant_override("separation", 12)
	dialogue_panel.add_child(dialogue_layout)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label.add_theme_font_size_override("font_size", 17)
	dialogue_label.add_theme_color_override(
		"font_color",
		Color("#FFF2D5")
	)
	dialogue_layout.add_child(dialogue_label)

	next_button = Button.new()
	next_button.text = "Continuer"
	next_button.custom_minimum_size = Vector2(0, 48)
	next_button.pressed.connect(_on_next_pressed)
	dialogue_layout.add_child(next_button)

	# Préparation des données.
	if not enemy_data.is_empty():
		_update_character()
		_update_dialogue()


# --------------------------------------------------
# AFFICHAGE DU PERSONNAGE
# --------------------------------------------------

func _update_character() -> void:
	name_label.text = enemy_data.get("name", "Inconnu")
	title_label.text = enemy_data.get("title", "")
	
	var portrait_path: String = enemy_data.get("portrait", "")

	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var loaded_texture := load(portrait_path) as Texture2D
		
		portrait.texture = loaded_texture
		portrait.visible = loaded_texture != null
	else:
		portrait.texture = null
		portrait.visible = false
		push_warning("Portrait introuvable : " + portrait_path)

# --------------------------------------------------
# GESTION DES DIALOGUES
# --------------------------------------------------

func _update_dialogue() -> void:

	if dialogue_lines.is_empty():
		dialogue_label.text = "..."
		next_button.text = "Préparer le duel"
		return

	dialogue_label.text = str(dialogue_lines[current_line])

	if current_line == dialogue_lines.size() - 1:
		next_button.text = "Préparer le duel"
	else:
		next_button.text = "Continuer"


func _on_next_pressed() -> void:

	if dialogue_lines.is_empty():
		_request_duel()
		return

	if current_line < dialogue_lines.size() - 1:
		current_line += 1
		_update_dialogue()
	else:
		_request_duel()

# --------------------------------------------------
# ACTIONS
# --------------------------------------------------

func _request_duel() -> void:
	duel_requested.emit(enemy_data.duplicate(true))


func _on_back_pressed() -> void:
	dialogue_closed.emit()
	queue_free()
