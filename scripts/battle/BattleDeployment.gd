extends Control

signal starting_player_decided(player_starts: bool)
signal return_to_adventure_requested

enum BattlePhase { DEPLOYMENT, PLAYER_MOVEMENT, PLAYER_ACTIONS, ENEMY_TURN, FINISHED }

const CELL_GAP := 2.0
const BOARD_SIZE := 9
const CENTER_COLUMN := 4
const ATTACK_RANGE := 1
const NO_PATH_DISTANCE := 100000
const OBSTACLE_COUNT := 5
const ENEMY_STEP_DURATION := 0.22
const TECHNIQUE_SLOT_COUNT := 3

var main_layout: VBoxContainer
var board_grid: GridContainer
var board_container: CenterContainer
var opponent_heart_container: CenterContainer
var opponent_lives_label: Label
var player_lives_label: Label
var player_figures_container: HBoxContainer
var player_figure_slots: Array[Panel] = []
var enemy_id: String = ""
var enemy_data: Dictionary = {}
var enemy_strategy: String = "balanced"
var enemy_heart_attack_count: int = 0
var enemy_figure_attack_count: int = 0
var selected_instance_ids: Array = []
var selected_figures: Array = []
var enemy_figures: Array[Dictionary] = []
var figures_layer: Control
var enemy_figure_visuals: Array[TextureRect] = []
var combat_button: Button
var combat_button_spacer: Control
var starting_player_dialog: AcceptDialog
var player_starts: bool = false
var current_phase: int = BattlePhase.DEPLOYMENT
var battle_result_shown: bool = false
var turn_status_label: Label
var unit_health: Dictionary = {}
var enemy_figure_positions: Dictionary = {}
var player_move_points_used: Dictionary = {}
var reachable_cell_costs: Dictionary = {}
var obstacle_positions: Dictionary = {}
var player_acted: Dictionary = {}
var defending_units: Dictionary = {}
var status_effects: Dictionary = {}
var selected_actor_id: int = -1
var pending_action: String = ""
var reachable_cells: Array[Vector2i] = []
var player_heart_lives: int = 3
var opponent_heart_lives: int = 3
var unit_max_health: Dictionary = {}
var turn_controls: VBoxContainer
var action_controls: VBoxContainer
var selected_actor_label: Label
var phase_button: Button
var attack_button: Button
var technique_row: HBoxContainer
var technique_buttons: Array[Button] = []
var cancel_action_button: Button
var combat_message_label: Label
var combat_message_timer: Timer

# Positions des figurines déjà placées.
# Clé : instance_id / Valeur : Vector2i(ligne, colonne)
var player_figure_positions: Dictionary = {}

# Illustrations affichées sur le plateau.
var figure_visuals: Dictionary = {}

# Gestion du glisser-déposer.
var dragged_instance_id: int = -1
var drag_preview: TextureRect = null
var drag_pointer_position: Vector2 = Vector2.ZERO
var is_dragging_figure: bool = false
var drag_origin_was_placed: bool = false

func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	# Fond général.
	var background := ColorRect.new()
	background.color = Color("#183C32")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Organisation verticale.
	main_layout = VBoxContainer.new()
	main_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Petite marge autour de toute l'interface.
	main_layout.offset_left = 12
	main_layout.offset_right = -12
	main_layout.offset_top = 12
	main_layout.offset_bottom = -12

	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_theme_constant_override("separation", 8)
	add_child(main_layout)

	# Cœur adverse.
	var opponent_label := Label.new()
	opponent_label.text = "CŒUR ADVERSE"
	opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_label.add_theme_color_override(
		"font_color", Color("#F2D58B")
	)
	opponent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_child(opponent_label)

	opponent_heart_container = CenterContainer.new()
	opponent_heart_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_heart_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_layout.add_child(opponent_heart_container)

	opponent_lives_label = Label.new()
	opponent_lives_label.text = "♥ ♥ ♥"
	opponent_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_lives_label.add_theme_font_size_override("font_size", 25)
	opponent_lives_label.add_theme_color_override(
		"font_color", Color("#E85B5B")
	)
	opponent_lives_label.z_index = 100
	opponent_lives_label.z_as_relative = false
	opponent_lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opponent_lives_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	opponent_heart_container.add_child(opponent_lives_label)

	# Plateau carré.
	board_container = CenterContainer.new()
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_container.custom_minimum_size = Vector2.ZERO
	board_container.resized.connect(_update_board_size)
	main_layout.add_child(board_container)
	
	main_layout.resized.connect(_update_board_size)

	board_grid = GridContainer.new()
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.columns = BOARD_SIZE
	board_grid.add_theme_constant_override("h_separation", 2)
	board_grid.add_theme_constant_override("v_separation", 2)
	board_container.add_child(board_grid)
	
	# Calque d'affichage des figurines.
	figures_layer = Control.new()
	figures_layer.name = "FiguresLayer"
	figures_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	figures_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figures_layer.clip_contents = false
	figures_layer.z_index = 1

	board_container.add_child(figures_layer)

	_create_board()
	_create_obstacles()
	# Cette ligne permet d'attendre que Godot ait attribué leurs dimensions aux conteneurs avant de
	# calculer la taille des cases.
	call_deferred("_update_board_size")

	# Cœur du joueur.
	player_lives_label = Label.new()
	player_lives_label.text = "♥ ♥ ♥"
	player_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_lives_label.add_theme_font_size_override("font_size", 25)
	player_lives_label.add_theme_color_override(
		"font_color", Color("#E85B5B")
	)
	player_lives_label.mouse_filter = Control.MOUSE_FILTER_STOP
	player_lives_label.gui_input.connect(_on_heart_input.bind(false))
	player_lives_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_child(player_lives_label)

	var player_label := Label.new()
	player_label.text = "TON CŒUR"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_color_override(
		"font_color", Color("#F2D58B")
	)
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_child(player_label)

	combat_message_timer = Timer.new()
	combat_message_timer.one_shot = true
	combat_message_timer.wait_time = 1.8
	combat_message_timer.timeout.connect(_on_combat_message_timeout)
	add_child(combat_message_timer)
	
	# Barre des figurines du joueur.
	player_figures_container = HBoxContainer.new()
	player_figures_container.alignment = BoxContainer.ALIGNMENT_CENTER
	player_figures_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_figures_container.custom_minimum_size.y = 90
	player_figures_container.add_theme_constant_override("separation", 12)

	main_layout.add_child(player_figures_container)

	_create_player_figure_slots()
	_create_combat_button()
	
	_update_board_size()


func _create_board() -> void:
	for row in range(BOARD_SIZE):
		for column in range(BOARD_SIZE):
			var cell := Panel.new()

			cell.custom_minimum_size = Vector2(1, 1)

			# On identifie la position de la case.
			cell.set_meta("row", row)
			cell.set_meta("column", column)

			var style := StyleBoxFlat.new()

			# Couleur selon la zone du plateau.
			if row <= 1:
				style.bg_color = Color("#55705D")
			elif row <= 6:
				style.bg_color = Color("#3E624D")
			else:
				style.bg_color = Color("#557A61")

			# Bordures.
			style.set_border_width_all(1)
			style.border_color = Color("#253F32")

			cell.add_theme_stylebox_override("panel", style)
			cell.set_meta("base_style", style.duplicate())

			board_grid.add_child(cell)
			
			cell.gui_input.connect(_on_cell_input.bind(row, column))

func _create_obstacles() -> void:
	var candidates: Array[Vector2i] = []
	for row in range(2, 7):
		for column in range(BOARD_SIZE):
			if column != CENTER_COLUMN:
				candidates.append(Vector2i(row, column))

	for index in range(mini(OBSTACLE_COUNT, candidates.size())):
		var swap_index := randi_range(index, candidates.size() - 1)
		var candidate := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = candidate

		var position: Vector2i = candidates[index]
		obstacle_positions[position] = true
		var cell_index: int = position.x * BOARD_SIZE + position.y
		var cell := board_grid.get_child(cell_index) as Panel
		var obstacle := Panel.new()
		obstacle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		obstacle.offset_left = 5
		obstacle.offset_top = 5
		obstacle.offset_right = -5
		obstacle.offset_bottom = -5
		obstacle.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style := StyleBoxFlat.new()
		style.bg_color = Color("#766B54")
		style.border_color = Color("#403A2F")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		obstacle.add_theme_stylebox_override("panel", style)
		cell.add_child(obstacle)

