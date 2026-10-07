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

const UNREACHABLE_COST := 2147483647

var exploration_finished: bool = false
var local_position: Vector2i = Vector2i.ZERO
var local_map: Dictionary = {}
var cells_to_explore: Array[Vector2i] = []
var explored_cells: Dictionary = {}
var task_assignments: Dictionary = {}
var assignment_revisions: Dictionary = {}
var map_renderer: AgentMapRenderer
var display_radius: float = 3.5
var current_target: Vector2i = Vector2i.ZERO
var current_communication_array: Dictionary = {}
var new_contact_agents: Dictionary = {}
var meeting_position: Vector2i = Vector2i.ZERO
var exploration_round_active: bool = false
var waiting_log_emitted: bool = false


func initialize(tile_size: float) -> void:
	local_position = Vector2i.ZERO
	current_target = local_position
	local_map.clear()
	cells_to_explore.clear()
	explored_cells.clear()
	task_assignments.clear()
	assignment_revisions.clear()
	current_communication_array.clear()
	new_contact_agents.clear()
	meeting_position = local_position
	exploration_round_active = false
	exploration_finished = false
	waiting_log_emitted = false

	display_radius = tile_size * 0.35
	z_index = 1

	queue_redraw()


func get_cell_state(coord: Vector2i) -> int:
	return int(local_map.get(coord, CellState.UNKNOWN))


func _draw() -> void:
	draw_circle(Vector2.ZERO, display_radius, _get_agent_color())


func _get_agent_color() -> Color:
	match name:
		"Agent":
			return Color.CORAL
		"Agent2":
			return Color.DEEP_SKY_BLUE
		"Agent3":
			return Color.GOLD
		"Agent4":
			return Color.LIME_GREEN
		_:
			return Color.WHITE


func choose_move_action() -> Vector2i:
	var was_finished: bool = exploration_finished
	exploration_finished = false
	_refresh_cells_to_explore()
	_remove_invalid_assigned_tasks()
	_claim_reachable_unassigned_tasks()

	var own_tasks := _get_assigned_tasks(self)
	var distances := _get_distances_from(local_position)
	var closest_task: Vector2i
	var closest_cost: int = UNREACHABLE_COST

	for task: Vector2i in own_tasks:
		var cost: int = int(distances.get(task, UNREACHABLE_COST))
		if cost < closest_cost or (cost == closest_cost and _is_coord_before(task, closest_task)):
			closest_cost = cost
			closest_task = task

	if closest_cost < UNREACHABLE_COST:
		current_target = closest_task
		waiting_log_emitted = false
		return _get_next_step_toward(current_target)

	if exploration_round_active:
		if local_position == meeting_position:
			if not waiting_log_emitted:
				print(
					"[WAIT] %s at rendezvous %s; waiting for a merge. Remaining tasks: %s"
					% [name, meeting_position, _get_waiting_tasks_summary()]
				)
				waiting_log_emitted = true
			exploration_finished = true
			return Vector2i.ZERO

		current_target = meeting_position
		if not waiting_log_emitted:
			print(
				"[RETURN] %s returning to rendezvous %s; assigned tasks: %s"
				% [name, meeting_position, _get_assigned_tasks(self)]
			)
			waiting_log_emitted = true
		var return_action := _get_next_step_toward(meeting_position)
		if return_action == Vector2i.ZERO:
			push_warning("%s cannot find a known path back to its meeting point." % name)
		return return_action

	if cells_to_explore.is_empty():
		exploration_finished = true
		if not was_finished:
			print(name, ": exploration finished.")
		return Vector2i.ZERO

	# Tasks reserved for an agent not currently present cannot be taken over.
	# Keep the simulation active until the responsible agent returns to merge.
	exploration_finished = false
	if not waiting_log_emitted:
		print(
			"[WAIT] %s has no local task; waiting for assigned agents. Remaining tasks: %s"
			% [name, _get_waiting_tasks_summary()]
		)
		waiting_log_emitted = true
	return Vector2i.ZERO


func confirm_move(action: Vector2i) -> void:
	if action == Vector2i.ZERO:
		return

	local_position += action
	explored_cells[local_position] = true
	exploration_finished = false
	if exploration_round_active and local_position == meeting_position:
		waiting_log_emitted = false
	_refresh_cells_to_explore()
	_remove_invalid_assigned_tasks()


func resume_unfinished_exploration() -> void:
	task_assignments.clear()
	assignment_revisions.clear()
	exploration_round_active = false
	exploration_finished = false
	waiting_log_emitted = false
	_refresh_cells_to_explore()
	print(
		"[RESUME] %s restarting frontier exploration; %d frontiers available."
		% [name, cells_to_explore.size()]
	)


func perceive(observation: Dictionary) -> void:
	for offset: Vector2i in observation:
		var local_coord := local_position + offset
		local_map[local_coord] = observation[offset]

	explored_cells[local_position] = true
	_refresh_cells_to_explore()
	_remove_invalid_assigned_tasks()
	map_renderer.queue_redraw()


