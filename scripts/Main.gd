
extends Control

# Pré-chargement des différentes scènes
const DOORS_GAME_SCENE = preload("res://scenes/DoorsGame.tscn")
const ADVENTURE_MAP_SCENE = preload("res://scenes/adventure/AdventureMap.tscn")
const ADVENTURE_DIALOGUE_SCENE = preload("res://scenes/adventure/AdventureDialogue.tscn")
const CHARACTER_SELECTION_SCENE = preload("res://scenes/battle/CharacterSelection.tscn")
const BATTLE_DEPLOYMENT_SCENE = preload("res://scenes/battle/BattleDeployment.tscn")

const BG_COLOR := Color("54423bff")
const PANEL_COLOR := Color("38305e00")
const ACCENT_COLOR := Color("ffc83cff")
const TEXT_COLOR := Color("#FFF8E7")
const RARITY_COLOR_NORMAL := Color("#a0e3ff")
const RARITY_COLOR_RARE := Color("#7cdc85")
const RARITY_COLOR_SUPERRARE := Color("#c27fd3")
const RARITY_COLOR_ULTRARARE := Color("#ffaa6b")
const RARITY_COLOR_LEGENDARY := Color("#ffef80")
const RARITY_COLOR_DIVINE := Color("4a27b5ff")
const DOORS_ENTRY_COST: int = 10
const CHARACTERS_IMAGE_PATH := "res://assets/characters/"
const CHARACTER_PREVIEW_PATH := "res://assets/characters/previews/"
const BACKGROUNDS_FOLDER := "res://assets/backgrounds/"
const GAMES_TAB_NAME := "Epreuves"
const ADVENTURE_TAB_NAME := "Aventure"
const COLLECTION_TAB_NAME := "Collection"
const SHOP_TAB_NAME := "Boutique"

# Liste des mini-jeux ainsi que leur coût
const MINI_GAMES: Array[Dictionary] = [
	{
		"id": "mystery_doors",
		"name": "Pierres sacrées",
		"cost": DOORS_ENTRY_COST
	}
]

var active_game: Control = null
var doors_game_started: bool = false
var points: int = 0
var current_tab: String = GAMES_TAB_NAME
var points_label: Label
var gems_label: Label
var currency_limit_dialog: AcceptDialog
var recharge_background: PanelContainer
var recharge_label: Label
var content: VBoxContainer
var games_button: Button
var adventure_button: Button
var collection_button: Button
var shop_button: Button
var screen_background: TextureRect

func _ready() -> void:
	_build_interface()

	# Permet de mettre à jour l'affichage des points
	GameManager.points_changed.connect(_on_points_changed)
	GameManager.gems_changed.connect(_on_gems_changed)
	GameManager.currency_limit_reached.connect(_on_currency_limit_reached)
	# On charge les points sauvegardés
	_on_points_changed(GameManager.points)
	_on_gems_changed(GameManager.gems)
	GameManager.collection_changed.connect(_on_collection_changed)

	# Par défaut, on affiche la vue "Mini-jeux"
	_show_games()
	
	# On crée le timer qui va servir à la recharge automatique des points
	var recharge_timer := Timer.new()
	recharge_timer.wait_time = 1.0
	recharge_timer.timeout.connect(_update_recharge_label)
	add_child(recharge_timer)
	recharge_timer.start()

	_update_recharge_label()