func _update_board_size() -> void:
	if main_layout == null or board_container == null or board_grid == null:
		return

	var available_width: float = board_container.size.x
	var available_height: float = main_layout.size.y

	if available_width <= 0 or available_height <= 0:
		return

	# Calcul de la hauteur utilisée par les autres éléments.
	var fixed_height: float = 0.0

	for child in main_layout.get_children():
		if child != board_container:
			fixed_height += child.get_combined_minimum_size().y

	# Espacement entre les éléments du VBoxContainer.
	var separation: float = (
		main_layout.get_theme_constant("separation")
		* (main_layout.get_child_count() - 1)
	)

	# Hauteur réellement disponible pour le plateau.
	var board_available_height: float = (
		available_height - fixed_height - separation
	)

	if board_available_height <= 0:
		return

	# Le plateau ne dépasse ni la largeur ni la hauteur disponible.
	var board_size: float = min(
		available_width,
		board_available_height
	)

	# On réserve exactement cette hauteur au plateau.
	board_container.custom_minimum_size.y = board_size

	# Calcul de la taille de chaque case.
	var cell_size: float = (
		board_size - CELL_GAP * (BOARD_SIZE - 1)
	) / BOARD_SIZE

	if cell_size <= 0:
		return

	opponent_lives_label.custom_minimum_size.x = cell_size

	for cell in board_grid.get_children():
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
	
	call_deferred("_align_figures_layer")

