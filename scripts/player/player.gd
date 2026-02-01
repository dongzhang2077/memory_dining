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

## Player state enum
enum State {
	IDLE,       # Standing still
	MOVING,     # Moving horizontally
	FALLING,    # Falling due to no support
	DIGGING,    # Digging a block
	DEAD        # Player is dead
}

## Player properties
@export var grid_system_path: NodePath
@export var move_speed: float = 100.0
@export var gravity: float = 500.0
@export var max_fall_damage_height: int = 3  # 3+ blocks = 1 HP damage
@export var instant_death_height: int = 5     # 5+ blocks = instant death

## Grid system reference (resolved from path)
var grid_system: GridSystem

## Player stats
var current_hp: int = 3
var max_hp: int = 3
var current_state: State = State.IDLE
var grid_position: Vector2i = Vector2i.ZERO

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

		# Connect to block falling signal for crush damage
		grid_system.block_falling.connect(_on_block_falling_check_crush)

func _on_grid_initialized(width: int, height: int):
	_spawn_at_start_position()

func _spawn_at_start_position():
	# Spawn at center of top row (row 0 is empty for player)
	# Player's grid_position is the cell they occupy
	grid_position = Vector2i(grid_system.grid_width / 2, 0)
	# Position player so their feet are at the bottom of row 0 (top of row 1 blocks)
	position = grid_system.grid_to_world(grid_position)

func _physics_process(delta):
	if current_state == State.DEAD:
		return

	_handle_input(delta)
	_handle_movement(delta)
	_apply_gravity(delta)
	_handle_digging(delta)

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

			current_state = State.IDLE

## Update player state
func _update_state():
	if current_state == State.DEAD:
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
	current_state = State.IDLE
	velocity = Vector2.ZERO
	is_falling = false
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
		State.DEAD:
			return "Dead"
		_:
			return "Unknown"

## Called when a block starts falling - check if it will crush the player
## Simple logic: only the first block landing directly on player's head causes damage
func _on_block_falling_check_crush(from_position: Vector2i, to_position: Vector2i, block_data: BlockData):
	if current_state == State.DEAD:
		return

	# Check if block is in the same column as player
	if from_position.x != grid_position.x:
		return  # Different column, no collision

	# Only damage if block lands exactly one cell above player (on their head)
	# This means there was empty space above player, and this is the first block falling onto them
	var player_head_y = grid_position.y - 1  # One cell above player

	if to_position.y == player_head_y:
		_take_damage(2, "Crushed by falling block")
		print("Player crushed by falling block at (%d, %d)" % [to_position.x, to_position.y])

		# Push player to an adjacent empty space
		_push_player_to_side()

## Push player to an adjacent empty cell when crushed by falling block
func _push_player_to_side():
	if current_state == State.DEAD:
		return

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
