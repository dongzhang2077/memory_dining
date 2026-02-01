class_name GridVisualizer
extends Node2D

## Visualizes the grid system
## Handles rendering of blocks and visual effects
## 可视化网格系统
## 处理方块渲染和视觉效果

@export var grid_system_path: NodePath
@export var block_scene: PackedScene
@export var cell_size: Vector2 = Vector2(32, 32)

## Grid system reference (resolved from path)
var grid_system: GridSystem

## Dictionary mapping grid positions to block nodes
var block_nodes: Dictionary = {}

## Block sprite colors for different types
var block_colors = {
	BlockType.Type.SOFT_DIRT: Color(0.6, 0.4, 0.2),      # Brown
	BlockType.Type.HARD_STONE: Color(0.5, 0.5, 0.55),    # Gray
	BlockType.Type.UNBREAKABLE: Color(0.15, 0.1, 0.2),   # Dark Purple - clearly different
	BlockType.Type.TREASURE: Color(1.0, 0.8, 0.0),       # Gold
	BlockType.Type.ENERGY_CRYSTAL: Color(0.0, 0.8, 1.0)  # Cyan
}

## Block sprite textures (can be loaded from resources)
var block_textures: Dictionary = {}

## Initialize with grid system
func _ready():
	# Resolve grid system from path
	if grid_system_path:
		grid_system = get_node(grid_system_path) as GridSystem

	if grid_system == null:
		push_error("GridVisualizer: GridSystem not assigned!")
		return
	
	# Connect to grid system signals
	grid_system.grid_initialized.connect(_on_grid_initialized)
	grid_system.block_changed.connect(_on_block_changed)
	grid_system.block_destroyed.connect(_on_block_destroyed)
	grid_system.block_damaged.connect(_on_block_damaged)
	grid_system.treasure_revealed.connect(_on_treasure_revealed)
	grid_system.block_falling.connect(_on_block_falling)
	grid_system.block_landed.connect(_on_block_landed)
	grid_system.treasure_broken.connect(_on_treasure_broken)

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

	# Create sprite (ColorRect for now, can be replaced with Sprite2D later)
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = cell_size

	# Set color based on block type
	var color = block_colors.get(block_data.type, Color.WHITE)
	sprite.color = color

	# Adjust visibility based on block data
	if not block_data.is_visible:
		sprite.modulate.a = 0.0  # Invisible
		# Also disable collision for invisible blocks
		collision.disabled = true
	elif block_data.is_scanned and (block_data.type == BlockType.Type.TREASURE or block_data.type == BlockType.Type.ENERGY_CRYSTAL):
		# Add sparkle effect for scanned hidden blocks
		sprite.modulate.a = 0.7  # Semi-transparent
		_add_sparkle_effect(sprite)

	block_node.add_child(sprite)

	# Position the node at grid position (top-left corner)
	var world_pos = grid_system.grid_to_world(block_data.grid_position)
	block_node.position = world_pos

	add_child(block_node)
	block_nodes[block_data.grid_position] = block_node

	return block_node

## Add sparkle effect to a sprite
func _add_sparkle_effect(sprite: ColorRect):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.5, 0.5)

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
			# Flash effect
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", block_colors.get(grid_system.get_block(position).type, Color.WHITE), 0.1)

## Called when a treasure is revealed
func _on_treasure_revealed(position: Vector2i, treasure_data: TreasureData):
	# Create treasure collection effect
	_create_treasure_effect(position, treasure_data)

## Create destruction effect
func _create_destruction_effect(position: Vector2i, block_type: BlockType.Type):
	var world_pos = grid_system.grid_to_world(position)
	
	# Create particles
	var particles = CPUParticles2D.new()
	particles.name = "DestructionParticles"
	particles.position = world_pos
	particles.emitting = true
	particles.amount = 10
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	
	# Set particle color
	var color = block_colors.get(block_type, Color.WHITE)
	particles.color = color
	
	add_child(particles)
	
	# Auto-remove after animation
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

	# Animate the fall
	var tween = create_tween()
	tween.tween_property(node, "position", to_world, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## Called when a block lands after falling
func _on_block_landed(position: Vector2i, block_data: BlockData, fall_distance: int):
	var node = block_nodes.get(position)
	if node == null:
		return

	# Landing shake effect
	var sprite = node.get_node_or_null("Sprite")
	if sprite != null and fall_distance > 0:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.05)
		tween.tween_property(sprite, "scale", Vector2(0.95, 1.05), 0.05)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

	# Create dust particles on landing
	if fall_distance > 0:
		_create_landing_dust(position)

## Called when a treasure breaks from falling
func _on_treasure_broken(position: Vector2i, treasure_data: TreasureData):
	var node = block_nodes.get(position)
	if node != null:
		var sprite = node.get_node_or_null("Sprite")
		if sprite != null:
			# Change color to gray (broken)
			sprite.color = Color(0.3, 0.3, 0.3)

	# Create breaking effect
	_create_treasure_break_effect(position)
	print("Treasure broken at (%d, %d): %s" % [position.x, position.y, treasure_data.name])

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
