extends Node2D

@export var spawn_seed: int = 12345
@export var randomize_spawn: bool = false

@onready var world: Map = $"../Map"
@onready var map_renderer: MapRenderer = $"../MapRenderer"
@onready var agents_root: Node2D = $"../Agents"

var agent_with_world_positions: Dictionary = {}

var spawn_rng := RandomNumberGenerator.new()

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


func _get_free_cells() -> Array[Vector2i]:
	var free_cells: Array[Vector2i] = []

	for tile in world.content:
		if not tile.obstacle:
			free_cells.append(tile.coord)

	return free_cells


func _register_agent(agent: Agent, world_position: Vector2i) -> void:
	agent_with_world_positions[agent] = world_position
	agent.initialize(float(map_renderer.tile_size))
	_update_agent_display(agent)
	print("Registered ", agent.name, " at world cell ", world_position, "; local position: ", agent.local_position)


func _update_agent_display(agent: Agent) -> void:
	var world_position: Vector2i = (agent_with_world_positions[agent])
	var tile_size := float(map_renderer.tile_size)

	var cell_center := (Vector2(world_position) * tile_size+ Vector2.ONE * tile_size * 0.5)

	agent.global_position = map_renderer.to_global(cell_center)
