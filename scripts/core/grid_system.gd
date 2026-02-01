class_name GridSystem
extends Node

## Core grid system for Memory Mine
## Manages the grid data, block interactions, and digging logic
## Memory Mine 的核心网格系统
## 管理网格数据、方块交互和挖掘逻辑

signal grid_initialized(width: int, height: int)
signal block_changed(position: Vector2i, block_data: BlockData)
signal block_destroyed(position: Vector2i, block_type: BlockType.Type)
signal block_damaged(position: Vector2i, remaining_hits: int)
signal treasure_revealed(position: Vector2i, treasure_data: TreasureData)
signal energy_gained(amount: int)
signal block_falling(from_position: Vector2i, to_position: Vector2i, block_data: BlockData)
signal block_landed(position: Vector2i, block_data: BlockData, fall_distance: int)
signal treasure_broken(position: Vector2i, treasure_data: TreasureData)
signal bomb_explosion(center: Vector2i, affected_positions: Array)

## Grid dimensions
var grid_width: int = 12
var grid_height: int = 20

## 2D array storing block data [column][row]
var grid: Array = []

## Grid configuration
var cell_size: Vector2 = Vector2(32, 32)  # Pixel size of each cell

## Falling block tracking
## Dictionary: Vector2i -> { timer: float, falling: bool }
var pending_falls: Dictionary = {}
const FALL_DELAY: float = 0.5  # 0.5 second delay before falling

## Process falling blocks
func _process(delta: float):
	_update_falling_blocks(delta)

## Update falling block timers and trigger falls
func _update_falling_blocks(delta: float):
	var blocks_to_fall: Array[Vector2i] = []
	var blocks_to_remove: Array[Vector2i] = []

	# Update timers for pending falls
	for pos in pending_falls.keys():
		var data = pending_falls[pos]
		data.timer -= delta

		if data.timer <= 0:
			# Check if block still exists and still needs to fall
			var block = get_block(pos)
			if block != null and BlockType.is_fallable(block.type):
				var below = Vector2i(pos.x, pos.y + 1)
				if _is_valid_position(below) and is_empty(below):
					blocks_to_fall.append(pos)
				else:
					blocks_to_remove.append(pos)
			else:
				blocks_to_remove.append(pos)

	# Remove blocks that no longer need to fall
	for pos in blocks_to_remove:
		pending_falls.erase(pos)

	# Execute falls (in order from bottom to top to avoid conflicts)
	blocks_to_fall.sort_custom(func(a, b): return a.y > b.y)
	for pos in blocks_to_fall:
		_execute_block_fall(pos)
		pending_falls.erase(pos)

## Check all blocks for falling after a block is destroyed
func check_falling_blocks():
	for col in range(grid_width):
		for row in range(grid_height - 1, -1, -1):  # Bottom to top
			var pos = Vector2i(col, row)
			var block = get_block(pos)

			if block != null and BlockType.is_fallable(block.type):
				var below = Vector2i(col, row + 1)
				if _is_valid_position(below) and is_empty(below):
					# Schedule this block to fall if not already scheduled
					if not pending_falls.has(pos):
						pending_falls[pos] = { "timer": FALL_DELAY }

## Execute a single block fall
func _execute_block_fall(from_pos: Vector2i):
	var block = get_block(from_pos)
	if block == null:
		return

	# Find the target position (how far it will fall)
	var target_row = from_pos.y + 1
	while target_row < grid_height - 1:
		var next_below = Vector2i(from_pos.x, target_row + 1)
		if not is_empty(next_below):
			break
		target_row += 1

	var to_pos = Vector2i(from_pos.x, target_row)
	var fall_distance = to_pos.y - from_pos.y

	# Emit falling signal (for animation)
	block_falling.emit(from_pos, to_pos, block)

	# Update grid data
	grid[from_pos.x][from_pos.y] = null
	block.grid_position = to_pos
	grid[to_pos.x][to_pos.y] = block

	# Emit change signals
	block_changed.emit(from_pos, null)
	block_changed.emit(to_pos, block)

	# Check if treasure broke from falling
	if block.type == BlockType.Type.TREASURE and fall_distance >= 2:
		if block.treasure_data != null:
			treasure_broken.emit(to_pos, block.treasure_data)
			block.treasure_data = null  # Treasure is now worthless

	# Emit landed signal
	block_landed.emit(to_pos, block, fall_distance)

	# After this block lands, check if more blocks need to fall
	call_deferred("check_falling_blocks")

