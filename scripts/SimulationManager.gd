extends Node2D

@export var spawn_seed: int = 12345
@export var randomize_spawn: bool = false
@export var agent_configs: Array[AgentConfig] = []

@onready var world: Map = $"../Map"
@onready var map_renderer: MapRenderer = $"../MapRenderer"
@onready var agents_root: Node2D = $"../Agents"
@onready var agent_maps_root: Node2D = $"../AgentMaps"
@onready var heat_map: HeatMap = $"../HeatMap"
@onready var heat_map_renderer: HeatMapRenderer = $"../HeatMapRenderer"

@onready var step_timer: Timer = $StepTimer
@onready var run_pause_button: Button = $"../UI/ControlBar/RunPauseButton"
@onready var step_button: Button = $"../UI/ControlBar/StepButton"
@onready var restart_button: Button = $"../UI/ControlBar/RestartButton"
@onready var cnp_button: CheckButton = $"../UI/ControlBar/CNPButton"
@onready var communication_button: CheckButton = $"../UI/ControlBar/CommunicationButton"

var simulation_finished: bool = false

var agent_with_world_positions: Dictionary = {}

var spawn_rng := RandomNumberGenerator.new()

var simulation_step: int = 0
var waiting_for_map_coverage: bool = false

var allow_cnp: bool = true
var allow_communication: bool = true
var cnp_needs_allocation: bool = true