func _on_cell_input(event: InputEvent, row: int, column: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Case sélectionnée : ligne ", row, " / colonne ", column)

func _create_player_figure_slots() -> void:
	player_figure_slots.clear()
	
	for i in range(3):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(75, 75)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#294A3A")
		style.set_border_width_all(2)
		style.border_color = Color("#D5BD79")
		
		slot.add_theme_stylebox_override("panel", style)
		
		player_figures_container.add_child(slot)
		player_figure_slots.append(slot)
		
		slot.gui_input.connect(_on_figure_slot_input.bind(i))

func configure(opponent: Dictionary, instance_ids: Array) -> void:
	enemy_data = opponent.duplicate(true)
	enemy_id = str(enemy_data.get("id", ""))
	enemy_strategy = str(enemy_data.get("strategy", "balanced"))
	if not ["figures_only", "heart_only", "balanced"].has(enemy_strategy):
		push_warning("Stratégie inconnue pour " + enemy_id + "; stratégie équilibrée utilisée.")
		enemy_strategy = "balanced"
	enemy_heart_attack_count = 0
	enemy_figure_attack_count = 0
	selected_instance_ids = instance_ids.duplicate()

	var collection: Array = GameManager.get_collection()
	selected_figures.clear()
	enemy_figures.clear()
	enemy_figure_positions.clear()

	var enemy_team: Variant = enemy_data.get("team", [])
	if enemy_team is Array:
		for character_id in enemy_team:
			var character_data: Dictionary = GameManager.get_character_data(
				str(character_id)
			)
			if character_data.is_empty():
				push_warning("Personnage ennemi introuvable : " + str(character_id))
				continue

			var enemy_instance_id := -(enemy_figures.size() + 1)
			var enemy_columns: Array[int] = [1, 4, 7]
			enemy_figures.append({
				"instance_id": enemy_instance_id,
				"character_id": str(character_id),
				"level": 1,
				"data": character_data
			})
			enemy_figure_positions[enemy_instance_id] = Vector2i(
				1,
				enemy_columns[enemy_figures.size() - 1]
			)
	else:
		push_warning("L'équipe de l'adversaire est invalide : " + enemy_id)

	for instance_id in selected_instance_ids:
		for figurine in collection:
			if int(figurine.get("instance_id", -1)) == int(instance_id):
				var character_data: Dictionary = GameManager.get_character_data(
					str(figurine.get("character_id", ""))
				)

				selected_figures.append({
					"instance_id": instance_id,
					"character_id": figurine.get("character_id", ""),
					"level": figurine.get("level", 1),
					"data": character_data
				})
				
				break
	
	_refresh_player_figure_slots()
	call_deferred("_update_board_size")

func _get_player_figure(instance_id: int) -> Dictionary:
	for figure in selected_figures:
		if int(figure.get("instance_id", -1)) == instance_id:
			return figure
	return {}

func _refresh_player_figure_slots() -> void:
	for i in range(player_figure_slots.size()):
		var slot: Panel = player_figure_slots[i]

		# Nettoyer le contenu précédent.
		for child in slot.get_children():
			child.queue_free()

		if i >= selected_figures.size():
			continue

		var figure: Dictionary = selected_figures[i]
		var instance_id := int(figure.get("instance_id", -1))

		if player_figure_positions.has(instance_id):
			continue

		if is_dragging_figure and instance_id == dragged_instance_id:
			continue
		
		var character_data: Dictionary = figure.get("data", {})

		# Organisation verticale.
		var layout := VBoxContainer.new()
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layout.add_theme_constant_override("separation", 2)
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(layout)

		# Portrait.
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(55, 52)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var image_path: String = "res://assets/characters/" + str(character_data.get("image", ""))

		if image_path != "":
			var texture := load(image_path) as Texture2D
			if texture != null:
				portrait.texture = texture

		layout.add_child(portrait)

		# Nom de la figurine.
		var figure_name := Label.new()
		figure_name.text = str(character_data.get("name", "Figurine"))
		figure_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		figure_name.add_theme_font_size_override("font_size", 11)
		figure_name.clip_text = true
		figure_name.mouse_filter = Control.MOUSE_FILTER_IGNORE

		layout.add_child(figure_name)
		_update_combat_button()
	_update_combat_button()

func _align_figures_layer() -> void:
	if figures_layer == null or board_grid == null:
		return

	figures_layer.position = board_grid.position
	figures_layer.size = board_grid.size
	_refresh_player_figure_visuals()
	_refresh_enemy_figure_visuals()

func _refresh_player_figure_visuals() -> void:
	var placed_instance_ids: Array = player_figure_positions.keys()
	for instance_id in placed_instance_ids:
		var sprite: TextureRect = figure_visuals.get(int(instance_id))
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		figure_visuals.erase(int(instance_id))

	for instance_id in placed_instance_ids:
		var figure := _get_player_figure(int(instance_id))
		if figure.is_empty():
			continue
		var position: Vector2i = player_figure_positions[instance_id]
		_create_figure_visual(figure, position.x, position.y)

func _get_cell_center(row: int, column: int) -> Vector2:
	if board_grid == null or board_grid.get_child_count() == 0:
		return Vector2.ZERO

	var first_cell := board_grid.get_child(0) as Control
	var cell_size: float = first_cell.size.x

	var spacing: float = CELL_GAP

	var x: float = column * (cell_size + spacing) + cell_size / 2.0
	var y: float = row * (cell_size + spacing) + cell_size / 2.0

	return Vector2(x, y)

func _create_figure_visual(
	figure: Dictionary,
	row: int,
	column: int,
	is_player_figure: bool = true
) -> void:

	var instance_id: int = int(figure.get("instance_id", -1))

	if (is_player_figure and instance_id < 0) or figures_layer == null:
		return

	var character_data: Dictionary = figure.get("data", {})
	var image_name: String = str(character_data.get("image", ""))

	if image_name.is_empty():
		return

	var image_path: String = "res://assets/characters/" + image_name
	var texture := load(image_path) as Texture2D

	if texture == null:
		push_warning("Impossible de charger : " + image_path)
		return

	# Taille de la case.
	var cell_center: Vector2 = _get_cell_center(row, column)
	var cell_size: float = board_grid.get_child(0).size.x

	# La figurine dépasse légèrement de son socle.
	var sprite_width: float = cell_size * 1.4

	# Conservation des proportions originales.
	var texture_ratio: float = (
		float(texture.get_width()) / float(texture.get_height())
	)

	var sprite_height: float = sprite_width / texture_ratio

	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_player_figure:
		sprite.mouse_filter = Control.MOUSE_FILTER_STOP
		sprite.gui_input.connect(_on_placed_figure_input.bind(instance_id))
	else:
		sprite.mouse_filter = Control.MOUSE_FILTER_STOP
		sprite.gui_input.connect(_on_enemy_figure_input.bind(instance_id))

	sprite.size = Vector2(sprite_width, sprite_height)

	# Centrage horizontal et alignement du bas sur la case.
	sprite.position = Vector2(
		cell_center.x - sprite_width / 2.0,
		cell_center.y + cell_size / 2.0 - sprite_height
	)

	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0
	var max_health := int(character_data.get("stats", {}).get("lifepoints", 1))
	health_bar.max_value = max_health
	health_bar.value = unit_health.get(instance_id, max_health)
	health_bar.show_percentage = false
	health_bar.z_index = 100
	health_bar.z_as_relative = false
	health_bar.size = Vector2(sprite_width * 0.7, 7)
	health_bar.position = Vector2(
		(sprite_width - health_bar.size.x) / 2.0,
		sprite_height - health_bar.size.y - 4
	)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("#202A24")
	health_bar.add_theme_stylebox_override("background", health_background)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = (
		Color("#8BC56A")
		if is_player_figure
		else Color("#E85B5B")
	)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	sprite.add_child(health_bar)

	# Les figurines situées plus bas passent devant.
	sprite.z_index = row

	figures_layer.add_child(sprite)

	if is_player_figure:
		figure_visuals[instance_id] = sprite
		player_figure_positions[instance_id] = Vector2i(row, column)
	else:
		enemy_figure_visuals.append(sprite)
		figure_visuals[instance_id] = sprite
		enemy_figure_positions[instance_id] = Vector2i(row, column)

func _refresh_enemy_figure_visuals() -> void:
	for sprite in enemy_figure_visuals:
		if is_instance_valid(sprite):
			sprite.queue_free()
	enemy_figure_visuals.clear()
	for figure in enemy_figures:
		figure_visuals.erase(int(figure.get("instance_id", -1)))

	if enemy_figures.is_empty() or board_grid.get_child_count() == 0:
		return

	if board_grid.get_child(0).size.x <= 0:
		return

	for figure in enemy_figures:
		var instance_id := int(figure.get("instance_id", -1))
		if not enemy_figure_positions.has(instance_id):
			continue
		var position: Vector2i = enemy_figure_positions.get(
			instance_id,
			Vector2i(1, 4)
		)
		_create_figure_visual(figure, position.x, position.y, false)

func _on_figure_slot_input(event: InputEvent, slot_index: int) -> void:
	if deployment_confirmed:
		return
	
	var pointer_position := Vector2.ZERO

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		pointer_position = get_global_mouse_position()

	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
		pointer_position = event.position

	else:
		return

	if slot_index >= selected_figures.size():
		return

	var figure: Dictionary = selected_figures[slot_index]
	var instance_id := int(figure.get("instance_id", -1))

	# Ne pas reprendre une figurine déjà placée.
	if player_figure_positions.has(instance_id):
		return

	if is_dragging_figure:
		return

	_start_figure_drag(figure, pointer_position)
	_refresh_player_figure_slots()


func _start_figure_drag(figure: Dictionary, pointer_position: Vector2) -> void:
	if is_dragging_figure:
		return
	
	if figures_layer == null:
		return

	var character_data: Dictionary = figure.get("data", {})
	var image_name := str(character_data.get("image", ""))
	var image_path := "res://assets/characters/" + image_name
	var texture := load(image_path) as Texture2D

	if texture == null:
		push_warning("Impossible de charger : " + image_path)
		return

	dragged_instance_id = int(figure.get("instance_id", -1))
	is_dragging_figure = true
	drag_pointer_position = pointer_position

	var cell_size: float = board_grid.get_child(0).size.x
	var sprite_width: float = cell_size * 1.4
	var texture_ratio := float(texture.get_width()) / float(texture.get_height())
	var sprite_height := sprite_width / texture_ratio

	drag_preview = TextureRect.new()
	drag_preview.texture = texture
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.size = Vector2(sprite_width, sprite_height)
	drag_preview.modulate = Color(1, 1, 1, 0.8)
	drag_preview.z_index = 100

	figures_layer.add_child(drag_preview)

	var local_position := figures_layer.get_global_transform().affine_inverse() * pointer_position
	drag_preview.position = Vector2(
		local_position.x - sprite_width / 2.0,
		local_position.y - sprite_height
	)

func _input(event: InputEvent) -> void:
	var pointer_position := Vector2.ZERO
	var is_pointer_press := false

	if event is InputEventMouseButton:
		is_pointer_press = (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
		pointer_position = event.position
	elif event is InputEventScreenTouch:
		is_pointer_press = event.pressed
		pointer_position = event.position

	if (
		is_pointer_press
		and opponent_lives_label != null
		and _get_opponent_heart_hitbox().has_point(pointer_position)
	):
		_on_heart_input(event, true)
		get_viewport().set_input_as_handled()
		return

	if (
		is_pointer_press
		and current_phase == BattlePhase.PLAYER_ACTIONS
		and not pending_action.is_empty()
	):
		var target_instance_id := _get_enemy_figure_at_position(pointer_position)
		if target_instance_id != -1:
			_resolve_character_action(target_instance_id)
			get_viewport().set_input_as_handled()
			return

	if not is_dragging_figure or drag_preview == null:
		return

	var pointer_moved := false
	var pointer_released := false
	var new_position := drag_pointer_position

	if event is InputEventMouseMotion:
		new_position = event.position
		pointer_moved = true

	elif event is InputEventScreenDrag:
		new_position = event.position
		pointer_moved = true

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			pointer_released = true

	elif event is InputEventScreenTouch:
		if not event.pressed:
			pointer_released = true

	if pointer_moved:
		drag_pointer_position = new_position

		var local_position := (
			figures_layer.get_global_transform().affine_inverse()
			* drag_pointer_position
		)

		drag_preview.position = Vector2(
			local_position.x - drag_preview.size.x / 2.0,
			local_position.y - drag_preview.size.y
		)

	if pointer_released:
		_drop_figure_on_board(drag_pointer_position)

func _get_opponent_heart_hitbox() -> Rect2:
	if (
		opponent_heart_container == null
		or opponent_lives_label == null
		or board_grid == null
		or board_grid.get_child_count() == 0
	):
		return Rect2()

	var cell_size: float = board_grid.get_child(0).size.x
	var label_rect := opponent_lives_label.get_global_rect()
	var center_x: float = opponent_heart_container.get_global_rect().get_center().x
	return Rect2(
		Vector2(center_x - cell_size / 2.0, label_rect.position.y),
		Vector2(cell_size, label_rect.size.y)
	)

func _get_enemy_figure_at_position(pointer_position: Vector2) -> int:
	for index in range(enemy_figure_visuals.size() - 1, -1, -1):
		var sprite := enemy_figure_visuals[index]
		if not is_instance_valid(sprite) or not sprite.visible:
			continue
		if not sprite.get_global_rect().has_point(pointer_position):
			continue
		for instance_id in enemy_figure_positions:
			if figure_visuals.get(int(instance_id)) == sprite:
				return int(instance_id)
	return -1

func _cancel_figure_drag() -> void:
	if drag_preview != null:
		drag_preview.queue_free()

	drag_preview = null
	if drag_origin_was_placed and figure_visuals.has(dragged_instance_id):
		var original_sprite: TextureRect = figure_visuals[dragged_instance_id]
		original_sprite.visible = true
	dragged_instance_id = -1
	is_dragging_figure = false
	drag_origin_was_placed = false
	
	_refresh_player_figure_slots()

func _drop_figure_on_board(global_position: Vector2) -> void:
	var local_position := (
		board_grid.get_global_transform().affine_inverse()
		* global_position
	)

	var cell_size: float = board_grid.get_child(0).size.x
	var cell_step: float = cell_size + CELL_GAP

	var column := int(floor(local_position.x / cell_step))
	var row := int(floor(local_position.y / cell_step))

	var valid_row := (
		row >= 7 and row <= 8
		if current_phase == BattlePhase.DEPLOYMENT
		else reachable_cells.has(Vector2i(row, column))
	)
	var valid_position := (
		valid_row
		and column >= 0
		and column < BOARD_SIZE
		and local_position.x >= 0
		and local_position.y >= 0
	)

	var occupied_instance_id: int = -1

	if valid_position:
		for id in player_figure_positions:
			var position: Vector2i = player_figure_positions[id]

			if position == Vector2i(row, column) and int(id) != dragged_instance_id:
				occupied_instance_id = int(id)
				break

		if occupied_instance_id != -1:
			if current_phase == BattlePhase.PLAYER_MOVEMENT or not drag_origin_was_placed:
				valid_position = false

		for id in enemy_figure_positions:
			var enemy_position: Vector2i = enemy_figure_positions[id]
			if enemy_position == Vector2i(row, column):
				valid_position = false

	if valid_position:
		var figure: Dictionary = {}

		for selected_figure in selected_figures:
			if int(selected_figure.get("instance_id", -1)) == dragged_instance_id:
				figure = selected_figure
				break

		if not figure.is_empty():
			var was_placed := drag_origin_was_placed
			var moved_instance_id := dragged_instance_id
			var movement_cost := int(
				reachable_cell_costs.get(Vector2i(row, column), 0)
			)
			var old_position: Vector2i = Vector2i(-1, -1)

			if was_placed:
				old_position = player_figure_positions[dragged_instance_id]

				# Supprimer l'ancienne représentation de la figurine déplacée.
				if figure_visuals.has(dragged_instance_id):
					figure_visuals[dragged_instance_id].queue_free()
					figure_visuals.erase(dragged_instance_id)

				player_figure_positions.erase(dragged_instance_id)

			var exchanged_figure: Dictionary = {}

			if occupied_instance_id != -1:
				for selected_figure in selected_figures:
					if int(selected_figure.get("instance_id", -1)) == occupied_instance_id:
						exchanged_figure = selected_figure
						break

				if was_placed:
					if figure_visuals.has(occupied_instance_id):
						figure_visuals[occupied_instance_id].queue_free()
						figure_visuals.erase(occupied_instance_id)

					player_figure_positions.erase(occupied_instance_id)

			_cancel_figure_drag()
			_clear_movement_highlights()

			_create_figure_visual(figure, row, column)
			if current_phase == BattlePhase.PLAYER_MOVEMENT:
				player_move_points_used[moved_instance_id] = (
					int(player_move_points_used.get(moved_instance_id, 0))
					+ movement_cost
				)

			if not exchanged_figure.is_empty() and was_placed:
				_create_figure_visual(
					exchanged_figure,
					old_position.x,
					old_position.y
				)

			_refresh_player_figure_slots()
			return

	# Dépôt invalide : la figurine retourne à son emplacement initial.
	_clear_movement_highlights()
	_cancel_figure_drag()

func _get_reachable_cells(
	start: Vector2i,
	move_points: int,
	actor_id: int
) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	reachable_cell_costs.clear()
	var pending: Array[Vector2i] = [start]
	var distance_by_cell: Dictionary = {start: 0}
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 0)
	]

	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		var next_distance: int = int(distance_by_cell[current]) + 1
		if next_distance > move_points:
			continue

		for direction in directions:
			var next_cell: Vector2i = current + direction
			if (
				next_cell.x < 0 or next_cell.x >= BOARD_SIZE
				or next_cell.y < 0 or next_cell.y >= BOARD_SIZE
				or distance_by_cell.has(next_cell)
				or _is_position_occupied(
					next_cell,
					actor_id,
					_can_pass_obstacles(actor_id)
				)
			):
				continue

			distance_by_cell[next_cell] = next_distance
			reachable_cell_costs[next_cell] = next_distance
			reachable.append(next_cell)
			pending.append(next_cell)

	return reachable

