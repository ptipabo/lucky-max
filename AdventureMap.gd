extends Control

signal stage_selected(stage_id: String, enemy_data: Dictionary)

const BACKGROUND_COLOR := Color("#263D32")
const STONE_COLOR := Color("#806B50")
const GOLD_COLOR := Color("#E8B95D")
const LOCKED_COLOR := Color("#514E48")
const TEXT_COLOR := Color("#FFF2D5")
const ADVENTURE_BACKGROUND: Texture2D = preload("res://assets/backgrounds/adventure_bg.jpg")

const MAP_HEIGHT := 1250.0
const NODE_SIZE := Vector2(76, 76)

const STAGES: Array[Dictionary] = [
	{"id": "stage_01", "name": "Entrée de la jungle", "unlocked": true, "enemy_id": "rival_explorer"},
	{"id": "stage_02", "name": "Sanctuaire oublié", "unlocked": false, "enemy_id": "jade_guardian"},
	{"id": "stage_03", "name": "Ruines de jade", "unlocked": false, "enemy_id": "relic_hunter"},
	{"id": "stage_04", "name": "Temple du soleil", "unlocked": false, "enemy_id": "sun_priest"},
	{"id": "stage_05", "name": "Cité engloutie", "unlocked": false, "enemy_id": "mercenary_captain"},
	{"id": "stage_06", "name": "Pont des anciens", "unlocked": false, "enemy_id": "ancient_sentinel"},
	{"id": "stage_07", "name": "Temple des serpents", "unlocked": false, "enemy_id": "high_priest"},
	{"id": "stage_08", "name": "Sanctuaire céleste", "unlocked": false, "enemy_id": "forgotten_ruler"}
]

var enemies_by_id: Dictionary = {}

# Cette classe dessine le chemin sur la carte.
class MapCanvas extends Control:
	var path_points: PackedVector2Array = []
	var background_texture: Texture2D
	
	func _draw() -> void:

		# 1. Dessin du décor.
		if background_texture != null:

			var texture_size := background_texture.get_size()

			# Calcul du recadrage pour conserver les proportions.
			var target_ratio: float = size.x / size.y
			var texture_ratio: float = (
				texture_size.x / texture_size.y
			)

			var source_rect := Rect2(
				Vector2.ZERO,
				texture_size
			)

			if texture_ratio > target_ratio:

				var new_width := texture_size.y * target_ratio
				source_rect.position.x = (
					texture_size.x - new_width
				) / 2.0
				source_rect.size.x = new_width

			else:

				var new_height := texture_size.x / target_ratio
				source_rect.position.y = (
					texture_size.y - new_height
				) / 2.0
				source_rect.size.y = new_height

			draw_texture_rect_region(
				background_texture,
				Rect2(Vector2.ZERO, size),
				source_rect
			)

		# 2. Assombrissement léger du décor.
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0.03, 0.06, 0.04, 0.30)
		)

		# 3. Dessin du chemin.
		if path_points.size() > 1:

			draw_polyline(
				path_points,
				Color("#403A2F"),
				29.0,
				true
			)

			draw_polyline(
				path_points,
				Color("#A88C59"),
				19.0,
				true
			)

			draw_polyline(
				path_points,
				Color("#D0B77F"),
				3.0,
				true
			)


var map_canvas: MapCanvas
var stage_buttons: Array[Button] = []


func _ready() -> void:
	_load_enemies()
	_build_interface()


# --------------------------------------------------
# INTERFACE
# --------------------------------------------------

func _build_interface() -> void:

	# Fond général.
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Organisation verticale.
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	# En-tête.
	var header := VBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 85)
	header.add_theme_constant_override("separation", 4)
	layout.add_child(header)

	var title := Label.new()
	title.text = "L'ANCIENNE CIVILISATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", GOLD_COLOR)
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Explore les terres oubliées..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_child(subtitle)

	# Zone défilante.
	var scroll := ScrollContainer.new()
	scroll.name = "AdventureScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)

	# Contenu de la carte.
	map_canvas = MapCanvas.new()
	map_canvas.name = "MapCanvas"
	map_canvas.background_texture = ADVENTURE_BACKGROUND
	map_canvas.custom_minimum_size = Vector2(0, MAP_HEIGHT)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(map_canvas)

	# Création des étapes après le calcul de la taille.
	map_canvas.resized.connect(_layout_stages)
	call_deferred("_layout_stages")
	call_deferred("_scroll_to_bottom", scroll)


# --------------------------------------------------
# CRÉATION DU PARCOURS
# --------------------------------------------------