func _ready() -> void:
	allow_cnp = cnp_button.button_pressed
	allow_communication = communication_button.button_pressed or allow_cnp
	communication_button.set_pressed_no_signal(allow_communication)

	run_pause_button.disabled = true
	step_button.disabled = true
	
	run_pause_button.pressed.connect(_on_run_pause_button_pressed)
	step_button.pressed.connect(_on_step_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	cnp_button.toggled.connect(_on_cnp_button_toggled)
	communication_button.toggled.connect(_on_communication_button_toggled)
		
	call_deferred("initialize_agents")
	

func initialize_agents() -> void:
	if randomize_spawn:
		spawn_rng.randomize()
	else:
		spawn_rng.seed = spawn_seed

	var agents: Array[Agent] = []

	if agent_configs.is_empty():
		push_warning("no configuration found.")
		return

	for config: AgentConfig in agent_configs:
		if config == null:
			push_error("agent configuration is empty.")
			return

	var free_cells := _get_free_cells()

	if free_cells.size() < agent_configs.size():
		push_error("Not enough place.")
		return

	agent_with_world_positions.clear()

	for i in range(agent_configs.size()):
		var config: AgentConfig = agent_configs[i]
		var agent := Agent.new()
		agent.name = "Agent%02d" % (i + 1)
		agent.speed = config.speed
		agent.vision_range = config.vision_range
		agent.communication_range = config.communication_range
		agent.display_color = config.color
		agents_root.add_child(agent)
		agents.append(agent)

		var index := spawn_rng.randi_range(0, free_cells.size() - 1)
		var spawn_position: Vector2i = free_cells[index]

		free_cells[index] = free_cells[free_cells.size() - 1]
		free_cells.pop_back()

		_register_agent(agent, spawn_position, i)
	
	# mise à jour le communication array pour tous les agent après la registation
	for agent in agents:
		_update_agent_comunicate_array(agent)
		_update_heat_map(agent)
	
	# échanger la carte avant partir
	if allow_communication:
		var map_changes: Dictionary = _exchange_agent_maps()
		if allow_cnp:
			_run_cnp(map_changes)
	
	#$StepTimer.start()
	step_timer.stop()
	simulation_finished = false
	_update_control_buttons()
	
	

func _get_free_cells() -> Array[Vector2i]:
	var free_cells: Array[Vector2i] = []

	for tile in world.content:
		if not tile.obstacle:
			free_cells.append(tile.coord)

	return free_cells


func _register_agent(agent: Agent, world_position: Vector2i, index: int) -> void:
	agent_with_world_positions[agent] = world_position
	agent.initialize(float(map_renderer.tile_size))

	var renderer := AgentMapRenderer.new()
	renderer.name = "Map_%s" % agent.name
	renderer.label_text = str(agent.name)
	var column: int = floori(index / 3.0)
	var row: int = index % 3
	renderer.position = Vector2(column * 300, row * 200)
	agent_maps_root.add_child(renderer)
	agent.map_renderer = renderer
	renderer.setup(agent)
	
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


func _exchange_agent_maps() -> Dictionary:
	if not allow_communication:
		return {}

	var map_messages: Dictionary = {}
	var map_changes: Dictionary = {}
	
	# collecter toutes les carte local de tous les agents
	for agent: Agent in agent_with_world_positions:
		map_messages[agent] = agent.prepare_map_to_send()
		map_changes[agent] = {}
	
	# envoyer la carte à agent dans le range de communication
	for agent: Agent in agent_with_world_positions:
		var message: Dictionary = map_messages[agent]
		
		for other_agent: Agent in agent.current_communication_array:
			map_changes[other_agent][agent] = other_agent.recive_map_to_merge(agent, message)

	return map_changes


func _run_cnp(map_changes: Dictionary) -> void:
	if not allow_communication or not allow_cnp:
		return

	var cnp_messages: Dictionary = {}
	for agent: Agent in agent_with_world_positions:
		cnp_messages[agent] = agent.prepare_cnp_message()

	for agent: Agent in agent_with_world_positions:
		for other_agent: Agent in agent.current_communication_array:
			var received_changes: Dictionary = map_changes.get(other_agent, {})
			other_agent.receive_cnp_message(
				agent,
				cnp_messages[agent],
				bool(received_changes.get(agent, false)),
				cnp_needs_allocation
			)

	cnp_needs_allocation = false


func _on_step_timer_timeout() -> void:
	step_simulation()
	

func step_simulation() -> void:
	if simulation_finished or agent_with_world_positions.is_empty():
		return
		
	simulation_step += 1
	var all_finished: bool = true
	
	#print("Simulation step: ", simulation_step)
	
	# execute agents action
	for agent: Agent in agent_with_world_positions:
		var perception_updated: bool = false

		for _move_index in range(agent.speed):
			var action: Vector2i = agent.choose_move_action(allow_communication and allow_cnp)
			if action == Vector2i.ZERO:
				break

			var current_agent_location: Vector2i = (agent_with_world_positions[agent])
			var target: Vector2i = current_agent_location + action

			if absi(action.x) + absi(action.y) != 1:
				push_warning("%s illegal move action：:%s" % [agent.name, action])
				break
			elif not world.is_inside_map(target):
				push_warning("%s illegal move action：%s" % [agent.name, target])
				break
			elif world.get_tile(target).obstacle:
				push_warning("%s illegal move action：%s" % [agent.name, target])
				break
			else:
				agent_with_world_positions[agent] = target
				agent.confirm_move(action)
				_update_agent_display(agent)
				_update_heat_map(agent)
				_update_agent_perception(agent)
				perception_updated = true

		if not perception_updated:
			_update_agent_perception(agent)
		
		if not agent.exploration_finished:
			all_finished = false
	
	# mise à jour le communication array pour tous les agents
	for agent: Agent in agent_with_world_positions:
		_update_agent_comunicate_array(agent)
	
	# échanger la carte entre les agents
	if allow_communication:
		var map_changes: Dictionary = _exchange_agent_maps()
		if allow_cnp:
			_run_cnp(map_changes)

	all_finished = true
	for agent: Agent in agent_with_world_positions:
		if not agent.exploration_finished:
			all_finished = false
			break

	if all_finished:
		var all_agent_maps_complete: bool = true
		for agent: Agent in agent_with_world_positions:
			if _get_missing_world_cells_count(agent) > 0:
				all_agent_maps_complete = false
				break

		if all_agent_maps_complete:
			simulation_finished = true
			step_timer.stop()
			_update_control_buttons()
			print("Exploration finished! ")
		elif not waiting_for_map_coverage:
			waiting_for_map_coverage = true
			push_warning(
				"Agents are idle, but at least one map is incomplete; restarting frontier exploration."
			)
			for agent: Agent in agent_with_world_positions:
				agent.resume_unfinished_exploration()
			cnp_needs_allocation = true
	elif waiting_for_map_coverage:
		waiting_for_map_coverage = false


func _get_missing_world_cells_count(agent: Agent) -> int:
	var missing_count: int = 0
	var agent_world_origin: Vector2i = (
		agent_with_world_positions[agent] - agent.local_position
	)

	for tile: Tile in world.content:
		var local_coord: Vector2i = tile.coord - agent_world_origin
		if not agent.local_map.has(local_coord):
			missing_count += 1

	return missing_count


func _on_run_pause_button_pressed() -> void:
	if simulation_finished:
		return

	if step_timer.is_stopped():
		step_timer.start()
	else:
		step_timer.stop()

	_update_control_buttons()


func _on_step_button_pressed() -> void:
	if simulation_finished or not step_timer.is_stopped():
		return
	step_simulation()
	_update_control_buttons()


func _on_restart_button_pressed() -> void:
	step_timer.stop()
	get_tree().reload_current_scene()


func _on_cnp_button_toggled(enabled: bool) -> void:
	allow_cnp = enabled

	if enabled:
		allow_communication = true
		communication_button.set_pressed_no_signal(true)

	_reset_cnp_state()
	_update_control_buttons()


func _on_communication_button_toggled(enabled: bool) -> void:
	allow_communication = enabled

	if not enabled:
		allow_cnp = false
		cnp_button.set_pressed_no_signal(false)
		_reset_cnp_state()

	_update_control_buttons()


func _reset_cnp_state() -> void:
	for agent: Agent in agent_with_world_positions:
		agent.reset_task_allocation()
	cnp_needs_allocation = true
	waiting_for_map_coverage = false


func _update_control_buttons() -> void:
	if agent_with_world_positions.is_empty():
		run_pause_button.disabled = true
		step_button.disabled = true
		return

	if simulation_finished:
		run_pause_button.text = "Finished"
		run_pause_button.disabled = true
		step_button.disabled = true
		return

	var is_paused: bool = step_timer.is_stopped()
	run_pause_button.disabled = false

	if is_paused:
		run_pause_button.text = "Start"
	else:
		run_pause_button.text = "Pause"

	step_button.disabled = not is_paused


func _update_heat_map(agent: Agent) -> void:
	var coord: Vector2i = agent_with_world_positions[agent]

	if not heat_map.case_with_number.has(coord):
		push_warning("Heat map does not contain cell: %s" % coord)
		return

	heat_map.case_with_number[coord] += 1
	heat_map_renderer.queue_redraw()