func _get_move_points(figure: Dictionary) -> int:
	if _has_status_effect(int(figure.get("instance_id", -1)), "freeze"):
		return 0
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	var move_points := int(stats.get("moves", 1))
	for technique_id in stats.get("techniques", []):
		var technique: Dictionary = GameManager.techniques_catalog.get(
			str(technique_id),
			{}
		)
		if technique.get("type", "") == "move":
			move_points += int(technique.get("value", 0))
	return maxi(0, move_points)

func _is_position_occupied(
	position: Vector2i,
	ignored_instance_id: int,
	can_pass_obstacles: bool = false
) -> bool:
	for instance_id in player_figure_positions:
		if int(instance_id) == ignored_instance_id:
			continue
		if player_figure_positions[instance_id] == position:
			return true

	for instance_id in enemy_figure_positions:
		if int(instance_id) == ignored_instance_id:
			continue
		if enemy_figure_positions[instance_id] == position:
			return true

	if not can_pass_obstacles and obstacle_positions.has(position):
		return true

	return false

func _can_pass_obstacles(instance_id: int) -> bool:
	var figure := _get_unit_figure(instance_id)
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	return stats.get("techniques", []).has("ignore_walls")

func _highlight_movement_cells() -> void:
	for position in reachable_cells:
		var cell_index: int = position.x * BOARD_SIZE + position.y
		var cell := board_grid.get_child(cell_index) as Panel
		var style: StyleBoxFlat = cell.get_meta("base_style").duplicate()
		style.bg_color = Color("#B3C96A")
		cell.add_theme_stylebox_override("panel", style)

func _clear_movement_highlights() -> void:
	reachable_cells.clear()
	reachable_cell_costs.clear()
	for cell in board_grid.get_children():
		cell.add_theme_stylebox_override("panel", cell.get_meta("base_style"))

func _on_placed_figure_input(event: InputEvent, instance_id: int) -> void:
	if current_phase == BattlePhase.PLAYER_MOVEMENT:
		pass
	elif current_phase == BattlePhase.PLAYER_ACTIONS:
		pass
	elif current_phase == BattlePhase.DEPLOYMENT:
		if deployment_confirmed:
			return
	else:
		return
	
	if is_dragging_figure:
		return

	var pointer_position := Vector2.ZERO

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		pointer_position = get_global_mouse_position()

	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
		pointer_position = event.position

	else:
		return

	if current_phase == BattlePhase.PLAYER_MOVEMENT:
		var start: Vector2i = player_figure_positions.get(
			instance_id,
			Vector2i(-1, -1)
		)
		var figure: Dictionary = _get_player_figure(instance_id)
		if start.x < 0 or figure.is_empty():
			return
		reachable_cells = _get_reachable_cells(
			start,
			maxi(
				0,
				_get_move_points(figure)
				- int(player_move_points_used.get(instance_id, 0))
			),
			instance_id
		)
		_highlight_movement_cells()
		turn_status_label.text = "%d PM restants" % maxi(
			0,
			_get_move_points(figure)
			- int(player_move_points_used.get(instance_id, 0))
		)

	if current_phase == BattlePhase.PLAYER_ACTIONS:
		if pending_action.is_empty():
			_select_player_actor(instance_id)
		else:
			_resolve_character_action(instance_id)
		return

	var figure: Dictionary = {}

	for selected_figure in selected_figures:
		if int(selected_figure.get("instance_id", -1)) == instance_id:
			figure = selected_figure
			break

	if figure.is_empty():
		return

	drag_origin_was_placed = true

	if figure_visuals.has(instance_id):
		var original_sprite: TextureRect = figure_visuals[instance_id]
		original_sprite.visible = false

	_start_figure_drag(figure, pointer_position)
	_update_combat_button()

func _create_combat_button() -> void:
	starting_player_dialog = AcceptDialog.new()
	starting_player_dialog.title = "Tirage au sort"
	starting_player_dialog.dialog_text = ""
	starting_player_dialog.ok_button_text = "Continuer"
	starting_player_dialog.confirmed.connect(_begin_combat)
	GameManager.apply_button_skin(starting_player_dialog.get_ok_button())
	add_child(starting_player_dialog)

	combat_button = Button.new()
	combat_button.text = "COMBAT !"
	combat_button.custom_minimum_size = Vector2(0, 48)
	combat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_button.visible = false
	GameManager.apply_button_skin(combat_button)

	main_layout.add_child(combat_button)
	combat_button.pressed.connect(_on_combat_button_pressed)

func _update_combat_button() -> void:
	if combat_button == null:
		return

	combat_button.visible = (
		current_phase == BattlePhase.DEPLOYMENT
		and player_figure_positions.size() == 3
		and not is_dragging_figure
	)

var deployment_confirmed: bool = false


func _on_combat_button_pressed() -> void:
	if deployment_confirmed:
		return

	if player_figure_positions.size() != 3:
		return

	if is_dragging_figure:
		return

	deployment_confirmed = true
	combat_button.disabled = true
	combat_button.text = "DÉPLOIEMENT VALIDÉ !"
	GameManager.apply_button_skin(combat_button)
	player_starts = randi_range(0, 1) == 0
	starting_player_dialog.dialog_text = (
		"Pile ! Tu commences."
		if player_starts
		else "Face ! L'adversaire commence."
	)
	starting_player_dialog.popup_centered(Vector2i(320, 160))
	starting_player_decided.emit(player_starts)

	print("Déploiement confirmé !")
	print("Positions des figurines : ", player_figure_positions)
	print("Le joueur commence : ", player_starts)

