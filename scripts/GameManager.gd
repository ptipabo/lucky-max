
extends Node

signal points_changed(new_total: int)
signal gems_changed(new_total: int)
signal currency_limit_reached(currency_name: String)
signal collection_changed
signal save_completed
# Recharge automatique des points
signal recharge_status_changed(ready_at: int)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
const MAX_CURRENCY: int = 999999
const CHARACTERS_CATALOG_PATH := "res://data/characters.json"
const TECHNIQUES_CATALOG_PATH := "res://data/techniques.json"
const BUTTON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/backgrounds/button_extra_short.png"),
	preload("res://assets/backgrounds/button_short.png"),
	preload("res://assets/backgrounds/button_medium.png"),
	preload("res://assets/backgrounds/button_large.png")
]
const BUTTON_TEXTURE_WIDTHS: Array[int] = [144, 279, 541, 783]
const RECHARGE_THRESHOLD: int = 10
const RECHARGE_AMOUNT: int = 10
const RECHARGE_DELAY_SECONDS: int = 15#300

var save_load_valid: bool = true
var recharge_ready_at: int = 0
var recharge_paused: bool = false
var characters_catalog: Dictionary = {}
var techniques_catalog: Dictionary = {}
var points: int = 0
var gems: int = 0
var collection: Array = []
var next_instance_id: int = 1


func _ready() -> void:
	load_characters_catalog()
	load_techniques_catalog()
	load_game()
	
	# Ne jamais sauvegarder si le chargement a échoué.
	if not save_load_valid:
		push_error("Le jeu est arrêté pour protéger la sauvegarde existante.")
		return
	
	_update_recharge_schedule()
	_save_game()

	var recharge_timer := Timer.new()
	recharge_timer.name = "RechargeTimer"
	recharge_timer.wait_time = 1.0
	recharge_timer.timeout.connect(_check_recharge)
	add_child(recharge_timer)
	recharge_timer.start()

func apply_button_skin(button: Button) -> void:
	if not button.has_meta("skin_resize_connected"):
		button.set_meta("skin_resize_connected", true)
		button.resized.connect(_update_button_skin.bind(button))
	_update_button_skin(button)

func _update_button_skin(button: Button) -> void:
	if not is_instance_valid(button):
		return

	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width := 0.0
	if font != null:
		for line in button.text.split("\n"):
			text_width = maxf(
				text_width,
				font.get_string_size(
					line,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size
				).x
			)

	var requested_width: float = maxf(
		button.custom_minimum_size.x,
		text_width + 64.0
	)
	requested_width = maxf(requested_width, button.size.x)
	var texture_index := BUTTON_TEXTURE_WIDTHS.size() - 1
	for index in range(BUTTON_TEXTURE_WIDTHS.size()):
		if requested_width <= BUTTON_TEXTURE_WIDTHS[index]:
			texture_index = index
			break

	if int(button.get_meta("skin_texture_index", -1)) == texture_index:
		return
	button.set_meta("skin_texture_index", texture_index)

	var normal := _make_button_stylebox(BUTTON_TEXTURES[texture_index])
	button.add_theme_stylebox_override("normal", normal)

	var hover := _make_button_stylebox(BUTTON_TEXTURES[texture_index])
	hover.modulate_color = Color(1.12, 1.12, 1.12, 1.0)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := _make_button_stylebox(BUTTON_TEXTURES[texture_index])
	pressed.modulate_color = Color(0.78, 0.72, 0.62, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled := _make_button_stylebox(BUTTON_TEXTURES[texture_index])
	disabled.modulate_color = Color(0.58, 0.58, 0.58, 0.8)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)

