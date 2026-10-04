extends Node2D
class_name MapRenderer

@export var tile_size: int = 10

const COLOR_OBSTACLE = Color.DARK_GRAY
const BIOME_COLORS := {
	"water": Color(0.2, 0.45, 0.8),
	"sand": Color(0.82, 0.72, 0.48),
	"grass": Color(0.35, 0.65, 0.3),
	"forest": Color(0.12, 0.4, 0.22),
	"snow": Color(0.90, 0.90, 1),
}

var map: Map

func draw_tile(tile: Tile):
	var position := Vector2(tile.coord * tile_size)
	var rect := Rect2(position, Vector2(tile_size, tile_size))

	if tile.obstacle:
		draw_rect(rect, COLOR_OBSTACLE)
	else:
		draw_rect(rect, BIOME_COLORS[tile.biome])

	draw_rect(rect, Color.BLACK, false, 1.0)

func setup(target_map: Map):
	map = target_map
	queue_redraw()


func _draw():
	if map == null:
		return

	for tile in map.content:
		draw_tile(tile)
