extends Node2D
class_name Map

@export var size: int = 20
@export_range(0.0, 0.6)
var obstacle_density: float = 0.9

@export var seed: int = 666
@export var randomize_seed: bool = false

var content: Array[Tile] = []
var rng: RandomNumberGenerator
var biome_noise: FastNoiseLite

@onready var renderer: MapRenderer = $"../MapRenderer"

func get_biome(noise_value: float) -> String:
	if noise_value < -0.2:
		return "water"
	if noise_value < -0.08:
		return "sand"
	if noise_value < 0.12:
		return "grass"
	if noise_value < 0.28:
		return "forest"
	return "snow"

func get_tile(coord: Vector2i) -> Tile:
	return content[coord.y * size + coord.x]

func is_inside_map(coord: Vector2i) -> bool:
	return (
		coord.x >= 0
		and coord.x < size
		and coord.y >= 0
		and coord.y < size
	)

func is_fully_explorable() -> bool:
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

	if visited.size() != total_free_cells:
		return false

	for tile in content:
		if not tile.obstacle:
			continue

		var has_accessible_neighbor := false

		for direction in directions:
			var neighbor = tile.coord + direction

			if is_inside_map(neighbor) and not get_tile(neighbor).obstacle:
				has_accessible_neighbor = true
				break

		if not has_accessible_neighbor:
			return false

	return true


func _ready():
	generate_map()
	renderer.setup(self)


func generate_map():
	rng = RandomNumberGenerator.new()

	if randomize_seed:
		rng.randomize()
	else:
		rng.seed = seed

	biome_noise = FastNoiseLite.new()
	biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	biome_noise.seed = rng.seed
	biome_noise.frequency = 0.08
	biome_noise.fractal_octaves = 3

	content.clear()

	# 1. Créer une map entièrement libre
	for y in range(size):
		for x in range(size):
			var tile := Tile.new()
			var coord := Vector2i(x, y)
			var biome := get_biome(biome_noise.get_noise_2d(x, y))
			tile.init(coord, false, biome)

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

		# Keep free cells connected and every obstacle visible from a free cell.
		if is_fully_explorable():
			obstacles_added += 1
		else:
			# Cet obstacle crée une séparation
			tile.obstacle = false

	print("Map generated with ", obstacles_added, " obstacles.")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
