extends PanelContainer
class_name AgentMapCard


func setup(agent: Agent, world_map: Map, world_origin: Vector2i) -> AgentMapRenderer:
	name = "Card_%s" % agent.name
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(250.0, 166.0)
	tooltip_text = "Speed: %d | Vision: %d | Communication: %d" % [
		agent.speed, agent.vision_range, agent.communication_range
	]

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	var color_marker := ColorRect.new()
	color_marker.custom_minimum_size = Vector2(10.0, 10.0)
	color_marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_marker.color = agent.display_color
	color_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(color_marker)

	var title := Label.new()
	title.text = str(agent.name)
	header.add_child(title)

	var renderer := AgentMapRenderer.new()
	renderer.custom_minimum_size = Vector2(0.0, 116.0)
	renderer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renderer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	renderer.world_map = world_map
	renderer.world_origin = world_origin
	content.add_child(renderer)
	renderer.setup(agent)
	return renderer