func _begin_combat() -> void:
	if current_phase != BattlePhase.DEPLOYMENT:
		return

	for slot in player_figure_slots:
		slot.visible = false
	_create_combat_controls()
	if combat_button_spacer == null:
		var button_index := combat_button.get_index()
		combat_button_spacer = Control.new()
		combat_button_spacer.custom_minimum_size = combat_button.custom_minimum_size
		combat_button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_layout.add_child(combat_button_spacer)
		main_layout.move_child(combat_button_spacer, button_index)

	current_phase = (
		BattlePhase.PLAYER_MOVEMENT
		if player_starts
		else BattlePhase.ENEMY_TURN
	)
	combat_button.visible = false
	turn_status_label.visible = true
	unit_health.clear()

	for figure in selected_figures:
		var instance_id := int(figure.get("instance_id", -1))
		var stats: Dictionary = figure.get("data", {}).get("stats", {})
		var max_health := int(stats.get("lifepoints", 1))
		unit_health[instance_id] = max_health
		unit_max_health[instance_id] = max_health

	for figure in enemy_figures:
		var instance_id := int(figure.get("instance_id", -1))
		var stats: Dictionary = figure.get("data", {}).get("stats", {})
		var max_health := int(stats.get("lifepoints", 1))
		unit_health[instance_id] = max_health
		unit_max_health[instance_id] = max_health
		_update_unit_health_display(instance_id)

	if player_starts:
		turn_status_label.text = "Tour du joueur : déplacements"
	else:
		turn_status_label.text = "Tour de l'adversaire"
	_update_combat_ui()
	player_move_points_used.clear()
	player_acted.clear()
	if not player_starts:
		call_deferred("_run_enemy_turn")

func _create_combat_controls() -> void:
	turn_controls = VBoxContainer.new()
	turn_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	turn_controls.offset_left = 14
	turn_controls.offset_right = -14
	turn_controls.offset_top = -190
	turn_controls.offset_bottom = -12
	turn_controls.add_theme_constant_override("separation", 4)
	turn_controls.visible = false
	add_child(turn_controls)

	turn_status_label = Label.new()
	turn_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_status_label.add_theme_color_override("font_color", Color("#F2D58B"))
	turn_controls.add_child(turn_status_label)

	combat_message_label = Label.new()
	combat_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_message_label.add_theme_color_override("font_color", Color("#FFC83C"))
	combat_message_label.visible = false
	turn_controls.add_child(combat_message_label)

	action_controls = VBoxContainer.new()
	action_controls.add_theme_constant_override("separation", 6)
	turn_controls.add_child(action_controls)

	selected_actor_label = Label.new()
	selected_actor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_actor_label.add_theme_color_override("font_color", Color("#F2D58B"))
	action_controls.add_child(selected_actor_label)

	attack_button = Button.new()
	attack_button.text = "⚔ Attaque"
	attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack_button.pressed.connect(_on_attack_pressed)
	_apply_action_button_style(attack_button)
	action_controls.add_child(attack_button)

	technique_row = HBoxContainer.new()
	technique_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	technique_row.add_theme_constant_override("separation", 6)
	action_controls.add_child(technique_row)
	technique_buttons.clear()
	for index in range(TECHNIQUE_SLOT_COUNT):
		var technique_button := Button.new()
		technique_button.custom_minimum_size = Vector2(48, 48)
		technique_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		technique_button.add_theme_font_size_override("font_size", 24)
		technique_button.set_meta("technique_id", "")
		technique_button.pressed.connect(
			_on_technique_button_pressed.bind(index)
		)
		_apply_action_button_style(technique_button)
		technique_row.add_child(technique_button)
		technique_buttons.append(technique_button)

	cancel_action_button = Button.new()
	cancel_action_button.text = "Annuler"
	cancel_action_button.pressed.connect(_on_cancel_action_pressed)
	_apply_action_button_style(cancel_action_button)
	action_controls.add_child(cancel_action_button)

	var phase_button_margin := MarginContainer.new()
	phase_button_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_button_margin.add_theme_constant_override("margin_bottom", 8)
	turn_controls.add_child(phase_button_margin)

	phase_button = Button.new()
	phase_button.custom_minimum_size.y = 42
	phase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_button.pressed.connect(_on_phase_button_pressed)
	_apply_action_button_style(phase_button)
	phase_button_margin.add_child(phase_button)

func _apply_action_button_style(button: Button) -> void:
	GameManager.apply_button_skin(button)
	button.add_theme_color_override("font_color", Color("#FFC83C"))
	button.add_theme_color_override("font_hover_color", Color("#FFF2D5"))

func _update_combat_ui() -> void:
	if turn_controls == null:
		return

	player_lives_label.text = _format_hearts(player_heart_lives)
	opponent_lives_label.text = _format_hearts(opponent_heart_lives)
	var is_player_turn := (
		current_phase == BattlePhase.PLAYER_MOVEMENT
		or current_phase == BattlePhase.PLAYER_ACTIONS
	)
	var battle_active := (
		current_phase != BattlePhase.DEPLOYMENT
		and current_phase != BattlePhase.FINISHED
	)
	turn_controls.visible = battle_active
	phase_button.visible = is_player_turn
	phase_button.text = (
		"Passer aux actions"
		if current_phase == BattlePhase.PLAYER_MOVEMENT
		else "Fin du tour"
	)
	GameManager.apply_button_skin(phase_button)
	var can_act: bool = (
		current_phase == BattlePhase.PLAYER_ACTIONS
		and selected_actor_id > 0
		and not bool(player_acted.get(selected_actor_id, false))
	)
	action_controls.visible = battle_active
	selected_actor_label.visible = can_act
	attack_button.disabled = not can_act or not pending_action.is_empty()
	for technique_button in technique_buttons:
		technique_button.disabled = (
			not can_act
			or not pending_action.is_empty()
			or str(technique_button.get_meta("technique_id", "")).is_empty()
		)
	cancel_action_button.visible = not pending_action.is_empty()

	if current_phase == BattlePhase.PLAYER_MOVEMENT:
		turn_status_label.text = "Tour du joueur : déplacements"
	elif current_phase == BattlePhase.PLAYER_ACTIONS:
		turn_status_label.text = (
			"Choisis une cible"
			if not pending_action.is_empty()
			else "Actions : sélectionne une figurine"
		)
	elif current_phase == BattlePhase.ENEMY_TURN:
		turn_status_label.text = "Tour de l'adversaire"
	elif current_phase == BattlePhase.FINISHED:
		turn_controls.visible = false

func _on_phase_button_pressed() -> void:
	if current_phase == BattlePhase.PLAYER_MOVEMENT:
		_clear_movement_highlights()
		current_phase = BattlePhase.PLAYER_ACTIONS
		selected_actor_id = -1
		pending_action = ""
	elif current_phase == BattlePhase.PLAYER_ACTIONS:
		for instance_id in player_figure_positions:
			if not bool(player_acted.get(instance_id, false)):
				defending_units[instance_id] = true
		_tick_side_effects(true)
		if _check_battle_over():
			return
		current_phase = BattlePhase.ENEMY_TURN
		selected_actor_id = -1
		pending_action = ""
	_update_combat_ui()
	if current_phase == BattlePhase.ENEMY_TURN:
		call_deferred("_run_enemy_turn")

func _select_player_actor(instance_id: int) -> void:
	if not player_figure_positions.has(instance_id):
		return
	if player_acted.get(instance_id, false):
		return

	selected_actor_id = instance_id
	var figure := _get_player_figure(instance_id)
	selected_actor_label.text = str(
		figure.get("data", {}).get("name", "Figurine")
	)
	_populate_technique_buttons(instance_id)
	_update_combat_ui()

func _populate_technique_buttons(instance_id: int) -> void:
	for button in technique_buttons:
		button.set_meta("technique_id", "")
		button.text = ""
		button.tooltip_text = ""
		button.disabled = true

	var figure := _get_player_figure(instance_id)
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	var slot_index := 0
	for technique_id in stats.get("techniques", []):
		var technique: Dictionary = GameManager.techniques_catalog.get(
			str(technique_id),
			{}
		)
		if technique.get("type", "") != "action":
			continue
		if slot_index >= technique_buttons.size():
			break
		var button: Button = technique_buttons[slot_index]
		button.set_meta("technique_id", str(technique_id))
		button.text = _get_technique_emoji(str(technique_id))
		button.tooltip_text = str(technique.get("name", technique_id))
		GameManager.apply_button_skin(button)
		button.disabled = false
		slot_index += 1

func _get_technique_emoji(technique_id: String) -> String:
	match technique_id:
		"fire":
			return "🔥"
		"heal":
			return "💚"
		"ice":
			return "❄"
		"extra_move":
			return "👟"
		_:
			return "✨"