# Génère l'interface visuelle
func _build_interface() -> void:
	# Fond couvrant toute la fenêtre.
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BG_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# On rend le fond intangible pour la souris donc même s'il est placé devant d'autres éléments,
	# on pourra quand même cliquer sur ce qu'il y a derrière
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	currency_limit_dialog = AcceptDialog.new()
	currency_limit_dialog.title = "Maximum atteint"
	currency_limit_dialog.ok_button_text = "Fermer"
	GameManager.apply_button_skin(currency_limit_dialog.get_ok_button())
	add_child(currency_limit_dialog)

	# Conteneur extérieur avec de vraies marges.
	var scene_margins := MarginContainer.new()
	scene_margins.name = "SceneMargins"
	scene_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_margins.add_theme_constant_override("margin_left", 20)
	scene_margins.add_theme_constant_override("margin_right", 20)
	scene_margins.add_theme_constant_override("margin_top", 20)
	scene_margins.add_theme_constant_override("margin_bottom", 16)
	add_child(scene_margins)

	# Organisation verticale : en-tête, contenu, navigation.
	var layout := VBoxContainer.new()
	layout.name = "MainLayout"
	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_margins.add_child(layout)

	# En-tête : compteur de points.
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 64)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(header)
	
	# Bloc du compteur : sa taille est indépendante du fond.
	var points_block := Control.new()
	points_block.custom_minimum_size = Vector2(215, 64)
	points_block.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	points_block.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(points_block)

	var gems_background := PanelContainer.new()
	gems_background.custom_minimum_size = Vector2(132, 48)
	gems_background.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gems_style_box := StyleBoxFlat.new()
	gems_style_box.bg_color = BG_COLOR
	gems_style_box.border_color = ACCENT_COLOR
	gems_style_box.set_border_width_all(2)
	gems_style_box.set_corner_radius_all(24)
	gems_style_box.set_content_margin_all(8.0)
	gems_background.add_theme_stylebox_override("panel", gems_style_box)
	header.add_child(gems_background)

	gems_label = Label.new()
	gems_label.text = "💎 " + str(GameManager.gems)
	gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gems_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gems_label.add_theme_color_override("font_color", ACCENT_COLOR)
	gems_label.add_theme_font_size_override("font_size", 18)
	gems_background.add_child(gems_label)

	# Fond fixe.
	var points_background := PanelContainer.new()
	points_background.name = "PointsBackground"
	points_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Marges externes du fond.
	points_background.offset_left = 35
	points_background.offset_right = 0
	points_background.offset_top = 5
	points_background.offset_bottom = -10
	
	var points_bg_style_box := StyleBoxFlat.new()
	points_bg_style_box.bg_color = BG_COLOR
	points_bg_style_box.set_corner_radius_all(25)
	# Contour
	points_bg_style_box.border_color = ACCENT_COLOR
	points_bg_style_box.set_border_width_all(2)
	# Marges internes : espace entre le texte et le fond.
	points_bg_style_box.content_margin_left = 45.0
	points_bg_style_box.content_margin_right = 18.0
	points_bg_style_box.content_margin_top = 10.0
	points_bg_style_box.content_margin_bottom = 10.0
	
	points_background.add_theme_stylebox_override("panel", points_bg_style_box)

	points_block.add_child(points_background)
	
	points_label = Label.new()
	points_label.name = "PointsLabel"
	points_label.text = str(points) + " points"
	points_label.add_theme_color_override("font_color", ACCENT_COLOR)
	points_label.add_theme_font_size_override("font_size", 24)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	points_background.add_child(points_label)
	
	# Contenu indépendant du fond.
	var points_container := HBoxContainer.new()
	points_container.position = Vector2(0, -5)
	points_container.size = Vector2(215, 75)
	points_container.add_theme_constant_override("separation", 8)
	points_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# On dessine le contenu au-dessus du fond.
	points_block.add_child(points_container)
	
	# Ajout de l'icône des points
	var points_icon := TextureRect.new()
	points_icon.custom_minimum_size = Vector2(75, 75)
	points_icon.size = Vector2(75, 75)
	points_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	points_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	points_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On centre l'icône verticalement dans la ligne
	points_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var image_path := "res://assets/icons/points_icon.png"
	var texture := load(image_path) as Texture2D
	
	if texture != null:
		points_icon.texture = texture
	else:
		push_warning("Image introuvable : " + image_path)
	
	points_container.add_child(points_icon)
	
	
	var recharge_container := HBoxContainer.new()
	recharge_container.custom_minimum_size = Vector2(0, 64)
	recharge_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(recharge_container)
	
	recharge_background = PanelContainer.new()
	recharge_background.name = "RechargeContainer"
	recharge_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var recharge_bg_style_box := StyleBoxFlat.new()
	recharge_bg_style_box.bg_color = BG_COLOR
	recharge_bg_style_box.set_corner_radius_all(35)
	# Contour
	recharge_bg_style_box.border_color = ACCENT_COLOR
	recharge_bg_style_box.set_border_width_all(3)
	# Marges internes : espace entre le texte et le fond.
	recharge_bg_style_box.set_content_margin_all(20.0)
	
	recharge_background.add_theme_stylebox_override("panel", recharge_bg_style_box)
	header.add_child(recharge_background)
	
	recharge_label = Label.new()
	recharge_label.text = ""
	recharge_label.add_theme_font_size_override("font_size", 16)
	recharge_label.add_theme_color_override("font_color", ACCENT_COLOR)
	recharge_background.add_child(recharge_label)

	# Zone centrale extensible.
	var center_panel := PanelContainer.new()
	center_panel.name = "CenterPanel"
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override(
		"panel", _make_panel_style(PANEL_COLOR, 20)
	)
	layout.add_child(center_panel)

	# Conteneur général de l'écran
	var content_area := Control.new()
	content_area.name = "ContentArea"
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(content_area)

	# Image de fond
	var minigames_background := TextureRect.new()
	minigames_background.name = "ScreenBackground"
	minigames_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minigames_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minigames_background.stretch_mode = TextureRect.STRETCH_SCALE
	minigames_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(minigames_background)
	screen_background = minigames_background

	# Conteneur des éléments de l'écran
	content = VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 16)
	content_area.add_child(content)

	# Navigation permanente en bas.
	var navigation := HBoxContainer.new()
	navigation.name = "BottomNavigation"
	navigation.custom_minimum_size = Vector2(0, 68)
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_theme_constant_override("separation", 8)
	layout.add_child(navigation)

	games_button = _make_nav_button(GAMES_TAB_NAME)
	adventure_button = _make_nav_button(ADVENTURE_TAB_NAME)
	collection_button = _make_nav_button(COLLECTION_TAB_NAME)
	shop_button = _make_nav_button(SHOP_TAB_NAME)

	navigation.add_child(games_button)
	navigation.add_child(adventure_button)
	navigation.add_child(collection_button)
	navigation.add_child(shop_button)

	# Création des évènements de type "Clique" pour changer de vue sur le menu principal
	games_button.pressed.connect(_show_games)
	adventure_button.pressed.connect(_show_adventure)
	collection_button.pressed.connect(_show_collection)
	shop_button.pressed.connect(_show_shop)

