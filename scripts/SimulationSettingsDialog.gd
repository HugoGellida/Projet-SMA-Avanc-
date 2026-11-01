extends Window
class_name SimulationSettingsDialog

signal configuration_submitted(config: SimulationConfig)

var draft_config: SimulationConfig
var map_size_input: SpinBox
var density_input: SpinBox
var agent_count_input: SpinBox
var seed_label: Label
var agent_table: GridContainer
var error_label: Label
var agent_rows: Array[Dictionary] = []


func _ready() -> void:
	title = "Simulation settings"
	min_size = Vector2i(680, 440)
	size = Vector2i(760, 560)
	transient = true
	exclusive = true
	theme = get_node("%Screen").theme
	close_requested.connect(hide)
	_build_controls()


func open_settings(config: SimulationConfig) -> void:
	if SimulationSession.configuration_locked:
		return
	draft_config = config.create_copy()
	map_size_input.set_value_no_signal(draft_config.map_size)
	density_input.set_value_no_signal(draft_config.obstacle_density * 100.0)
	agent_count_input.set_value_no_signal(draft_config.agent_configs.size())
	seed_label.text = "Map seed: %d    Spawn seed: %d" % [draft_config.map_seed, draft_config.spawn_seed]
	error_label.hide()
	_rebuild_agent_rows()
	popup_centered(Vector2i(760, 560))


func show_error(message: String) -> void:
	error_label.text = message
	error_label.show()


func _build_controls() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var map_fields := GridContainer.new()
	map_fields.columns = 2
	map_fields.add_theme_constant_override("h_separation", 16)
	map_fields.add_theme_constant_override("v_separation", 8)
	content.add_child(map_fields)
	_add_label(map_fields, "Map size (N × N)")
	map_size_input = _create_number_input(SimulationConfig.MIN_MAP_SIZE, SimulationConfig.MAX_MAP_SIZE)
	map_fields.add_child(map_size_input)
	_add_label(map_fields, "Target obstacle density")
	density_input = _create_number_input(0, 100)
	density_input.step = 0.1
	density_input.rounded = false
	density_input.suffix = "%"
	map_fields.add_child(density_input)
	_add_label(map_fields, "Agent count")
	agent_count_input = _create_number_input(1, SimulationConfig.MAX_AGENTS)
	agent_count_input.value_changed.connect(_on_agent_count_changed)
	map_fields.add_child(agent_count_input)

	seed_label = Label.new()
	seed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seed_label.add_theme_font_size_override("font_size", 12)
	content.add_child(seed_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	agent_table = GridContainer.new()
	agent_table.columns = 5
	agent_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	agent_table.add_theme_constant_override("h_separation", 10)
	agent_table.add_theme_constant_override("v_separation", 8)
	scroll.add_child(agent_table)

	var note := Label.new()
	note.text = "Start or Step locks these settings until Reset. Reset keeps the current configuration."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	content.add_child(note)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	error_label.hide()
	content.add_child(error_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(hide)
	actions.add_child(cancel_button)
	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_submit_configuration)
	actions.add_child(apply_button)


func _create_number_input(minimum: float, maximum: float) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = 1.0
	input.rounded = true
	input.custom_minimum_size = Vector2(100.0, 0.0)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return input


func _add_label(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _rebuild_agent_rows() -> void:
	for child in agent_table.get_children():
		agent_table.remove_child(child)
		child.queue_free()
	agent_rows.clear()
	for heading: String in ["Agent", "Speed", "Vision", "Comm. range", "Color"]:
		_add_label(agent_table, heading)
	for index in range(draft_config.agent_configs.size()):
		var config: AgentConfig = draft_config.agent_configs[index]
		if config == null:
			config = AgentConfig.new()
			draft_config.agent_configs[index] = config
		_add_label(agent_table, "Agent%02d" % (index + 1))
		var speed_input: SpinBox = _create_number_input(1, 20)
		speed_input.value = config.speed
		agent_table.add_child(speed_input)
		var vision_input: SpinBox = _create_number_input(1, 20)
		vision_input.value = config.vision_range
		agent_table.add_child(vision_input)
		var communication_input: SpinBox = _create_number_input(1, 20)
		communication_input.value = config.communication_range
		agent_table.add_child(communication_input)
		var color_input := ColorPickerButton.new()
		color_input.color = config.color
		color_input.edit_alpha = false
		color_input.custom_minimum_size = Vector2(80.0, 30.0)
		agent_table.add_child(color_input)
		agent_rows.append({
			"speed": speed_input,
			"vision": vision_input,
			"communication": communication_input,
			"color": color_input
		})


func _store_agent_values() -> void:
	for index in range(agent_rows.size()):
		var row: Dictionary = agent_rows[index]
		row["speed"].apply()
		row["vision"].apply()
		row["communication"].apply()
		var config: AgentConfig = draft_config.agent_configs[index]
		config.speed = int(row["speed"].value)
		config.vision_range = int(row["vision"].value)
		config.communication_range = int(row["communication"].value)
		config.color = row["color"].color


func _on_agent_count_changed(value: float) -> void:
	if draft_config == null:
		return
	_store_agent_values()
	var previous_count: int = draft_config.agent_configs.size()
	var count: int = int(value)
	draft_config.agent_configs.resize(count)
	for index in range(previous_count, count):
		var config := AgentConfig.new()
		config.color = Color.from_hsv(fposmod(index * 0.61803398875, 1.0), 0.7, 0.95)
		draft_config.agent_configs[index] = config
	_rebuild_agent_rows()


func _submit_configuration() -> void:
	if SimulationSession.is_loading:
		return
	if SimulationSession.configuration_locked:
		show_error("Reset the simulation before editing settings.")
		return
	map_size_input.apply()
	density_input.apply()
	_store_agent_values()
	agent_count_input.apply()
	draft_config.map_size = int(map_size_input.value)
	draft_config.obstacle_density = density_input.value / 100.0
	var error: String = draft_config.validate()
	if not error.is_empty():
		show_error(error)
		return
	configuration_submitted.emit(draft_config.create_copy())
