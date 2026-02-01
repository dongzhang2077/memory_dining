class_name Player
extends CharacterBody2D

## Player character for Memory Mine
## Handles movement, state, and interaction with the grid
## Memory Mine 的玩家角色
## 处理移动、状态和与网格的交互

## Signals
signal player_moved(new_position: Vector2i)
signal player_falling(height: int)
signal player_landed(fall_height: int)
signal player_damaged(amount: int, reason: String)
signal player_died(reason: String)
signal player_digging(position: Vector2i)
signal energy_changed(current: int, max_energy: int)
signal scan_mode_entered()
signal scan_mode_exited()
signal scan_performed(center_position: Vector2i)
signal scan_failed_no_energy()
signal bomb_placed(position: Vector2i)
signal bomb_exploded(position: Vector2i)
signal bomb_failed_no_energy()

## Player state enum
enum State {
	IDLE,       # Standing still
	MOVING,     # Moving horizontally
	FALLING,    # Falling due to no support
	DIGGING,    # Digging a block
	SCANNING,   # In scan mode
	DEAD        # Player is dead
}

## Player properties
@export var grid_system_path: NodePath
@export var move_speed: float = 100.0
@export var gravity: float = 500.0
@export var max_fall_damage_height: int = 3  # 3+ blocks = 1 HP damage
@export var instant_death_height: int = 5     # 5+ blocks = instant death

## Energy system configuration - easy to adjust
@export var max_energy: int = 30              # Maximum energy capacity
@export var scan_energy_cost: int = 10        # Energy cost per scan
@export var starting_energy: int = 0          # Starting energy (set higher for testing)

## Bomb system configuration
@export var bomb_energy_cost: int = 15        # Energy cost per bomb
@export var bomb_fuse_time: float = 1.0       # Seconds before bomb explodes
@export var bomb_range: int = 1               # Explosion range (cells in each direction)
@export var bomb_damage: int = 1              # Damage to player if caught in explosion

## Grid system reference (resolved from path)
var grid_system: GridSystem

## Player stats
var current_hp: int = 3
var max_hp: int = 3
var current_energy: int = 0
var current_state: State = State.IDLE
var grid_position: Vector2i = Vector2i.ZERO

## Scanning
var scan_frame_position: Vector2i = Vector2i.ZERO  # Current scan frame center (grid coords)
var camera: Camera2D = null  # Reference to camera for scan mode following

## Animation
var animated_sprite: AnimatedSprite2D = null

## Falling tracking
var fall_start_y: float = 0.0
var is_falling: bool = false

## Digging
var dig_cooldown: float = 0.3
var dig_timer: float = 0.0

## Input
var input_direction: int = 0  # -1 left, 0 none, 1 right

func _ready():
	# Resolve grid system from path
	if grid_system_path:
		grid_system = get_node(grid_system_path) as GridSystem

	# Get camera reference
	camera = get_node_or_null("Camera2D")

	# Get animated sprite reference
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite != null:
		animated_sprite.play("idle")
		animated_sprite.animation_finished.connect(_on_animation_finished)

	# Set z_index to render player above blocks
	z_index = 10

	# Configure CharacterBody2D for proper floor detection
	# up_direction is Vector2.UP by default, which is correct
	# floor_stop_on_slope prevents sliding on angled surfaces
	floor_stop_on_slope = true

	# Wait for grid to be initialized before spawning
	if grid_system != null:
		if not grid_system.grid.is_empty():
			_spawn_at_start_position()
		else:
			grid_system.grid_initialized.connect(_on_grid_initialized)

		# Connect to block landed signal for crush damage
		grid_system.block_landed.connect(_on_block_landed_check_crush)

		# Connect to energy gained signal
		grid_system.energy_gained.connect(_on_energy_gained)

func _on_grid_initialized(width: int, height: int):
	_spawn_at_start_position()

func _spawn_at_start_position():
	# Spawn at center of top row (row 0 is empty for player)
	# Player's grid_position is the cell they occupy
	grid_position = Vector2i(grid_system.grid_width / 2, 0)
	# Position player so their feet are at the bottom of row 0 (top of row 1 blocks)
	position = grid_system.grid_to_world(grid_position)
	# Set starting energy
	current_energy = starting_energy
	energy_changed.emit(current_energy, max_energy)

