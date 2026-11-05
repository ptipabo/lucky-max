extends Control

const CELL_GAP := 2.0
const BOARD_SIZE := 9
const CENTER_COLUMN := 4

var main_layout: VBoxContainer
var board_grid: GridContainer
var board_container: CenterContainer
var opponent_lives_label: Label
var player_lives_label: Label
var player_figures_container: HBoxContainer
var player_figure_slots: Array[Panel] = []
var enemy_id: String = ""
var selected_instance_ids: Array = []
var selected_figures: Array = []
var figures_layer: Control
var combat_button: Button

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

	opponent_lives_label = Label.new()
	opponent_lives_label.text = "♥ ♥ ♥"
	opponent_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_lives_label.add_theme_font_size_override("font_size", 25)
	opponent_lives_label.add_theme_color_override(
		"font_color", Color("#E85B5B")
	)
	opponent_lives_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_child(opponent_lives_label)

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

			board_grid.add_child(cell)
			
			cell.gui_input.connect(_on_cell_input.bind(row, column))

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

func configure(opponent_id: String, instance_ids: Array) -> void:
	enemy_id = opponent_id
	selected_instance_ids = instance_ids.duplicate()

	var collection: Array = GameManager.get_collection()
	selected_figures.clear()

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
	column: int
) -> void:

	var instance_id: int = int(figure.get("instance_id", -1))

	if instance_id < 0 or figures_layer == null:
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
	sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite.gui_input.connect(_on_placed_figure_input.bind(instance_id))

	sprite.size = Vector2(sprite_width, sprite_height)

	# Centrage horizontal et alignement du bas sur la case.
	sprite.position = Vector2(
		cell_center.x - sprite_width / 2.0,
		cell_center.y + cell_size / 2.0 - sprite_height
	)

	# Les figurines situées plus bas passent devant.
	sprite.z_index = row

	figures_layer.add_child(sprite)

	# Mémorisation de l'illustration et de sa position.
	figure_visuals[instance_id] = sprite
	player_figure_positions[instance_id] = Vector2i(row, column)

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

	var valid_position := (
		row >= 7
		and row <= 8
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

		# Une figurine venant du bas ne peut pas échanger
		# sa place avec une figurine déjà posée.
		if occupied_instance_id != -1 and not drag_origin_was_placed:
			valid_position = false

	if valid_position:
		var figure: Dictionary = {}

		for selected_figure in selected_figures:
			if int(selected_figure.get("instance_id", -1)) == dragged_instance_id:
				figure = selected_figure
				break

		if not figure.is_empty():
			var was_placed := drag_origin_was_placed
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

			_create_figure_visual(figure, row, column)

			if not exchanged_figure.is_empty() and was_placed:
				_create_figure_visual(
					exchanged_figure,
					old_position.x,
					old_position.y
				)

			_refresh_player_figure_slots()
			return

	# Dépôt invalide : la figurine retourne à son emplacement initial.
	_cancel_figure_drag()

func _on_placed_figure_input(event: InputEvent, instance_id: int) -> void:
	if deployment_confirmed:
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
	combat_button = Button.new()
	combat_button.text = "COMBAT !"
	combat_button.custom_minimum_size = Vector2(0, 48)
	combat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_button.visible = false

	main_layout.add_child(combat_button)
	combat_button.pressed.connect(_on_combat_button_pressed)

func _update_combat_button() -> void:
	if combat_button == null:
		return

	combat_button.visible = (
		player_figure_positions.size() == 3
		and not is_dragging_figure
	)

var deployment_confirmed: bool = false


func _on_combat_button_pressed() -> void:
	if player_figure_positions.size() != 3:
		return

	if is_dragging_figure:
		return

	deployment_confirmed = true
	combat_button.disabled = true
	combat_button.text = "DÉPLOIEMENT VALIDÉ !"

	print("Déploiement confirmé !")
	print("Positions des figurines : ", player_figure_positions)
