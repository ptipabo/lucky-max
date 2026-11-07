
extends Control

signal game_started
signal replay_requested

var has_started: bool = false

signal points_earned(amount: int)
signal back_requested

const BG_COLOR := Color("785f42ff")
const SECOND_COLOR := Color("#8A4FBB")
const THIRD_COLOR := Color("#574477")
const GOLD := Color("#FFC857")
const TEXT_COLOR := Color("fff8e7ff")

var rewards: Array[int] = []
var doors: Array[TextureButton] = []
var glow_overlays: Array[TextureRect] = []
var plate_controls: Array[Control] = []
var selected_door: int = -1
var game_finished: bool = false

var doors_container: HBoxContainer
var result_label: Label
var replay_overlay: Control
var replay_button: Button
var instruction_label: Label
var overlay_message: Label

func _ready() -> void:
	randomize()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_build_game()
	_start_round()

func _build_game() -> void:
	# On crée un fond pour notre mini-jeu
	var game_background := Panel.new()
	game_background.name = "Background"
	game_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# On lui ajoute des coins arrondis
	var game_bg_style_box := StyleBoxFlat.new()
	game_bg_style_box.bg_color = BG_COLOR
	game_bg_style_box.set_corner_radius_all(18)
	game_background.add_theme_stylebox_override("panel", game_bg_style_box)
	
	add_child(game_background)
	
	# Conteneur extérieur avec de vraies marges.
	var game_margins := MarginContainer.new()
	game_margins.name = "SceneMargins"
	game_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_margins.add_theme_constant_override("margin_left", 20)
	game_margins.add_theme_constant_override("margin_right", 20)
	game_margins.add_theme_constant_override("margin_top", 20)
	game_margins.add_theme_constant_override("margin_bottom", 20)
	add_child(game_margins)
	
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 18)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_margins.add_child(layout)

	var title := Label.new()
	title.text = "Pierres sacrées"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", GOLD)
	layout.add_child(title)

	instruction_label = Label.new()
	instruction_label.text = "Choisis une divinité et découvre ce qu'elle t'offre."
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_color_override("font_color", TEXT_COLOR)
	layout.add_child(instruction_label)

	# Zone de jeu
	var game_area := Control.new()
	game_area.custom_minimum_size = Vector2(620, 320)
	game_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(game_area)

	# Plateau de pierre
	var table := TextureRect.new()
	table.texture = load("res://assets/plates/table.png")
	table.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	table.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# On déplace la table légèrement vers le haut
	var table_pos_fix := 151
	table.offset_top -= table_pos_fix
	table.offset_bottom -= table_pos_fix
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_area.add_child(table)

	var plate_data = [
		{
			"name":"condor",
			"pos":Vector2(28,55)
		},
		{
			"name":"snake",
			"pos":Vector2(221,55)
		},
		{
			"name":"jaguar",
			"pos":Vector2(414,55)
		}
	]

	for i in range(3):
		var plates_size = Vector2(90, 116)
		
		var holder := Control.new()
		holder.position = plate_data[i]["pos"]
		holder.size = plates_size
		holder.custom_minimum_size = plates_size
		game_area.add_child(holder)
		plate_controls.append(holder)
		
		var button := TextureButton.new()
		button.texture_normal = load(
			"res://assets/plates/%s.png"
			% plate_data[i]["name"]
		)
		button.texture_pressed = button.texture_normal
		button.texture_hover = button.texture_normal
		
		# Force la plaque normale à respecter la taille du holder.
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var plates_pos_fix := 108
		button.offset_top += plates_pos_fix
		button.offset_bottom += plates_pos_fix
		button.size = plates_size
		button.custom_minimum_size = Vector2.ZERO
		button.pressed.connect(_on_door_pressed.bind(i))
		holder.add_child(button)
		
		var glow := TextureRect.new()
		glow.texture = load(
			"res://assets/plates/%s_glow.png"
			% plate_data[i]["name"]
		)
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.offset_top += plates_pos_fix
		glow.offset_bottom += plates_pos_fix
		glow.size = plates_size
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.visible = false
		holder.add_child(glow)
		
		# Plateau de pierre
		var table_bottom := TextureRect.new()
		table_bottom.texture = load("res://assets/plates/table_bottom.png")
		table_bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		table_bottom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		table_bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# On déplace la table légèrement vers le haut
		table_bottom.offset_top -= table_pos_fix
		table_bottom.offset_bottom -= table_pos_fix
		table_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_area.add_child(table_bottom)

		doors.append(button)
		glow_overlays.append(glow)

	result_label = Label.new()
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 25)
	result_label.add_theme_color_override("font_color", GOLD)
	layout.add_child(result_label)

	_build_replay_overlay()