func _physics_process(delta):
	if current_state == State.DEAD:
		return

	# In scanning mode, only handle scan input
	if current_state == State.SCANNING:
		_handle_scanning_input()
		return

	_handle_input(delta)
	_handle_movement(delta)
	_apply_gravity(delta)
	_handle_digging(delta)
	_handle_scan_trigger()
	_handle_bomb_trigger()

	# Apply movement - this updates is_on_floor()
	move_and_slide()

	# Check landing after move_and_slide (is_on_floor is now accurate)
	_check_landing()
	_update_state()

## Handle player input
func _handle_input(delta: float):
	input_direction = 0
	
	if Input.is_action_pressed("move_left"):
		input_direction = -1
	elif Input.is_action_pressed("move_right"):
		input_direction = 1

## Handle horizontal movement - physics-based collision
func _handle_movement(delta: float):
	if current_state == State.FALLING or current_state == State.DIGGING:
		velocity.x = 0
		return

	if input_direction != 0:
		# Set velocity, let move_and_slide() handle collision
		velocity.x = input_direction * move_speed
		current_state = State.MOVING

		# Check screen bounds
		var min_x = 0.0
		var max_x = (grid_system.grid_width - 1) * grid_system.cell_size.x
		if position.x < min_x:
			position.x = min_x
			velocity.x = 0
		elif position.x > max_x:
			position.x = max_x
			velocity.x = 0
	else:
		# No input - stop immediately
		velocity.x = 0

## Apply gravity (called before move_and_slide)
func _apply_gravity(delta: float):
	# If not on floor, apply gravity
	if not is_on_floor():
		if not is_falling:
			# Start falling
			is_falling = true
			fall_start_y = position.y
			current_state = State.FALLING
			player_falling.emit(0)

		# Apply gravity
		velocity.y += gravity * delta

## Check if player has landed (called after move_and_slide)
func _check_landing():
	if is_on_floor():
		if is_falling:
			# Just landed
			var fall_distance = int((position.y - fall_start_y) / grid_system.cell_size.y)
			is_falling = false
			velocity.y = 0
			current_state = State.IDLE
			player_landed.emit(fall_distance)

			# Check fall damage
			_check_fall_damage(fall_distance)
		else:
			# On ground, keep Y velocity zero
			velocity.y = 0

## Handle digging action
func _handle_digging(delta: float):
	if dig_timer > 0:
		dig_timer -= delta
		return

	if Input.is_action_just_pressed("dig"):
		# Must hold a direction key to dig
		# Left/Right/Down + dig key = dig in that direction
		# No direction key = no digging
		var dig_pos: Vector2i
		var has_direction := false

		if Input.is_action_pressed("move_left"):
			# Dig left
			dig_pos = grid_position + Vector2i(-1, 0)
			has_direction = true
		elif Input.is_action_pressed("move_right"):
			# Dig right
			dig_pos = grid_position + Vector2i(1, 0)
			has_direction = true
		elif Input.is_action_pressed("move_down"):
			# Dig down
			dig_pos = grid_position + Vector2i(0, 1)
			has_direction = true

		if not has_direction:
			return

		var block = grid_system.get_block(dig_pos)

		if block != null and BlockType.is_breakable(block.type):
			current_state = State.DIGGING
			dig_timer = dig_cooldown
			player_digging.emit(dig_pos)

			var result = grid_system.dig_at(dig_pos)
			if result.success:
				print("Dug at (%d, %d): energy=%d" % [dig_pos.x, dig_pos.y, result.energy_gained])

			# Don't immediately set to IDLE - let animation finish via signal

## Update player state
func _update_state():
	if current_state == State.DEAD or current_state == State.SCANNING:
		return

	# Update grid position based on player center point
	# Add half cell size to get center-based grid position
	var center_pos = position + Vector2(grid_system.cell_size.x * 0.5, grid_system.cell_size.y * 0.5)
	var new_grid_pos = grid_system.world_to_grid(center_pos)

	# Clamp to valid bounds
	new_grid_pos.x = clampi(new_grid_pos.x, 0, grid_system.grid_width - 1)
	new_grid_pos.y = clampi(new_grid_pos.y, 0, grid_system.grid_height - 1)

	# Only update if actually moved to a new cell
	if new_grid_pos != grid_position:
		grid_position = new_grid_pos
		player_moved.emit(grid_position)

	# Update state based on velocity
	if current_state != State.FALLING and current_state != State.DIGGING:
		if velocity.x != 0:
			current_state = State.MOVING
		else:
			current_state = State.IDLE

	# Update animation based on state
	_update_animation()

