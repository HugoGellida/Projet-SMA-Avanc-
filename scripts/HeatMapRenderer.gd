extends Node2D
class_name HeatMapRenderer

@export var tile_size: int = 10
@export_range(1, 100, 1) var max_heat_visits: int = 10

@onready var heat_map: HeatMap = $"../HeatMap"
@onready var world_map: Map = $"../Map"


func _draw() -> void:
	for tile: Tile in world_map.content:
		var coord: Vector2i = tile.coord
		var visits: int = heat_map.case_with_number.get(coord, 0)

		var color: Color

		if tile.obstacle:
			color = Color.DARK_GRAY
		else:
			var intensity: float = clampf(
				float(visits) / float(max_heat_visits),
				0.0,
				1.0
			)

			var low_color := Color.WHITE
			var high_color := Color(1.0, 0.27, 0.0)

			color = low_color.lerp(high_color, intensity)

		var rect := Rect2(
			Vector2(coord) * tile_size,
			Vector2.ONE * tile_size
		)

		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 1.0)
