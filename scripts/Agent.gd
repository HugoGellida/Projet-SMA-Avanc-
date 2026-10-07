extends Node2D
class_name Agent

@export_range(1, 20, 1) var vision_range: int = 1
@export_range(1, 20, 1) var communication_range: int = 2


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

var current_communication_array: Dictionary = {}


func initialize(tile_size: float) -> void:
	local_position = Vector2i.ZERO
	current_target = local_position
	local_map.clear()
	current_communication_array.clear()
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


# voir avec quels agents on peut communiquer et leur position dans notre local map
func update_communication_array(agent_array :Dictionary) -> void:
	current_communication_array.clear()
	
	for other_agent : Agent in agent_array:
		var offset: Vector2i = agent_array[other_agent]
		# transform other agent position into local map position
		var other_agent_position: Vector2i = local_position + offset
		current_communication_array[other_agent] = other_agent_position
	
	# pour debug
	#if not agent_array.is_empty():
		#print(name, " communication array: ", current_communication_array)


# voir si un case est un frontier case
func _is_frontier_position(coord: Vector2i) -> bool:
	if get_cell_state(coord) != CellState.FREE:
		return false
		
	for direction in  DIRECTIONS:
		if get_cell_state(coord + direction) == CellState.UNKNOWN:
			return true
			
	return false


# envoyer la carte à d'autres agents
func prepare_map_to_send() -> Dictionary:
	return local_map.duplicate()


# changer la carte avec les agent dans le range de communication
func recive_map_to_merge(sender: Agent, message: Dictionary) -> void:
	if not current_communication_array.has(sender):
		return
		
	if message.is_empty():
		return
	
	# commencer à merge la carte
	var sender_position_in_my_map: Vector2i = current_communication_array[sender]
	var sender_local_position: Vector2i = message["local_position"]
	var pivot_offset: Vector2i = sender_position_in_my_map - sender_local_position
	
	var sender_map: Dictionary = message["local_map"]
	
	for position_in_sender_map: Vector2i in sender_map:
		# changer position in sender map to my map
		var position_in_my_map: Vector2i  = position_in_sender_map + pivot_offset
		if local_map.has(position_in_my_map):
			continue
		
		# update my map
		local_map[position_in_my_map] = sender_map[position_in_sender_map]