## Initialize the grid with default blocks
func initialize(width: int = 12, height: int = 20):
	grid_width = width
	grid_height = height
	
	# Create empty grid
	grid = []
	for col in range(grid_width):
		grid.append([])
		for row in range(grid_height):
			grid[col].append(null)
	
	# Fill with default blocks (soft dirt)
	_fill_with_default_blocks()
	
	grid_initialized.emit(grid_width, grid_height)

## Fill grid with default soft dirt blocks
func _fill_with_default_blocks():
	# Reset treasure sprites for this new level
	TreasureData.reset_level_sprites()

	for col in range(grid_width):
		for row in range(grid_height):
			# Skip top row for player spawn
			if row == 0:
				continue

			# Random block generation
			var block_type = _generate_random_block_type(row)
			var block_data = BlockData.new(block_type, Vector2i(col, row))

			# Add treasure data if it's a treasure block
			if block_type == BlockType.Type.TREASURE:
				var era = _get_era_for_depth(row)
				block_data.treasure_data = TreasureData.generate_random(era)

			grid[col][row] = block_data

## Generate random block type based on depth
func _generate_random_block_type(row: int) -> BlockType.Type:
	var rand_val = randf()
	
	# Deeper rows have more hard stones and treasures
	var depth_factor = float(row) / float(grid_height)
	
	if rand_val < 0.05 + (depth_factor * 0.05):
		return BlockType.Type.ENERGY_CRYSTAL
	elif rand_val < 0.10 + (depth_factor * 0.10):
		return BlockType.Type.TREASURE
	elif rand_val < 0.15 + (depth_factor * 0.15):
		return BlockType.Type.UNBREAKABLE
	elif rand_val < 0.40 + (depth_factor * 0.20):
		return BlockType.Type.HARD_STONE
	else:
		return BlockType.Type.SOFT_DIRT

## Get era based on depth (deeper = older)
func _get_era_for_depth(row: int) -> TreasureData.Era:
	var depth_ratio = float(row) / float(grid_height)
	
	if depth_ratio < 0.25:
		return TreasureData.Era.ERA_1990S
	elif depth_ratio < 0.50:
		return TreasureData.Era.ERA_1980S
	elif depth_ratio < 0.75:
		return TreasureData.Era.ERA_1970S
	else:
		return TreasureData.Era.ERA_1960S

## Get block data at position
func get_block(position: Vector2i) -> BlockData:
	if not _is_valid_position(position):
		return null
	
	# Additional safety check for array bounds
	if position.x >= grid.size():
		return null
	if grid[position.x] == null or position.y >= grid[position.x].size():
		return null
	
	return grid[position.x][position.y]

## Set block data at position
func set_block(position: Vector2i, block_data: BlockData):
	if not _is_valid_position(position):
		return
	
	grid[position.x][position.y] = block_data
	block_changed.emit(position, block_data)

## Check if position is valid
func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < grid_width and position.y >= 0 and position.y < grid_height

## Try to dig at position
## Returns: Dictionary with result { success: bool, energy_gained: int, treasure: TreasureData }
func dig_at(position: Vector2i) -> Dictionary:
	var result = {
		"success": false,
		"energy_gained": 0,
		"treasure": null,
		"block_destroyed": false
	}
	
	var block = get_block(position)
	if block == null:
		return result
	
	# Check if block is breakable
	if not BlockType.is_breakable(block.type):
		return result
	
	# Apply damage
	var destroyed = block.take_damage()
	
	if destroyed:
		# Block destroyed
		var energy = BlockType.get_energy_yield(block.type)
		result.energy_gained = energy
		result.success = true
		result.block_destroyed = true
		
		# Handle treasure
		if block.type == BlockType.Type.TREASURE and block.treasure_data != null:
			result.treasure = block.treasure_data
			treasure_revealed.emit(position, block.treasure_data)
		
		# Emit signals
		block_destroyed.emit(position, block.type)
		if energy > 0:
			energy_gained.emit(energy)

		# Play dig sound effect
		AudioManager.play_sfx("dig", 0.8)

		# Remove block from grid
		grid[position.x][position.y] = null
		block_changed.emit(position, null)

		# Check for blocks that need to fall
		check_falling_blocks()
	else:
		# Block damaged but not destroyed
		result.success = true
		block_damaged.emit(position, block.get_remaining_hits())
		block_changed.emit(position, block)

	return result

