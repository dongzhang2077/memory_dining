class_name GridVisualizer
extends Node2D

## Visualizes the grid system
## Handles rendering of blocks and visual effects
## 可视化网格系统
## 处理方块渲染和视觉效果

@export var grid_system_path: NodePath
@export var player_path: NodePath
@export var block_scene: PackedScene
@export var cell_size: Vector2 = Vector2(32, 32)

## Grid system reference (resolved from path)
var grid_system: GridSystem

## Player reference (for scan frame)
var player: Player

## Dictionary mapping grid positions to block nodes
var block_nodes: Dictionary = {}

## Scan frame visual
var scan_frame: Node2D = null
var scan_frame_visible: bool = false

## Block sprite colors for different types (fallback if no texture)
var block_colors = {
	BlockType.Type.SOFT_DIRT: Color(0.6, 0.4, 0.2),      # Brown
	BlockType.Type.HARD_STONE: Color(0.5, 0.5, 0.55),    # Gray
	BlockType.Type.UNBREAKABLE: Color(0.15, 0.1, 0.2),   # Dark Purple - clearly different
	BlockType.Type.TREASURE: Color(1.0, 0.8, 0.0),       # Gold
	BlockType.Type.ENERGY_CRYSTAL: Color(0.0, 0.8, 1.0)  # Cyan
}

## Block sprite textures
var block_textures: Dictionary = {}

## Explosion animation resource
var explosion_frames: SpriteFrames = null

## Load block textures from assets
func _load_block_textures():
	block_textures[BlockType.Type.SOFT_DIRT] = load("res://assets/sprites/blocks/soft_dirt.png")
	block_textures[BlockType.Type.HARD_STONE] = load("res://assets/sprites/blocks/hard_stone.png")
	block_textures[BlockType.Type.UNBREAKABLE] = load("res://assets/sprites/blocks/unbreakable.png")
	block_textures[BlockType.Type.TREASURE] = load("res://assets/sprites/blocks/treasure.png")
	block_textures[BlockType.Type.ENERGY_CRYSTAL] = load("res://assets/sprites/blocks/energy_crystal.png")
	# Load explosion animation
	explosion_frames = load("res://assets/sprites/player/explosion/explotion.tres")
	print("Block textures loaded")

## Initialize with grid system
func _ready():
	# Load block textures
	_load_block_textures()

	# Resolve grid system from path
	if grid_system_path:
		grid_system = get_node(grid_system_path) as GridSystem

	if grid_system == null:
		push_error("GridVisualizer: GridSystem not assigned!")
		return

	# Resolve player from path
	if player_path:
		player = get_node(player_path) as Player
		if player != null:
			player.scan_mode_entered.connect(_on_scan_mode_entered)
			player.scan_mode_exited.connect(_on_scan_mode_exited)

	# Connect to grid system signals
	grid_system.grid_initialized.connect(_on_grid_initialized)
	grid_system.block_changed.connect(_on_block_changed)
	grid_system.block_destroyed.connect(_on_block_destroyed)
	grid_system.block_damaged.connect(_on_block_damaged)
	grid_system.treasure_revealed.connect(_on_treasure_revealed)
	grid_system.block_falling.connect(_on_block_falling)
	grid_system.block_landed.connect(_on_block_landed)
	grid_system.treasure_broken.connect(_on_treasure_broken)
	grid_system.bomb_explosion.connect(_on_bomb_explosion)

	# Connect to player bomb signal if player exists
	if player != null:
		player.bomb_placed.connect(_on_bomb_placed)

	# Create scan frame visual
	_create_scan_frame()

	# Initialize if grid is already initialized
	if grid_system.grid.size() > 0:
		_rebuild_visuals()

## Called when grid is initialized
func _on_grid_initialized(width: int, height: int):
	_rebuild_visuals()

## Rebuild all visuals from grid data
func _rebuild_visuals():
	# Clear existing nodes
	for node in block_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	block_nodes.clear()
	
	# Create new nodes
	for col in range(grid_system.grid_width):
		for row in range(grid_system.grid_height):
			var pos = Vector2i(col, row)
			var block_data = grid_system.get_block(pos)
			
			if block_data != null:
				_create_block_visual(block_data)