func _on_attack_pressed() -> void:
	if selected_actor_id <= 0:
		return
	pending_action = "attack"
	_update_combat_ui()

func _on_technique_button_pressed(index: int) -> void:
	if index < 0 or index >= technique_buttons.size() or selected_actor_id <= 0:
		return
	pending_action = str(technique_buttons[index].get_meta("technique_id", ""))
	if pending_action.is_empty():
		return
	_update_combat_ui()

func _on_cancel_action_pressed() -> void:
	pending_action = ""
	_update_combat_ui()

func _on_enemy_figure_input(event: InputEvent, instance_id: int) -> void:
	if current_phase != BattlePhase.PLAYER_ACTIONS or pending_action.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
	else:
		return
	_resolve_character_action(instance_id)

func _on_heart_input(event: InputEvent, target_is_opponent: bool) -> void:
	if not target_is_opponent:
		return
	if current_phase != BattlePhase.PLAYER_ACTIONS or selected_actor_id <= 0:
		return

	var is_offensive_action := pending_action == "attack"
	if not is_offensive_action:
		var technique: Dictionary = GameManager.techniques_catalog.get(
			pending_action,
			{}
		)
		is_offensive_action = int(technique.get("value", 0)) < 0
	if not is_offensive_action:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
	else:
		return

	var actor_position: Vector2i = _get_unit_position(selected_actor_id)
	var heart_position := Vector2i(-1, CENTER_COLUMN)
	if (
		actor_position.x < 0
		or _grid_distance(actor_position, heart_position)
		> _get_action_range(pending_action)
	):
		turn_status_label.text = "Le cœur adverse est hors de portée"
		return
	if not _has_clear_attack_line(
		actor_position,
		heart_position,
		selected_actor_id
	):
		turn_status_label.text = "La ligne de tir vers le cœur est bloquée"
		return
	opponent_heart_lives = maxi(0, opponent_heart_lives - 1)
	_complete_player_action()

func _resolve_character_action(target_id: int) -> void:
	if selected_actor_id <= 0 or not unit_health.has(target_id):
		return
	var actor_position: Vector2i = _get_unit_position(selected_actor_id)
	var target_position: Vector2i = _get_unit_position(target_id)
	if actor_position.x < 0 or target_position.x < 0:
		return
	if _grid_distance(actor_position, target_position) > _get_action_range(pending_action):
		turn_status_label.text = "La cible est hors de portée"
		return

	var actor := _get_player_figure(selected_actor_id)
	var actor_stats: Dictionary = actor.get("data", {}).get("stats", {})
	var is_offensive_action := pending_action == "attack"
	if not is_offensive_action:
		var selected_technique: Dictionary = GameManager.techniques_catalog.get(
			pending_action,
			{}
		)
		is_offensive_action = int(selected_technique.get("value", 0)) < 0
	if (
		is_offensive_action
		and not _has_clear_attack_line(
			actor_position,
			target_position,
			selected_actor_id
		)
	):
		turn_status_label.text = "La ligne de tir est bloquée"
		return

	if pending_action == "attack":
		if target_id > 0:
			return
		_apply_damage(
			target_id,
			int(actor_stats.get("attack", 0)),
			"physical",
			0,
			true,
			str(actor.get("data", {}).get("name", "Figurine alliée"))
		)
	else:
		var technique: Dictionary = GameManager.techniques_catalog.get(
			pending_action,
			{}
		)
		var value := int(technique.get("value", 0))
		if value < 0 and target_id < 0:
			var hit := _apply_damage(
				target_id,
				abs(value),
				"magic",
				int(actor_stats.get("magic", 0)),
				true,
				str(actor.get("data", {}).get("name", "Figurine alliée"))
			)
			if hit:
				_try_apply_side_effect(target_id, technique)
		elif value > 0 and target_id > 0:
			_apply_healing(target_id, value)
		else:
			return
	_complete_player_action()

func _complete_player_action() -> void:
	player_acted[selected_actor_id] = true
	selected_actor_id = -1
	pending_action = ""
	if not _check_battle_over():
		_update_combat_ui()

func _grid_distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)

func _has_clear_attack_line(
	origin: Vector2i,
	target: Vector2i,
	attacker_id: int
) -> bool:
	if origin == target:
		return false
	var row_distance: int = absi(target.x - origin.x)
	var column_distance: int = absi(target.y - origin.y)
	var is_axis_aligned := origin.x == target.x or origin.y == target.y
	var is_diagonal := row_distance == column_distance
	if not is_axis_aligned and not is_diagonal:
		return false

	var direction := Vector2i(
		signi(target.x - origin.x),
		signi(target.y - origin.y)
	)
	var current := origin + direction
	while current != target:
		if _is_position_occupied(current, attacker_id):
			return false
		current += direction
	return true

func _get_action_range(action_id: String) -> int:
	if action_id == "attack":
		return ATTACK_RANGE
	var technique: Dictionary = GameManager.techniques_catalog.get(action_id, {})
	return maxi(1, int(technique.get("range", ATTACK_RANGE)))

func _get_unit_position(instance_id: int) -> Vector2i:
	if instance_id > 0:
		return player_figure_positions.get(instance_id, Vector2i(-1, -1))
	return enemy_figure_positions.get(instance_id, Vector2i(-1, -1))

func _get_unit_figure(instance_id: int) -> Dictionary:
	if instance_id > 0:
		return _get_player_figure(instance_id)
	for figure in enemy_figures:
		if int(figure.get("instance_id", 0)) == instance_id:
			return figure
	return {}

func _apply_damage(
	instance_id: int,
	amount: int,
	damage_type: String = "physical",
	magic_bonus: int = 0,
	can_dodge: bool = true,
	source_name: String = ""
) -> bool:
	if amount <= 0 or not unit_health.has(instance_id):
		return false
	var target_figure := _get_unit_figure(instance_id)
	var target_stats: Dictionary = target_figure.get("data", {}).get("stats", {})
	var effective_defense := 0.0
	if can_dodge:
		var dodge_chance := clampf(
			0.1 + float(target_stats.get("escape", 0)) * 0.05,
			0.0,
			1.0
		)
		if randf() < dodge_chance:
			var character_name := str(
				target_figure.get("data", {}).get("name", "La figurine")
			)
			var attacker_name := source_name if not source_name.is_empty() else "l'attaque"
			_show_combat_message(character_name + " esquive " + attacker_name + " !")
			_flash_unit(instance_id, Color("#73D99A"))
			return false

	if damage_type == "magic":
		amount += magic_bonus
		effective_defense = float(target_stats.get("spirit", 0))
	elif damage_type == "physical":
		effective_defense = float(target_stats.get("defense", 0))
	if defending_units.has(instance_id):
		effective_defense *= 1.25
		defending_units.erase(instance_id)
	amount = maxi(1, int(ceil(float(amount) - effective_defense)))
	unit_health[instance_id] = maxi(0, int(unit_health[instance_id]) - amount)
	var target_name := str(target_figure.get("data", {}).get("name", "Figurine"))
	var damage_source := source_name
	if damage_source.is_empty():
		damage_source = "la magie" if damage_type == "magic" else "l'attaque"
	if damage_type == "effect":
		damage_source = source_name if not source_name.is_empty() else "un effet"
	_show_combat_message(
		"%s subit %d dégâts (%s)." % [target_name, amount, damage_source]
	)
	var flash_color := Color("#F06B5F")
	if damage_type == "magic":
		flash_color = Color("#6CCCF0")
	elif damage_type == "effect":
		flash_color = Color("#F2A64A")
	_flash_unit(instance_id, flash_color)
	_update_unit_health_display(instance_id)
	if int(unit_health[instance_id]) == 0:
		if instance_id > 0:
			player_figure_positions.erase(instance_id)
			player_move_points_used.erase(instance_id)
			player_acted.erase(instance_id)
		else:
			enemy_figure_positions.erase(instance_id)
		var sprite: TextureRect = figure_visuals.get(instance_id)
		if sprite != null:
			sprite.queue_free()
			figure_visuals.erase(instance_id)
			enemy_figure_visuals.erase(sprite)
		unit_health.erase(instance_id)
		unit_max_health.erase(instance_id)
		status_effects.erase(instance_id)
	return true

func _flash_unit(instance_id: int, flash_color: Color) -> void:
	var sprite: TextureRect = figure_visuals.get(instance_id)
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", flash_color, 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.22)