func _door_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _build_replay_overlay() -> void:
	replay_overlay = Control.new()
	replay_overlay.name = "ReplayOverlay"
	replay_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	replay_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	replay_overlay.visible = false
	add_child(replay_overlay)

	# On crée un conteneur qui maintiendra le cadre contenant le bouton "Rejouer" au centre de l'écran
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	replay_overlay.add_child(center)

	# On ajoute du style à notre conteneur
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 200)
	panel.add_theme_stylebox_override(
		"panel", _door_style(BG_COLOR)
	)
	center.add_child(panel)

	# On crée le cadre contenant le bouton "Rejouer"
	var replay_container := VBoxContainer.new()
	replay_container.add_theme_constant_override("separation", 16)
	panel.add_child(replay_container)
	
	# On crée un titre pour ce cadre
	var replay_title := Label.new()
	replay_title.text = "Les Dieux ont parlés."
	replay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_title.add_theme_font_size_override("font_size", 22)
	replay_title.add_theme_color_override("font_color", GOLD)
	replay_container.add_child(replay_title)

	overlay_message = Label.new()
	overlay_message.text = "Veux-tu retenter ta chance, aventurier ?"
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_message.add_theme_color_override("font_color", TEXT_COLOR)
	replay_container.add_child(overlay_message)

	# On crée un bouton "Rejouer" afin de pouvoir rejouer directement au même jeu
	replay_button = Button.new()
	replay_button.text = "Rejouer"
	replay_button.custom_minimum_size = Vector2(0, 52)
	replay_button.add_theme_font_size_override("font_size", 21)
	replay_button.pressed.connect(_on_replay_pressed)
	GameManager.apply_button_skin(replay_button)
	replay_container.add_child(replay_button)

func _on_replay_pressed() -> void:
	replay_requested.emit()

func _start_round() -> void:
	has_started = false
	rewards.clear()
	selected_door = -1
	game_finished = false
	result_label.text = ""
	instruction_label.text = "Choisis une divinité et découvre ce qu'elle t'offre."
	replay_overlay.visible = false

	for i in range(3):
		rewards.append(randi_range(0, 30))

		var door := doors[i]
		door.disabled = false
		door.disabled = false
		door.scale = Vector2.ONE

		glow_overlays[i].visible = false
		plate_controls[i].position.y = 55

func _on_door_pressed(index: int) -> void:
	# le montant dépensé pour jouer à ce mini-jeu n'est plus remboursable dès qu'on a choisi une pierre
	if not has_started:
		has_started = true
		game_started.emit()
	
	# Empêche les doubles clics et les récompenses multiples.
	if game_finished or selected_door != -1:
		return

	selected_door = index
	game_finished = true

	for door in doors:
		door.disabled = true

	instruction_label.text = "Ainsi soit-il..."
	glow_overlays[index].visible = true
	var chosen_door := doors[index]

	# Animation des plaques de pierre
	var tween := create_tween()
	tween.tween_property(
		plate_controls[index],
		"position:y",
		plate_controls[index].position.y + 6,
		0.12
	)
	tween.tween_callback(_reveal_reward.bind(index))

func _reveal_reward(index: int) -> void:
	var reward: int = rewards[index]

	var reward_message = "Les Dieux t'octroient " + str(reward) + " points."

	result_label.text = reward_message
	instruction_label.text = "Fais-en bon usage."

	# Prépare le message qui apparaîtra au premier plan.
	overlay_message.text = reward_message
	overlay_message.add_theme_color_override("font_color", GOLD)

	# Le gestionnaire principal mettra le compteur à jour.
	points_earned.emit(reward)

	# Laisse le temps de voir les pierres avant d'afficher le panneau.
	var tween := create_tween()
	tween.tween_callback(_reveal_other_doors.bind(index))
	tween.tween_interval(2)
	tween.tween_callback(_show_replay)

func _reveal_other_doors(chosen_index: int) -> void:
	for i in range(doors.size()):
		if i == chosen_index:
			continue
	
	instruction_label.text = "Voici ce que les autres divités avaient prévus pour toi."

func _show_replay() -> void:
	replay_overlay.visible = true

func show_insufficient_points_message() -> void:
	overlay_message.text = "Tu n'as pas assez de points !\nIl te faut 10 points pour être digne de retenter ta chance."
	overlay_message.add_theme_color_override("font_color", GOLD)
	replay_overlay.visible = true