## Scan a 2x2 area starting at position
## Returns: Array of revealed blocks
func scan_area(start_position: Vector2i) -> Array:
	var revealed_blocks = []

	for col in range(start_position.x, start_position.x + 2):
		for row in range(start_position.y, start_position.y + 2):
			var pos = Vector2i(col, row)
			var block = get_block(pos)

			if block != null and not block.is_visible:
				block.set_scanned()
				revealed_blocks.append(block)
				block_changed.emit(pos, block)

	return revealed_blocks

## Scan a 3x3 area centered at position
## Only reveals TREASURE and ENERGY_CRYSTAL blocks
## Returns: Number of blocks revealed
func scan_area_3x3(center_position: Vector2i) -> int:
	var revealed_count = 0
	print("=== SCANNING 3x3 area at center (%d, %d) ===" % [center_position.x, center_position.y])

	# Scan 3x3 area centered on position
	for col in range(center_position.x - 1, center_position.x + 2):
		for row in range(center_position.y - 1, center_position.y + 2):
			var pos = Vector2i(col, row)

			# Skip invalid positions
			if not _is_valid_position(pos):
				continue

			var block = get_block(pos)

			# Only reveal hidden treasure and energy crystal blocks
			if block != null and not block.is_scanned:
				if block.type == BlockType.Type.TREASURE or block.type == BlockType.Type.ENERGY_CRYSTAL:
					block.set_scanned()
					revealed_count += 1
					var type_name = BlockType.get_type_name(block.type)
					print("  ✓ REVEALED: %s at (%d, %d)" % [type_name, pos.x, pos.y])
					block_changed.emit(pos, block)

	if revealed_count == 0:
		print("  (No treasure or energy crystals found in this area)")
	else:
		print("  Total revealed: %d blocks" % revealed_count)
		# Play scan sound effect
		AudioManager.play_sfx("scan", 0.7)

	return revealed_count

## Check if block exists at position
func has_block(position: Vector2i) -> bool:
	return get_block(position) != null

## Check if position is empty
func is_empty(position: Vector2i) -> bool:
	return not has_block(position)

## Get all blocks that should fall (no support below)
func get_falling_blocks() -> Array[Vector2i]:
	var falling_positions: Array[Vector2i] = []
	
	# Check from bottom to top
	for row in range(grid_height - 2, -1, -1):
		for col in range(grid_width):
			var pos = Vector2i(col, row)
			var block = get_block(pos)
			
			if block != null and BlockType.is_fallable(block.type):
				var below_pos = Vector2i(col, row + 1)
				
				# Check if space below is empty
				if is_empty(below_pos):
					falling_positions.append(pos)
	
	return falling_positions

## Move block from one position to another
func move_block(from: Vector2i, to: Vector2i) -> bool:
	if not _is_valid_position(from) or not _is_valid_position(to):
		return false
	
	var block = get_block(from)
	if block == null:
		return false
	
	# Update block position
	block.grid_position = to
	
	# Move in grid
	grid[to.x][to.y] = block
	grid[from.x][from.y] = null
	
	# Emit signals
	block_changed.emit(from, null)
	block_changed.emit(to, block)
	
	return true

## Get grid world position from grid coordinates
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * cell_size.x, grid_pos.y * cell_size.y)

## Get grid coordinates from world position
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / cell_size.x),
		int(world_pos.y / cell_size.y)
	)