func _apply_healing(instance_id: int, amount: int) -> void:
	if amount <= 0 or not unit_health.has(instance_id):
		return
	var previous_health: int = int(unit_health[instance_id])
	unit_health[instance_id] = mini(
		int(unit_max_health[instance_id]),
		int(unit_health[instance_id]) + amount
	)
	_update_unit_health_display(instance_id)
	var healed_amount: int = int(unit_health[instance_id]) - previous_health
	if healed_amount > 0:
		var figure := _get_unit_figure(instance_id)
		var character_name := str(figure.get("data", {}).get("name", "Figurine"))
		_show_combat_message("%s récupère %d PV." % [character_name, healed_amount])
		_flash_unit(instance_id, Color("#73D99A"))
	var effects: Array = status_effects.get(instance_id, [])
	for index in range(effects.size() - 1, -1, -1):
		var effect_id := str(effects[index].get("id", ""))
		if effect_id in ["burn", "poison"]:
			effects.remove_at(index)
	if effects.is_empty():
		status_effects.erase(instance_id)
	else:
		status_effects[instance_id] = effects

func _try_apply_side_effect(instance_id: int, technique: Dictionary) -> void:
	if not unit_health.has(instance_id):
		return
	var effect_id := str(technique.get("side_effect", ""))
	var chance := clampf(float(technique.get("side_effect_chance", 0.0)), 0.0, 1.0)
	if effect_id.is_empty() or randf() >= chance:
		return

	var effects: Array = status_effects.get(instance_id, [])
	var remaining_turns := int(technique.get("side_effect_duration", -1))
	var power := int(technique.get("side_effect_power", 0))
	for effect in effects:
		if str(effect.get("id", "")) != effect_id:
			continue
		if int(effect.get("remaining_turns", -1)) >= 0:
			if remaining_turns < 0:
				effect["remaining_turns"] = -1
			else:
				effect["remaining_turns"] = maxi(
					int(effect["remaining_turns"]),
					remaining_turns
				)
		effect["power"] = maxi(int(effect.get("power", 0)), power)
		status_effects[instance_id] = effects
		return

	effects.append({
		"id": effect_id,
		"remaining_turns": remaining_turns,
		"power": power
	})
	status_effects[instance_id] = effects

func _has_status_effect(instance_id: int, effect_id: String) -> bool:
	for effect in status_effects.get(instance_id, []):
		if str(effect.get("id", "")) == effect_id:
			return true
	return false

func _tick_side_effects(player_side: bool) -> void:
	for instance_key in status_effects.keys():
		var instance_id := int(instance_key)
		if (instance_id > 0) != player_side:
			continue
		var effects: Array = status_effects[instance_key]
		var remaining_effects: Array = []
		for effect in effects:
			var effect_id := str(effect.get("id", ""))
			if effect_id in ["burn", "poison"]:
				var effect_name := "brûlure" if effect_id == "burn" else "poison"
				_apply_damage(
					instance_id,
					int(effect.get("power", 1)),
					"effect",
					0,
					false,
					effect_name
				)
				if not unit_health.has(instance_id):
					continue
			var turns_left := int(effect.get("remaining_turns", -1))
			if turns_left > 0:
				turns_left -= 1
				effect["remaining_turns"] = turns_left
			if turns_left != 0:
				remaining_effects.append(effect)
		if remaining_effects.is_empty():
			status_effects.erase(instance_key)
		else:
			status_effects[instance_key] = remaining_effects

func _update_unit_health_display(instance_id: int) -> void:
	if not figure_visuals.has(instance_id):
		return
	var sprite: TextureRect = figure_visuals[instance_id]
	var health_bar := sprite.get_node_or_null("HealthBar") as ProgressBar
	if health_bar != null and unit_health.has(instance_id):
		health_bar.value = unit_health[instance_id]

func _format_hearts(lives: int) -> String:
	return "♥ ".repeat(lives).strip_edges()

func _show_combat_message(message: String) -> void:
	combat_message_label.text = message
	combat_message_label.visible = true
	combat_message_timer.start()

func _on_combat_message_timeout() -> void:
	combat_message_label.visible = false

func _check_battle_over() -> bool:
	if current_phase == BattlePhase.FINISHED:
		return true
	if opponent_heart_lives <= 0 or enemy_figure_positions.is_empty():
		_finish_battle(true)
		return true
	if player_heart_lives <= 0 or player_figure_positions.is_empty():
		_finish_battle(false)
		return true
	return false

func _finish_battle(is_victory: bool) -> void:
	if battle_result_shown:
		return
	battle_result_shown = true
	current_phase = BattlePhase.FINISHED
	turn_status_label.text = "Victoire !" if is_victory else "Défaite..."
	_update_combat_ui()

	var result_detail := "Aucune gemme gagnée."
	if is_victory:
		var reward := maxi(0, int(enemy_data.get("reward", 0)))
		var chance_multiplier := 0
		for figure in selected_figures:
			var stats: Dictionary = figure.get("data", {}).get("stats", {})
			chance_multiplier += maxi(0, int(stats.get("chance", 0)))
		var requested_gems := reward * chance_multiplier
		var received_gems: int = GameManager.add_gems(requested_gems)
		result_detail = "💎 +%d gemmes" % received_gems
		if received_gems < requested_gems:
			result_detail += "\nLe maximum de gemmes (999 999) est atteint."

	_show_battle_result_overlay(is_victory, result_detail)

func _show_battle_result_overlay(is_victory: bool, result_detail: String) -> void:
	var overlay := ColorRect.new()
	overlay.name = "BattleResultOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.04, 0.03, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 210)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#183C32")
	panel_style.border_color = Color("#FFC83C")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "VICTOIRE !" if is_victory else "DÉFAITE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#F2D58B"))
	layout.add_child(title)

	var detail := Label.new()
	detail.text = result_detail
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color("#FFF2D5"))
	layout.add_child(detail)

	var return_button := Button.new()
	return_button.text = "Retour à l'aventure"
	return_button.custom_minimum_size.y = 44
	return_button.pressed.connect(_on_result_return_pressed)
	GameManager.apply_button_skin(return_button)
	layout.add_child(return_button)

func _on_result_return_pressed() -> void:
	return_to_adventure_requested.emit()

func _run_enemy_turn() -> void:
	if current_phase != BattlePhase.ENEMY_TURN:
		return

	for figure in enemy_figures:
		var instance_id := int(figure.get("instance_id", -1))
		if not enemy_figure_positions.has(instance_id):
			continue

		await get_tree().create_timer(0.25).timeout
		if not is_inside_tree() or current_phase != BattlePhase.ENEMY_TURN:
			return
		await _run_enemy_figure_turn(instance_id)
		if _check_battle_over():
			return

	_tick_side_effects(false)
	if _check_battle_over():
		return
	_start_player_turn()

func _get_path_distance_map(
	goal: Vector2i,
	ignored_instance_id: int
) -> Dictionary:
	var distances: Dictionary = {goal: 0}
	var pending: Array[Vector2i] = [goal]
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 0)
	]

	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		for direction in directions:
			var next_cell: Vector2i = current + direction
			if (
				next_cell.x < 0 or next_cell.x >= BOARD_SIZE
				or next_cell.y < 0 or next_cell.y >= BOARD_SIZE
				or distances.has(next_cell)
				or _is_position_occupied(
					next_cell,
					ignored_instance_id,
					_can_pass_obstacles(ignored_instance_id)
				)
			):
				continue

			distances[next_cell] = int(distances[current]) + 1
			pending.append(next_cell)

	return distances

func _get_shortest_path(
	start: Vector2i,
	goal: Vector2i,
	ignored_instance_id: int
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if start == goal:
		return path

	var pending: Array[Vector2i] = [start]
	var previous_cell: Dictionary = {}
	var visited: Dictionary = {start: true}
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 0)
	]

	while not pending.is_empty() and not visited.has(goal):
		var current: Vector2i = pending.pop_front()
		for direction in directions:
			var next_cell: Vector2i = current + direction
			if (
				next_cell.x < 0 or next_cell.x >= BOARD_SIZE
				or next_cell.y < 0 or next_cell.y >= BOARD_SIZE
				or visited.has(next_cell)
				or _is_position_occupied(
					next_cell,
					ignored_instance_id,
					_can_pass_obstacles(ignored_instance_id)
				)
			):
				continue

			visited[next_cell] = true
			previous_cell[next_cell] = current
			pending.append(next_cell)

	if not visited.has(goal):
		return path

	var current := goal
	while current != start:
		path.push_front(current)
		current = previous_cell[current]
	return path

