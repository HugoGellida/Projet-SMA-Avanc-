extends Node2D
class_name AgentMapRenderer

@export var tile_size: int = 5

const COLOR_UNKNOWN = Color(0.15, 0.15, 0.15)
const COLOR_OBSTACLE = Color.DARK_GRAY
const COLOR_BOUNDARY = Color(0.7, 0.2, 0.2)

# Couleurs identiques à celles de MapRenderer.gd
const BIOME_COLORS := {
"water": Color(0.2, 0.45, 0.8),
"sand": Color(0.82, 0.72, 0.48),
"grass": Color(0.35, 0.65, 0.3),
"forest": Color(0.12, 0.4, 0.22),
"snow": Color(0.90, 0.90, 1),
}

var agent: Agent
var label_text: String = ""

# Référence vers la carte principale et origine de la carte locale
var world_map: Map
var world_origin: Vector2i = Vector2i.ZERO


func setup(target_agent: Agent) -> void:
	agent = target_agent
	queue_redraw()


func _draw() -> void:
	if agent == null:
		return

	# Dessiner la carte locale de l'agent.
	for coord in agent.local_map:
		var state: int = agent.local_map[coord]

		var position := Vector2(coord * tile_size)
		var rect := Rect2(
			position,
			Vector2(tile_size, tile_size)
		)

		var color := COLOR_UNKNOWN

		match state:
			Agent.CellState.FREE:
				color = _get_biome_color(coord)

			Agent.CellState.OBSTACLE:
				color = COLOR_OBSTACLE

			Agent.CellState.BOUNDARY:
				color = COLOR_BOUNDARY

			Agent.CellState.UNKNOWN:
				color = COLOR_UNKNOWN

		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 1.0)

	# Calculer la largeur de la carte locale.
	var map_width: float = 0.0

	for coord in agent.local_map:
		map_width = maxf(
			map_width,
			(coord.x + 1) * tile_size
		)

	# Calculer le centre vertical de la carte locale.
	var label_y: float = 0.0

	if not agent.local_map.is_empty():
		var min_y: int = 0
		var max_y: int = 0

		for coord in agent.local_map:
			min_y = mini(min_y, coord.y)
			max_y = maxi(max_y, coord.y)

		label_y = (min_y + max_y + 1) * tile_size / 2.0

	# Afficher une pastille de la couleur de l'agent.
	draw_circle(
		Vector2(map_width + 15, label_y),
		5.0,
		agent.display_color
	)

	# Afficher le nom de l'agent à droite de la pastille.
	draw_string(
		ThemeDB.fallback_font,
		Vector2(map_width + 30, label_y + 5),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
)

func _get_biome_color(local_coord: Vector2i) -> Color:
	if world_map == null:
		return COLOR_UNKNOWN

	# Convertir les coordonnées locales en coordonnées de la carte principale.
	var world_coord: Vector2i = world_origin + local_coord

	if not world_map.is_inside_map(world_coord):
		return COLOR_UNKNOWN

	var tile: Tile = world_map.get_tile(world_coord)

	if tile == null:
		return COLOR_UNKNOWN

	return BIOME_COLORS.get(tile.biome, COLOR_UNKNOWN)
