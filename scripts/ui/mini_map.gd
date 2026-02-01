class_name MiniMap
extends Control

## MiniMap UI Component
## Displays an overview of the entire level with player position
## 小地图UI组件
## 显示整个关卡概览和玩家位置

@export var grid_system_path: NodePath
@export var grid_visualizer_path: NodePath
@export var player_path: NodePath

## Size configuration
@export var map_width: int = 72
@export var map_height: int = 120
@export var border_width: int = 2
@export var border_color: Color = Color(0.4, 0.4, 0.4, 0.8)
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.7)

## Player marker configuration
@export var player_marker_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var player_marker_size: float = 4.0

## References
var grid_system: GridSystem
var grid_visualizer: GridVisualizer
var player: Player

## Internal nodes
var viewport_container: SubViewportContainer
var viewport: SubViewport
var mini_camera: Camera2D
var player_marker: ColorRect
var border: ColorRect
var background: ColorRect

func _ready():
	# Resolve references
	if grid_system_path:
		grid_system = get_node(grid_system_path) as GridSystem
	if grid_visualizer_path:
		grid_visualizer = get_node(grid_visualizer_path) as GridVisualizer
	if player_path:
		player = get_node(player_path) as Player

	if grid_system == null:
		push_error("MiniMap: GridSystem not assigned!")
		return

	# Setup the minimap UI
	_setup_minimap()

func _setup_minimap():
	# Set control size
	custom_minimum_size = Vector2(map_width + border_width * 2, map_height + border_width * 2)
	size = custom_minimum_size

	# Create background
	background = ColorRect.new()
	background.name = "Background"
	background.size = Vector2(map_width + border_width * 2, map_height + border_width * 2)
	background.color = background_color
	add_child(background)

	# Create border (as 4 rects)
	_create_border()

	# Create SubViewportContainer
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.position = Vector2(border_width, border_width)
	viewport_container.size = Vector2(map_width, map_height)
	viewport_container.stretch = true
	add_child(viewport_container)

	# Create SubViewport
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = Vector2i(map_width, map_height)
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport_container.add_child(viewport)

	# Create camera for minimap
	mini_camera = Camera2D.new()
	mini_camera.name = "MiniCamera"
	viewport.add_child(mini_camera)

	# Calculate camera position and zoom to fit entire grid
	_update_camera()

	# Create player marker (on top of viewport)
	player_marker = ColorRect.new()
	player_marker.name = "PlayerMarker"
	player_marker.size = Vector2(player_marker_size, player_marker_size)
	player_marker.color = player_marker_color
	player_marker.z_index = 100
	add_child(player_marker)

	# Start player marker blinking
	_start_marker_blink()

	# Wait for grid to initialize if needed
	if grid_system.grid.is_empty():
		grid_system.grid_initialized.connect(_on_grid_initialized)
	else:
		_copy_grid_visuals()

func _create_border():
	# Top border
	var top = ColorRect.new()
	top.size = Vector2(map_width + border_width * 2, border_width)
	top.color = border_color
	add_child(top)

	# Bottom border
	var bottom = ColorRect.new()
	bottom.position = Vector2(0, map_height + border_width)
	bottom.size = Vector2(map_width + border_width * 2, border_width)
	bottom.color = border_color
	add_child(bottom)

	# Left border
	var left = ColorRect.new()
	left.position = Vector2(0, border_width)
	left.size = Vector2(border_width, map_height)
	left.color = border_color
	add_child(left)

	# Right border
	var right = ColorRect.new()
	right.position = Vector2(map_width + border_width, border_width)
	right.size = Vector2(border_width, map_height)
	right.color = border_color
	add_child(right)

func _update_camera():
	if grid_system == null or mini_camera == null:
		return

	# Calculate the grid world size
	var grid_world_width = grid_system.grid_width * grid_system.cell_size.x
	var grid_world_height = grid_system.grid_height * grid_system.cell_size.y

	# Center camera on grid
	mini_camera.position = Vector2(grid_world_width / 2, grid_world_height / 2)

	# Calculate zoom to fit entire grid in viewport
	var zoom_x = float(map_width) / grid_world_width
	var zoom_y = float(map_height) / grid_world_height
	var zoom_factor = min(zoom_x, zoom_y)

	mini_camera.zoom = Vector2(zoom_factor, zoom_factor)

func _on_grid_initialized(width: int, height: int):
	_update_camera()
	_copy_grid_visuals()

