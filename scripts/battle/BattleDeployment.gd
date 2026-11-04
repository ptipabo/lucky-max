extends Control

const CELL_GAP := 2.0
const BOARD_SIZE := 11
const CENTER_COLUMN := 5

var board_grid: GridContainer
var board_container: CenterContainer
var opponent_lives_label: Label
var player_lives_label: Label

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
	var main_layout := VBoxContainer.new()
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
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var screen_width: float = get_viewport_rect().size.x - 24.0
	board_container.custom_minimum_size = Vector2(screen_width, screen_width)

	board_container.resized.connect(_update_board_size)
	main_layout.add_child(board_container)

	board_grid = GridContainer.new()
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.columns = BOARD_SIZE
	board_grid.add_theme_constant_override("h_separation", 2)
	board_grid.add_theme_constant_override("v_separation", 2)
	board_container.add_child(board_grid)

	_create_board()
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
	
	_update_board_size()


func _create_board() -> void:
	for row in range(BOARD_SIZE):
		for column in range(BOARD_SIZE):
			var cell := Panel.new()
			cell.custom_minimum_size = Vector2(1, 1)

			var style := StyleBoxFlat.new()

			if (row + column) % 2 == 0:
				style.bg_color = Color("#557A61")
			else:
				style.bg_color = Color("#3E624D")

			style.set_border_width_all(1)
			style.border_color = Color("#253F32")

			cell.add_theme_stylebox_override("panel", style)
			board_grid.add_child(cell)

func _update_board_size() -> void:
	if board_container == null or board_grid == null:
		return

	var available_width: float = board_container.size.x
	var available_height: float = board_container.size.y

	# On attend que le conteneur ait reçu ses dimensions.
	if available_width <= 0 or available_height <= 0:
		return

	# Le plateau doit rester carré.
	var board_size: float = min(available_width, available_height)

	var cell_size: float = (
		board_size - (CELL_GAP * (BOARD_SIZE - 1))
	) / BOARD_SIZE

	if cell_size <= 0:
		return

	for cell in board_grid.get_children():
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
