extends RefCounted

var battleDeployment: Node

func setup(battle_context: Node) -> void:
	battleDeployment = battle_context

# Applique les éventuels effets secondaires des techniques spéciales
func try_apply_side_effect(instance_id: int, technique: Dictionary) -> void:
	if not battleDeployment.unit_health.has(instance_id):
		return

	var effect_id := str(technique.get("side_effect", ""))
	var chance := clampf(
		float(technique.get("side_effect_chance", 0.0)),
		0.0,
		1.0
	)

	if effect_id.is_empty() or randf() >= chance:
		return

	var effects: Array = battleDeployment.status_effects.get(instance_id, [])
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
		battleDeployment.status_effects[instance_id] = effects
		return

	effects.append({
		"id": effect_id,
		"remaining_turns": remaining_turns,
		"power": power
	})

	battleDeployment.status_effects[instance_id] = effects

# Permet de générer les boutons d'attaque spéciales de chaque personnage selon
# les techniques qu'il possède
func populate_technique_buttons(instance_id: int) -> void:
	# Réinitialiser tous les emplacements
	for button in battleDeployment.technique_buttons:
		for child in button.get_children():
			if child is TextureRect:
				button.remove_child(child)
				child.queue_free()
		button.set_meta("technique_id", "")
		button.text = ""
		button.icon = null
		button.tooltip_text = ""
		button.disabled = true
		button.add_theme_constant_override("icon_max_width", 32)

	# Premier emplacement : attaque de base
	if battleDeployment.technique_buttons.size() > 0:
		var attack_button: Button = battleDeployment.technique_buttons[0]
		attack_button.set_meta("technique_id", "attack")
		attack_button.icon = null
		attack_button.tooltip_text = "Attaque"
		attack_button.disabled = false

		var attack_texture: Texture2D = load(
			"res://assets/icons/techniques/attack_icon.png"
		)
		if attack_texture != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = attack_texture
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(60, 60)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.set_anchors_preset(Control.PRESET_CENTER)
			icon_rect.position = Vector2(-30, -35)
			attack_button.add_child(icon_rect)

	# Récupérer les techniques du personnage
	var figure: Dictionary = battleDeployment._get_player_figure(instance_id)
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	var slot_index := 1

	for technique_id in stats.get("techniques", []):
		var technique: Dictionary = GameManager.techniques_catalog.get(
			str(technique_id),
			{}
		)

		if technique.get("type", "") != "action":
			continue

		if slot_index >= battleDeployment.technique_buttons.size():
			break

		var button: Button = battleDeployment.technique_buttons[slot_index]
		button.set_meta("technique_id", str(technique_id))

		var icon_path := "res://assets/icons/techniques/" + str(
			technique.get("icon", "")
		)

		button.icon = null
		button.tooltip_text = str(technique.get("name", technique_id))
		button.disabled = false

		var icon_texture: Texture2D = load(icon_path)
		if icon_texture != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_texture
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(60, 60)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.set_anchors_preset(Control.PRESET_CENTER)
			icon_rect.position = Vector2(-30, -40)
			button.add_child(icon_rect)

		slot_index += 1

# Permet de vérifier si une technique est utilisée correctement ou non par le joueur
func resolve_technique(
	target_id: int,
	actor_stats: Dictionary,
	actor_name: String
) -> bool:
	var technique: Dictionary = GameManager.techniques_catalog.get(
		battleDeployment.pending_action,
		{}
	)

	var value := int(technique.get("value", 0))

	# Technique Foudre : dégâts de zone
	if battleDeployment.pending_action == "thunder":
		var origin: Vector2i = battleDeployment._get_unit_position(
			battleDeployment.selected_actor_id
		)

		var magic_bonus: int = int(actor_stats.get("magic", 0))

		# Copie des identifiants pour éviter les problèmes si un ennemi est supprimé
		var enemies_to_hit: Array = battleDeployment.enemy_figure_positions.keys().duplicate()

		for enemy_id in enemies_to_hit:
			var target_id_in_area: int = int(enemy_id)

			if not battleDeployment.unit_health.has(target_id_in_area):
				continue

			var enemy_position: Vector2i = battleDeployment._get_unit_position(
				target_id_in_area
			)

			if battleDeployment._grid_distance(origin, enemy_position) <= 2:
				var target_sprite = battleDeployment.figure_visuals.get(target_id_in_area)
				var sprite_position := Vector2.ZERO
				var sprite_size := Vector2.ZERO
				var sprite_z_index := 0

				if is_instance_valid(target_sprite):
					sprite_position = target_sprite.position
					sprite_size = target_sprite.size
					sprite_z_index = target_sprite.z_index

				var hit: bool = battleDeployment._apply_damage(
					target_id_in_area,
					abs(value),
					"magic",
					magic_bonus,
					true,
					actor_name,
					true
				)

				if hit:
					battleDeployment._play_technique_animation(
						"thunder",
						sprite_position,
						sprite_size,
						sprite_z_index,
						target_sprite,
						not battleDeployment.unit_health.has(target_id_in_area)
					)

					try_apply_side_effect(target_id_in_area, technique)

		return true

	if value < 0 and target_id < 0:
		var target_sprite := battleDeployment.figure_visuals.get(target_id) as TextureRect

		var target_position := Vector2.ZERO
		var target_size := Vector2.ZERO
		var target_z_index := 0

		if is_instance_valid(target_sprite):
			target_position = target_sprite.position
			target_size = target_sprite.size
			target_z_index = target_sprite.z_index

		var hit: bool = battleDeployment._apply_damage(
			target_id,
			abs(value),
			"magic",
			int(actor_stats.get("magic", 0)),
			true,
			actor_name,
			battleDeployment.pending_action == "fire"
		)

		if hit:
			if (battleDeployment.pending_action == "fire" 
				or battleDeployment.pending_action == "thunder"
				or battleDeployment.pending_action == "darkness"
				or battleDeployment.pending_action == "ice"):
				battleDeployment._play_technique_animation(
					battleDeployment.pending_action,
					target_position,
					target_size,
					target_z_index,
					target_sprite,
					not battleDeployment.unit_health.has(target_id)
				)

			try_apply_side_effect(target_id, technique)

		return true

	elif value > 0 and target_id > 0:
		battleDeployment._apply_healing(target_id, value)
		return true

	return false

# Permet de recalculer les points de déplacement d'un personnage d'après une technique
func get_move_points(figure: Dictionary) -> int:
	if battleDeployment._has_status_effect(
		int(figure.get("instance_id", -1)),
        "freeze"
	):
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

# Permet à un personnage de passer à travers les obstacles s'il possède une capacité le permettant
func can_pass_obstacles(instance_id: int) -> bool:
	var figure: Dictionary = battleDeployment._get_unit_figure(instance_id)
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	return stats.get("techniques", []).has("ignore_walls")

# Permet d'effectuer une technique si un des boutons de technique est appuyé
func on_technique_button_pressed(index: int) -> void:
	if index < 0 or index >= battleDeployment.technique_buttons.size():
		return

	var button: Button = battleDeployment.technique_buttons[index]
	var technique_id := str(button.get_meta("technique_id", ""))

	if technique_id.is_empty():
		return

	battleDeployment._clear_movement_highlights()
	battleDeployment.pending_action = technique_id

	var technique: Dictionary = GameManager.techniques_catalog.get(
		technique_id,
		{}
	)

	# Afficher le halo uniquement pour les techniques offensives
	if int(technique.get("value", 0)) < 0:
		battleDeployment._highlight_targetable_cells(technique_id)

	battleDeployment._update_combat_ui()
