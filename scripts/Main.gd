
extends Control

# Pré-chargement des différentes scènes
const DOORS_GAME_SCENE = preload("res://scenes/DoorsGame.tscn")
const COLLECTION_SCENE = preload("res://scenes/collection/Collection.tscn")
const FIGURE_DETAILS_SCENE = preload("res://scenes/collection/FigureDetails.tscn")
const ADVENTURE_MAP_SCENE = preload("res://scenes/adventure/AdventureMap.tscn")
const ADVENTURE_DIALOGUE_SCENE = preload("res://scenes/adventure/AdventureDialogue.tscn")
const CHARACTER_SELECTION_SCENE = preload("res://scenes/battle/CharacterSelection.tscn")
const BATTLE_DEPLOYMENT_SCENE = preload("res://scenes/battle/BattleDeployment.tscn")

const BG_COLOR := Color("54423bff")
const PANEL_COLOR := Color("38305e00")
const ACCENT_COLOR := Color("ffc83cff")
const DOORS_ENTRY_COST: int = 10
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
var content_area: Control
var center_panel: PanelContainer
var center_panel_style: StyleBoxFlat
var games_button: Button
var adventure_button: Button
var collection_button: Button
var shop_button: Button
var screen_background: TextureRect
var current_stage_id: String = ""

