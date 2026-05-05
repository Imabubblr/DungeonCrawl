extends Node2D
@export var tile_map_layer: TileMapLayer

#region Tile IDs
var floor_tile := Vector2i(3,2)
var wall_tile_bottom := Vector2i(3,0)
var wall_tile_top := Vector2i(3,4)
var wall_tile_left := Vector2i(5,2)
var wall_tile_right := Vector2i(0,2)
#endregion

#region Dungeon Generation Parameters
const WIDTH = 80 # Size of the dungeon grid (in tiles)
const HEIGHT = 60 # Size of the dungeon grid (in tiles)
const MIN_ROOM_SIZE = 5	# Minimum size of a room (in tiles)
const MAX_ROOM_SIZE = 10 # Maximum size of a room (in tiles)
const MIN_ROOMS = 5 # Minimum number of rooms to generate
const MAX_ROOMS = 10 # Maximum number of rooms to generate 
const ROOMS_PER_BRANCH = 3  # Max rooms that can branch from one room
const MAX_BRANCH_DEPTH = 4  # How deep branches can go
const MIN_HALL_LENGTH = 5 # Minimum length of the hallway between rooms (in tiles) - this is important to prevent rooms from being too close together and merging into one big room.
const ROOM_PADDING = 1  # Minimum empty tiles around every room
#endregion

var grid = [] # 2D array representing the dungeon layout (0 = floor, 1 = wall)
var rooms = [] # Stores the Rect2 of each room for easy access and connection
var room_connections = {}  # Tracks which room each room connects to (parent)

func _ready():
	randomize() # Initialize random seed
	
	initialize_grid() # Fill the grid with walls
	generate_dungeon() # Generate the dungeon layout
	draw_dungeon() # Draw the dungeon on the TileMapLayer

func initialize_grid():
	for x in range(WIDTH):
		grid.append([])
		for y in range(HEIGHT):
			grid[x].append(1)

func generate_dungeon():
	var target_room_count = randi_range(MIN_ROOMS, MAX_ROOMS)
	# Create the starting room
	var start_room = generate_room()
	if place_room(start_room):
		rooms.append(start_room)
		room_connections[rooms.size() - 1] = -1  # Starting room has no parent
	
	# Generate branching rooms until we reach the target count
	var rooms_to_process = [0]  # Start with the first room
	var attempts = 0
	var max_attempts = 50
	
	while rooms.size() < target_room_count and attempts < max_attempts:
		attempts += 1
		
		if rooms_to_process.is_empty():
			# If queue is empty but we don't have enough rooms, restart from existing rooms
			rooms_to_process = range(rooms.size())
		
		var parent_idx = rooms_to_process.pop_front()
		
		# Always try to create branches until we reach the target room count
		var num_branches = 2 if rooms.size() < target_room_count else randi() % 2 + 1
		
		for branch in range(num_branches):
			if rooms.size() >= MAX_ROOMS:
				break
			
			var new_room = generate_adjacent_room(rooms[parent_idx])
			if new_room == null:
				continue
			if place_room(new_room):
				connect_rooms(rooms[parent_idx], new_room)
				rooms.append(new_room)
				room_connections[rooms.size() - 1] = parent_idx
				rooms_to_process.append(rooms.size() - 1)
				
				if rooms.size() >= target_room_count:
					break
		
		# Continue branching with remaining rooms
		if rooms.size() > target_room_count and randf() > 0.6:
			continue

func generate_room():
	var size = generate_square_room_size()
	var width = size.x
	var height = size.y
	
	var x = randi() % (WIDTH - width - 1) + 1
	var y = randi() % (HEIGHT - height - 1) + 1
	
	return Rect2(x, y, width, height)

func generate_square_room_size():
	var width = randi() % (MAX_ROOM_SIZE - MIN_ROOM_SIZE + 1) + MIN_ROOM_SIZE
	var delta = randi_range(0, 2)
	var height = width

	if randf() < 0.5:
		height = clampi(width + delta, MIN_ROOM_SIZE, MAX_ROOM_SIZE)
	else:
		height = clampi(width - delta, MIN_ROOM_SIZE, MAX_ROOM_SIZE)

	return Vector2i(width, height)

