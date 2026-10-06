extends Node2D

@export var spawn_seed: int = 12345
@export var randomize_spawn: bool = false

@onready var world: Map = $"../Map"
@onready var map_renderer: MapRenderer = $"../MapRenderer"
@onready var agents_root: Node2D = $"../Agents"

var agent_with_world_positions: Dictionary = {}

var spawn_rng := RandomNumberGenerator.new()

var simulation_step: int = 0

func _ready() -> void:
	call_deferred("initialize_agents")

func initialize_agents() -> void:
	if randomize_spawn:
		spawn_rng.randomize()
	else:
		spawn_rng.seed = spawn_seed

	var agents: Array[Agent] = []

	for child in agents_root.get_children():
		if child is Agent:
			agents.append(child)

	if agents.is_empty():
		push_warning("No Agent found.")
		return

	var free_cells := _get_free_cells()

	if free_cells.size() < agents.size():
		push_error("Not enough free cells to spawn all agents.")
		return

	agent_with_world_positions.clear()

	for agent in agents:
		var index := spawn_rng.randi_range(0, free_cells.size() - 1)
		var spawn_position: Vector2i = free_cells[index]

		free_cells[index] = free_cells[free_cells.size() - 1]
		free_cells.pop_back()

		_register_agent(agent, spawn_position)
	
	# mise à jour le communication array pour tous les agent après la registation
	for agent in agents:
		_update_agent_comunicate_array(agent)
	
	# échanger la carte avant partir
	_exchange_agent_maps()
	
	$StepTimer.start()


func _get_free_cells() -> Array[Vector2i]:
	var free_cells: Array[Vector2i] = []

	for tile in world.content:
		if not tile.obstacle:
			free_cells.append(tile.coord)

	return free_cells


func _register_agent(agent: Agent, world_position: Vector2i) -> void:
	agent_with_world_positions[agent] = world_position
	agent.initialize(float(map_renderer.tile_size))
	_update_agent_perception(agent)
	_update_agent_display(agent)
	print("Registered ", agent.name, " at world cell ", world_position, "; local position: ", agent.local_position)
	print(agent.name, " local map: ", agent.local_map)


func _update_agent_display(agent: Agent) -> void:
	var world_position: Vector2i = (agent_with_world_positions[agent])
	var tile_size := float(map_renderer.tile_size)

	var cell_center := (Vector2(world_position) * tile_size+ Vector2.ONE * tile_size * 0.5)

	agent.global_position = map_renderer.to_global(cell_center)


func _update_agent_perception(agent: Agent) -> void:
	var world_position: Vector2i = (agent_with_world_positions[agent])

	var observation := world.get_observation(world_position, agent.vision_range)
	
	agent.perceive(observation)


func _update_agent_comunicate_array(agent: Agent) -> void:
	var agent_position: Vector2i = (agent_with_world_positions[agent])
	
	var communication_array: Dictionary = {}
	
	for other_agent: Agent in agent_with_world_positions:
		if agent != other_agent:
			
			var other_agent_position : Vector2i = agent_with_world_positions[other_agent]
			var offset : Vector2i = (other_agent_position - agent_position)
			var distance: int = maxi(absi(offset.x), absi(offset.y))
			
			if distance <= agent.communication_range:
				communication_array[other_agent] = offset
	
	agent.update_communication_array(communication_array)


func _exchange_agent_maps() -> void:
	var map_messages: Dictionary = {}
	
	# collecter toutes les carte local de tous les agents
	for agent: Agent in agent_with_world_positions:
		var map = agent.prepare_map_to_send()
		map_messages[agent] = {
			"local_position" : agent.local_position,
			"local_map" : map
		}
	
	# envoyer la carte à agent dans le range de communication
	for agent: Agent in agent_with_world_positions:
		var message: Dictionary = map_messages[agent]
		
		for other_agent: Agent in agent.current_communication_array:
			other_agent.recive_map_to_merge(agent, message)
			


func _on_setp_timer_timeout() -> void:
	step_simulation()
	

func step_simulation() -> void:
	simulation_step += 1
	var all_finished: bool = true
	
	print("Simulation step: ", simulation_step)
	
	# execute agents action
	for agent: Agent in agent_with_world_positions:
		var action: Vector2i = agent.choose_move_action()
		
		if action != Vector2i.ZERO:
			var current_agent_location: Vector2i = (agent_with_world_positions[agent])
			
			var target: Vector2i = current_agent_location + action
			
			if absi(action.x) + absi(action.y) != 1:
				push_warning("%s illegal move action：:%s" % [agent.name, action])
			elif not world.is_inside_map(target):
				push_warning("%s illegal move action：%s" % [agent.name, target])
			elif world.get_tile(target).obstacle:
				push_warning("%s illegal move action：%s" % [agent.name, target])
			else:
				agent_with_world_positions[agent] = target
				agent.confirm_move(action)
				_update_agent_display(agent)
			
		_update_agent_perception(agent)
		
		if not agent.exploration_finished:
			all_finished = false
	
	# mise à jour le communication array pour tous les agents
	for agent: Agent in agent_with_world_positions:
		_update_agent_comunicate_array(agent)
	
	# échanger la carte entre les agents
	_exchange_agent_maps()
		
	if all_finished:
		$StepTimer.stop()
		print("Exploration finished! ")
