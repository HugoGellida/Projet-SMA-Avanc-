extends Node

var current_config: SimulationConfig
var configuration_locked: bool = false
var is_loading: bool = false
var loading_overlay: ColorRect
var loading_title: Label


func _ready() -> void:
	var loading_layer := CanvasLayer.new()
	loading_layer.layer = 1025
	add_child(loading_layer)
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color(0.035, 0.045, 0.065, 0.92)
	loading_overlay.focus_mode = Control.FOCUS_ALL
	loading_layer.add_child(loading_overlay)
	loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	loading_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	loading_title = Label.new()
	loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_title.add_theme_font_size_override("font_size", 22)
	content.add_child(loading_title)
	var description := Label.new()
	description.text = "Generating the map and preparing agents.\nLarge maps may take a moment. Please wait."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)
	loading_overlay.hide()


func _input(_event: InputEvent) -> void:
	if is_loading:
		get_viewport().set_input_as_handled()


func reload_simulation(message: String) -> void:
	if is_loading:
		return
	is_loading = true
	var screen: Control = get_tree().current_scene.get_node("%Screen")
	loading_overlay.theme = screen.theme
	loading_title.text = message
	loading_overlay.show()
	loading_overlay.grab_focus()
	await _wait_for_display()
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		loading_overlay.hide()
		is_loading = false
		push_error("Unable to reload the simulation: %s" % error_string(error))


func complete_loading() -> void:
	if not is_loading:
		return
	await _wait_for_display()
	loading_overlay.hide()
	is_loading = false


func _wait_for_display() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await get_tree().process_frame


func begin_scene(default_config: SimulationConfig) -> SimulationConfig:
	if current_config == null:
		current_config = default_config.create_copy()
	configuration_locked = false
	return current_config.create_copy()


func apply_config(config: SimulationConfig) -> String:
	if is_loading:
		return "Please wait for the current configuration to finish loading."
	if configuration_locked:
		return "Configuration is locked. Reset the simulation before editing settings."
	var error: String = config.validate()
	if not error.is_empty():
		return error
	current_config = config.create_copy()
	current_config.communication_enabled = config.communication_enabled or config.cnp_enabled
	return ""


func lock_configuration() -> void:
	configuration_locked = true


func update_protocol_options(communication_enabled: bool, cnp_enabled: bool) -> void:
	if current_config == null:
		return
	current_config.communication_enabled = communication_enabled or cnp_enabled
	current_config.cnp_enabled = cnp_enabled