func _ready() -> void:
	var game_theme := Theme.new()
	if GameManager.ui_font != null:
		game_theme.default_font = GameManager.ui_font
	game_theme.default_font_size = GameManager.FONT_SIZE_TEXT
	theme = game_theme
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
	recharge_timer.name = "RechargeTimer"
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
	currency_limit_dialog.name = "CurrencyLimitDialog"
	currency_limit_dialog.title = "Maximum atteint"
	currency_limit_dialog.ok_button_text = "Fermer"
	GameManager.apply_button_skin(currency_limit_dialog.get_ok_button())
	add_child(currency_limit_dialog)

	# Conteneur extérieur avec de vraies marges.
	var scene_margins := MarginContainer.new()
	scene_margins.name = "SceneMargins"
	scene_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_margins.add_theme_constant_override("margin_left", 0)
	scene_margins.add_theme_constant_override("margin_right", 0)
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
	var main_header_margin := MarginContainer.new()
	main_header_margin.name = "MainHeader"
	main_header_margin.custom_minimum_size = Vector2(0, 90)
	main_header_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_header_margin.add_theme_constant_override("margin_left", 20)
	main_header_margin.add_theme_constant_override("margin_right", 20)
	layout.add_child(main_header_margin)

	var main_header := HBoxContainer.new()
	main_header.name = "MainHeaderLayout"
	main_header.custom_minimum_size = Vector2(0, 64)
	main_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_header_margin.add_child(main_header)
	
	# Bloc du compteur de points : sa taille est indépendante du fond.
	var points_block := Control.new()
	points_block.name = "PointsCounter"
	points_block.custom_minimum_size = Vector2(220, 64)
	points_block.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	points_block.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_header.add_child(points_block)

	# Fond fixe.
	var points_background := PanelContainer.new()
	points_background.name = "PointsBackground"
	points_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Marges externes du fond.
	points_background.offset_left = 60
	points_background.offset_right = 0
	points_background.offset_top = 15
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
	points_label.text = _add_missing_zeros(points)
	points_label.add_theme_color_override("font_color", ACCENT_COLOR)
	points_label.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_TITLE)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	points_background.add_child(points_label)
	
	# Contenu indépendant du fond.
	var points_container := HBoxContainer.new()
	points_container.name = "PointsIconContainer"
	points_container.position = Vector2(0, -5)
	points_container.size = Vector2(215, 75)
	points_container.add_theme_constant_override("separation", 8)
	points_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# On dessine le contenu au-dessus du fond.
	points_block.add_child(points_container)
	
	# Ajout de l'icône des points
	var points_icon := TextureRect.new()
	points_icon.name = "PointsIcon"
	points_icon.custom_minimum_size = Vector2(100, 100)
	points_icon.size = Vector2(100, 100)
	points_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	points_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	points_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On centre l'icône verticalement dans la ligne
	points_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var points_icon_path := "res://assets/icons/points_icon.png"
	var points_texture := load(points_icon_path) as Texture2D
	
	if points_texture != null:
		points_icon.texture = points_texture
	else:
		push_warning("Image introuvable : " + points_icon_path)
	
	points_container.add_child(points_icon)
	
	var gems_block_margin := MarginContainer.new()
	gems_block_margin.name = "GemsCounterMargin"
	gems_block_margin.custom_minimum_size = Vector2(0, 68)
	gems_block_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gems_block_margin.add_theme_constant_override("margin_left", 20)
	gems_block_margin.add_theme_constant_override("margin_right", 20)
	main_header.add_child(gems_block_margin)
	
	# Bloc du compteur de gemmes : sa taille est indépendante du fond.
	var gems_block := Control.new()
	gems_block.name = "GemsCounter"
	gems_block.custom_minimum_size = Vector2(220, 64)
	gems_block.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	gems_block.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gems_block_margin.add_child(gems_block)
	
	# Fond fixe.
	var gems_background := PanelContainer.new()
	gems_background.name = "GemsBackground"
	gems_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Marges externes du fond.
	gems_background.offset_left = 60
	gems_background.offset_right = 0
	gems_background.offset_top = 15
	gems_background.offset_bottom = -10
	
	var gems_bg_style_box := StyleBoxFlat.new()
	gems_bg_style_box.bg_color = BG_COLOR
	gems_bg_style_box.set_corner_radius_all(25)
	# Contour
	gems_bg_style_box.border_color = ACCENT_COLOR
	gems_bg_style_box.set_border_width_all(2)
	# Marges internes : espace entre le texte et le fond.
	gems_bg_style_box.content_margin_left = 45.0
	gems_bg_style_box.content_margin_right = 18.0
	gems_bg_style_box.content_margin_top = 10.0
	gems_bg_style_box.content_margin_bottom = 10.0
	
	gems_background.add_theme_stylebox_override("panel", gems_bg_style_box)

	gems_block.add_child(gems_background)
	
	gems_label = Label.new()
	gems_label.name = "GemsLabel"
	gems_label.text = _add_missing_zeros(GameManager.gems)
	gems_label.add_theme_color_override("font_color", ACCENT_COLOR)
	gems_label.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_TITLE)
	gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gems_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	gems_background.add_child(gems_label)
	
	# Contenu indépendant du fond.
	var gems_container := HBoxContainer.new()
	gems_container.name = "GemsIconContainer"
	gems_container.position = Vector2(0, -5)
	gems_container.size = Vector2(215, 75)
	gems_container.add_theme_constant_override("separation", 8)
	gems_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# On dessine le contenu au-dessus du fond.
	gems_block.add_child(gems_container)
	
	# Ajout de l'icône des points
	var gems_icon := TextureRect.new()
	gems_icon.name = "GemsIcon"
	gems_icon.custom_minimum_size = Vector2(100, 100)
	gems_icon.size = Vector2(100, 100)
	gems_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gems_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	gems_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On centre l'icône verticalement dans la ligne
	gems_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var gems_icon_path := "res://assets/icons/gems_icon.png"
	var gems_texture := load(gems_icon_path) as Texture2D
	
	if gems_texture != null:
		gems_icon.texture = gems_texture
	else:
		push_warning("Image introuvable : " + gems_icon_path)
	
	gems_container.add_child(gems_icon)
	
	var recharge_container := HBoxContainer.new()
	recharge_container.name = "RechargeContainer"
	recharge_container.custom_minimum_size = Vector2(0, 64)
	recharge_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_header.add_child(recharge_container)
	
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
	main_header.add_child(recharge_background)
	
	recharge_label = Label.new()
	recharge_label.name = "RechargeLabel"
	recharge_label.text = ""
	recharge_label.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_TEXT)
	recharge_label.add_theme_color_override("font_color", ACCENT_COLOR)
	recharge_background.add_child(recharge_label)

	# Zone centrale extensible.
	center_panel = PanelContainer.new()
	center_panel.name = "CenterPanel"
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel_style = _make_panel_style(PANEL_COLOR, 20)
	center_panel_style.content_margin_left = 0
	center_panel_style.content_margin_right = 32
	center_panel.add_theme_stylebox_override("panel", center_panel_style)
	layout.add_child(center_panel)

	# Conteneur général de l'écran
	content_area = Control.new()
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
	var navigation_margin := MarginContainer.new()
	navigation_margin.name = "NavigationMargin"
	navigation_margin.custom_minimum_size = Vector2(0, 68)
	navigation_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_margin.add_theme_constant_override("margin_left", 20)
	navigation_margin.add_theme_constant_override("margin_right", 20)
	layout.add_child(navigation_margin)

	var navigation := HBoxContainer.new()
	navigation.name = "BottomNavigation"
	navigation.custom_minimum_size = Vector2(0, 68)
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_theme_constant_override("separation", 8)
	navigation_margin.add_child(navigation)

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
	button.name = "GenericButton"
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_BUTTON)
	button.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
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
	_set_adventure_content_full_width(false)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _set_adventure_content_full_width(enabled: bool) -> void:
	var horizontal_margin := 0 if enabled else 32
	center_panel_style.content_margin_left = horizontal_margin
	center_panel_style.content_margin_right = horizontal_margin
	center_panel.add_theme_stylebox_override("panel", center_panel_style)