## Create visual node for a block with collision
func _create_block_visual(block_data: BlockData) -> StaticBody2D:
	# Create StaticBody2D as the root for physics collision
	var block_node = StaticBody2D.new()
	block_node.name = "Block_%d_%d" % [block_data.grid_position.x, block_data.grid_position.y]

	# Set collision layer (layer 1) and mask
	block_node.collision_layer = 1
	block_node.collision_mask = 1

	# Create collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape"
	var shape = RectangleShape2D.new()
	shape.size = cell_size
	collision.shape = shape
	# Position collision shape so its center is at the cell center
	# This means the top of the collision is at y=0 (top of cell)
	collision.position = cell_size / 2
	block_node.add_child(collision)

	# Determine which texture to use based on block type and scanned status
	var is_hidden_valuable = (block_data.type == BlockType.Type.TREASURE or block_data.type == BlockType.Type.ENERGY_CRYSTAL)
	var display_type = block_data.type

	if is_hidden_valuable and not block_data.is_scanned:
		# Hidden treasure/crystal - disguise as soft dirt
		display_type = BlockType.Type.SOFT_DIRT

	# Create sprite with texture
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false  # Position from top-left corner

	# Try to use texture, fallback to ColorRect if not available
	var texture: Texture2D = null

	# For scanned treasure blocks, use the unique treasure sprite
	if block_data.is_scanned and block_data.type == BlockType.Type.TREASURE and block_data.treasure_data != null:
		if block_data.treasure_data.sprite_path != "":
			texture = load(block_data.treasure_data.sprite_path)

	# Fallback to default block texture
	if texture == null:
		texture = block_textures.get(display_type)

	if texture != null:
		sprite.texture = texture
		# Scale sprite to fit cell size
		var tex_size = texture.get_size()
		sprite.scale = cell_size / tex_size
	else:
		# Fallback: create a colored placeholder
		push_warning("No texture for block type: %s" % display_type)

	# Adjust visibility based on block data
	if not block_data.is_visible:
		sprite.modulate.a = 0.0  # Invisible
		# Also disable collision for invisible blocks
		collision.disabled = true
	elif block_data.is_scanned and is_hidden_valuable:
		# Scanned blocks: show with distinct border and pulsing effect
		_add_scanned_effect(block_node, sprite, block_data.type)

	block_node.add_child(sprite)

	# Position the node at grid position (top-left corner)
	var world_pos = grid_system.grid_to_world(block_data.grid_position)
	block_node.position = world_pos

	add_child(block_node)
	block_nodes[block_data.grid_position] = block_node

	return block_node

## Add sparkle effect to a sprite (legacy, kept for compatibility)
func _add_sparkle_effect(sprite: Node2D):
	var tween = sprite.create_tween()  # Bind to sprite so tween stops when sprite is freed
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.5, 0.5)