func update_communication_array(agent_array: Dictionary) -> void:
	var previous_communication_array := current_communication_array.duplicate()
	current_communication_array.clear()
	new_contact_agents.clear()

	for other_agent: Agent in agent_array:
		var offset: Vector2i = agent_array[other_agent]
		var other_agent_position: Vector2i = local_position + offset
		current_communication_array[other_agent] = other_agent_position

		if not previous_communication_array.has(other_agent):
			new_contact_agents[other_agent] = true


func _is_frontier_position(coord: Vector2i) -> bool:
	if get_cell_state(coord) != CellState.FREE:
		return false

	for direction in DIRECTIONS:
		if get_cell_state(coord + direction) == CellState.UNKNOWN:
			return true

	return false


func _refresh_cells_to_explore() -> void:
	cells_to_explore.clear()

	for coord: Vector2i in local_map:
		if _is_frontier_position(coord):
			cells_to_explore.append(coord)


func _remove_invalid_assigned_tasks() -> void:
	for owner: Agent in task_assignments:
		var remaining: Array[Vector2i] = []
		for task: Vector2i in task_assignments[owner]:
			if cells_to_explore.has(task):
				remaining.append(task)
		task_assignments[owner] = remaining


func _claim_reachable_unassigned_tasks() -> void:
	var distances := _get_distances_from(local_position)
	var own_tasks := _get_assigned_tasks(self)
	var claimed_new_task: bool = false

	for task: Vector2i in cells_to_explore:
		if _has_task_owner(task):
			continue
		if int(distances.get(task, UNREACHABLE_COST)) >= UNREACHABLE_COST:
			continue
		own_tasks.append(task)
		claimed_new_task = true

	task_assignments[self] = own_tasks
	if claimed_new_task:
		assignment_revisions[self] = int(assignment_revisions.get(self, 0)) + 1


func _get_assigned_tasks(owner: Agent) -> Array[Vector2i]:
	var tasks: Array[Vector2i] = []
	for task: Vector2i in task_assignments.get(owner, []):
		tasks.append(task)
	return tasks


func _has_task_owner(task: Vector2i) -> bool:
	for owner: Agent in task_assignments:
		if task_assignments[owner].has(task):
			return true
	return false


func _get_distances_from(start: Vector2i) -> Dictionary:
	var distances: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1

		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if distances.has(next) or get_cell_state(next) != CellState.FREE:
				continue
			distances[next] = int(distances[current]) + 1
			queue.append(next)

	return distances


func _get_next_step_toward(target: Vector2i) -> Vector2i:
	if target == local_position:
		return Vector2i.ZERO

	var queue: Array[Vector2i] = [local_position]
	var first_moves: Dictionary = {local_position: Vector2i.ZERO}
	var head: int = 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1

		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if first_moves.has(next) or get_cell_state(next) != CellState.FREE:
				continue

			first_moves[next] = direction if current == local_position else first_moves[current]
			if next == target:
				return first_moves[next]
			queue.append(next)

	return Vector2i.ZERO


func _is_coord_before(first: Vector2i, second: Vector2i) -> bool:
	if first == Vector2i.ZERO and second == Vector2i.ZERO:
		return false
	if first.y == second.y:
		return first.x < second.x
	return first.y < second.y


func prepare_map_to_send() -> Dictionary:
	return {
		"local_position": local_position,
		"local_map": local_map.duplicate(),
		"explored_cells": explored_cells.keys(),
		"task_assignments": task_assignments.duplicate(true),
		"assignment_revisions": assignment_revisions.duplicate()
	}


func recive_map_to_merge(sender: Agent, message: Dictionary) -> void:
	if not current_communication_array.has(sender) or message.is_empty():
		return

	var sender_position_in_my_map: Vector2i = current_communication_array[sender]
	var sender_local_position: Vector2i = message["local_position"]
	var pivot_offset: Vector2i = sender_position_in_my_map - sender_local_position
	var map_changed: bool = false
	var sender_map: Dictionary = message["local_map"]

	for position_in_sender_map: Vector2i in sender_map:
		var position_in_my_map: Vector2i = position_in_sender_map + pivot_offset
		if local_map.has(position_in_my_map):
			continue

		local_map[position_in_my_map] = sender_map[position_in_sender_map]
		map_changed = true

	for explored_position: Vector2i in message.get("explored_cells", []):
		var translated_position: Vector2i = explored_position + pivot_offset
		if not explored_cells.has(translated_position):
			explored_cells[translated_position] = true
			map_changed = true

	var assignment_changes := _merge_assignments_from_message(message, pivot_offset, sender)
	_refresh_cells_to_explore()
	_remove_invalid_assigned_tasks()

	var is_new_contact: bool = new_contact_agents.has(sender)
	if is_new_contact:
		meeting_position = (
			sender_position_in_my_map
			if sender.name < name
			else local_position
		)

	if assignment_changes["pair_changed"]:
		exploration_finished = false

	if is_new_contact or map_changed or assignment_changes["other_changed"]:
		_assign_remaining_tasks(sender, sender_position_in_my_map)

	if map_renderer != null:
		map_renderer.queue_redraw()