# Permet de créer un bouton avec un texte personalisé
func _make_nav_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_stylebox_override(
		"normal", _make_panel_style(Color("#514477"), 14)
	)
	button.add_theme_stylebox_override(
		"hover", _make_panel_style(Color("#6B5896"), 14)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_panel_style(ACCENT_COLOR, 14)
	)
	GameManager.apply_button_skin(button)
	return button

# Permet de créer un cadre de couleur avec des coins arrondis
func _make_panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

# Supprime la partie centrale de l'interface afin de charger une autre vue
func _clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

# Génère la vue "Aventure" permettant de faire le mode histoire
func _show_adventure() -> void:
	_refund_unplayed_game()
	current_tab = ADVENTURE_TAB_NAME
	_clear_content()
	
	# screen_background.texture = load(BACKGROUNDS_FOLDER + "adventure_bg.jpg")
	
	#var title := Label.new()
	#title.text = current_tab
	#title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#title.add_theme_font_size_override("font_size", 28)
	#title.add_theme_color_override("font_color", TEXT_COLOR)
	#content.add_child(title)
	var adventure_map = ADVENTURE_MAP_SCENE.instantiate()
	
	adventure_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adventure_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	adventure_map.stage_selected.connect(
		_on_adventure_stage_selected
	)
	
	content.add_child(adventure_map)

# Réagit à la sélection d'une étape.
func _on_adventure_stage_selected(
	stage_id: String,
	enemy_data: Dictionary
) -> void:

	_clear_content()

	var dialogue = ADVENTURE_DIALOGUE_SCENE.instantiate()

	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	dialogue.dialogue_closed.connect(_show_adventure)

	dialogue.duel_requested.connect(_on_dialogue_duel_requested)

	content.add_child(dialogue)

	dialogue.configure(enemy_data)


