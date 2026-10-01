extends Node2D
class_name Map

@export var size: int = 20
@export_range(0.0, 0.6)
var obstacle_density: float = 0.30

@export var seed: int = 12345
@export var randomize_seed: bool = false

var content: Array[Tile] = []
var rng: RandomNumberGenerator

@onready var renderer: MapRenderer = $"../MapRenderer"

func get_tile(coord: Vector2i) -> Tile:
	return content[coord.y * size + coord.x]

func is_inside_map(coord: Vector2i) -> bool:
	return (
		coord.x >= 0
		and coord.x < size
		and coord.y >= 0
		and coord.y < size
	)

func is_fully_accessible() -> bool:
	var start: Vector2i = Vector2i(-1, -1)
	var total_free_cells := 0

	# Trouver une première cellule libre
	for tile in content:
		if not tile.obstacle:
			total_free_cells += 1

			if start == Vector2i(-1, -1):
				start = tile.coord

	if total_free_cells == 0:
		return false

	# BFS
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []

	queue.append(start)
	visited[start] = true

	var directions := [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]
	

	while not queue.is_empty():
		var current = queue.pop_front()

		for direction in directions:
			var next = current + direction

			if not is_inside_map(next):
				continue

			if visited.has(next):
				continue

			var tile := get_tile(next)

			if tile.obstacle:
				continue

			visited[next] = true
			queue.append(next)

	return visited.size() == total_free_cells


func _ready():
	generate_map()
	renderer.setup(self)


func generate_map():
	rng = RandomNumberGenerator.new()

	if randomize_seed:
		rng.randomize()
	else:
		rng.seed = seed

	content.clear()

	# 1. Créer une map entièrement libre
	for y in range(size):
		for x in range(size):
			var tile := Tile.new()

			tile.coord = Vector2i(x, y)
			tile.explored = false
			tile.obstacle = false

			content.append(tile)

	# 2. Liste des cellules candidates
	var candidates: Array[Vector2i] = []

	for y in range(size):
		for x in range(size):
			candidates.append(Vector2i(x, y))

	# 3. Mélanger les cellules avec NOTRE RNG
	#    => le résultat dépend uniquement de `seed`
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)

		var temp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temp

	# 4. Ajouter les obstacles progressivement
	var target_obstacles := int(size * size * obstacle_density)
	var obstacles_added := 0

	for coord in candidates:
		if obstacles_added >= target_obstacles:
			break

		var tile := get_tile(coord)

		tile.obstacle = true

		# Vérifier que toutes les cellules libres restent accessibles
		if is_fully_accessible():
			obstacles_added += 1
		else:
			# Cet obstacle crée une séparation
			tile.obstacle = false

	print("Map generated with ", obstacles_added, " obstacles.")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