## Add scanned effect with distinct border for treasure/energy crystal
func _add_scanned_effect(block_node: Node2D, sprite: Node2D, block_type: BlockType.Type):
	# Set sprite to semi-transparent with slight desaturation
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)

	# Create a distinct colored border based on block type
	var border_color: Color
	var inner_glow_color: Color
	if block_type == BlockType.Type.TREASURE:
		border_color = Color(1.0, 0.85, 0.0, 1.0)  # Bright gold
		inner_glow_color = Color(1.0, 0.9, 0.3, 0.4)  # Soft gold glow
	else:  # ENERGY_CRYSTAL
		border_color = Color(0.0, 1.0, 1.0, 1.0)  # Bright cyan
		inner_glow_color = Color(0.3, 1.0, 1.0, 0.4)  # Soft cyan glow

	# Create border using 4 lines
	var border_width = 3.0
	var border_node = Node2D.new()
	border_node.name = "ScannedBorder"
	border_node.z_index = 5  # Above sprite

	# Top line
	var top = Line2D.new()
	top.points = [Vector2(0, 0), Vector2(cell_size.x, 0)]
	top.width = border_width
	top.default_color = border_color
	border_node.add_child(top)

	# Bottom line
	var bottom = Line2D.new()
	bottom.points = [Vector2(0, cell_size.y), Vector2(cell_size.x, cell_size.y)]
	bottom.width = border_width
	bottom.default_color = border_color
	border_node.add_child(bottom)

	# Left line
	var left = Line2D.new()
	left.points = [Vector2(0, 0), Vector2(0, cell_size.y)]
	left.width = border_width
	left.default_color = border_color
	border_node.add_child(left)

	# Right line
	var right = Line2D.new()
	right.points = [Vector2(cell_size.x, 0), Vector2(cell_size.x, cell_size.y)]
	right.width = border_width
	right.default_color = border_color
	border_node.add_child(right)

	block_node.add_child(border_node)

	# Add inner glow effect (semi-transparent overlay)
	var glow = ColorRect.new()
	glow.name = "InnerGlow"
	glow.size = cell_size - Vector2(4, 4)
	glow.position = Vector2(2, 2)
	glow.color = inner_glow_color
	glow.z_index = 1
	block_node.add_child(glow)

	# Pulsing animation on the border - bind to block_node so tween stops when node is freed
	var tween = block_node.create_tween()
	tween.set_loops()
	tween.tween_property(border_node, "modulate:a", 0.4, 0.6)
	tween.tween_property(border_node, "modulate:a", 1.0, 0.6)

	# Also pulse the inner glow - bind to block_node
	var glow_tween = block_node.create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "modulate:a", 0.2, 0.8)
	glow_tween.tween_property(glow, "modulate:a", 0.8, 0.8)

	# Add sparkle particles for treasure
	_add_sparkle_particles(block_node, block_type)

## Add sparkle particle effect for scanned treasures
func _add_sparkle_particles(block_node: Node2D, block_type: BlockType.Type):
	var particles = CPUParticles2D.new()
	particles.name = "SparkleParticles"
	particles.position = cell_size / 2  # Center of block
	particles.z_index = 10

	# Configure particle emission
	particles.emitting = true
	particles.amount = 6
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.5

	# Emission shape - small area around center
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = cell_size * 0.3

	# Particle movement - float upward slowly
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, -10)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 15.0

	# Particle size - small sparkles
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0

	# Color based on block type
	if block_type == BlockType.Type.TREASURE:
		particles.color = Color(1.0, 0.9, 0.3, 0.9)  # Gold sparkles
	else:  # ENERGY_CRYSTAL
		particles.color = Color(0.5, 1.0, 1.0, 0.9)  # Cyan sparkles

	# Fade out
	var color_ramp = Gradient.new()
	color_ramp.set_offset(0, 0.0)
	color_ramp.set_color(0, Color(1, 1, 1, 1))
	color_ramp.set_offset(1, 1.0)
	color_ramp.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = color_ramp

	block_node.add_child(particles)

## Called when a block changes
func _on_block_changed(position: Vector2i, block_data: BlockData):
	# Remove old node if exists
	if block_nodes.has(position):
		var old_node = block_nodes[position]
		if is_instance_valid(old_node):
			old_node.queue_free()
		block_nodes.erase(position)
	
	# Create new node if block exists
	if block_data != null:
		_create_block_visual(block_data)

## Called when a block is destroyed
func _on_block_destroyed(position: Vector2i, block_type: BlockType.Type):
	# Visual effect for destruction
	_create_destruction_effect(position, block_type)

## Called when a block is damaged
func _on_block_damaged(position: Vector2i, remaining_hits: int):
	var node = block_nodes.get(position)
	if node != null:
		var sprite = node.get_node("Sprite")
		if sprite != null:
			# Flash effect - flash red then back to white (texture handles color)
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

## Called when a treasure is revealed
func _on_treasure_revealed(position: Vector2i, treasure_data: TreasureData):
	# Create treasure collection effect
	_create_treasure_effect(position, treasure_data)