func _layout_stages() -> void:
	if map_canvas == null:
		return

	var map_width := map_canvas.size.x

	if map_width <= 0:
		return

	# On supprime les anciens boutons.
	for child in map_canvas.get_children():
		child.queue_free()

	stage_buttons.clear()

	var points := PackedVector2Array()

	# Positions verticales des étapes.
	var vertical_spacing := 145.0

	# Alternance gauche / droite.
	var horizontal_positions := [
		0.35,
		0.65,
		0.78,
		0.45,
		0.22,
		0.42,
		0.72,
		0.55
	]

	for i in range(STAGES.size()):

		var x: float = map_width * horizontal_positions[i]
		var y: float = MAP_HEIGHT - 90.0 - (float(i) * vertical_spacing)

		points.append(Vector2(x, y))

	# On transmet les positions à la classe chargée du dessin.
	map_canvas.path_points = points
	map_canvas.queue_redraw()

	# Création des boutons.
	for i in range(STAGES.size()):
		_create_stage_button(i, points[i])


func _create_stage_button(index: int,position_on_map: Vector2) -> void:
	var stage: Dictionary = STAGES[index]
	var is_unlocked: bool = stage["unlocked"]
	
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	
	button.position = position_on_map - NODE_SIZE / 2.0
	
	button.text = str(index + 1)
	
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override(
		"font_color",
		TEXT_COLOR
	)
	
	# Apparence des étapes accessibles et verrouillées.
	var button_color := STONE_COLOR
	
	if is_unlocked:
		button_color = GOLD_COLOR
	else:
		button_color = LOCKED_COLOR
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = button_color
	normal_style.set_corner_radius_all(38)
	normal_style.set_border_width_all(4)
	normal_style.border_color = Color("#D8C49A")
	# Ombre pour donner du relief au médaillon.
	normal_style.shadow_color = Color(0, 0, 0, 0.55)
	normal_style.shadow_size = 8
	normal_style.shadow_offset = Vector2(0, 5)
	
	normal_style.set_content_margin_all(8)
	
	button.add_theme_stylebox_override(
		"normal",
		normal_style
	)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color("#F2D58B")
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color("#B59A63")
	
	button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)
	
	button.add_theme_stylebox_override(
		"hover",
		hover_style
	)
	
	button.disabled = not is_unlocked
	
	button.pressed.connect(
		_on_stage_pressed.bind(stage["id"])
	)
	
	map_canvas.add_child(button)
	stage_buttons.append(button)
	
	# Nom de l'étape.
	var stage_label := Label.new()
	
	stage_label.text = stage["name"]
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.position = Vector2(
		position_on_map.x - 100,
		position_on_map.y + 43
	)
	stage_label.size = Vector2(200, 30)
	
	stage_label.add_theme_font_size_override("font_size", 13)
	stage_label.add_theme_color_override(
		"font_color",
		TEXT_COLOR if is_unlocked else Color("#AAA49A")
	)
	
	map_canvas.add_child(stage_label)
	# Affichage du portrait de l'adversaire.
	_create_enemy_portrait(index, stage, position_on_map)

# --------------------------------------------------
# SÉLECTION D'UNE ÉTAPE
# --------------------------------------------------

func _on_stage_pressed(stage_id: String) -> void:
	for stage in STAGES:
		if stage["id"] == stage_id:
			var enemy_id: String = stage.get("enemy_id", "")
			var enemy_data: Dictionary = enemies_by_id.get(
				enemy_id,
				{}
			)
			
			if enemy_data.is_empty():
				push_warning("Adversaire introuvable : " + enemy_id)
				return
			
			stage_selected.emit(stage_id, enemy_data)
			return
	
func _scroll_to_bottom(scroll: ScrollContainer) -> void:
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
	
func _load_enemies() -> void:
	var file := FileAccess.open(
		"res://data/enemies.json",
		FileAccess.READ
	)
	
	if file == null:
		push_error("Impossible de charger enemies.json")
		return
		
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	
	if error != OK:
		push_error(
			"Erreur JSON : " + json.get_error_message()
		)
		return
		
	var data: Dictionary = json.data
	
	for enemy in data.get("enemies", []):
		enemies_by_id[enemy["id"]] = enemy

func _create_enemy_portrait(index: int, stage: Dictionary, stage_position: Vector2) -> void:
	var enemy_id: String = stage.get("enemy_id", "")

	if not enemies_by_id.has(enemy_id):
		return

	var enemy: Dictionary = enemies_by_id[enemy_id]
	var portrait_path: String = enemy.get("portrait", "")

	# Vérification de l'existence du portrait.
	if not ResourceLoader.exists(portrait_path):
		return

	var portrait_texture := load(portrait_path) as Texture2D

	if portrait_texture == null:
		return

	var portrait := TextureRect.new()

	portrait.texture = portrait_texture

	# Taille réduite du portrait.
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.size = Vector2(48, 64)

	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Placement à gauche ou à droite du médaillon.
	var side: float = 1.0

	if stage_position.x > map_canvas.size.x * 0.5:
		side = -1.0

	portrait.position = Vector2(
		stage_position.x + (side * 68.0) - 24.0,
		stage_position.y - 32.0
	)

	# Les adversaires verrouillés sont assombris.
	if not stage.get("unlocked", false):
		portrait.modulate = Color(0.45, 0.45, 0.45, 0.85)
	
	map_canvas.add_child(portrait)
	portrait.reset_size()
	portrait.size = Vector2(48, 64)
