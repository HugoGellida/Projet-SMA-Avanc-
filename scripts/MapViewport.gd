extends Control
class_name MapViewport

signal zoom_changed(zoom_level: float)

@export var interactive: bool = true
@export var maximum_zoom: float = 32.0

@onready var map_content: Node2D = $MapContent

var map_pixel_size: Vector2 = Vector2.ZERO
var fit_scale: float = 1.0
var zoom_level: float = 1.0
var dragging: bool = false


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_viewport_resized)


func set_map_size(pixel_size: Vector2) -> void:
	map_pixel_size = pixel_size
	fit_map()


func fit_map() -> void:
	if map_pixel_size.x <= 0.0 or map_pixel_size.y <= 0.0:
		return
	var available_size: Vector2 = size - Vector2(24.0, 24.0)
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return
	fit_scale = minf(available_size.x / map_pixel_size.x, available_size.y / map_pixel_size.y)
	zoom_level = 1.0
	dragging = false
	map_content.scale = Vector2.ONE * fit_scale
	map_content.position = (size - map_pixel_size * fit_scale) * 0.5
	zoom_changed.emit(zoom_level)
	queue_redraw()


func zoom_at(view_position: Vector2, zoom_factor: float) -> void:
	if map_pixel_size == Vector2.ZERO:
		return
	var map_position: Vector2 = (view_position - map_content.position) / map_content.scale.x
	zoom_level = clampf(zoom_level * zoom_factor, 1.0, maximum_zoom)
	map_content.scale = Vector2.ONE * fit_scale * zoom_level
	map_content.position = view_position - map_position * map_content.scale.x
	_clamp_map_position()
	zoom_changed.emit(zoom_level)


func zoom_in() -> void:
	zoom_at(size * 0.5, 1.25)


func zoom_out() -> void:
	zoom_at(size * 0.5, 0.8)


func pan_map(offset: Vector2) -> void:
	map_content.position += offset
	_clamp_map_position()


func _clamp_map_position() -> void:
	var displayed_size: Vector2 = map_pixel_size * map_content.scale
	for axis in range(2):
		if displayed_size[axis] <= size[axis]:
			map_content.position[axis] = (size[axis] - displayed_size[axis]) * 0.5
		else:
			map_content.position[axis] = clampf(
				map_content.position[axis], size[axis] - displayed_size[axis] - 12.0, 12.0
			)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, 1.2)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, 1.0 / 1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			if dragging:
				grab_focus()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan_map(event.relative)
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
		accept_event()
	elif event is InputEventPanGesture:
		pan_map(-event.delta * 24.0)
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		fit_map()
		accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = false


func _on_viewport_resized() -> void:
	fit_map()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.07, 0.09))