## Create destruction effect using explosion animation
func _create_destruction_effect(position: Vector2i, block_type: BlockType.Type):
	var world_pos = grid_system.grid_to_world(position)

	# Create animated sprite for explosion
	if explosion_frames != null:
		var explosion_sprite = AnimatedSprite2D.new()
		explosion_sprite.name = "ExplosionEffect"
		explosion_sprite.sprite_frames = explosion_frames
		explosion_sprite.centered = true  # Center the sprite

		# Position at block center (world_pos is top-left, add half cell to center)
		explosion_sprite.position = world_pos + cell_size / 2

		# Get actual texture size from first frame and scale to match cell size
		var first_frame = explosion_frames.get_frame_texture("explosion", 0)
		if first_frame != null:
			var tex_size = first_frame.get_size()
			explosion_sprite.scale = cell_size / tex_size

		explosion_sprite.z_index = 20  # Above blocks

		add_child(explosion_sprite)
		explosion_sprite.play("explosion")

		# Connect to animation_finished to auto-remove
		explosion_sprite.animation_finished.connect(func(): explosion_sprite.queue_free())
	else:
		# Fallback to particle effect if explosion animation not loaded
		var particles = CPUParticles2D.new()
		particles.name = "DestructionParticles"
		particles.position = world_pos + cell_size / 2
		particles.emitting = true
		particles.amount = 10
		particles.lifetime = 0.5
		particles.explosiveness = 0.8

		var color = block_colors.get(block_type, Color.WHITE)
		particles.color = color

		add_child(particles)

		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(particles):
			particles.queue_free()

