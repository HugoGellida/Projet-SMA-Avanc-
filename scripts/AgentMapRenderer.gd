extends Control
class_name AgentMapRenderer

const COLOR_UNKNOWN := Color(0.07, 0.09, 0.12)
const COLOR_OBSTACLE := Color.DARK_GRAY

var agent: Agent
var world_map: Map
var world_origin: Vector2i = Vector2i.ZERO


func setup(target_agent: Agent) -> void:
	agent = target_agent
	resized.connect(queue_redraw)
	queue_redraw()


func get_map_rect() -> Rect2:
	var edge: float = minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge)


func _draw() -> void:
	if agent == null or world_map == null or world_map.size <= 0:
		return

	var map_rect: Rect2 = get_map_rect()
	var cell_size: float = map_rect.size.x / float(world_map.size)
	draw_rect(map_rect, COLOR_UNKNOWN)

	for local_coord: Vector2i in agent.local_map:
		var world_coord: Vector2i = world_origin + local_coord
		if not world_map.is_inside_map(world_coord):
			continue

		var color: Color = COLOR_UNKNOWN
		match agent.get_cell_state(local_coord):
			Agent.CellState.FREE:
				color = MapRenderer.BIOME_COLORS.get(world_map.get_tile(world_coord).biome, COLOR_UNKNOWN)
			Agent.CellState.OBSTACLE:
				color = COLOR_OBSTACLE

		var cell_rect := Rect2(
			map_rect.position + Vector2(world_coord) * cell_size,
			Vector2.ONE * cell_size
		)
		draw_rect(cell_rect, color)
		if cell_size >= 8.0:
			draw_rect(cell_rect, Color(0.0, 0.0, 0.0, 0.25), false, 1.0)

	var agent_world_position: Vector2i = world_origin + agent.local_position
	var marker_position: Vector2 = map_rect.position + (Vector2(agent_world_position) + Vector2.ONE * 0.5) * cell_size
	draw_circle(marker_position, clampf(cell_size * 0.35, 1.5, 5.0), agent.display_color)