## Update animation based on current state
func _update_animation():
	if animated_sprite == null:
		return

	match current_state:
		State.IDLE:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		State.MOVING:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
			# Flip sprite based on movement direction
			if input_direction != 0:
				animated_sprite.flip_h = (input_direction < 0)
		State.FALLING:
			if animated_sprite.animation != "fall":
				animated_sprite.play("fall")
		State.DIGGING:
			if animated_sprite.animation != "dig":
				animated_sprite.play("dig")
		State.DEAD:
			# Could add a death animation
			animated_sprite.stop()
		State.SCANNING:
			# Keep current animation during scanning
			pass

## Called when a non-looping animation finishes
func _on_animation_finished():
	if animated_sprite == null:
		return

	var anim_name = animated_sprite.animation
	# Return to IDLE after dig animation finishes
	if anim_name == "dig" and current_state == State.DIGGING:
		current_state = State.IDLE
		animated_sprite.play("idle")

## Check if player can move to position
func _can_move_to(target_pos: Vector2i) -> bool:
	# Check bounds
	if target_pos.x < 0 or target_pos.x >= grid_system.grid_width:
		return false
	if target_pos.y < 0 or target_pos.y >= grid_system.grid_height:
		return false
	
	# Check if there's a block at target position (can't move into blocks)
	var block = grid_system.get_block(target_pos)
	if block != null:
		return false
	
	return true

## Check if player has support below (based on player's feet position)
func _has_support_below() -> bool:
	# Player collision shape is centered at (16, 18) with size (24, 28)
	# So the bottom of the collision is at y = 18 + 14 = 32 (one cell height)
	# Check the grid row directly below the player's feet
	var player_center_x = position.x + grid_system.cell_size.x * 0.5
	var feet_y = position.y + grid_system.cell_size.y  # Bottom of player's cell

	# Check grid position directly below feet
	var below_pos = grid_system.world_to_grid(Vector2(player_center_x, feet_y + 1))

	# Check bounds - if below grid, no support (fall off bottom)
	if below_pos.y >= grid_system.grid_height:
		return false

	# Has support if there's a block below
	var block_below = grid_system.get_block(below_pos)
	return block_below != null

## Check fall damage
func _check_fall_damage(fall_height: int):
	if fall_height >= instant_death_height:
		_die("Fall damage")
	elif fall_height >= max_fall_damage_height:
		_take_damage(1, "Fall damage")

## Take damage
func _take_damage(amount: int, reason: String):
	current_hp -= amount
	player_damaged.emit(amount, reason)
	
	if current_hp <= 0:
		_die(reason)

## Die
func _die(reason: String):
	current_state = State.DEAD
	velocity = Vector2.ZERO
	player_died.emit(reason)
	print("Player died: %s" % reason)

## Respawn
func respawn():
	current_hp = max_hp
	current_energy = 0
	current_state = State.IDLE
	velocity = Vector2.ZERO
	is_falling = false
	energy_changed.emit(current_energy, max_energy)
	_spawn_at_start_position()

## Get current state as string
func get_state_name() -> String:
	match current_state:
		State.IDLE:
			return "Idle"
		State.MOVING:
			return "Moving"
		State.FALLING:
			return "Falling"
		State.DIGGING:
			return "Digging"
		State.SCANNING:
			return "Scanning"
		State.DEAD:
			return "Dead"
		_:
			return "Unknown"

## Called when a block lands - check if it landed on or overlaps with player
## Simple logic: if block lands at player position or directly above, push player aside and deal damage
func _on_block_landed_check_crush(landed_position: Vector2i, block_data: BlockData, fall_distance: int):
	if current_state == State.DEAD:
		return

	# Only check blocks that actually fell
	if fall_distance <= 0:
		return

	# Check if block landed in the same column as player
	if landed_position.x != grid_position.x:
		return  # Different column, no collision

	# Check if block landed at player's position or directly above (on their head)
	# Player position is where they stand, so check if block is at or above player
	if landed_position.y == grid_position.y or landed_position.y == grid_position.y - 1:
		print("Player crushed by block landing at (%d, %d), player at (%d, %d)" % [landed_position.x, landed_position.y, grid_position.x, grid_position.y])

		# FIRST push player to an adjacent empty space, THEN deal damage
		# This ensures player is moved even if the damage kills them
		_push_player_to_side()
		_take_damage(2, "Crushed by falling block")