func generate_adjacent_room(parent_room):
	# Generate a room adjacent to the parent room with a hall between them.
	# We reject invalid placements instead of clamping, so the hallway length stays intact.
	for attempt in range(12):
		var size = generate_square_room_size()
		var width = size.x
		var height = size.y
		var direction = randi() % 4  # 0=right, 1=down, 2=left, 3=up
		var x = 0
		var y = 0
		
		match direction:
			0:  # Right
				x = int(parent_room.end.x) + MIN_HALL_LENGTH
				y = int(parent_room.position.y + parent_room.size.y / 2 - height / 2)
			1:  # Down
				x = int(parent_room.position.x + parent_room.size.x / 2 - width / 2)
				y = int(parent_room.end.y) + MIN_HALL_LENGTH
			2:  # Left
				x = int(parent_room.position.x) - width - MIN_HALL_LENGTH
				y = int(parent_room.position.y + parent_room.size.y / 2 - height / 2)
			3:  # Up
				x = int(parent_room.position.x + parent_room.size.x / 2 - width / 2)
				y = int(parent_room.position.y) - height - MIN_HALL_LENGTH
		
		var candidate_room = Rect2(x, y, width, height)
		if candidate_room.position.x < 1:
			continue
		if candidate_room.position.y < 1:
			continue
		if candidate_room.end.x >= WIDTH:
			continue
		if candidate_room.end.y >= HEIGHT:
			continue
		return candidate_room

	return null
	
func place_room(room):
	var left = int(room.position.x) - ROOM_PADDING
	var top = int(room.position.y) - ROOM_PADDING
	var right = int(room.end.x) + ROOM_PADDING
	var bottom = int(room.end.y) + ROOM_PADDING

	if left < 0 or top < 0 or right > WIDTH or bottom > HEIGHT:
		return false

	for x in range(left, right):
		for y in range(top, bottom):
			if grid[x][y] == 0:
				return false
	
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			grid[x][y] = 0
	return true

func connect_rooms(room1, room2, corridor_width=1):
	# Find midpoints of the adjacent sides
	var midpoint1 = Vector2()
	var midpoint2 = Vector2()
	
	# Determine which sides are adjacent and draw straight line between their midpoints
	var room1_right = int(room1.end.x)
	var room1_left = int(room1.position.x)
	var room1_top = int(room1.position.y)
	var room1_bottom = int(room1.end.y)
	
	var room2_right = int(room2.end.x)
	var room2_left = int(room2.position.x)
	var room2_top = int(room2.position.y)
	var room2_bottom = int(room2.end.y)
	
	var room1_mid_y = int(room1.position.y + room1.size.y / 2)
	var room1_mid_x = int(room1.position.x + room1.size.x / 2)
	var room2_mid_y = int(room2.position.y + room2.size.y / 2)
	var room2_mid_x = int(room2.position.x + room2.size.x / 2)
	
	# Horizontal corridor (rooms are left-right adjacent)
	if room1_right < room2_left:  # Room1 is to the left
		midpoint1 = Vector2(room1_right, room1_mid_y)
		midpoint2 = Vector2(room2_left, room2_mid_y)
		# Draw horizontal line
		for x in range(int(midpoint1.x), int(midpoint2.x) + 1):
			for i in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
				if room1_mid_y + i >= 0 and room1_mid_y + i < HEIGHT:
					grid[x][room1_mid_y + i] = 0
	elif room2_right < room1_left:  # Room2 is to the left
		midpoint1 = Vector2(room1_left, room1_mid_y)
		midpoint2 = Vector2(room2_right, room2_mid_y)
		# Draw horizontal line
		for x in range(int(midpoint2.x), int(midpoint1.x) + 1):
			for i in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
				if room1_mid_y + i >= 0 and room1_mid_y + i < HEIGHT:
					grid[x][room1_mid_y + i] = 0
	# Vertical corridor (rooms are top-bottom adjacent)
	elif room1_bottom < room2_top:  # Room1 is above
		midpoint1 = Vector2(room1_mid_x, room1_bottom)
		midpoint2 = Vector2(room2_mid_x, room2_top)
		# Draw vertical line
		for y in range(int(midpoint1.y), int(midpoint2.y) + 1):
			for i in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
				if room1_mid_x + i >= 0 and room1_mid_x + i < WIDTH:
					grid[room1_mid_x + i][y] = 0
	elif room2_bottom < room1_top:  # Room2 is above
		midpoint1 = Vector2(room1_mid_x, room1_top)
		midpoint2 = Vector2(room2_mid_x, room2_bottom)
		# Draw vertical line
		for y in range(int(midpoint2.y), int(midpoint1.y) + 1):
			for i in range(-int(corridor_width / 2), int(corridor_width / 2) + 1):
				if room1_mid_x + i >= 0 and room1_mid_x + i < WIDTH:
					grid[room1_mid_x + i][y] = 0

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
	room_connections.clear()


func _on_button_pressed() -> void:
	reset_dungeon()
	generate_dungeon()
	draw_dungeon()
