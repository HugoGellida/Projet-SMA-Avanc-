extends Node2D
class_name HeatMap

@onready var world_map: Map = $"../Map"


var case_with_number: Dictionary = {}


func _ready():
	initialize()


func initialize() ->void:
	case_with_number.clear()
	
	for tile in world_map.content:
		var coord:Vector2i = tile.coord
		case_with_number[coord] = 0;
	