# Génère la vue "Aventure" permettant de faire le mode histoire
func _show_adventure() -> void:
	_refund_unplayed_game()
	current_tab = ADVENTURE_TAB_NAME
	_clear_content()
	_set_adventure_content_full_width(true)
	
	# screen_background.texture = load(BACKGROUNDS_FOLDER + "adventure_bg.jpg")
	
	var adventure_map = ADVENTURE_MAP_SCENE.instantiate()
	
	adventure_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adventure_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	adventure_map.stage_selected.connect(
		_on_adventure_stage_selected
	)
	
	content.add_child(adventure_map)

# Réagit à la sélection d'une étape.
func _on_adventure_stage_selected(stage_id: String, enemy_data: Dictionary) -> void:
	current_stage_id = stage_id

	_clear_content()
	_set_adventure_content_full_width(true)

	var dialogue = ADVENTURE_DIALOGUE_SCENE.instantiate()

	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	dialogue.dialogue_closed.connect(_show_adventure)

	dialogue.duel_requested.connect(_on_dialogue_duel_requested)

	content.add_child(dialogue)

	dialogue.configure(enemy_data)

func _on_dialogue_duel_requested(enemy_data: Dictionary) -> void:
	_clear_content()
	_set_adventure_content_full_width(true)

	var selection = CHARACTER_SELECTION_SCENE.instantiate()

	content.add_child(selection)

	selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.size_flags_vertical = Control.SIZE_EXPAND_FILL

	selection.team_confirmed.connect(_on_team_confirmed)

	selection.configure(enemy_data)

func _on_team_confirmed(enemy_data: Dictionary, selected_instance_ids: Array) -> void:
	_clear_content()
	_set_adventure_content_full_width(true)
	
	var deployment = BATTLE_DEPLOYMENT_SCENE.instantiate()
	
	content.add_child(deployment)
	
	deployment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deployment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deployment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deployment.return_to_adventure_requested.connect(_show_adventure)
	
	deployment.configure(enemy_data, selected_instance_ids, current_stage_id)

# Génère la vue "Mini-jeux" contenant la liste de tous les mini-jeux
func _show_games() -> void:
	_refund_unplayed_game()
	current_tab = GAMES_TAB_NAME
	_clear_content()
	
	screen_background.texture = load(BACKGROUNDS_FOLDER + "minigames_bg.jpg")
	
	content.add_child(GameManager.create_title_header(current_tab, 28))

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Choisis ta prochaine épreuve, aventurier."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
	content.add_child(subtitle)

	# On affiche la liste des mini-jeux
	for mini_game in MINI_GAMES:
		var mini_game_button := Button.new()
		mini_game_button.name = "MiniGameButton"
		mini_game_button.text = "%s  —  %d points" % [
			mini_game["name"],
			mini_game["cost"]
		]
		mini_game_button.custom_minimum_size = Vector2(0, 100)
		mini_game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mini_game_button.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_BUTTON)
		GameManager.apply_button_skin(mini_game_button)

		if mini_game["id"] == "mystery_doors":
			mini_game_button.pressed.connect(_show_not_enough_credit)

		content.add_child(mini_game_button)

# Prépare la vue pour le mini-jeu des portes
func _show_not_enough_credit() -> void:
	if not GameManager.spend_points(DOORS_ENTRY_COST):
		_clear_content()

		var not_enough_credit_label := Label.new()
		not_enough_credit_label.name = "NotEnoughCreditLabel"
		not_enough_credit_label.text = "Pas assez de points !"
		not_enough_credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(not_enough_credit_label)

		var balance_label := Label.new()
		balance_label.name = "BalanceLabel"
		balance_label.text = "Il te faut 10 points pour jouer."
		balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(balance_label)

		var back_button := Button.new()
		back_button.name = "BackButton"
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

	var collection_scene = COLLECTION_SCENE.instantiate()
	
	collection_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Ouvrir les détails au clic
	collection_scene.card_selected.connect(
		_show_figurine_details
	)
	
	content.add_child(collection_scene)

# Charge la vue "Détail de figurine"
func _show_figurine_details(figurine: Dictionary) -> void:
	_clear_content()

	var character_id := str(figurine.get("character_id", ""))
	var character: Dictionary = GameManager.get_character_data(character_id)

	if character.is_empty():
		_show_collection()
		return
		
	var figure_details_scene = FIGURE_DETAILS_SCENE.instantiate()
	
	figure_details_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure_details_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	figure_details_scene.configure(character, figurine)
	
	figure_details_scene.back_from_figure_details.connect(
		_show_collection
	)
	
	content.add_child(figure_details_scene)

