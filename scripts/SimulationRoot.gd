extends Node2D


func _enter_tree() -> void:
	var world: Map = $Map
	var manager: Node = $SimulationManager
	var communication_button: CheckButton = get_node("%CommunicationButton")
	var cnp_button: CheckButton = get_node("%CNPButton")
	var defaults := SimulationConfig.new()
	defaults.map_size = world.size
	defaults.obstacle_density = world.obstacle_density
	defaults.map_seed = world.seed
	defaults.spawn_seed = manager.spawn_seed
	defaults.agent_configs = manager.agent_configs
	defaults.communication_enabled = communication_button.button_pressed
	defaults.cnp_enabled = cnp_button.button_pressed

	if SimulationSession.current_config == null:
		var random_seed_generator := RandomNumberGenerator.new()
		if world.randomize_seed:
			random_seed_generator.randomize()
			defaults.map_seed = random_seed_generator.seed
		if manager.randomize_spawn:
			random_seed_generator.randomize()
			defaults.spawn_seed = random_seed_generator.seed

	var config: SimulationConfig = SimulationSession.begin_scene(defaults)
	world.size = config.map_size
	world.obstacle_density = config.obstacle_density
	world.seed = config.map_seed
	world.randomize_seed = false
	manager.spawn_seed = config.spawn_seed
	manager.randomize_spawn = false
	manager.agent_configs = config.agent_configs
	communication_button.set_pressed_no_signal(config.communication_enabled or config.cnp_enabled)
	cnp_button.set_pressed_no_signal(config.cnp_enabled)