func _copy_grid_visuals():
	# We need to duplicate the grid visualizer into our viewport
	# This is tricky - instead, we'll create a simplified version
	# that just shows colored blocks

	# Clear existing children (except camera)
	for child in viewport.get_children():
		if child != mini_camera:
			child.queue_free()

	# Create a simple grid representation
	var mini_grid = Node2D.new()
	mini_grid.name = "MiniGrid"
	viewport.add_child(mini_grid)

	# Connect to grid changes to update minimap
	if not grid_system.block_changed.is_connected(_on_block_changed):
		grid_system.block_changed.connect(_on_block_changed)
	if not grid_system.block_destroyed.is_connected(_on_block_destroyed):
		grid_system.block_destroyed.connect(_on_block_destroyed)

	# Draw initial grid
	_redraw_grid(mini_grid)

func _redraw_grid(mini_grid: Node2D):
	# Clear existing
	for child in mini_grid.get_children():
		child.queue_free()

	# Draw each block
	for col in range(grid_system.grid_width):
		for row in range(grid_system.grid_height):
			var pos = Vector2i(col, row)
			var block = grid_system.get_block(pos)

			if block != null:
				_create_mini_block(mini_grid, pos, block)

func _create_mini_block(parent: Node2D, pos: Vector2i, block: BlockData):
	var block_rect = ColorRect.new()
	block_rect.name = "Block_%d_%d" % [pos.x, pos.y]
	block_rect.size = grid_system.cell_size
	block_rect.position = grid_system.grid_to_world(pos)

	# Determine color based on block type and scanned status
	var color: Color
	var is_hidden_valuable = (block.type == BlockType.Type.TREASURE or block.type == BlockType.Type.ENERGY_CRYSTAL)

	if block.is_scanned and is_hidden_valuable:
		# Scanned valuable blocks - show distinct bright colors
		if block.type == BlockType.Type.TREASURE:
			color = Color(1.0, 0.85, 0.0, 1.0)  # Bright gold
		else:
			color = Color(0.0, 1.0, 1.0, 1.0)  # Bright cyan
	elif is_hidden_valuable:
		# Hidden (not scanned) treasure/crystal - disguise as soft dirt
		color = Color(0.5, 0.35, 0.2, 0.8)  # Same as soft dirt
	else:
		# Normal block colors
		match block.type:
			BlockType.Type.SOFT_DIRT:
				color = Color(0.5, 0.35, 0.2, 0.8)
			BlockType.Type.HARD_STONE:
				color = Color(0.45, 0.45, 0.5, 0.8)
			BlockType.Type.UNBREAKABLE:
				color = Color(0.2, 0.15, 0.25, 1.0)
			_:
				color = Color(0.5, 0.5, 0.5, 0.8)

	block_rect.color = color
	parent.add_child(block_rect)

func _on_block_changed(pos: Vector2i, block_data: BlockData):
	# Update the specific block in minimap
	var mini_grid = viewport.get_node_or_null("MiniGrid")
	if mini_grid == null:
		return

	# Find and remove old block
	var old_block = mini_grid.get_node_or_null("Block_%d_%d" % [pos.x, pos.y])
	if old_block != null:
		old_block.queue_free()

	# Create new block if exists
	if block_data != null:
		_create_mini_block(mini_grid, pos, block_data)

func _on_block_destroyed(pos: Vector2i, block_type: BlockType.Type):
	# Remove the block from minimap when destroyed
	var mini_grid = viewport.get_node_or_null("MiniGrid")
	if mini_grid == null:
		return

	var old_block = mini_grid.get_node_or_null("Block_%d_%d" % [pos.x, pos.y])
	if old_block != null:
		old_block.queue_free()

func _process(delta: float):
	_update_player_marker()

func _update_player_marker():
	if player == null or player_marker == null or grid_system == null:
		return

	# Calculate player position on minimap
	var player_grid_pos = player.grid_position
	var player_world_pos = grid_system.grid_to_world(player_grid_pos)

	# Calculate grid world size
	var grid_world_width = grid_system.grid_width * grid_system.cell_size.x
	var grid_world_height = grid_system.grid_height * grid_system.cell_size.y

	# Convert to minimap coordinates
	var map_x = (player_world_pos.x / grid_world_width) * map_width + border_width
	var map_y = (player_world_pos.y / grid_world_height) * map_height + border_width

	# Center the marker
	player_marker.position = Vector2(
		map_x + grid_system.cell_size.x / grid_world_width * map_width / 2 - player_marker_size / 2,
		map_y + grid_system.cell_size.y / grid_world_height * map_height / 2 - player_marker_size / 2
	)

func _start_marker_blink():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(player_marker, "modulate:a", 0.3, 0.4)
	tween.tween_property(player_marker, "modulate:a", 1.0, 0.4)
