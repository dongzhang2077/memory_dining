extends Node

## Test script for Player
## Player 测试脚本

@onready var grid_system: GridSystem = $GridSystem
@onready var grid_visualizer: GridVisualizer = $GridVisualizer
@onready var player: Player = $Player

func _ready():
	print("=== Player Test Started ===")

	# Setup input map
	InputMapConfig.setup_input_map()
	print("✓ Input map configured")

	# Connect signals for testing
	_connect_test_signals()

	# Initialize grid (only once)
	grid_system.initialize(12, 20)
	print("✓ Grid initialized")

	# Wait for initialization
	await get_tree().create_timer(0.5).timeout

	print("\n=== Player Test Ready ===")
	print("Controls:")
	print("  Arrow Keys / WASD - Move")
	print("  Space + Direction - Dig")
	print("  E - Enter scan mode (costs %d energy)" % player.scan_energy_cost)
	print("  WASD / E / Click - Move scan frame / Confirm scan")
	print("  ESC - Cancel scan mode")
	print("  B - Place bomb (costs %d energy, explodes in %.1fs)" % [player.bomb_energy_cost, player.bomb_fuse_time])
	print("  R - Respawn")
	print("\nPlayer HP: %d/%d" % [player.current_hp, player.max_hp])
	print("Player Energy: %d/%d" % [player.current_energy, player.max_energy])
	print("Player Position: (%d, %d)" % [player.grid_position.x, player.grid_position.y])
	print("Player State: %s" % player.get_state_name())

func _connect_test_signals():
	player.player_moved.connect(_on_player_moved)
	player.player_falling.connect(_on_player_falling)
	player.player_landed.connect(_on_player_landed)
	player.player_damaged.connect(_on_player_damaged)
	player.player_died.connect(_on_player_died)
	player.player_digging.connect(_on_player_digging)
	player.energy_changed.connect(_on_player_energy_changed)
	player.scan_mode_entered.connect(_on_scan_mode_entered)
	player.scan_mode_exited.connect(_on_scan_mode_exited)
	player.scan_performed.connect(_on_scan_performed)
	player.scan_failed_no_energy.connect(_on_scan_failed_no_energy)
	player.bomb_placed.connect(_on_bomb_placed)
	player.bomb_exploded.connect(_on_bomb_exploded)
	player.bomb_failed_no_energy.connect(_on_bomb_failed_no_energy)

	grid_system.energy_gained.connect(_on_energy_gained)
	grid_system.treasure_revealed.connect(_on_treasure_revealed)
	grid_system.block_falling.connect(_on_block_falling)
	grid_system.block_landed.connect(_on_block_landed)
	grid_system.treasure_broken.connect(_on_treasure_broken)
	grid_system.bomb_explosion.connect(_on_grid_bomb_explosion)

func _on_player_moved(new_position: Vector2i):
	print("Player moved to (%d, %d)" % [new_position.x, new_position.y])

func _on_player_falling(height: int):
	print("Player is falling...")

func _on_player_landed(fall_height: int):
	if fall_height > 0:
		print("Player landed after falling %d blocks" % fall_height)

func _on_player_damaged(amount: int, reason: String):
	print("Player took %d damage: %s" % [amount, reason])
	print("Player HP: %d/%d" % [player.current_hp, player.max_hp])

func _on_player_died(reason: String):
	print("Player died: %s" % reason)
	print("Press R to respawn")

func _on_player_digging(position: Vector2i):
	print("Player digging at (%d, %d)" % [position.x, position.y])

func _on_energy_gained(amount: int):
	print("Energy gained: %d" % amount)

func _on_treasure_revealed(position: Vector2i, treasure_data: TreasureData):
	print("Treasure revealed: %s (%s, %s) - %d coins" % [
		treasure_data.name,
		TreasureData.get_era_name(treasure_data.era),
		TreasureData.get_rarity_name(treasure_data.rarity),
		treasure_data.value
	])

func _on_block_falling(from_pos: Vector2i, to_pos: Vector2i, block_data: BlockData):
	print("Block falling from (%d, %d) to (%d, %d)" % [from_pos.x, from_pos.y, to_pos.x, to_pos.y])

func _on_block_landed(position: Vector2i, block_data: BlockData, fall_distance: int):
	print("Block landed at (%d, %d) after falling %d blocks" % [position.x, position.y, fall_distance])

func _on_treasure_broken(position: Vector2i, treasure_data: TreasureData):
	print("TREASURE BROKEN at (%d, %d): %s is now worthless!" % [position.x, position.y, treasure_data.name])

func _on_player_energy_changed(current: int, max_e: int):
	# Print is already handled in player.gd
	pass

func _on_scan_mode_entered():
	print("=== SCAN MODE ENTERED ===")
	print("Move mouse to position scan frame, press E or click to scan, ESC to cancel")

func _on_scan_mode_exited():
	print("=== SCAN MODE EXITED ===")

func _on_scan_performed(center_position: Vector2i):
	print("Scan performed at (%d, %d)" % [center_position.x, center_position.y])

func _on_scan_failed_no_energy():
	print("SCAN FAILED: Not enough energy!")

func _on_bomb_placed(bomb_pos: Vector2i):
	print("=== BOMB PLACED at (%d, %d) ===" % [bomb_pos.x, bomb_pos.y])
	print("GET AWAY! Explosion in %.1f seconds!" % player.bomb_fuse_time)

func _on_bomb_exploded(bomb_pos: Vector2i):
	print("=== BOMB EXPLODED at (%d, %d) ===" % [bomb_pos.x, bomb_pos.y])

func _on_bomb_failed_no_energy():
	print("BOMB FAILED: Not enough energy! Need %d" % player.bomb_energy_cost)

func _on_grid_bomb_explosion(center: Vector2i, affected_positions: Array):
	print("Explosion affected %d positions" % affected_positions.size())

func _input(event):
	if event.is_action_pressed("restart"):
		print("\n=== Respawning ===")
		player.respawn()
		print("Player HP: %d/%d" % [player.current_hp, player.max_hp])
		print("Player Energy: %d/%d" % [player.current_energy, player.max_energy])
		print("Player Position: (%d, %d)" % [player.grid_position.x, player.grid_position.y])
		print("Player State: %s" % player.get_state_name())
