extends MarginContainer

@onready var world_map_view: MapViewport = %WorldMapViewport
@onready var zoom_level_label: Label = %ZoomLevelLabel
@onready var heat_map_renderer: HeatMapRenderer = %HeatMapRenderer


func _ready() -> void:
	theme = _create_interface_theme()
	%HeatMapLegend.text = "White: 0    Orange-red: %d+ visits" % heat_map_renderer.max_heat_visits
	%FitMapButton.pressed.connect(world_map_view.fit_map)
	%ZoomInButton.pressed.connect(world_map_view.zoom_in)
	%ZoomOutButton.pressed.connect(world_map_view.zoom_out)
	world_map_view.zoom_changed.connect(_update_zoom_level)


func _update_zoom_level(zoom_level: float) -> void:
	zoom_level_label.text = "%.0f%%" % (zoom_level * 100.0)


func _create_interface_theme() -> Theme:
	var interface_theme := Theme.new()
	interface_theme.default_font_size = 14
	interface_theme.set_color("font_color", "Label", Color(0.89, 0.92, 0.97))
	interface_theme.set_color("font_color", "Button", Color(0.89, 0.92, 0.97))
	interface_theme.set_color("font_color", "CheckButton", Color(0.89, 0.92, 0.97))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.15, 0.20)
	panel_style.border_color = Color(0.23, 0.28, 0.35)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	interface_theme.set_stylebox("panel", "PanelContainer", panel_style)

	var normal_button := StyleBoxFlat.new()
	normal_button.bg_color = Color(0.20, 0.25, 0.32)
	normal_button.border_color = Color(0.30, 0.37, 0.46)
	normal_button.set_border_width_all(1)
	normal_button.set_corner_radius_all(5)
	normal_button.content_margin_left = 12.0
	normal_button.content_margin_right = 12.0
	normal_button.content_margin_top = 7.0
	normal_button.content_margin_bottom = 7.0
	interface_theme.set_stylebox("normal", "Button", normal_button)

	var hover_button: StyleBoxFlat = normal_button.duplicate()
	hover_button.bg_color = Color(0.27, 0.34, 0.43)
	interface_theme.set_stylebox("hover", "Button", hover_button)
	var pressed_button: StyleBoxFlat = normal_button.duplicate()
	pressed_button.bg_color = Color(0.16, 0.22, 0.30)
	interface_theme.set_stylebox("pressed", "Button", pressed_button)
	var disabled_button: StyleBoxFlat = normal_button.duplicate()
	disabled_button.bg_color = Color(0.14, 0.17, 0.22)
	interface_theme.set_stylebox("disabled", "Button", disabled_button)
	return interface_theme
