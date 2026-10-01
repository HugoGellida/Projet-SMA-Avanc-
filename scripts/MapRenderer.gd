extends Node2D
class_name MapRenderer

@export var tile_size: int = 10

var map: Map

func draw_tile(tile: Tile):
	var position := Vector2(tile.coord * tile_size)
	var rect := Rect2(position, Vector2(tile_size, tile_size))

	if tile.obstacle:
		draw_rect(rect, Color.DARK_GRAY)
	else:
		draw_rect(rect, Color.WHITE)

	draw_rect(rect, Color.BLACK, false, 1.0)

func setup(target_map: Map):
	map = target_map
	queue_redraw()


func _draw():
	if map == null:
		return

	for tile in map.content:
		draw_tile(tile)
