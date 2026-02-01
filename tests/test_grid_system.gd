extends Node

## Test script for GridSystem
## GridSystem 测试脚本

var grid_system: GridSystem
var grid_visualizer: GridVisualizer

func _ready():
	print("=== GridSystem Test Started ===")
	
	# Create grid system
	grid_system = GridSystem.new()
	add_child(grid_system)
	
	# Create visualizer
	grid_visualizer = GridVisualizer.new()
	grid_visualizer.grid_system = grid_system
	add_child(grid_visualizer)
	
	# Connect signals for testing
	_connect_test_signals()
	
	# Run tests
	await get_tree().process_frame
	_test_initialization()
	await get_tree().create_timer(1.0).timeout
	
	_test_digging()
	await get_tree().create_timer(1.0).timeout
	
	_test_hard_stone()
	await get_tree().create_timer(1.0).timeout
	
	_test_scanning()
	await get_tree().create_timer(1.0).timeout
	
	_test_falling_blocks()
	await get_tree().create_timer(1.0).timeout
	
	print("=== GridSystem Test Completed ===")

func _connect_test_signals():
	grid_system.grid_initialized.connect(_on_grid_initialized)
	grid_system.block_changed.connect(_on_block_changed)
	grid_system.block_destroyed.connect(_on_block_destroyed)
	grid_system.block_damaged.connect(_on_block_damaged)
	grid_system.treasure_revealed.connect(_on_treasure_revealed)
	grid_system.energy_gained.connect(_on_energy_gained)

func _on_grid_initialized(width: int, height: int):
	print("✓ Grid initialized: %dx%d" % [width, height])

func _on_block_changed(position: Vector2i, block_data: BlockData):
	var type_str = "null" if block_data == null else BlockType.get_type_name(block_data.type)
	print("  Block changed at (%d, %d): %s" % [position.x, position.y, type_str])

func _on_block_destroyed(position: Vector2i, block_type: BlockType.Type):
	print("✓ Block destroyed at (%d, %d): %s" % [position.x, position.y, BlockType.get_type_name(block_type)])

func _on_block_damaged(position: Vector2i, remaining_hits: int):
	print("  Block damaged at (%d, %d): %d hits remaining" % [position.x, position.y, remaining_hits])

func _on_treasure_revealed(position: Vector2i, treasure_data: TreasureData):
	print("✓ Treasure revealed at (%d, %d): %s (%s, %s)" % [
		position.x, position.y,
		treasure_data.name,
		TreasureData.get_era_name(treasure_data.era),
		TreasureData.get_rarity_name(treasure_data.rarity)
	])

func _on_energy_gained(amount: int):
	print("✓ Energy gained: %d" % amount)

func _test_initialization():
	print("\n--- Test 1: Initialization ---")
	grid_system.initialize(12, 20)
	
	# Check grid size
	assert(grid_system.grid_width == 12, "Grid width should be 12")
	assert(grid_system.grid_height == 20, "Grid height should be 20")
	print("✓ Grid dimensions correct")
	
	# Check some blocks exist
	var block = grid_system.get_block(Vector2i(5, 5))
	assert(block != null, "Block should exist at (5, 5)")
	print("✓ Blocks generated correctly")

func _test_digging():
	print("\n--- Test 2: Digging ---")
	
	# Find a soft dirt block to dig
	var dig_pos = Vector2i(-1, -1)
	for col in range(grid_system.grid_width):
		for row in range(1, grid_system.grid_height):  # Skip row 0
			var block = grid_system.get_block(Vector2i(col, row))
			if block != null and block.type == BlockType.Type.SOFT_DIRT:
				dig_pos = Vector2i(col, row)
				break
		if dig_pos != Vector2i(-1, -1):
			break
	
	if dig_pos != Vector2i(-1, -1):
		print("Found soft dirt at (%d, %d)" % [dig_pos.x, dig_pos.y])
		var result = grid_system.dig_at(dig_pos)
		print("Dig result: success=%s, energy=%d, destroyed=%s" % [result.success, result.energy_gained, result.block_destroyed])
		assert(result.success, "Digging soft dirt should succeed")
		assert(result.block_destroyed, "Soft dirt should be destroyed in 1 hit")
		assert(result.energy_gained == 1, "Soft dirt should give 1 energy")
		print("✓ Soft dirt digging works correctly")
	else:
		print("⚠ No soft dirt block found for testing")
	
	# Test digging unbreakable rock
	var unbreakable_pos = Vector2i(-1, -1)
	for col in range(grid_system.grid_width):
		for row in range(1, grid_system.grid_height):
			var block = grid_system.get_block(Vector2i(col, row))
			if block != null and block.type == BlockType.Type.UNBREAKABLE:
				unbreakable_pos = Vector2i(col, row)
				break
		if unbreakable_pos != Vector2i(-1, -1):
			break
	
	if unbreakable_pos != Vector2i(-1, -1):
		print("Found unbreakable rock at (%d, %d)" % [unbreakable_pos.x, unbreakable_pos.y])
		var result = grid_system.dig_at(unbreakable_pos)
		assert(not result.success, "Should not be able to dig unbreakable rock")
		print("✓ Unbreakable rock cannot be dug")
	else:
		print("⚠ No unbreakable rock found for testing")

