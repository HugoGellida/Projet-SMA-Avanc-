extends Node2D
class_name Agent

enum CellState {
	UNKNOWN,
	FREE,
	OBSTACLE,
	BOUNDARY
}

var local_position: Vector2i = Vector2i.ZERO

var local_map: Dictionary = {}

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
