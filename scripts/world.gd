extends Node2D

@onready var tile_map = $TileMap
@onready var label = $CanvasLayer/CenterContainer/Label

@onready var example_map : TileMap = preload("res://scenes/example_map.tscn").instantiate()

func _ready():
	var start = Time.get_ticks_msec()
	wfc(Vector2i(50, 50))
	print((Time.get_ticks_msec() - start) / 1000.0)
	

func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func wfc(grid_size: Vector2i):
	var rules = wfc_setup()
	#for rule in rules:
		#print(rule, ": ", rules[rule], "\n")
	var grid = create_grid(grid_size, rules)
	
	var wait_time = 0.00
	label.text = str(wait_time)
	var pressed_once = false
	
	for i in range(10000):
		var picked_tile_coords = find_tile(grid)
		if type_string(typeof(picked_tile_coords)) == "bool":
			print("finished!")
			break
		check_neighbors(grid, rules, picked_tile_coords, grid_size, wait_time > 0)
		if Input.is_action_pressed("ui_left"):
			if not pressed_once:
				wait_time = clamp(wait_time + 0.01, 0, 0.2)
				label.text = str(wait_time)
				pressed_once = true
		elif Input.is_action_pressed("ui_right"):
			if not pressed_once:
				wait_time = clamp(wait_time - 0.01, 0, 0.2)
				label.text = str(wait_time)
				pressed_once = true
		else:
			pressed_once = false
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time).timeout
	
	var x_idx = 0
	var y_idx = 0
	for x in grid:
		for y in x:
			#print(Vector2i(x_idx, y_idx), ", ", y[0])
			tile_map.set_cell(0, Vector2i(x_idx, y_idx), 0, str_to_var(y[0]))
			y_idx += 1
		y_idx = 0
		x_idx += 1

func wfc_setup():
	var example_tiles_positions = example_map.get_used_cells(0)
	var rules = {}
	for tile_pos in example_tiles_positions:
		var atlas_coords = example_map.get_cell_atlas_coords(0, tile_pos)
		var atlas_coords_str = var_to_str(atlas_coords)
		if not rules.has(atlas_coords_str):
			rules[atlas_coords_str] = {
				"right": {},
				"left": {},
				"top": {},
				"bottom": {},
				"weight": 1,
				"start_weight": 1
			}
		else:
			rules[atlas_coords_str]["weight"] += 1
			rules[atlas_coords_str]["start_weight"] = rules[atlas_coords_str]["weight"]
		
		for dir in [["right", TileSet.CELL_NEIGHBOR_RIGHT_SIDE], ["left", TileSet.CELL_NEIGHBOR_LEFT_SIDE], ["top", TileSet.CELL_NEIGHBOR_TOP_SIDE], ["bottom", TileSet.CELL_NEIGHBOR_BOTTOM_SIDE]]:
			var neighbor_atlas_coords = example_map.get_cell_atlas_coords(0, example_map.get_neighbor_cell(tile_pos, dir[1]))
			if neighbor_atlas_coords != Vector2i(-1, -1):
				if rules[atlas_coords_str][dir[0]].has(var_to_str(neighbor_atlas_coords)):
					rules[atlas_coords_str][dir[0]][var_to_str(neighbor_atlas_coords)] += 1
				else:
					rules[atlas_coords_str][dir[0]][var_to_str(neighbor_atlas_coords)] = 1
	return rules

func create_grid(grid_size: Vector2i, rules: Dictionary):
	var grid = []
	for x in range(grid_size.x):
		grid.append([])
		for y in range(grid_size.y):
			grid[x].append(rules.keys())
	return grid

func find_tile(grid):
	var lowest_entropy = -1
	var picked_tiles_coords = []
	var x_idx = 0
	var y_idx = 0
	for x in grid:
		for y in x:
			#var type_y = type_string(typeof(y))
			#print(y.size(), ", ", lowest_entropy)
			if y.size() > 1 and ((lowest_entropy == -1) or (y.size() <= lowest_entropy)):
				if y.size() == lowest_entropy:
					picked_tiles_coords.push_back(Vector2i(x_idx, y_idx))
				else:
					picked_tiles_coords = [Vector2i(x_idx, y_idx)]
				lowest_entropy = y.size()
			y_idx += 1
		y_idx = 0
		x_idx += 1
	if picked_tiles_coords == []:
		return false
	else:
		return picked_tiles_coords.pick_random()