## Create treasure collection effect
func _create_treasure_effect(position: Vector2i, treasure_data: TreasureData):
	var world_pos = grid_system.grid_to_world(position)
	
	# Create sparkle particles
	var particles = CPUParticles2D.new()
	particles.name = "TreasureParticles"
	particles.position = world_pos
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 1.0
	particles.explosiveness = 0.5
	
	# Gold color for treasure
	particles.color = Color.GOLD
	
	add_child(particles)
	
	# Auto-remove after animation
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Called when a block starts falling
func _on_block_falling(from_position: Vector2i, to_position: Vector2i, block_data: BlockData):
	var node = block_nodes.get(from_position)
	if node == null:
		return

	# Update dictionary key
	block_nodes.erase(from_position)
	block_nodes[to_position] = node

	# Calculate fall animation
	var from_world = grid_system.grid_to_world(from_position)
	var to_world = grid_system.grid_to_world(to_position)
	var fall_distance = to_position.y - from_position.y
	var fall_duration = 0.1 + (fall_distance * 0.05)  # Faster fall for longer distances

	# Create falling dust particles at the start position
	_create_falling_dust(from_position)

	# Start shake effect before falling
	_shake_block_before_fall(node, fall_duration)

	# Animate the fall
	var tween = create_tween()
	tween.tween_property(node, "position", to_world, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## Called when a block lands after falling
func _on_block_landed(position: Vector2i, block_data: BlockData, fall_distance: int):
	var node = block_nodes.get(position)
	if node == null:
		return

	# Landing shake effect - use the block_node instead of sprite to avoid scale issues
	if fall_distance > 0:
		var original_scale = node.scale
		var tween = create_tween()
		tween.tween_property(node, "scale", original_scale * Vector2(1.1, 0.9), 0.05)
		tween.tween_property(node, "scale", original_scale * Vector2(0.95, 1.05), 0.05)
		tween.tween_property(node, "scale", original_scale, 0.05)

	# Create dust particles on landing
	if fall_distance > 0:
		_create_landing_dust(position)

## Called when a treasure breaks from falling
func _on_treasure_broken(position: Vector2i, treasure_data: TreasureData):
	var node = block_nodes.get(position)
	if node != null:
		var sprite = node.get_node_or_null("Sprite")
		if sprite != null:
			# Change to grayscale using modulate (works with Sprite2D)
			sprite.modulate = Color(0.3, 0.3, 0.3)

	# Create breaking effect
	_create_treasure_break_effect(position)
	print("Treasure broken at (%d, %d): %s" % [position.x, position.y, treasure_data.name])

## Shake block before it falls
func _shake_block_before_fall(node: Node2D, fall_duration: float):
	var original_pos = node.position
	var shake_tween = create_tween()
	var shake_amount = 1.5

	# Quick shake before falling (3 shakes in 0.1s)
	shake_tween.tween_property(node, "position", original_pos + Vector2(shake_amount, 0), 0.017)
	shake_tween.tween_property(node, "position", original_pos + Vector2(-shake_amount, 0), 0.017)
	shake_tween.tween_property(node, "position", original_pos + Vector2(shake_amount * 0.5, 0), 0.017)
	shake_tween.tween_property(node, "position", original_pos + Vector2(-shake_amount * 0.5, 0), 0.017)
	shake_tween.tween_property(node, "position", original_pos, 0.017)

## Create dust particles when block starts falling
func _create_falling_dust(position: Vector2i):
	var world_pos = grid_system.grid_to_world(position)
	# Particles come from bottom edges of the block
	world_pos.y += cell_size.y

	var particles = CPUParticles2D.new()
	particles.name = "FallingDust"
	particles.position = world_pos + Vector2(cell_size.x / 2, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 4
	particles.lifetime = 0.25
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, 1)  # Fall downward
	particles.spread = 45
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 25
	particles.gravity = Vector2(0, 150)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(0.6, 0.5, 0.4, 0.5)  # Light brown dust

	add_child(particles)

	# Auto-remove after particles fade
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Create dust particles when block lands
func _create_landing_dust(position: Vector2i):
	var world_pos = grid_system.grid_to_world(position)
	world_pos.y += cell_size.y  # Bottom of block

	var particles = CPUParticles2D.new()
	particles.name = "LandingDust"
	particles.position = world_pos + Vector2(cell_size.x / 2, 0)
	particles.emitting = true
	particles.amount = 6
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 60
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 40
	particles.gravity = Vector2(0, 100)
	particles.color = Color(0.5, 0.4, 0.3, 0.7)

	add_child(particles)

	# Auto-remove
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Create effect when treasure breaks
func _create_treasure_break_effect(position: Vector2i):
	var world_pos = grid_system.grid_to_world(position)

	var particles = CPUParticles2D.new()
	particles.name = "TreasureBreak"
	particles.position = world_pos + cell_size / 2
	particles.emitting = true
	particles.amount = 15
	particles.lifetime = 0.6
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 60
	particles.gravity = Vector2(0, 200)
	particles.color = Color(0.5, 0.5, 0.5)  # Gray for broken

	add_child(particles)

	# Auto-remove
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Update block visual at position
func update_block_visual(position: Vector2i):
	var block_data = grid_system.get_block(position)
	_on_block_changed(position, block_data)

## Get block node at position
func get_block_node(position: Vector2i) -> Node2D:
	return block_nodes.get(position)

## Clear all visuals
func clear_visuals():
	for node in block_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	block_nodes.clear()

## ============== Scan Frame Visual ==============

## Create the scan frame visual (3x3 green border)
func _create_scan_frame():
	scan_frame = Node2D.new()
	scan_frame.name = "ScanFrame"
	scan_frame.z_index = 20  # Above blocks and player
	scan_frame.visible = false

	# Create 4 lines for the border (top, bottom, left, right)
	var frame_size = cell_size * 3  # 3x3 cells
	var border_width = 2.0
	var border_color = Color(0.0, 1.0, 0.0, 0.8)  # Green with slight transparency

	# Top line
	var top_line = Line2D.new()
	top_line.name = "TopLine"
	top_line.points = [Vector2(0, 0), Vector2(frame_size.x, 0)]
	top_line.width = border_width
	top_line.default_color = border_color
	scan_frame.add_child(top_line)

	# Bottom line
	var bottom_line = Line2D.new()
	bottom_line.name = "BottomLine"
	bottom_line.points = [Vector2(0, frame_size.y), Vector2(frame_size.x, frame_size.y)]
	bottom_line.width = border_width
	bottom_line.default_color = border_color
	scan_frame.add_child(bottom_line)

	# Left line
	var left_line = Line2D.new()
	left_line.name = "LeftLine"
	left_line.points = [Vector2(0, 0), Vector2(0, frame_size.y)]
	left_line.width = border_width
	left_line.default_color = border_color
	scan_frame.add_child(left_line)

	# Right line
	var right_line = Line2D.new()
	right_line.name = "RightLine"
	right_line.points = [Vector2(frame_size.x, 0), Vector2(frame_size.x, frame_size.y)]
	right_line.width = border_width
	right_line.default_color = border_color
	scan_frame.add_child(right_line)

	add_child(scan_frame)

## Called when player enters scan mode
func _on_scan_mode_entered():
	scan_frame_visible = true
	scan_frame.visible = true

## Called when player exits scan mode
func _on_scan_mode_exited():
	scan_frame_visible = false
	scan_frame.visible = false

## Update scan frame position (called from _process)
func _process(delta: float):
	if scan_frame_visible and player != null:
		_update_scan_frame_position()

## Update the scan frame position to follow player's scan position
func _update_scan_frame_position():
	if player == null or scan_frame == null:
		return

	var scan_center = player.get_scan_frame_grid_position()
	# Convert center to top-left corner (center - 1 in each direction)
	var top_left = Vector2i(scan_center.x - 1, scan_center.y - 1)
	var world_pos = grid_system.grid_to_world(top_left)
	scan_frame.position = world_pos

## Show scan frame
func show_scan_frame():
	scan_frame_visible = true
	scan_frame.visible = true

## Hide scan frame
func hide_scan_frame():
	scan_frame_visible = false
	scan_frame.visible = false

## ============== Bomb Visual ==============

## Called when a bomb is placed
func _on_bomb_placed(bomb_pos: Vector2i):
	_create_bomb_visual(bomb_pos)

## Create bomb visual at position
func _create_bomb_visual(bomb_pos: Vector2i):
	var bomb_node = Node2D.new()
	bomb_node.name = "Bomb_%d_%d" % [bomb_pos.x, bomb_pos.y]
	bomb_node.z_index = 15  # Above blocks, below player

	# Create bomb sprite (simple red circle)
	var bomb_sprite = ColorRect.new()
	bomb_sprite.name = "BombSprite"
	bomb_sprite.size = cell_size * 0.8
	bomb_sprite.position = cell_size * 0.1  # Center it
	bomb_sprite.color = Color(0.8, 0.1, 0.1)  # Red

	bomb_node.add_child(bomb_sprite)

	# Position at grid location
	bomb_node.position = grid_system.grid_to_world(bomb_pos)

	add_child(bomb_node)

	# Blinking animation before explosion
	var tween = create_tween()
	tween.set_loops(5)  # Blink 5 times in 1 second
	tween.tween_property(bomb_sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(bomb_sprite, "modulate:a", 1.0, 0.1)

	# Remove bomb visual when it explodes (after fuse time)
	# The bomb will be removed by _on_bomb_explosion
	bomb_node.set_meta("bomb_pos", bomb_pos)

## Called when bomb explodes
func _on_bomb_explosion(center: Vector2i, affected_positions: Array):
	# Remove bomb visual
	for child in get_children():
		if child.name.begins_with("Bomb_"):
			if child.has_meta("bomb_pos") and child.get_meta("bomb_pos") == center:
				child.queue_free()
				break

	# Create explosion effect at center and affected positions
	_create_explosion_effect(center)
	for pos in affected_positions:
		if pos != center:
			_create_explosion_effect(pos)

## Create explosion visual effect
func _create_explosion_effect(pos: Vector2i):
	var world_pos = grid_system.grid_to_world(pos)

	# Create explosion particles
	var particles = CPUParticles2D.new()
	particles.name = "ExplosionParticles"
	particles.position = world_pos + cell_size / 2
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.gravity = Vector2(0, 200)
	particles.color = Color(1.0, 0.5, 0.0)  # Orange

	add_child(particles)

	# Also create a flash
	var flash = ColorRect.new()
	flash.size = cell_size
	flash.position = world_pos
	flash.color = Color(1.0, 1.0, 0.5, 0.8)  # Yellow-white flash
	flash.z_index = 25
	add_child(flash)

	# Fade out flash
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

	# Auto-remove particles
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()