func _get_waiting_tasks_summary() -> Dictionary:
	var tasks_by_owner: Dictionary = {}
	for owner: Agent in task_assignments:
		var tasks := _get_assigned_tasks(owner)
		if not tasks.is_empty():
			tasks_by_owner[owner.name] = tasks
	return tasks_by_owner


func _merge_assignments_from_message(
	message: Dictionary,
	pivot_offset: Vector2i,
	sender: Agent
) -> Dictionary:
	var incoming_assignments: Dictionary = message.get("task_assignments", {})
	var incoming_revisions: Dictionary = message.get("assignment_revisions", {})
	var pair_changed: bool = false
	var other_changed: bool = false

	for owner: Agent in incoming_assignments:
		var incoming_revision: int = int(incoming_revisions.get(owner, 0))
		var current_revision: int = int(assignment_revisions.get(owner, -1))
		if incoming_revision <= current_revision:
			continue

		var translated_tasks: Array[Vector2i] = []
		for task: Vector2i in incoming_assignments[owner]:
			translated_tasks.append(task + pivot_offset)
		task_assignments[owner] = translated_tasks
		assignment_revisions[owner] = incoming_revision
		if owner == self or owner == sender:
			pair_changed = true
		else:
			other_changed = true

	return {
		"pair_changed": pair_changed,
		"other_changed": other_changed
	}


func _assign_remaining_tasks(
	sender: Agent,
	sender_position: Vector2i
) -> void:
	var reserved_tasks: Dictionary = {}
	var other_owners: Array[Agent] = []

	for owner: Agent in task_assignments:
		if owner != self and owner != sender:
			other_owners.append(owner)
	other_owners.sort_custom(func(a: Agent, b: Agent) -> bool: return a.name < b.name)

	for owner: Agent in other_owners:
		var valid_tasks: Array[Vector2i] = []
		for task: Vector2i in task_assignments[owner]:
			if cells_to_explore.has(task) and not reserved_tasks.has(task):
				reserved_tasks[task] = true
				valid_tasks.append(task)
		task_assignments[owner] = valid_tasks

	var candidates: Array[Vector2i] = []
	for task: Vector2i in cells_to_explore:
		if not reserved_tasks.has(task):
			candidates.append(task)

	var canonical_position: Vector2i = local_position
	if sender.name < name:
		canonical_position = sender_position
	var stable_offset: Vector2i = canonical_position
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var relative_a: Vector2i = a - stable_offset
			var relative_b: Vector2i = b - stable_offset
			if relative_a.y == relative_b.y:
				return relative_a.x < relative_b.x
			return relative_a.y < relative_b.y
	)

	var self_tasks: Array[Vector2i] = []
	var sender_tasks: Array[Vector2i] = []
	var self_distances := _get_distances_from(local_position)
	var sender_distances := _get_distances_from(sender_position)
	var self_route_cost: int = 0
	var sender_route_cost: int = 0
	var self_route_position: Vector2i = local_position
	var sender_route_position: Vector2i = sender_position

	for task: Vector2i in candidates:
		var self_cost: int = int(self_distances.get(task, UNREACHABLE_COST))
		var sender_cost: int = int(sender_distances.get(task, UNREACHABLE_COST))
		if self_cost >= UNREACHABLE_COST and sender_cost >= UNREACHABLE_COST:
			continue

		var from_self: int = int(_get_distances_from(self_route_position).get(task, UNREACHABLE_COST))
		var from_sender: int = int(_get_distances_from(sender_route_position).get(task, UNREACHABLE_COST))
		var total_self_cost: int = self_route_cost + from_self
		var total_sender_cost: int = sender_route_cost + from_sender
		var assign_to_sender: bool = total_sender_cost < total_self_cost
		if total_sender_cost == total_self_cost:
			assign_to_sender = sender.name < name

		if assign_to_sender:
			sender_tasks.append(task)
			sender_route_cost = total_sender_cost
			sender_route_position = task
		else:
			self_tasks.append(task)
			self_route_cost = total_self_cost
			self_route_position = task

	var self_assignments_changed: bool = self_tasks != _get_assigned_tasks(self)
	var sender_assignments_changed: bool = (
		sender_tasks != _get_assigned_tasks(sender)
	)
	task_assignments[self] = self_tasks
	task_assignments[sender] = sender_tasks
	if self_assignments_changed:
		assignment_revisions[self] = int(assignment_revisions.get(self, 0)) + 1
	if sender_assignments_changed:
		assignment_revisions[sender] = int(assignment_revisions.get(sender, 0)) + 1

	var has_pending_tasks: bool = (
		not self_tasks.is_empty()
		or not sender_tasks.is_empty()
		or not reserved_tasks.is_empty()
	)
	if has_pending_tasks or not cells_to_explore.is_empty():
		exploration_round_active = true
		exploration_finished = false
		waiting_log_emitted = false
	else:
		exploration_round_active = false
		exploration_finished = true

	if has_pending_tasks or self_assignments_changed or sender_assignments_changed:
		print(
			"[TASKS] %s / %s meeting at %s; %s tasks: %s; %s tasks: %s"
			% [
				name,
				sender.name,
				meeting_position,
				name,
				self_tasks,
				sender.name,
				sender_tasks
			]
		)
