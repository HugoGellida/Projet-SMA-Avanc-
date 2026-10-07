extends Node2D
class_name AgentMapRenderer

@export var tile_size: int = 5

const COLOR_UNKNOWN = Color(0.15, 0.15, 0.15)
const COLOR_FREE = Color(0.35, 0.65, 0.3)
const COLOR_OBSTACLE = Color.DARK_GRAY
const COLOR_BOUNDARY = Color(0.7, 0.2, 0.2)

var agent: Agent

var label_text: String = ""


func setup(target_agent: Agent) -> void:
	agent = target_agent
	queue_redraw()


func _draw() -> void:
	if agent == null:
		return

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
				color = COLOR_FREE

			Agent.CellState.OBSTACLE:
				color = COLOR_OBSTACLE

			Agent.CellState.BOUNDARY:
				color = COLOR_BOUNDARY

			Agent.CellState.UNKNOWN:
				color = COLOR_UNKNOWN

		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 1.0)
	
	draw_string(
	ThemeDB.fallback_font,
	Vector2(100, 0),
	label_text,
	HORIZONTAL_ALIGNMENT_LEFT,
	-1,
	16,
	Color.WHITE
)