## Push player to an adjacent empty cell when crushed by falling block
func _push_player_to_side():
	# Don't check for DEAD state here - we want to push even if about to die

	# Try to find an empty cell to the left or right
	var left_pos = Vector2i(grid_position.x - 1, grid_position.y)
	var right_pos = Vector2i(grid_position.x + 1, grid_position.y)

	var can_go_left = _can_move_to(left_pos)
	var can_go_right = _can_move_to(right_pos)

	var target_pos: Vector2i

	if can_go_left and can_go_right:
		# Both sides available, pick randomly
		if randi() % 2 == 0:
			target_pos = left_pos
		else:
			target_pos = right_pos
	elif can_go_left:
		target_pos = left_pos
	elif can_go_right:
		target_pos = right_pos
	else:
		# No space to push, player stays (might get stuck)
		print("Player has nowhere to go!")
		return

	# Move player to the new position
	grid_position = target_pos
	var world_pos = grid_system.grid_to_world(target_pos)
	position = world_pos
	print("Player pushed to (%d, %d)" % [target_pos.x, target_pos.y])

## ============== Energy System ==============

## Called when energy is gained from digging
func _on_energy_gained(amount: int):
	add_energy(amount)

## Add energy (clamped to max)
func add_energy(amount: int):
	var old_energy = current_energy
	current_energy = mini(current_energy + amount, max_energy)
	if current_energy != old_energy:
		energy_changed.emit(current_energy, max_energy)
		print("Energy: %d/%d (+%d)" % [current_energy, max_energy, current_energy - old_energy])

## Use energy (returns true if successful)
func use_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		print("Energy: %d/%d (-%d)" % [current_energy, max_energy, amount])
		return true
	return false

## Check if player has enough energy
func has_energy(amount: int) -> bool:
	return current_energy >= amount

## ============== Scanning System ==============

## Handle scan trigger (press E to enter scan mode)
func _handle_scan_trigger():
	if Input.is_action_just_pressed("scan"):
		if has_energy(scan_energy_cost):
			_enter_scan_mode()
		else:
			# Not enough energy - shake player as feedback
			_play_no_energy_feedback()
			scan_failed_no_energy.emit()
			print("Not enough energy to scan! Need %d, have %d" % [scan_energy_cost, current_energy])

## Enter scanning mode
func _enter_scan_mode():
	current_state = State.SCANNING
	# Initialize scan frame at player position
	scan_frame_position = grid_position
	# Move camera to follow scan frame
	_update_camera_for_scan_frame()
	scan_mode_entered.emit()
	print("Entered scan mode")

## Exit scanning mode
func _exit_scan_mode():
	current_state = State.IDLE
	# Reset camera to follow player (position 0,0 relative to player)
	if camera != null:
		camera.position = Vector2.ZERO
	scan_mode_exited.emit()
	print("Exited scan mode")

## Handle input while in scanning mode
func _handle_scanning_input():
	# Cancel with ESC
	if Input.is_action_just_pressed("cancel"):
		print("Cancel pressed - exiting scan mode")
		_exit_scan_mode()
		return

	# Confirm scan with E or mouse click
	if Input.is_action_just_pressed("scan") or Input.is_action_just_pressed("scan_confirm"):
		print("Scan confirmed at (%d, %d)" % [scan_frame_position.x, scan_frame_position.y])
		_perform_scan()
		return

	# Move scan frame with WASD/Arrow keys
	_update_scan_frame_position_keyboard()

## Update scan frame position using keyboard (WASD/Arrows)
func _update_scan_frame_position_keyboard():
	var moved = false
	var new_pos = scan_frame_position

	if Input.is_action_just_pressed("move_left"):
		new_pos.x -= 1
		moved = true
	elif Input.is_action_just_pressed("move_right"):
		new_pos.x += 1
		moved = true

	if Input.is_action_just_pressed("move_up"):
		new_pos.y -= 1
		moved = true
	elif Input.is_action_just_pressed("move_down"):
		new_pos.y += 1
		moved = true

	if moved:
		# Clamp to grid bounds (accounting for 3x3 frame, center-based)
		# The frame extends 1 cell in each direction from center
		new_pos.x = clampi(new_pos.x, 1, grid_system.grid_width - 2)
		new_pos.y = clampi(new_pos.y, 1, grid_system.grid_height - 2)
		scan_frame_position = new_pos
		print("Scan frame moved to (%d, %d)" % [scan_frame_position.x, scan_frame_position.y])
		# Update camera to follow scan frame
		_update_camera_for_scan_frame()

