extends Node2D
@export var tile_map_layer: TileMapLayer

var floor_tile := Vector2i(3,2)
var wall_tile_bottom := Vector2i(3,0)
var wall_tile_top := Vector2i(3,4)
var wall_tile_left : = Vector2i(5,2)
var wall_tile_right : = Vector2i(0,2)

const WIDTH = 80
const HEIGHT = 60
const MIN_ROOM_SIZE = 5
const MAX_ROOM_SIZE = 10
const MAX_ROOMS = 10

var grid = []
var rooms = []

func _ready():
	randomize()
	
	initialize_grid()
	generate_dungeon()
	draw_dungeon()

func initialize_grid():
	for x in range(WIDTH):
		grid.append([])
		for y in range(HEIGHT):
			grid[x].append(1)

func generate_dungeon():
	for i in range(MAX_ROOMS):
		var room = generate_room()
		if place_room(room):
			if rooms.size() > 0:
				connect_rooms(rooms[-1], room)
			rooms.append(room)

func generate_room():
	var width = randi() % (MAX_ROOM_SIZE - MIN_ROOM_SIZE + 1) + MIN_ROOM_SIZE
	var height = randi() % (MAX_ROOM_SIZE - MIN_ROOM_SIZE + 1) + MIN_ROOM_SIZE
	
	var x = randi() % (WIDTH - width - 1) + 1
	var y = randi() % (HEIGHT - height - 1) + 1
	
	return Rect2(x, y, width, height)
	
func place_room(room):
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			if grid[x][y] == 0:
				return false
	
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			grid[x][y] = 0
	return true

func connect_rooms(room1, room2, corridor_width=1):
	var start = Vector2(
		int(room1.position.x + room1.size.x / 2),
		int(room1.position.y + room1.size.y / 2)
	)
	
	var end = Vector2(
		int(room2.position.x + room2.size.x / 2),
		int(room2.position.y + room2.size.y / 2)
	)
	
	var current = start
	
	while current.x != end.x:
		current.x += 1 if end.x > current.x else -1
		for i in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
			for j in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
				if current.y + j >= 0 and current.y + j < HEIGHT and current.x + i >= 0 and current.x + i < WIDTH:
					grid[current.x + i][current.y + j] = 0

	while current.y != end.y:
		current.y += 1 if end.y > current.y else -1
		for i in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
			for j in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
				if current.x + i >= 0 and current.x + i < WIDTH and current.y + j >= 0 and current.y + j < HEIGHT:
					grid[current.x + i][current.y + j] = 0

func draw_dungeon():
	if not tile_map_layer:
		push_error("tile_map_layer is null in draw_dungeon() — assign the exported TileMapLayer in the editor.")
		return
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var tile_position = Vector2i(x, y)
			if grid[x][y] == 0:
				tile_map_layer.set_cell(tile_position, 1, floor_tile)
			elif grid[x][y] == 1:
				if y < HEIGHT - 1 and grid[x][y + 1] == 0:
					tile_map_layer.set_cell(tile_position, 1, wall_tile_bottom)
				elif y > 0 and grid[x][y - 1] == 0:
					tile_map_layer.set_cell(tile_position, 1, wall_tile_top)
				elif x < WIDTH - 1 and grid[x + 1][y] == 0:
					tile_map_layer.set_cell(tile_position, 1, wall_tile_right)
				elif x > 0 and grid[x - 1][y] == 0:
					tile_map_layer.set_cell(tile_position, 1, wall_tile_left)
				else:
					tile_map_layer.set_cell(tile_position, 1, Vector2i(8, 7))
			else:
				tile_map_layer.set_cell(tile_position, 1, Vector2i(-1, -1))

func reset_dungeon():
	if tile_map_layer:
		for x in range(WIDTH):
			for y in range(HEIGHT):
				var tile_position = Vector2i(x, y)
				tile_map_layer.set_cell(tile_position, 1, Vector2i(-1, -1))

	grid.clear()
	initialize_grid()
	rooms.clear()


func _on_button_pressed() -> void:
	reset_dungeon()
	generate_dungeon()
	draw_dungeon()
