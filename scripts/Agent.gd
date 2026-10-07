extends Node2D
class_name Agent

@export_range(1, 20, 1) var vision_range: int = 1


enum CellState {
	UNKNOWN,
	FREE,
	OBSTACLE,
	BOUNDARY
}

var local_position: Vector2i = Vector2i.ZERO

var local_map: Dictionary = {}

var map_renderer: AgentMapRenderer

var display_radius: float = 3.5

func initialize(tile_size: float) -> void:
	local_position = Vector2i.ZERO
	local_map.clear()

	display_radius = tile_size * 0.35
	z_index = 1
	
	queue_redraw()


func get_cell_state(coord: Vector2i) -> int:
	return int(local_map.get(coord, CellState.UNKNOWN))


func _draw() -> void:
	draw_circle(Vector2.ZERO,display_radius,Color.BLUE_VIOLET)


func choose_move_action() -> Vector2i:
	print("Agent anme:", self.name, ", action: stay here.")
	return Vector2i.ZERO
	

func perceive(observation :Dictionary) -> void:
	for offset: Vector2i in observation:
		var local_coord := local_position + offset
		local_map[local_coord] = observation[offset]
	map_renderer.queue_redraw()