## Perform the actual scan at current frame position
func _perform_scan():
	if not use_energy(scan_energy_cost):
		_play_no_energy_feedback()
		scan_failed_no_energy.emit()
		return

	# Scan 3x3 area centered on scan_frame_position
	var scanned_count = grid_system.scan_area_3x3(scan_frame_position)
	scan_performed.emit(scan_frame_position)
	print("Scanned 3x3 area at (%d, %d), revealed %d blocks" % [scan_frame_position.x, scan_frame_position.y, scanned_count])

	# Exit scan mode after scanning
	_exit_scan_mode()

## Play feedback when player doesn't have enough energy
func _play_no_energy_feedback():
	# Shake the player sprite
	var sprite = get_node_or_null("Sprite2D")
	if sprite != null:
		var original_pos = sprite.position
		var tween = create_tween()
		tween.tween_property(sprite, "position", original_pos + Vector2(3, 0), 0.05)
		tween.tween_property(sprite, "position", original_pos + Vector2(-3, 0), 0.05)
		tween.tween_property(sprite, "position", original_pos + Vector2(2, 0), 0.05)
		tween.tween_property(sprite, "position", original_pos + Vector2(-2, 0), 0.05)
		tween.tween_property(sprite, "position", original_pos, 0.05)

## Get scan frame world position (for visualizer)
func get_scan_frame_world_position() -> Vector2:
	return grid_system.grid_to_world(scan_frame_position)

## Get scan frame grid position
func get_scan_frame_grid_position() -> Vector2i:
	return scan_frame_position

## Update camera position to center on scan frame
func _update_camera_for_scan_frame():
	if camera == null or grid_system == null:
		return

	# Calculate scan frame world position (center of 3x3 area)
	var scan_world_pos = grid_system.grid_to_world(scan_frame_position)
	# Add half cell to center the view on the scan frame center
	scan_world_pos += grid_system.cell_size * 0.5

	# Camera is a child of player, so we need to offset it relative to player position
	# Camera offset = scan_frame_world_pos - player_world_pos
	camera.position = scan_world_pos - position

## ============== Bomb System ==============

## Handle bomb trigger (press B to place bomb)
func _handle_bomb_trigger():
	if Input.is_action_just_pressed("bomb"):
		if has_energy(bomb_energy_cost):
			_place_bomb()
		else:
			_play_no_energy_feedback()
			bomb_failed_no_energy.emit()
			print("Not enough energy for bomb! Need %d, have %d" % [bomb_energy_cost, current_energy])

## Place a bomb at current position
func _place_bomb():
	if not use_energy(bomb_energy_cost):
		return

	var bomb_pos = grid_position
	bomb_placed.emit(bomb_pos)
	print("Bomb placed at (%d, %d) - explodes in %.1f seconds!" % [bomb_pos.x, bomb_pos.y, bomb_fuse_time])

	# Start fuse timer - bomb will explode after delay
	var timer = get_tree().create_timer(bomb_fuse_time)
	timer.timeout.connect(_on_bomb_explode.bind(bomb_pos))

## Called when bomb explodes
func _on_bomb_explode(bomb_pos: Vector2i):
	print("=== BOMB EXPLODING at (%d, %d) ===" % [bomb_pos.x, bomb_pos.y])
	bomb_exploded.emit(bomb_pos)

	# Check if player is in explosion range
	_check_bomb_damage(bomb_pos)

	# Explode in cross pattern
	grid_system.explode_cross(bomb_pos, bomb_range)

## Check if player is caught in bomb explosion
func _check_bomb_damage(bomb_pos: Vector2i):
	if current_state == State.DEAD:
		return

	# Check if player is at bomb position or in cross range
	var player_pos = grid_position
	var in_explosion = false

	# Check center
	if player_pos == bomb_pos:
		in_explosion = true
	else:
		# Check cross pattern
		for i in range(1, bomb_range + 1):
			if player_pos == Vector2i(bomb_pos.x - i, bomb_pos.y) or \
			   player_pos == Vector2i(bomb_pos.x + i, bomb_pos.y) or \
			   player_pos == Vector2i(bomb_pos.x, bomb_pos.y - i) or \
			   player_pos == Vector2i(bomb_pos.x, bomb_pos.y + i):
				in_explosion = true
				break

	if in_explosion:
		print("Player caught in bomb explosion!")
		_take_damage(bomb_damage, "Bomb explosion")