## Clear all blocks
func clear_grid():
	for col in range(grid_width):
		for row in range(grid_height):
			grid[col][row] = null

## Get grid state as dictionary (for saving)
func get_grid_state() -> Dictionary:
	var state = {
		"width": grid_width,
		"height": grid_height,
		"blocks": []
	}
	
	for col in range(grid_width):
		for row in range(grid_height):
			var block = grid[col][row]
			if block != null:
				state.blocks.append({
					"position": {"x": col, "y": row},
					"type": block.type,
					"durability": block.durability,
					"is_visible": block.is_visible,
					"is_scanned": block.is_scanned
				})
	
	return state

## Load grid state from dictionary
func load_grid_state(state: Dictionary):
	clear_grid()
	
	if state.has("width"):
		grid_width = state.width
	if state.has("height"):
		grid_height = state.height
	
	# Rebuild grid
	for col in range(grid_width):
		grid.append([])
		for row in range(grid_height):
			grid[col].append(null)
	
	# Load blocks
	if state.has("blocks"):
		for block_data in state.blocks:
			var pos = Vector2i(block_data.position.x, block_data.position.y)
			var block = BlockData.new(block_data.type, pos)
			block.durability = block_data.durability
			block.is_visible = block_data.is_visible
			block.is_scanned = block_data.is_scanned
			grid[pos.x][pos.y] = block

## ============== Bomb Explosion ==============

## Explode in a cross pattern from center position
## Returns: Dictionary with explosion results
func explode_cross(center: Vector2i, range_cells: int) -> Dictionary:
	var result = {
		"destroyed_blocks": 0,
		"energy_gained": 0,
		"treasures_destroyed": 0
	}

	var affected_positions: Array[Vector2i] = []

	# Collect all positions in cross pattern
	# Center position (where bomb was placed)
	affected_positions.append(center)

	# Four directions: up, down, left, right
	for i in range(1, range_cells + 1):
		affected_positions.append(Vector2i(center.x, center.y - i))  # Up
		affected_positions.append(Vector2i(center.x, center.y + i))  # Down
		affected_positions.append(Vector2i(center.x - i, center.y))  # Left
		affected_positions.append(Vector2i(center.x + i, center.y))  # Right

	# Process each position
	for pos in affected_positions:
		if not _is_valid_position(pos):
			continue

		var block = get_block(pos)
		if block == null:
			continue

		# Skip unbreakable blocks
		if block.type == BlockType.Type.UNBREAKABLE:
			print("  Unbreakable block at (%d, %d) - not affected" % [pos.x, pos.y])
			continue

		var type_name = BlockType.get_type_name(block.type)

		# Handle treasure specially - destroyed without value
		if block.type == BlockType.Type.TREASURE:
			print("  ✗ TREASURE DESTROYED at (%d, %d): %s" % [pos.x, pos.y, block.treasure_data.name if block.treasure_data else "Unknown"])
			result.treasures_destroyed += 1
			# Remove block without giving energy
			grid[pos.x][pos.y] = null
			block_destroyed.emit(pos, block.type)
			block_changed.emit(pos, null)
		else:
			# Other blocks give energy
			var energy = BlockType.get_energy_yield(block.type)
			result.energy_gained += energy
			print("  ✓ DESTROYED: %s at (%d, %d), energy +%d" % [type_name, pos.x, pos.y, energy])

			# Emit signals
			block_destroyed.emit(pos, block.type)
			if energy > 0:
				energy_gained.emit(energy)

			# Remove block
			grid[pos.x][pos.y] = null
			block_changed.emit(pos, null)

		result.destroyed_blocks += 1

	# Play bomb explosion sound
	AudioManager.play_sfx("bomb_explode", 1.0)

	# Emit explosion signal for visual effects
	bomb_explosion.emit(center, affected_positions)

	# Check for falling blocks after explosion
	check_falling_blocks()

	print("Explosion complete: %d blocks destroyed, %d energy gained, %d treasures lost" % [
		result.destroyed_blocks, result.energy_gained, result.treasures_destroyed
	])

	return result