func _make_button_stylebox(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 28
	style.texture_margin_right = 28
	style.texture_margin_top = 18
	style.texture_margin_bottom = 18
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

# --------------------------------------------------
# POINTS
# --------------------------------------------------

# Permet d'ajouter des points au compteur du joueur
func add_points(amount: int) -> void:
	if amount <= 0:
		return

	var previous_points := points
	points = mini(MAX_CURRENCY, points + amount)
	if points == MAX_CURRENCY:
		currency_limit_reached.emit("points")
	if points == previous_points:
		return

	_update_recharge_schedule()
	_save_game()
	# On emet le signal disant que les points ont été modifiés et on précise leur nouveau montant
	# afin que les autres scripts puissent le savoir
	points_changed.emit(points)

func add_gems(amount: int) -> int:
	if amount <= 0:
		return 0

	var previous_gems := gems
	gems = mini(MAX_CURRENCY, gems + amount)
	var added_gems := gems - previous_gems
	if gems == MAX_CURRENCY:
		currency_limit_reached.emit("gems")
	if added_gems <= 0:
		return 0

	_save_game()
	gems_changed.emit(gems)
	return added_gems

# Permet de retirer des points du compteur du joueur
func spend_points(amount: int) -> bool:
	if amount < 0 or points < amount:
		return false

	if amount == 0:
		return true

	points -= amount
	_update_recharge_schedule()
	_save_game()
	# On emet le signal disant que les points ont été modifiés et on précise leur nouveau montant
	# afin que les autres scripts puissent le savoir
	points_changed.emit(points)
	return true

# --------------------------------------------------
# COLLECTION
# --------------------------------------------------

# Permet d'ajouter une figurine à la collection du joueur
func add_figurine(character_id: String) -> Dictionary:
	if character_id.strip_edges().is_empty():
		return {}

	var figurine: Dictionary = {
		"instance_id": next_instance_id,
		"character_id": character_id,
		"level": 1,
		"acquired_at": Time.get_datetime_string_from_system(true)
	}

	next_instance_id += 1
	collection.append(figurine)

	_save_game()
	# On emet le signal disant que la collection de figurines à été modifiée afin que les autres
	# scripts puissent le savoir
	collection_changed.emit()

	return figurine.duplicate(true)

# Permet de retirer une figurine de la collection du joueur
func remove_figurine(instance_id: int) -> Dictionary:
	for i in range(collection.size()):
		var figurine: Dictionary = collection[i]

		if int(figurine.get("instance_id", -1)) == instance_id:
			var removed: Dictionary = figurine.duplicate(true)
			collection.remove_at(i)

			_save_game()
			# On emet le signal disant que la collection de figurines à été modifiée afin que les
			# autres scripts puissent le savoir
			collection_changed.emit()

			return removed

	return {}

# Permet de récupérer toutes les figurines actuellement possédées par le joueur
func get_collection() -> Array:
	return collection.duplicate(true)

# Permet de connaître le nombre exacte de figurines possédées par le joueur
func get_figurine_count() -> int:
	return collection.size()

# Permet de mettre à jour le temps de recharge automatique des points
func _update_recharge_schedule() -> void:
	var previous_ready_at := recharge_ready_at

	if points >= RECHARGE_THRESHOLD:
		recharge_ready_at = 0
	elif recharge_ready_at <= 0:
		recharge_ready_at = (
			int(Time.get_unix_time_from_system())
			+ RECHARGE_DELAY_SECONDS
		)

	if previous_ready_at != recharge_ready_at:
		# On emet le signal disant que le status de recharge a changé et on précise dans combien 
		# de secondes la recharge va se produire afin que les autres scripts puissent le savoir
		recharge_status_changed.emit(recharge_ready_at)

# Permet de vérifier si les points ont besoin d'être rechargés ou non
func _check_recharge() -> void:
	if recharge_paused:
		return
	
	var now := int(Time.get_unix_time_from_system())

	if points >= RECHARGE_THRESHOLD:
		if recharge_ready_at != 0:
			recharge_ready_at = 0
			_save_game()
			# On emet le signal disant que le status de recharge a changé et on précise dans combien
			# de secondes la recharge va se produire afin que les autres scripts puissent le savoir
			recharge_status_changed.emit(0)
		return

	if recharge_ready_at <= 0:
		recharge_ready_at = now + RECHARGE_DELAY_SECONDS
		_save_game()
		# On emet le signal disant que le status de recharge a changé et on précise dans combien 
		# de secondes la recharge va se produire afin que les autres scripts puissent le savoir
		recharge_status_changed.emit(recharge_ready_at)
		return

	if now >= recharge_ready_at:
		points += RECHARGE_AMOUNT
		recharge_ready_at = 0

		_update_recharge_schedule()
		_save_game()
		# On emet le signal disant que les points ont été modifiés et on précise leur nouveau
		# montant afin que les autres scripts puissent le savoir
		points_changed.emit(points)
		# On emet le signal disant que le status de recharge a changé et on précise dans combien 
		# de secondes la recharge va se produire afin que les autres scripts puissent le savoir
		recharge_status_changed.emit(recharge_ready_at)

# Permet de récupérer toutes les infos d'une figurine
func get_character_data(character_id: String) -> Dictionary:
	if not characters_catalog.has(character_id):
		return {}

	return characters_catalog[character_id].duplicate(true)

# --------------------------------------------------
# SAUVEGARDE
# --------------------------------------------------

# On met à jour le fichier JSON qui contient les données de jeu actuelles du joueur
func _save_game() -> void:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"points": points,
		"gems": gems,
		"collection": collection,
		"next_instance_id": next_instance_id,
		"recharge_ready_at": recharge_ready_at
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error(
            "Impossible d'ouvrir la sauvegarde : "
			+ str(FileAccess.get_open_error())
		)
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	file.close()

	# On emet le signal disant que les données du jeu viennent d'être enregistrées pour que les
	# autres scripts puisse le savoir
	save_completed.emit()

# On récupère toutes les données de jeu du joueur depuis le fichier JSON
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_load_valid = true
		points = 0
		gems = 0
		collection = []
		next_instance_id = 1
		_save_game()
		return
	
	# Une sauvegarde existe : elle est considérée invalide
	# tant que toutes les vérifications ne sont pas terminées.
	save_load_valid = false
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	
	if file == null:
		push_error("Impossible de lire la sauvegarde.")
		return
		
	var content := file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(content)
	
	if not parsed is Dictionary:
		push_error(
			"Sauvegarde invalide : les données n'ont pas été chargées."
		)
		return

	var data: Dictionary = parsed

	if int(data.get("version", -1)) != SAVE_VERSION:
		push_warning(
			"Version de sauvegarde inconnue. "
			+ "Les données existantes sont conservées."
		)
		return

	# Validation des données avant leur chargement.
	var loaded_points: Variant = data.get("points", 0)
	var loaded_gems: Variant = data.get("gems", 0)
	var loaded_collection: Variant = data.get("collection", [])
	var loaded_next_id: Variant = data.get("next_instance_id", 1)
	var loaded_recharge: Variant = data.get("recharge_ready_at", 0)

	if typeof(loaded_recharge) == TYPE_FLOAT:
		if (not is_finite(loaded_recharge) or loaded_recharge != floor(loaded_recharge)):
			push_error("L'heure de recharge sauvegardée est invalide.")
			return
		loaded_recharge = int(loaded_recharge)
	elif typeof(loaded_recharge) != TYPE_INT:
		push_error("L'heure de recharge sauvegardée est invalide.")
		return

	if loaded_recharge < 0:
		push_error("L'heure de recharge ne peut pas être négative.")
		return
	
	# Accepter les entiers et les nombres décimaux entiers.
	if typeof(loaded_points) == TYPE_FLOAT:
		if not is_finite(loaded_points) or loaded_points != floor(loaded_points):
			push_error("Le solde sauvegardé doit être un nombre entier.")
			return
		loaded_points = int(loaded_points)
	elif typeof(loaded_points) != TYPE_INT:
		push_error("Le solde sauvegardé est invalide.")
		return

	if loaded_points < 0:
		push_error("Le solde sauvegardé est négatif.")
		return
	if loaded_gems == null:
		loaded_gems = 0
	if typeof(loaded_gems) == TYPE_FLOAT:
		if not is_finite(loaded_gems) or loaded_gems != floor(loaded_gems):
			push_error("Le solde de gemmes sauvegardé doit être un nombre entier.")
			return
		loaded_gems = int(loaded_gems)
	elif typeof(loaded_gems) != TYPE_INT:
		push_error("Le solde de gemmes sauvegardé est invalide.")
		return
	if loaded_gems < 0:
		push_error("Le solde de gemmes sauvegardé est négatif.")
		return
	loaded_points = mini(MAX_CURRENCY, int(loaded_points))
	loaded_gems = mini(MAX_CURRENCY, int(loaded_gems))

	if typeof(loaded_collection) != TYPE_ARRAY:
		push_error("La collection sauvegardée est invalide.")
		return

	if typeof(loaded_next_id) == TYPE_FLOAT:
		if not is_finite(loaded_next_id) or loaded_next_id != floor(loaded_next_id):
			push_error("Le prochain identifiant doit être un entier.")
			return
		loaded_next_id = int(loaded_next_id)
	elif typeof(loaded_next_id) != TYPE_INT:
		push_error("Le prochain identifiant est invalide.")
		return

	if loaded_next_id < 1:
		push_error("Le prochain identifiant doit être supérieur ou égal à 1.")
		return

	for item in loaded_collection:
		if not item is Dictionary:
			push_error("Une figurine sauvegardée est invalide.")
			return

		if not item.has("instance_id") or not item.has("character_id"):
			push_error("Une figurine ne possède pas ses identifiants.")
			return

		var loaded_instance_id: Variant = item["instance_id"]
		var loaded_character_id: Variant = item["character_id"]

		if typeof(loaded_instance_id) == TYPE_FLOAT:
			if (
				not is_finite(loaded_instance_id)
				or loaded_instance_id != floor(loaded_instance_id)
			):
				push_error("Identifiant de figurine invalide.")
				return
			loaded_instance_id = int(loaded_instance_id)
		elif typeof(loaded_instance_id) != TYPE_INT:
			push_error("Identifiant de figurine invalide.")
			return

		if loaded_instance_id < 1:
			push_error("L'identifiant de figurine doit être positif.")
			return

		if typeof(loaded_character_id) != TYPE_STRING:
			push_error("Identifiant de personnage invalide.")
			return

		if str(loaded_character_id).is_empty():
			push_error("L'identifiant de personnage est vide.")
			return

		# Normaliser le type pour les prochaines sauvegardes.
		item["instance_id"] = loaded_instance_id
		
		# Ajouter le niveau 1 aux anciennes figurines.
		if not item.has("level"):
			item["level"] = 1

		# Vérifier le niveau enregistré.
		var loaded_level: Variant = item["level"]

		if typeof(loaded_level) == TYPE_FLOAT:
			if (not is_finite(loaded_level) or loaded_level != floor(loaded_level)):
				push_error("Le niveau d'une figurine est invalide.")
				return
			
			loaded_level = int(loaded_level)
		
		elif typeof(loaded_level) != TYPE_INT:
			push_error("Le niveau d'une figurine est invalide.")
			return
		
		if loaded_level < 1 or loaded_level > 10:
			push_error("Le niveau d'une figurine est invalide.")
			return
		
		item["level"] = int(loaded_level)
	
	points = loaded_points
	gems = loaded_gems
	collection = loaded_collection.duplicate(true)
	next_instance_id = loaded_next_id
	recharge_ready_at = loaded_recharge

	# Garantit que les prochains identifiants restent uniques.
	for item in collection:
		next_instance_id = maxi(
			next_instance_id,
			int(item["instance_id"]) + 1
		)
		
	# Réécrire la sauvegarde avec les identifiants normalisés.
	save_load_valid = true
	_save_game()
	
	# On emet le signal disant que les points ont été modifiés et on précise leur nouveau montant
	# afin que les autres scripts puissent le savoir
	points_changed.emit(points)
	# On emet le signal disant que la collection de figurines à été modifiée afin que les autres
	# scripts puissent le savoir
	collection_changed.emit()

# Permet de charger le fichier contenant toutes les figurines du jeu
func load_characters_catalog() -> void:
	if not FileAccess.file_exists(CHARACTERS_CATALOG_PATH):
		push_error("Catalogue introuvable : " + CHARACTERS_CATALOG_PATH)
		return

	var file := FileAccess.open(
		CHARACTERS_CATALOG_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Impossible de lire le catalogue des personnages.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		push_error("Le catalogue doit contenir un objet JSON.")
		return

	var characters: Variant = parsed.get("characters", [])

	if not characters is Array:
		push_error("La liste des personnages est invalide.")
		return

	var loaded_catalog: Dictionary = {}

	for character in characters:
		if not character is Dictionary:
			push_warning("Entrée de personnage ignorée : format invalide.")
			continue

		var character_id: String = str(character.get("id", ""))

		if character_id.is_empty():
			push_warning("Un personnage sans identifiant a été ignoré.")
			continue

		if loaded_catalog.has(character_id):
			push_warning("Identifiant de personnage en double : " + character_id)
			continue

		loaded_catalog[character_id] = character

	characters_catalog = loaded_catalog
	# print("Personnages chargés : ", characters_catalog.size())

func load_techniques_catalog() -> void:
	if not FileAccess.file_exists(TECHNIQUES_CATALOG_PATH):
		push_error("Catalogue introuvable : " + TECHNIQUES_CATALOG_PATH)
		return

	var file := FileAccess.open(
		TECHNIQUES_CATALOG_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Impossible de lire le catalogue des techniques.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		push_error("Le catalogue doit contenir un objet JSON.")
		return

	var techniques: Variant = parsed.get("techniques", [])

	if not techniques is Array:
		push_error("La liste des techniques est invalide.")
		return

	var loaded_catalog: Dictionary = {}

	for technique in techniques:
		if not technique is Dictionary:
			push_warning("Entrée de technique ignorée : format invalide.")
			continue

		var technique_id: String = str(technique.get("id", ""))

		if technique_id.is_empty():
			push_warning("Une technique sans identifiant a été ignorée.")
			continue

		if loaded_catalog.has(technique_id):
			push_warning("Identifiant de technique en double : " + technique_id)
			continue

		loaded_catalog[technique_id] = technique

	techniques_catalog = loaded_catalog
	# print("Techniques chargées : ", techniques_catalog.size())

# --------------------------------------------------
# BOUTIQUE
# --------------------------------------------------

# Défini les différents packs de la boutique et permet d'en acheter
func purchase_pack(pack_id: String) -> Dictionary:
	var packs := {
		"mini": {"name": "MiniPack", "price": 5, "count": 1},
		"super": {"name": "SuperPack", "price": 20, "count": 3},
		"maxi": {"name": "MaxiPack", "price": 40, "count": 5}
	}

	if not packs.has(pack_id):
		return {"success": false, "message": "Pack inconnu."}

	if characters_catalog.is_empty():
		return {
			"success": false,
			"message": "Le catalogue des personnages est vide."
		}

	var pack: Dictionary = packs[pack_id]
	var price: int = int(pack["price"])
	var count: int = int(pack["count"])

	if points < price:
		return {
			"success": false,
			"message": "Tu n'as pas assez de points !"
		}

	# Préparer tous les tirages avant de débiter le solde.
	var selected_ids: Array[String] = []

	for i in range(count):
		var character_id := _draw_random_character_id()
		if character_id.is_empty():
			return {
				"success": false,
				"message": "Impossible de tirer une figurine."
			}
		selected_ids.append(character_id)

	if not spend_points(price):
		return {
			"success": false,
			"message": "Achat impossible : solde insuffisant."
		}

	var obtained: Array[Dictionary] = []

	for character_id in selected_ids:
		var figurine := add_figurine(character_id)
		if not figurine.is_empty():
			obtained.append(figurine)

	if obtained.size() != count:
		push_error("Un achat n'a pas attribué toutes ses figurines.")
		return {
			"success": false,
			"message": "Erreur pendant l'attribution des figurines.",
			"figurines": obtained
		}

	return {
		"success": true,
		"message": "Achat réussi !",
		"pack_name": str(pack["name"]),
		"figurines": obtained
	}

# Permet de piocher un personnage au hasard selon son niveau de rareté
func _draw_random_character_id() -> String:
	var roll := randi_range(1, 100)
	var chosen_rarity: int

	if roll <= 60:
		chosen_rarity = 1
	elif roll <= 78:
		chosen_rarity = 2
	elif roll <= 85:
		chosen_rarity = 3
	elif roll <= 92:
		chosen_rarity = 4
	elif roll <= 97:
		chosen_rarity = 5
	else:
		chosen_rarity = 6

	var candidates: Array[String] = []

	for character_id in characters_catalog:
		var character: Dictionary = characters_catalog[character_id]
		if character.get("rarity", 0) == chosen_rarity:
			candidates.append(str(character_id))

	# Sécurité : si une rareté n'existe pas dans le catalogue,
	# choisir parmi les personnages disponibles.
	if candidates.is_empty():
		for character_id in characters_catalog:
			candidates.append(str(character_id))

	if candidates.is_empty():
		return ""

	return candidates[randi_range(0, candidates.size() - 1)]
