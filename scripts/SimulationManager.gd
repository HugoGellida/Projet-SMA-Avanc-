extends Node2D

@export var spawn_seed: int = 12345
@export var randomize_spawn: bool = false

@onready var world: Map = $"../Map"
@onready var map_renderer: MapRenderer = $"../MapRenderer"
@onready var agents_root: Node2D = $"../Agents"

@onready var agent_map_renderer_1: AgentMapRenderer = $"../AgentMapRenderer1"
@onready var agent_map_renderer_2: AgentMapRenderer = $"../AgentMapRenderer2"
@onready var agent_map_renderer_3: AgentMapRenderer = $"../AgentMapRenderer3"


var agent_with_world_positions: Dictionary = {}

var spawn_rng := RandomNumberGenerator.new()

var simulation_step: int = 0
var waiting_for_map_coverage: bool = false

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
	
	if agent.name == "Agent":
		agent.map_renderer = agent_map_renderer_1
		agent.map_renderer.setup(agent)
		agent.map_renderer.label_text = agent.name
		agent.map_renderer.position = Vector2(600, 100)

	elif agent.name == "Agent2":
		agent.map_renderer = agent_map_renderer_2
		agent.map_renderer.setup(agent)
		agent.map_renderer.label_text = agent.name
		agent.map_renderer.position = Vector2(600, 300)
		
	elif agent.name == "Agent3":
		agent.map_renderer = agent_map_renderer_3
		agent.map_renderer.setup(agent)
		agent.map_renderer.label_text = agent.name
		agent.map_renderer.position = Vector2(600, 500)
	
	_update_agent_perception(agent)
	_update_agent_display(agent)
	
	print("Registered ", agent.name, " at world cell ", world_position, "; local position: ", agent.local_position)


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
		map_messages[agent] = agent.prepare_map_to_send()
	
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

	all_finished = true
	for agent: Agent in agent_with_world_positions:
		if not agent.exploration_finished:
			all_finished = false
			break

	if all_finished:
		var missing_agent_map_cells: int = _get_missing_agent_map_cells_count()
		if missing_agent_map_cells == 0:
			$StepTimer.stop()
			print("Exploration finished! ")
		elif not waiting_for_map_coverage:
			waiting_for_map_coverage = true
			push_warning(
				"Agents are idle, but %d agent-map cells are still missing."
				% missing_agent_map_cells
			)
	elif waiting_for_map_coverage:
		waiting_for_map_coverage = false


func _get_missing_agent_map_cells_count() -> int:
	var missing_count: int = 0
	for agent: Agent in agent_with_world_positions:
		var agent_world_origin: Vector2i = (
			agent_with_world_positions[agent] - agent.local_position
		)
		for tile: Tile in world.content:
			var local_coord: Vector2i = tile.coord - agent_world_origin
			if not agent.local_map.has(local_coord):
				missing_count += 1

	return missing_count
