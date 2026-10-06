extends Node2D
class_name Agent

@export_range(1, 20, 1) var vision_range: int = 1


enum CellState {
	UNKNOWN,
	FREE,
	OBSTACLE,
	BOUNDARY
}

const DIRECTIONS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

var exploration_finished = false

var local_position: Vector2i = Vector2i.ZERO

var local_map: Dictionary = {}

var display_radius: float = 3.5

var current_target: Vector2i = Vector2i.ZERO


func initialize(tile_size: float) -> void:
	local_position = Vector2i.ZERO
	current_target = local_position
	local_map.clear()
	exploration_finished = false

	display_radius = tile_size * 0.35
	z_index = 1
	queue_redraw()


func get_cell_state(coord: Vector2i) -> int:
	return int(local_map.get(coord, CellState.UNKNOWN))


func _draw() -> void:
	draw_circle(Vector2.ZERO,display_radius,Color.BLUE_VIOLET)


func choose_move_action() -> Vector2i:
	current_target = local_position		# feault target
	var queue: Array[Vector2i] = [local_position]
	var head: int = 0
	
	var first_moves: Dictionary = {}
	first_moves[local_position] = Vector2i.ZERO
	
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		
		if _is_frontier_position(current):
			current_target = current
			exploration_finished = false
			
			var action: Vector2i = first_moves[current]
			return action
		
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if first_moves.has(next):
				continue
			
			if get_cell_state(next) != CellState.FREE:
				continue
			
			if current == local_position:
				first_moves[next] = direction
			else:
				first_moves[next] = first_moves[current]
			
			queue.append(next)
		
	if not exploration_finished:
		print(name, ": exploration finished.")

	exploration_finished = true
	return Vector2i.ZERO


# manager execute action
func confirm_move(action: Vector2i) -> void:
	if action == Vector2i.ZERO:
		return

	local_position += action
	exploration_finished = false

# voir les case dans range de vision
func perceive(observation :Dictionary) -> void:
	for offset: Vector2i in observation:
		var local_coord := local_position + offset
		local_map[local_coord] = observation[offset]


# voir si un case est un frontier case
func _is_frontier_position(coord: Vector2i) -> bool:
	if get_cell_state(coord) != CellState.FREE:
		return false
		
	for direction in  DIRECTIONS:
		if get_cell_state(coord + direction) == CellState.UNKNOWN:
			return true
			
	return false
