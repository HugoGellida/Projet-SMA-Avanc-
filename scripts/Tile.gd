extends Node2D

class_name Tile

var explored: bool = false
var obstacle: bool = false
var coord: Vector2i = Vector2i.ZERO
var biome: String

# Maybe later, add new things !

func init(p: Vector2i, o: bool, b: String):
	coord = p
	obstacle = o
	biome = b
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