func _on_dialogue_duel_requested(enemy_data: Dictionary) -> void:
	_clear_content()

	var selection = CHARACTER_SELECTION_SCENE.instantiate()

	content.add_child(selection)

	selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.size_flags_vertical = Control.SIZE_EXPAND_FILL

	selection.team_confirmed.connect(_on_team_confirmed)

	selection.configure(enemy_data)

func _on_team_confirmed(enemy_data: Dictionary, selected_instance_ids: Array) -> void:
	_clear_content()
	
	var deployment = BATTLE_DEPLOYMENT_SCENE.instantiate()
	
	content.add_child(deployment)
	
	deployment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deployment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deployment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deployment.return_to_adventure_requested.connect(_show_adventure)
	
	deployment.configure(enemy_data, selected_instance_ids)

# Génère la vue "Mini-jeux" contenant la liste de tous les mini-jeux
func _show_games() -> void:
	_refund_unplayed_game()
	current_tab = GAMES_TAB_NAME
	_clear_content()
	
	screen_background.texture = load(BACKGROUNDS_FOLDER + "minigames_bg.jpg")
	
	var title := Label.new()
	title.text = current_tab
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(title)

	var description := Label.new()
	description.text = "Choisis ta prochaine épreuve, aventurier."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(description)

	# On affiche la liste des mini-jeux
	for mini_game in MINI_GAMES:
		var game_button := Button.new()
		game_button.text = "%s  —  %d points" % [
			mini_game["name"],
			mini_game["cost"]
		]
		game_button.custom_minimum_size = Vector2(0, 100)
		game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game_button.add_theme_font_size_override("font_size", 22)
		GameManager.apply_button_skin(game_button)

		if mini_game["id"] == "mystery_doors":
			game_button.pressed.connect(_show_not_enough_credit)

		content.add_child(game_button)

# Prépare la vue pour le mini-jeu des portes
func _show_not_enough_credit() -> void:
	if not GameManager.spend_points(DOORS_ENTRY_COST):
		_clear_content()

		var message := Label.new()
		message.text = "Pas assez de points !"
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(message)

		var balance_label := Label.new()
		balance_label.text = "Il te faut 10 points pour jouer."
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(balance_label)

		var back_button := Button.new()
		back_button.text = "Retour aux mini-jeux"
		back_button.pressed.connect(_show_games)
		GameManager.apply_button_skin(back_button)
		content.add_child(back_button)
		return
	
	_create_doors_game_instance()

# Génère le jeu des portes
func _create_doors_game_instance() -> void:
	GameManager.recharge_paused = true
	_clear_content()

	var doors_game = DOORS_GAME_SCENE.instantiate()
	doors_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doors_game.size_flags_vertical = Control.SIZE_EXPAND_FILL

	doors_game.points_earned.connect(_on_points_earned)
	doors_game.back_requested.connect(_show_games)
	doors_game.game_started.connect(_on_doors_game_started)
	doors_game.replay_requested.connect(_on_doors_replay_requested)

	content.add_child(doors_game)

	active_game = doors_game
	doors_game_started = false

# Ajoute un certain nombre de points au compteur du joueur
func _on_points_earned(amount: int) -> void:
	GameManager.add_points(amount)