# Charge la vue "Boutique"
func _show_shop() -> void:
	_refund_unplayed_game()
	current_tab = SHOP_TAB_NAME
	_clear_content()
	
	screen_background.texture = load(BACKGROUNDS_FOLDER + "shop_bg.jpg")

	content.add_child(GameManager.create_title_header(current_tab, 25))

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Ouvre un pack et découvre tes figurines !"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
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
	var pack_button := Button.new()
	pack_button.name = "PackButton"
	pack_button.text = pack_title + "\n" + pack_description
	pack_button.custom_minimum_size = Vector2(0, 90)
	pack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_button.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_BUTTON)
	pack_button.pressed.connect(_buy_pack.bind(pack_id))
	GameManager.apply_button_skin(pack_button)
	content.add_child(pack_button)

# Permet d'acheter un pack
func _buy_pack(pack_id: String) -> void:
	# On charge la liste des personnages
	var result: Dictionary = GameManager.purchase_pack(pack_id)
	_show_pack_results(result)

# Charge la vue "Personnage obtenus"
func _show_pack_results(result: Dictionary) -> void:
	_clear_content()

	content.add_child(GameManager.create_title_header("✨ Résultat du tirage", 24))

	var pack_results_message := Label.new()
	pack_results_message.name = "PackResultsMessage"
	pack_results_message.text = str(result.get("message", ""))
	pack_results_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_results_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pack_results_message.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_SUBTITLE)
	pack_results_message.add_theme_color_override("font_color", GameManager.TEXT_COLOR)
	content.add_child(pack_results_message)

	var obtained: Array = result.get("figurines", [])

	if bool(result.get("success", false)):
		var scroll_container := ScrollContainer.new()
		scroll_container.name = "ScrollContainer"
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(scroll_container)

		var obtained_pack_list := VBoxContainer.new()
		obtained_pack_list.name = "ObtainedPacksList"
		obtained_pack_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		obtained_pack_list.add_theme_constant_override("separation", 10)
		scroll_container.add_child(obtained_pack_list)

		for figurine in obtained:
			var character: Dictionary = GameManager.get_character_data(str(figurine.get("character_id", "")))

			if character.is_empty():
				continue

			var obtained_pack_card := PanelContainer.new()
			obtained_pack_card.name = "ObtainedPackCard"
			obtained_pack_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var color := GameManager._get_rarity_color(character.get("rarity", 0))
			obtained_pack_card.add_theme_stylebox_override("panel", _make_panel_style(color, 12))
			obtained_pack_list.add_child(obtained_pack_card)

			var character_name := Label.new()
			character_name.name = "CharacterName"
			character_name.text = (
				str(character.get("name", "Inconnu"))
				+ "\n"
				+ GameManager._get_rarity_label(character.get("rarity", 0))
			)
			character_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			character_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			character_name.add_theme_font_size_override("font_size", GameManager.FONT_SIZE_TEXT)
			obtained_pack_card.add_child(character_name)

	var return_shop_button := Button.new()
	return_shop_button.name = "ReturnShopButton"
	return_shop_button.text = "← Retour à la boutique"
	return_shop_button.custom_minimum_size = Vector2(0, 48)
	return_shop_button.pressed.connect(_show_shop)
	GameManager.apply_button_skin(return_shop_button)
	content.add_child(return_shop_button)

	var view_collection_button := Button.new()
	view_collection_button.name = "ViewCollectionButton"
	view_collection_button.text = "Voir ma collection"
	view_collection_button.custom_minimum_size = Vector2(0, 48)
	view_collection_button.pressed.connect(_show_collection)
	GameManager.apply_button_skin(view_collection_button)
	content.add_child(view_collection_button)

# Permet de vérifier si les points ont besoin d'une recharge (en dessous de 10 points) ou pas
func _on_points_changed(new_total: int) -> void:
	points = new_total
	
	if is_instance_valid(points_label):
		points_label.text = _add_missing_zeros(points)
	
	_update_recharge_label()

func _on_gems_changed(new_total: int) -> void:
	if is_instance_valid(gems_label):
		gems_label.text = _add_missing_zeros(new_total)

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

# Ajoute des zéros au début d'un nombre pour qu'il fasse exactement 6 caractères
# de long (cela transforme automatiquement le nombre en chaine de caractères)
func _add_missing_zeros(raw_value: int)-> String:
	var number_formatted: String
	if raw_value < 10:
		number_formatted = "00000" + str(raw_value)
	elif raw_value >= 10 && raw_value < 100:
		number_formatted = "0000" + str(raw_value)
	elif raw_value >= 100 && raw_value < 1000:
		number_formatted = "000" + str(raw_value)
	elif raw_value >= 1000 && raw_value < 10000:
		number_formatted = "00" + str(raw_value)
	elif raw_value >= 10000 && raw_value < 100000:
		number_formatted = "0" + str(raw_value)
	else:
		number_formatted = str(raw_value)
	return number_formatted