func _run_enemy_figure_turn(instance_id: int) -> void:
	var target: Dictionary = _get_enemy_target(instance_id)
	if target.is_empty():
		defending_units[instance_id] = true
		return

	var actor_position: Vector2i = _get_unit_position(instance_id)
	var target_position: Vector2i = target["position"]
	var figure := _get_unit_figure(instance_id)
	var movement_target := target_position
	if bool(target["is_heart"]):
		movement_target = Vector2i(BOARD_SIZE - 1, CENTER_COLUMN)
	var path_distances := _get_path_distance_map(movement_target, instance_id)
	var best_position := actor_position
	var best_distance := int(path_distances.get(actor_position, NO_PATH_DISTANCE))

	for position in _get_reachable_cells(
		actor_position,
		_get_move_points(figure),
		instance_id
	):
		var distance := int(path_distances.get(position, NO_PATH_DISTANCE))
		if distance < best_distance:
			best_distance = distance
			best_position = position

	if best_position != actor_position:
		var movement_path := _get_shortest_path(
			actor_position,
			best_position,
			instance_id
		)
		if not movement_path.is_empty():
			await _animate_enemy_figure_move(instance_id, movement_path)
			actor_position = best_position

	var action: Dictionary = _choose_enemy_attack(figure, target)
	var performed_action := not action.is_empty()
	if performed_action:
		if bool(target["is_heart"]):
			player_heart_lives = maxi(0, player_heart_lives - 1)
			enemy_heart_attack_count += 1
		else:
			var target_id := int(target["instance_id"])
			var enemy_name := str(figure.get("data", {}).get("name", "Adversaire"))
			if action["type"] == "magic":
				var hit := _apply_damage(
					target_id,
					int(action["damage"]),
					"magic",
					int(action["magic_bonus"]),
					true,
					enemy_name
				)
				if hit:
					_try_apply_side_effect(target_id, action["technique"])
			else:
				_apply_damage(
					target_id,
					int(action["damage"]),
					"physical",
					0,
					true,
					enemy_name
				)
			enemy_figure_attack_count += 1
	if not performed_action:
		defending_units[instance_id] = true
	_update_combat_ui()

func _choose_enemy_attack(figure: Dictionary, target: Dictionary) -> Dictionary:
	var figure_data: Dictionary = figure.get("data", {})
	var stats: Dictionary = figure_data.get("stats", {})
	var figure_class := str(figure_data.get("class", "creature"))
	var target_is_heart := bool(target["is_heart"])
	var target_id := int(target.get("instance_id", 0))
	var target_stats: Dictionary = {}
	if not target_is_heart:
		target_stats = _get_unit_figure(target_id).get("data", {}).get("stats", {})
	var distance := _grid_distance(
		_get_unit_position(int(figure.get("instance_id", -1))),
		target["position"]
	)
	var has_clear_line := _has_clear_attack_line(
		_get_unit_position(int(figure.get("instance_id", -1))),
		target["position"],
		int(figure.get("instance_id", -1))
	)

	var physical_attack: Dictionary = {}
	if distance <= ATTACK_RANGE and has_clear_line:
		var defense_key := "spirit" if target_is_heart else "defense"
		physical_attack = {
			"type": "physical",
			"damage": int(stats.get("attack", 0)),
			"score": maxi(
				1,
				int(stats.get("attack", 0))
				- int(target_stats.get(defense_key, 0))
			)
		}

	var best_magic_attack: Dictionary = {}
	var target_spirit := 0 if target_is_heart else int(target_stats.get("spirit", 0))
	for technique_id in stats.get("techniques", []):
		var technique: Dictionary = GameManager.techniques_catalog.get(
			str(technique_id),
			{}
		)
		var value := int(technique.get("value", 0))
		if technique.get("type", "") != "action" or value >= 0:
			continue
		if (
			distance > _get_action_range(str(technique_id))
			or not has_clear_line
		):
			continue

		var damage: int = absi(value)
		var magic_score := maxi(
			1,
			damage + int(stats.get("magic", 0)) - target_spirit
		)
		if best_magic_attack.is_empty() or magic_score > int(best_magic_attack["score"]):
			best_magic_attack = {
				"type": "magic",
				"damage": damage,
				"magic_bonus": int(stats.get("magic", 0)),
				"score": magic_score,
				"technique": technique
			}

	match figure_class:
		"magician":
			if not best_magic_attack.is_empty():
				return best_magic_attack
			return physical_attack
		"warrior":
			if not physical_attack.is_empty():
				return physical_attack
			return best_magic_attack
		_:
			if (
				not best_magic_attack.is_empty()
				and (
					physical_attack.is_empty()
					or int(best_magic_attack["score"]) > int(physical_attack["score"])
				)
			):
				return best_magic_attack
			return physical_attack

func _get_enemy_target(enemy_instance_id: int) -> Dictionary:
	var heart_target := {
		"instance_id": 0,
		"position": Vector2i(BOARD_SIZE, CENTER_COLUMN),
		"is_heart": true
	}
	var nearest_player_id := _find_nearest_player(enemy_instance_id)

	if enemy_strategy == "heart_only":
		var blocker_id := _find_adjacent_heart_blocker(enemy_instance_id)
		if blocker_id > 0:
			return {
				"instance_id": blocker_id,
				"position": _get_unit_position(blocker_id),
				"is_heart": false
			}
		return heart_target
	if nearest_player_id < 0:
		return heart_target if enemy_strategy == "balanced" else {}
	if enemy_strategy == "figures_only":
		return {
			"instance_id": nearest_player_id,
			"position": _get_unit_position(nearest_player_id),
			"is_heart": false
		}

	var enemy_position: Vector2i = _get_unit_position(enemy_instance_id)
	var nearest_player_position: Vector2i = _get_unit_position(nearest_player_id)
	var heart_distance := _grid_distance(
		enemy_position,
		heart_target["position"]
	)
	var figure_distance := _grid_distance(enemy_position, nearest_player_position)
	var should_attack_heart := false

	if enemy_heart_attack_count < enemy_figure_attack_count:
		should_attack_heart = true
	elif enemy_heart_attack_count == enemy_figure_attack_count:
		should_attack_heart = heart_distance <= figure_distance

	if should_attack_heart:
		return heart_target
	return {
		"instance_id": nearest_player_id,
		"position": nearest_player_position,
		"is_heart": false
	}

func _find_adjacent_heart_blocker(enemy_instance_id: int) -> int:
	var enemy_position: Vector2i = _get_unit_position(enemy_instance_id)
	var heart_approach_position := Vector2i(BOARD_SIZE - 1, CENTER_COLUMN)
	var direct_path_distance := _grid_distance(
		enemy_position,
		heart_approach_position
	)

	for player_id in player_figure_positions:
		var player_position: Vector2i = player_figure_positions[player_id]
		if _grid_distance(enemy_position, player_position) != ATTACK_RANGE:
			continue
		if (
			_grid_distance(enemy_position, player_position)
			+ _grid_distance(player_position, heart_approach_position)
			== direct_path_distance
		):
			return int(player_id)
	return -1

func _find_nearest_player(enemy_id: int) -> int:
	var nearest_id := -1
	var nearest_distance := BOARD_SIZE * BOARD_SIZE + 1
	var enemy_position: Vector2i = _get_unit_position(enemy_id)

	for player_id in player_figure_positions:
		var distance := _grid_distance(
			enemy_position,
			player_figure_positions[player_id]
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = int(player_id)
	return nearest_id

func _animate_enemy_figure_move(
	instance_id: int,
	path: Array[Vector2i]
) -> void:
	if path.is_empty() or not figure_visuals.has(instance_id):
		return

	var sprite: TextureRect = figure_visuals[instance_id]
	var cell_size: float = board_grid.get_child(0).size.x
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	for destination in path:
		var cell_center := _get_cell_center(destination.x, destination.y)
		var target_position := Vector2(
			cell_center.x - sprite.size.x / 2.0,
			cell_center.y + cell_size / 2.0 - sprite.size.y
		)
		sprite.z_index = destination.x
		tween.tween_property(
			sprite,
			"position",
			target_position,
			ENEMY_STEP_DURATION
		)

	await tween.finished
	var final_position: Vector2i = path[path.size() - 1]
	enemy_figure_positions[instance_id] = final_position
	_update_unit_health_display(instance_id)

func _start_player_turn() -> void:
	if _check_battle_over():
		return
	current_phase = BattlePhase.PLAYER_MOVEMENT
	player_move_points_used.clear()
	player_acted.clear()
	selected_actor_id = -1
	pending_action = ""
	_update_combat_ui()
