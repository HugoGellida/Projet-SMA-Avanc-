extends Node2D

@export var spawn_seed: int = 12345
@export var randomize_spawn: bool = false

@onready var world: Map = $"../Map"
@onready var map_renderer: MapRenderer = $"../MapRenderer"
@onready var agents_root: Node2D = $"../Agents"

@onready var agent_map_renderer_1: AgentMapRenderer = $"../AgentMapRenderer1"
@onready var agent_map_renderer_2: AgentMapRenderer = $"../AgentMapRenderer2"

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
		agent.map_renderer.position = Vector2(600, 50)

	elif agent.name == "Agent2":
		agent.map_renderer = agent_map_renderer_2
		agent.map_renderer.setup(agent)
		agent.map_renderer.label_text = agent.name
		agent.map_renderer.position = Vector2(600, 200)
	
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


func _on_setp_timer_timeout() -> void:
	step_simulation()


func step_simulation() -> void:
	simulation_step += 1
	print("Simulation step: ", simulation_step)
	for agent: Agent in agent_with_world_positions:
		var move: Vector2i = agent.choose_move_action()
		
		