func check_neighbors(grid: Array, rules, picked_tile_coords, grid_size, draw_collapsed):
	var picked_tile = grid[picked_tile_coords.x][picked_tile_coords.y]
	for dir in [["right", Vector2i(-1, 0)], ["left", Vector2i(1, 0)], ["top", Vector2i(0, 1)], ["bottom", Vector2i(0, -1)]]:
		var normal_neighbor_coords = picked_tile_coords + dir[1]
		var neighbor_coords = normal_neighbor_coords.clamp(Vector2i(0, 0), Vector2i(grid_size.x - 1, grid_size.y - 1))
		if neighbor_coords == normal_neighbor_coords:
			var neighbor = grid[neighbor_coords.x][neighbor_coords.y]
			if neighbor.size() == 1:
				var neighbor_rules = rules[neighbor[0]][dir[0]]
				var to_remove = []
				for possibility in picked_tile:
					rules[possibility]["weight"] = rules[possibility]["start_weight"]
					if not (possibility in neighbor_rules):
						to_remove.append(possibility)
					else:
						rules[possibility]["weight"] += neighbor_rules[possibility]
				for remove in to_remove:
					if picked_tile.size() < 2:
						scramble_neighbors(grid, rules, grid_size, picked_tile_coords, draw_collapsed)
						print("scrambled start!")
						break
					picked_tile.erase(remove)
				if picked_tile.size() == 1:
					if draw_collapsed:
						tile_map.set_cell(0, picked_tile_coords, 0, str_to_var(picked_tile[0]))
	
	var idx = 0#randi_range(0, grid[picked_tile_coords.x][picked_tile_coords.y].size() - 1)
	var max_weight = 0
	for possibility in picked_tile:
		max_weight += rules[possibility]["weight"]
	var rand_num = randf_range(0, max_weight)
	var total = 0
	for possibility in picked_tile:
		total += rules[possibility]["weight"]
		if rand_num <= total:
			break
		idx += 1
	
	grid[picked_tile_coords.x][picked_tile_coords.y] = [grid[picked_tile_coords.x][picked_tile_coords.y][idx]]
	if draw_collapsed:
		tile_map.set_cell(0, picked_tile_coords, 0, str_to_var(grid[picked_tile_coords.x][picked_tile_coords.y][0]))
	update_neighbors(grid, rules, grid_size, picked_tile_coords, draw_collapsed)

func update_neighbors(grid, rules, grid_size, picked_tile_coords, draw_collapsed):
	var tile_atlas_coords = grid[picked_tile_coords.x][picked_tile_coords.y][0]
	var neighbor_rules = rules[tile_atlas_coords]
	for dir in [["right", Vector2i(1, 0)], ["left", Vector2i(-1, 0)], ["top", Vector2i(0, -1)], ["bottom", Vector2i(0, 1)]]:
		var normal_neighbor_coords = picked_tile_coords + dir[1]
		var neighbor_coords = normal_neighbor_coords.clamp(Vector2i(0, 0), Vector2i(grid_size.x - 1, grid_size.y - 1))
		if neighbor_coords == normal_neighbor_coords:
			var neighbor = grid[neighbor_coords.x][neighbor_coords.y]
			if neighbor.size() != 1:
				var dir_rules = neighbor_rules[dir[0]].keys()
				var to_remove = []
				for possibility in neighbor:
					if not (possibility in dir_rules):
						to_remove.append(possibility)
				for remove in to_remove:
					if neighbor.size() < 2:
						scramble_neighbors(grid, rules, grid_size, neighbor_coords, draw_collapsed)
						print("scrambled!")
						return
					neighbor.erase(remove)
				if neighbor.size() == 1:
					update_neighbors(grid, rules, grid_size, neighbor_coords, draw_collapsed)
					if draw_collapsed:
						tile_map.set_cell(0, neighbor_coords, 0, str_to_var(neighbor[0]))

func scramble_neighbors(grid, rules, grid_size, coords, draw_collapsed):
	for x in range(-5, 5):
		for y in range(-5, 5):
			var dir = Vector2i(x, y)
			var normal_neighbor_coords = coords + dir
			var neighbor_coords = normal_neighbor_coords.clamp(Vector2i(0, 0), Vector2i(grid_size.x - 1, grid_size.y - 1))
			if neighbor_coords == normal_neighbor_coords:
				grid[neighbor_coords.x][neighbor_coords.y]= rules.keys()
				if draw_collapsed:
					tile_map.set_cell(0, neighbor_coords)
	grid[coords.x][coords.y] = rules.keys()
	if draw_collapsed:
		tile_map.set_cell(0, coords)