# Charge la vue "Collection"
func _show_collection() -> void:
	_refund_unplayed_game()
	current_tab = COLLECTION_TAB_NAME
	_clear_content()
	
	screen_background.texture = load(BACKGROUNDS_FOLDER + "collection_bg.jpg")

	var title := Label.new()
	title.text = current_tab
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	content.add_child(title)

	var figurines: Array = GameManager.get_collection()

	var count_label := Label.new()
	count_label.text = str(figurines.size()) + " figurine(s) possédée(s)"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(count_label)

	if figurines.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Ta collection est vide !\nVa dans la Boutique pour obtenir ta première figurine."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_color_override("font_color", TEXT_COLOR)
		content.add_child(empty_label)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for figurine in figurines:
		var character_id := str(figurine.get("character_id", ""))
		var character: Dictionary = GameManager.get_character_data(character_id)

		if character.is_empty():
			continue
		
		# Carte du personnage
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 145)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.focus_mode = Control.FOCUS_NONE

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#29483B")
		card_style.border_color = _get_rarity_color(character.get("rarity", 0))
		card_style.set_corner_radius_all(8)
		card_style.set_border_width_all(3)
		card_style.set_content_margin_all(6)
		card.add_theme_stylebox_override("normal", card_style)
		var hover_style: StyleBoxFlat = card_style.duplicate()
		hover_style.bg_color = Color("#365C49")
		card.add_theme_stylebox_override("hover", hover_style)
		var pressed_style: StyleBoxFlat = card_style.duplicate()
		pressed_style.bg_color = Color("#1F3B2F")
		card.add_theme_stylebox_override("pressed", pressed_style)
		GameManager.apply_button_skin(card)

		# Contenu vertical de la carte
		var card_content := VBoxContainer.new()
		card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_content.add_theme_constant_override("separation", 3)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(card_content)

		# Image du personnage
		var character_image := TextureRect.new()
		character_image.custom_minimum_size = Vector2(0, 76)
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

		# Nom du personnage
		var name_label := Label.new()
		name_label.text = str(character.get("name", "Inconnu"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(name_label)

		# Rareté
		var rarity_label := Label.new()
		rarity_label.text = "Rareté : " + _get_rarity_label(character.get("rarity", 0))
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.add_theme_font_size_override("font_size", 10)
		rarity_label.add_theme_color_override("font_color", Color("#F2D58B"))
		rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(rarity_label)

		# Ouvrir les détails au clic
		card.pressed.connect(
			_show_figurine_details.bind(figurine.duplicate(true))
		)

		grid.add_child(card)

func _get_rarity_label(character_rarity_lvl: int) -> String:
	var rarity_label: String
	if character_rarity_lvl == 1:
		rarity_label = "Normale"
	elif character_rarity_lvl == 2:
		rarity_label = "Rare"
	elif character_rarity_lvl == 3:
		rarity_label = "Super rare"
	elif character_rarity_lvl == 4:
		rarity_label = "Ultra rare"
	elif character_rarity_lvl == 5:
		rarity_label = "Légendaire"
	elif character_rarity_lvl == 6:
		rarity_label = "Divin"
	else:
		rarity_label = "?"
		
	return rarity_label
	
func _get_rarity_color(character_rarity_lvl: int) -> Color:
	var rarity_color: Color
	if character_rarity_lvl == 1:
		rarity_color = RARITY_COLOR_NORMAL
	elif character_rarity_lvl == 2:
		rarity_color = RARITY_COLOR_RARE
	elif character_rarity_lvl == 3:
		rarity_color = RARITY_COLOR_SUPERRARE
	elif character_rarity_lvl == 4:
		rarity_color = RARITY_COLOR_ULTRARARE
	elif character_rarity_lvl == 5:
		rarity_color = RARITY_COLOR_LEGENDARY
	elif character_rarity_lvl == 6:
		rarity_color = RARITY_COLOR_DIVINE
	else:
		rarity_color = Color("#000000")
		
	return rarity_color

func _get_character_preview_path(character: Dictionary) -> String:
	var image_name := str(character.get("image", ""))
	var image_stem := image_name.get_basename()
	var preview_name := image_stem + "_preview.png"

	var preview_path := CHARACTER_PREVIEW_PATH + preview_name
	if ResourceLoader.exists(preview_path):
		return preview_path
	return CHARACTERS_IMAGE_PATH + image_name

# Charge la vue "Détail de figurine"
func _show_figurine_details(figurine: Dictionary) -> void:
	_clear_content()

	var character_id := str(figurine.get("character_id", ""))
	var character: Dictionary = GameManager.get_character_data(character_id)

	if character.is_empty():
		_show_collection()
		return

	var title := Label.new()
	title.text = str(character.get("name", "Inconnu"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	content.add_child(title)
	
	# Zone réservée à l'image : elle ne peut pas empiéter sur le titre
	var image_area := Control.new()
	image_area.custom_minimum_size = Vector2(0, 520)
	image_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(image_area)
	
	# Illustration du personnage
	var character_image := TextureRect.new()
	character_image.custom_minimum_size = Vector2(480, 480)
	character_image.size = Vector2(480, 480)
	character_image.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	character_image.position = Vector2(-240, -230)
	character_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	character_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var image_path: String = CHARACTERS_IMAGE_PATH + str(character.get("image", ""))
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
	#var float_tween := create_tween()
	#float_tween.set_loops(0)
	#float_tween.set_trans(Tween.TRANS_SINE)
	#float_tween.set_ease(Tween.EASE_IN_OUT)
	#float_tween.bind_node(character_image)
#
	#float_tween.tween_property(
		#character_image,
		#"position:y",
		#10.0,
		#1.0
	#)
	#float_tween.tween_property(
		#character_image,
		#"position:y",
		#22.0,
		#1.0
	#)

	var rarity := Label.new()
	rarity.text = "Rareté : " + _get_rarity_label(character.get("rarity", 0))
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_font_size_override("font_size", 19)
	rarity.add_theme_color_override("font_color",_get_rarity_color(character.get("rarity", 0)))
	content.add_child(rarity)

	var desc_container := PanelContainer.new()
	desc_container.name = "DescriptionContainer"
	desc_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(desc_container)
	
	var desc_margins := MarginContainer.new()
	desc_margins.name = "DescriptionMargins"
	desc_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desc_margins.add_theme_constant_override("margin_left", 20)
	desc_margins.add_theme_constant_override("margin_right", 20)
	desc_margins.add_theme_constant_override("margin_top", 20)
	desc_margins.add_theme_constant_override("margin_bottom", 16)
	desc_container.add_child(desc_margins)

	var description := Label.new()
	description.text = str(character.get("description", "Aucune description."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", TEXT_COLOR)
	desc_margins.add_child(description)

	var sell_value := int(character.get("sell_value", 0))

	var sell_button := Button.new()
	sell_button.text = "Vendre pour " + str(sell_value) + " points"
	sell_button.custom_minimum_size = Vector2(0, 50)
	sell_button.pressed.connect(
		_sell_figurine.bind(
			int(figurine.get("instance_id", -1)),
			sell_value
		)
	)
	GameManager.apply_button_skin(sell_button)
	content.add_child(sell_button)

	var back_button := Button.new()
	back_button.text = "← Retour à la collection"
	back_button.custom_minimum_size = Vector2(0, 45)
	back_button.pressed.connect(_show_collection)
	GameManager.apply_button_skin(back_button)
	content.add_child(back_button)

# Permet de revendre une figurine et de regagner des points
func _sell_figurine(instance_id: int, sell_value: int) -> void:
	if sell_value < 0:
		return

	var removed: Dictionary = GameManager.remove_figurine(instance_id)

	if removed.is_empty():
		return

	GameManager.add_points(sell_value)
	_show_collection()

# Charge la vue "Boutique"
func _show_shop() -> void:
	_refund_unplayed_game()
	current_tab = SHOP_TAB_NAME
	_clear_content()
	
	screen_background.texture = load(BACKGROUNDS_FOLDER + "shop_bg.jpg")

	var title := Label.new()
	title.text = current_tab
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ouvre un pack et découvre tes figurines !"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(subtitle)

	_add_pack_button(
		"🎁 MiniPack",
		"1 figurine · 5 points",
		"mini"
	)
	_add_pack_button(
		"🎉 SuperPack",
		"3 figurines · 20 points",
		"super"
	)
	_add_pack_button(
		"🌟 MaxiPack",
		"5 figurines · 40 points",
		"maxi"
	)

# Génère un bouton dont le texte est personalisable
func _add_pack_button(
	pack_title: String,
	pack_description: String,
	pack_id: String
	) -> void:
	var button := Button.new()
	button.text = pack_title + "\n" + pack_description
	button.custom_minimum_size = Vector2(0, 90)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(_buy_pack.bind(pack_id))
	GameManager.apply_button_skin(button)
	content.add_child(button)

# Permet d'acheter un pack
func _buy_pack(pack_id: String) -> void:
	# On charge la liste des personnages
	var result: Dictionary = GameManager.purchase_pack(pack_id)
	_show_pack_results(result)

# Charge la vue "Personnage obtenus"
func _show_pack_results(result: Dictionary) -> void:
	_clear_content()

	var title := Label.new()
	title.text = "✨ Résultat du tirage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	content.add_child(title)

	var message := Label.new()
	message.text = str(result.get("message", ""))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(message)

	var obtained: Array = result.get("figurines", [])

	if bool(result.get("success", false)):
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(scroll)

		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 10)
		scroll.add_child(list)

		for figurine in obtained:
			var character: Dictionary = GameManager.get_character_data(str(figurine.get("character_id", "")))

			if character.is_empty():
				continue

			var card := PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var color := _get_rarity_color(character.get("rarity", 0))
			card.add_theme_stylebox_override("panel", _make_panel_style(color, 12))
			list.add_child(card)

			var character_label := Label.new()
			character_label.text = (
				str(character.get("name", "Inconnu"))
				+ "\n"
				+ _get_rarity_label(character.get("rarity", 0))
			)
			character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			character_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			character_label.add_theme_font_size_override("font_size", 18)
			card.add_child(character_label)

	var return_shop_button := Button.new()
	return_shop_button.text = "← Retour à la boutique"
	return_shop_button.custom_minimum_size = Vector2(0, 48)
	return_shop_button.pressed.connect(_show_shop)
	GameManager.apply_button_skin(return_shop_button)
	content.add_child(return_shop_button)

	var view_collection_button := Button.new()
	view_collection_button.text = "🧸 Voir ma collection"
	view_collection_button.custom_minimum_size = Vector2(0, 48)
	view_collection_button.pressed.connect(_show_collection)
	GameManager.apply_button_skin(view_collection_button)
	content.add_child(view_collection_button)

# Permet de vérifier si les points ont besoin d'une recharge (en dessous de 10 points) ou pas
func _on_points_changed(new_total: int) -> void:
	points = new_total
	
	if is_instance_valid(points_label):
		points_label.text = str(points) + " points"
	
	_update_recharge_label()

func _on_gems_changed(new_total: int) -> void:
	if is_instance_valid(gems_label):
		gems_label.text = "💎 " + str(new_total)

func _on_currency_limit_reached(currency_name: String) -> void:
	var currency_label := "points" if currency_name == "points" else "gemmes"
	currency_limit_dialog.dialog_text = (
		"Le nombre maximal de " + currency_label
		+ " (999 999) est atteint."
	)
	currency_limit_dialog.popup_centered(Vector2i(360, 140))

# Permet de recharger la collection si jamais elle est modifiée pendant qu'on est sur la vue Collection
func _on_collection_changed() -> void:
	if current_tab == COLLECTION_TAB_NAME:
		_show_collection()

# Permet de savoir si le jeu des portes à réellement démarré ou pas (pour le remboursement du joueur
# en cas d'abandon avant d'avoir joué)
func _on_doors_game_started() -> void:
	doors_game_started = true
	GameManager.recharge_paused = false

# Permet de vérifier si le joueur a assez de points pour relancer une partie directement
func _on_doors_replay_requested() -> void:
	if not GameManager.spend_points(DOORS_ENTRY_COST):
		# Pas assez de points : on ne relance pas la partie.
		if is_instance_valid(active_game):
			active_game.show_insufficient_points_message()
		return

	# Le paiement est effectué : on crée une nouvelle partie.
	_create_doors_game_instance()

# Permet de rembourser le joueur si jamais il quitte un jeu avant de l'avoir réellement commencé
func _refund_unplayed_game() -> void:
	if not is_instance_valid(active_game):
		GameManager.recharge_paused = false
		return

	if not doors_game_started:
		GameManager.add_points(DOORS_ENTRY_COST)

	GameManager.recharge_paused = false
	active_game = null
	doors_game_started = false

# Permet de mettre à jour le message de recharge automatique des points
func _update_recharge_label() -> void:
	if not is_instance_valid(recharge_background):
		return

	if GameManager.points >= GameManager.RECHARGE_THRESHOLD:
		recharge_background.visible = false
		return

	recharge_background.visible = true

	if GameManager.recharge_paused:
		recharge_label.text = "⏳ Recharge en pause"
		return

	var now := int(Time.get_unix_time_from_system())
	var remaining: int = maxi(
		0,
		GameManager.recharge_ready_at - now
	)

	var minutes := int(remaining / 60)
	var seconds := remaining % 60

	recharge_label.text = "⏳ Recharge dans %02d:%02d" % [
		minutes,
		seconds
	]
