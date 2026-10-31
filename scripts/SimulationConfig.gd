extends Resource
class_name SimulationConfig

const MIN_MAP_SIZE: int = 2
const MAX_MAP_SIZE: int = 100
const MAX_AGENTS: int = 100

@export var map_size: int = 20
@export var obstacle_density: float = 0.5
@export var map_seed: int = 12345
@export var spawn_seed: int = 12345
@export var agent_configs: Array[AgentConfig] = []
@export var communication_enabled: bool = true
@export var cnp_enabled: bool = true


func create_copy() -> SimulationConfig:
	var config := SimulationConfig.new()
	config.map_size = map_size
	config.obstacle_density = obstacle_density
	config.map_seed = map_seed
	config.spawn_seed = spawn_seed
	config.communication_enabled = communication_enabled
	config.cnp_enabled = cnp_enabled
	for agent_config: AgentConfig in agent_configs:
		config.agent_configs.append(agent_config.duplicate() if agent_config != null else null)
	return config


func validate() -> String:
	if map_size < MIN_MAP_SIZE or map_size > MAX_MAP_SIZE:
		return "Map size must be between %d and %d." % [MIN_MAP_SIZE, MAX_MAP_SIZE]
	if not is_finite(obstacle_density) or obstacle_density < 0.0 or obstacle_density > 1.0:
		return "Target obstacle density must be between 0% and 100%."
	if agent_configs.is_empty() or agent_configs.size() > MAX_AGENTS:
		return "Agent count must be between 1 and %d." % MAX_AGENTS
	if agent_configs.size() > map_size * map_size:
		return "There are more agents than map cells."
	for index in range(agent_configs.size()):
		var config: AgentConfig = agent_configs[index]
		if config == null:
			return "Agent %d has no configuration." % (index + 1)
		if config.speed < 1 or config.speed > 20:
			return "Agent %d speed must be between 1 and 20." % (index + 1)
		if config.vision_range < 1 or config.vision_range > 20:
			return "Agent %d vision range must be between 1 and 20." % (index + 1)
		if config.communication_range < 1 or config.communication_range > 20:
			return "Agent %d communication range must be between 1 and 20." % (index + 1)
	return ""
