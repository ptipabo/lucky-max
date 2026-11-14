extends RefCounted

var battle: Node

func setup(battle_context: Node) -> void:
	battle = battle_context

# Permet d'afficher une icône pour chaque type d'attaque spéciale
func get_technique_emoji(technique_id: String) -> String:
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

# Applique les éventuels effets secondaires des techniques spéciales
func try_apply_side_effect(instance_id: int, technique: Dictionary) -> void:
	if not battle.unit_health.has(instance_id):
		return

	var effect_id := str(technique.get("side_effect", ""))
	var chance := clampf(
		float(technique.get("side_effect_chance", 0.0)),
		0.0,
		1.0
	)

	if effect_id.is_empty() or randf() >= chance:
		return

	var effects: Array = battle.status_effects.get(instance_id, [])
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
		battle.status_effects[instance_id] = effects
		return

	effects.append({
		"id": effect_id,
		"remaining_turns": remaining_turns,
		"power": power
	})

	battle.status_effects[instance_id] = effects

# Permet de générer les boutons d'attaque spéciales de chaque personnage selon
# les techniques qu'il possède
func populate_technique_buttons(instance_id: int) -> void:
	for button in battle.technique_buttons:
		button.set_meta("technique_id", "")
		button.text = ""
		button.tooltip_text = ""
		button.disabled = true

	var figure: Dictionary = battle._get_player_figure(instance_id)
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	var slot_index := 0

	for technique_id in stats.get("techniques", []):
		var technique: Dictionary = GameManager.techniques_catalog.get(
			str(technique_id),
			{}
		)

		if technique.get("type", "") != "action":
			continue

		if slot_index >= battle.technique_buttons.size():
			break

		var button: Button = battle.technique_buttons[slot_index]
		button.set_meta("technique_id", str(technique_id))
		button.text = get_technique_emoji(str(technique_id))
		button.tooltip_text = str(technique.get("name", technique_id))
		GameManager.apply_button_skin(button)
		button.disabled = false
		slot_index += 1

# Permet de vérifier si une technique est utilisée correctement ou non par le joueur
func resolve_technique(
	target_id: int,
	actor_stats: Dictionary,
	actor_name: String
) -> bool:
	var technique: Dictionary = GameManager.techniques_catalog.get(
		battle.pending_action,
		{}
	)

	var value := int(technique.get("value", 0))

	# Technique Foudre : dégâts de zone
	if battle.pending_action == "thunder":
		var origin: Vector2i = battle._get_unit_position(
			battle.selected_actor_id
		)

		var magic_bonus: int = int(actor_stats.get("magic", 0))

		for enemy_id in battle.enemy_figure_positions.keys():
			var target_id_in_area: int = int(enemy_id)
			var target_position: Vector2i = battle._get_unit_position(
				target_id_in_area
			)

			if battle._grid_distance(origin, target_position) <= 2:
				battle._apply_damage(
					target_id_in_area,
					abs(value),
					"magic",
					magic_bonus,
					true,
					actor_name
				)

		return true

	if value < 0 and target_id < 0:
		var hit: bool = battle._apply_damage(
			target_id,
			abs(value),
			"magic",
			int(actor_stats.get("magic", 0)),
			true,
			actor_name
		)

		if hit:
			try_apply_side_effect(target_id, technique)

		return true

	elif value > 0 and target_id > 0:
		battle._apply_healing(target_id, value)
		return true

	return false

# Permet de recalculer les points de déplacement d'un personnage d'après une technique
func get_move_points(figure: Dictionary) -> int:
	if battle._has_status_effect(
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
	var figure: Dictionary = battle._get_unit_figure(instance_id)
	var stats: Dictionary = figure.get("data", {}).get("stats", {})
	return stats.get("techniques", []).has("ignore_walls")

# Permet d'effectuer une technique si un des boutons de technique est appuyé
func on_technique_button_pressed(index: int) -> void:
	if index < 0 or index >= battle.technique_buttons.size():
		return

	var button: Button = battle.technique_buttons[index]
	var technique_id := str(button.get_meta("technique_id", ""))

	if technique_id.is_empty():
		return

	battle._clear_movement_highlights()
	battle.pending_action = technique_id

	var technique: Dictionary = GameManager.techniques_catalog.get(
		technique_id,
		{}
	)

	# Afficher le halo uniquement pour les techniques offensives
	if int(technique.get("value", 0)) < 0:
		battle._highlight_targetable_cells(technique_id)

	battle._update_combat_ui()