func _test_scanning():
	print("\n--- Test 3: Scanning ---")
	
	# Find a hidden block (treasure or energy crystal)
	var scan_pos = Vector2i(-1, -1)
	for col in range(grid_system.grid_width):
		for row in range(1, grid_system.grid_height):
			var block = grid_system.get_block(Vector2i(col, row))
			if block != null and not block.is_visible:
				scan_pos = Vector2i(col, row)
				break
		if scan_pos != Vector2i(-1, -1):
			break
	
	if scan_pos != Vector2i(-1, -1):
		print("Found hidden block at (%d, %d), scanning area..." % [scan_pos.x, scan_pos.y])
		# Scan a 2x2 area starting from the hidden block position
		var scan_start = Vector2i(max(0, scan_pos.x - 1), max(0, scan_pos.y - 1))
		var revealed = grid_system.scan_area(scan_start)
		print("Scanned area starting at (%d, %d), revealed %d blocks" % [scan_start.x, scan_start.y, revealed.size()])
		
		for block in revealed:
			print("  - %s at (%d, %d)" % [BlockType.get_type_name(block.type), block.grid_position.x, block.grid_position.y])
		
		assert(revealed.size() > 0, "Scanning should reveal at least one block")
		print("✓ Scanning works correctly")
	else:
		print("⚠ No hidden blocks found for scanning test")

func _test_hard_stone():
	print("\n--- Test 2.5: Hard Stone Digging ---")
	
	# Find a hard stone block
	var hard_stone_pos = Vector2i(-1, -1)
	for col in range(grid_system.grid_width):
		for row in range(1, grid_system.grid_height):
			var block = grid_system.get_block(Vector2i(col, row))
			if block != null and block.type == BlockType.Type.HARD_STONE:
				hard_stone_pos = Vector2i(col, row)
				break
		if hard_stone_pos != Vector2i(-1, -1):
			break
	
	if hard_stone_pos != Vector2i(-1, -1):
		print("Found hard stone at (%d, %d)" % [hard_stone_pos.x, hard_stone_pos.y])
		
		# First hit
		var result1 = grid_system.dig_at(hard_stone_pos)
		print("First hit: success=%s, destroyed=%s" % [result1.success, result1.block_destroyed])
		assert(result1.success, "First hit should succeed")
		assert(not result1.block_destroyed, "Hard stone should not be destroyed in 1 hit")
		
		# Second hit
		var result2 = grid_system.dig_at(hard_stone_pos)
		print("Second hit: success=%s, destroyed=%s" % [result2.success, result2.block_destroyed])
		assert(result2.success, "Second hit should succeed")
		assert(not result2.block_destroyed, "Hard stone should not be destroyed in 2 hits")
		
		# Third hit
		var result3 = grid_system.dig_at(hard_stone_pos)
		print("Third hit: success=%s, destroyed=%s, energy=%d" % [result3.success, result3.block_destroyed, result3.energy_gained])
		assert(result3.success, "Third hit should succeed")
		assert(result3.block_destroyed, "Hard stone should be destroyed in 3 hits")
		assert(result3.energy_gained == 2, "Hard stone should give 2 energy")
		
		print("✓ Hard stone durability works correctly")
	else:
		print("⚠ No hard stone found for testing")

func _test_falling_blocks():
	print("\n--- Test 4: Falling Blocks ---")
	
	# Create a scenario where blocks should fall
	# Clear a column below some blocks
	for row in range(5, 10):
		grid_system.grid[5][row] = null
	
	var falling = grid_system.get_falling_blocks()
	print("Found %d blocks that should fall" % falling.size())
	
	for pos in falling:
		print("  - Block at (%d, %d)" % [pos.x, pos.y])
