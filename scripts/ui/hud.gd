class_name HUD
extends Control

## 游戏HUD - 显示血量、能量和宝藏收集进度
## Game HUD - Displays health, energy, and treasure collection progress
## 布局: 左上角 - 红心 + 宝藏槽位, 左下角 - 能量

## Node paths for connecting to game systems
@export var player_path: NodePath
@export var grid_system_path: NodePath

## UI Configuration - Separate size control for each icon type
@export var heart_icon_size: float = 40.0  # Heart icon size
@export var energy_icon_size: float = 225.0  # Energy icon size
@export var treasure_icon_size: float = 40.0  # Treasure slot icon size
@export var heart_spacing: float = 1.0  # Spacing between hearts
@export var treasure_spacing: float = 1.0  # Spacing between treasure slots
@export var margin: float = 3.0  # Screen margin
@export var panel_padding: float = 6.0  # Padding inside background panels
@export var panel_color: Color = Color(0.0, 0.0, 0.0, 0.5)  # Semi-transparent black background

## Treasure celebration settings
@export var celebration_duration: float = 2.0  # Total celebration time
@export var treasure_zoom_size: float = 200.0  # Size of treasure when zoomed to center
@export var camera_shake_intensity: float = 5.0  # Camera shake strength
@export var particle_count: int = 30  # Gold particles count

## References
var player: Player
var grid_system: GridSystem

## UI Textures
var heart_texture: Texture2D
var energy_textures: Array[Texture2D] = []  # 4 states: empty, 1/3, 2/3, full
var question_treasure_texture: Texture2D
var collected_treasure_texture: Texture2D

## UI Nodes - Top Left
var top_left_container: VBoxContainer
var health_panel: PanelContainer
var health_container: HBoxContainer
var treasure_panel: PanelContainer
var treasure_container: HBoxContainer

## UI Nodes - Bottom Left
var energy_sprite: TextureRect

## State tracking
var max_hp: int = 3
var current_hp: int = 3
var max_energy: int = 30
var current_energy: int = 0
var total_treasures: int = 0
var collected_treasures: int = 0
var treasure_slots: Array[TextureRect] = []
var collected_treasure_textures: Array[Texture2D] = []  # Store actual treasure textures when collected

## Celebration state
var is_celebrating: bool = false
var celebration_overlay: ColorRect = null
var celebration_treasure_sprite: TextureRect = null
var celebration_particles: CPUParticles2D = null
var player_camera: Camera2D = null

func _ready():
	_load_textures()
	_setup_ui()

	# Resolve references
	if player_path:
		player = get_node(player_path) as Player
	if grid_system_path:
		grid_system = get_node(grid_system_path) as GridSystem

	# Connect to player signals
	if player != null:
		player.energy_changed.connect(_on_energy_changed)
		player.player_damaged.connect(_on_player_damaged)
		player.player_died.connect(_on_player_died)
		player.player_respawned.connect(_on_player_respawned)
		max_hp = player.max_hp
		current_hp = player.current_hp
		max_energy = player.max_energy
		current_energy = player.current_energy

	# Connect to grid system for treasure tracking
	if grid_system != null:
		grid_system.treasure_revealed.connect(_on_treasure_collected)
		# Check if grid is already initialized by checking if blocks exist
		if grid_system.grid_width > 0 and grid_system.grid_height > 0:
			# Grid already initialized, count treasures after a frame to ensure data is ready
			call_deferred("_count_total_treasures")
		else:
			# Wait for grid to initialize
			grid_system.grid_initialized.connect(_on_grid_initialized)

	# Initial UI update
	_update_health_display()
	_update_energy_display()

func _on_grid_initialized(_width: int, _height: int):
	_count_total_treasures()

func _count_total_treasures():
	if grid_system == null:
		return

	total_treasures = 0
	for y in range(grid_system.grid_height):
		for x in range(grid_system.grid_width):
			var block = grid_system.get_block(Vector2i(x, y))
			if block != null and block.type == BlockType.Type.TREASURE:
				total_treasures += 1

	# Cap at 3 treasures max per level
	total_treasures = mini(total_treasures, 3)

	collected_treasures = 0
	_setup_treasure_slots()
	print("HUD: Found %d treasures to collect" % total_treasures)

func _load_textures():
	# Load heart texture
	heart_texture = load("res://assets/sprites/UI/heart.png")

	# Load energy textures - create atlas textures from the combination image
	var energy_atlas = load("res://assets/sprites/UI/energy_combination_stages.png") as Texture2D
	if energy_atlas != null:
		var atlas_width = energy_atlas.get_width()
		var atlas_height = energy_atlas.get_height()
		var frame_width = atlas_width / 4  # 4 frames horizontally

		for i in range(4):
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = energy_atlas
			atlas_tex.region = Rect2(i * frame_width, 0, frame_width, atlas_height)
			energy_textures.append(atlas_tex)

	# Load treasure textures
	question_treasure_texture = load("res://assets/sprites/UI/question_mark_treasure.png")
	collected_treasure_texture = load("res://assets/sprites/blocks/treasure.png")

## Create a styled panel container with background
func _create_panel_container() -> PanelContainer:
	var panel = PanelContainer.new()

	# Create a StyleBoxFlat for the background
	var style = StyleBoxFlat.new()
	style.bg_color = panel_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = panel_padding
	style.content_margin_right = panel_padding
	style.content_margin_top = panel_padding
	style.content_margin_bottom = panel_padding

	panel.add_theme_stylebox_override("panel", style)
	return panel

func _setup_ui():
	# Make this control fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# === TOP LEFT: Health + Treasures ===
	top_left_container = VBoxContainer.new()
	top_left_container.name = "TopLeftContainer"
	top_left_container.add_theme_constant_override("separation", 8)
	top_left_container.position = Vector2(margin, margin)
	add_child(top_left_container)

	# Health row with background panel
	health_panel = _create_panel_container()
	health_panel.name = "HealthPanel"
	top_left_container.add_child(health_panel)

	health_container = HBoxContainer.new()
	health_container.name = "HealthContainer"
	health_container.add_theme_constant_override("separation", int(heart_spacing))
	health_panel.add_child(health_container)

	# Treasure row with background panel
	treasure_panel = _create_panel_container()
	treasure_panel.name = "TreasurePanel"
	top_left_container.add_child(treasure_panel)

	treasure_container = HBoxContainer.new()
	treasure_container.name = "TreasureContainer"
	treasure_container.add_theme_constant_override("separation", int(treasure_spacing))
	treasure_panel.add_child(treasure_container)

	# === BOTTOM LEFT: Energy ===
	energy_sprite = TextureRect.new()
	energy_sprite.name = "EnergySprite"
	energy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	energy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_sprite.custom_minimum_size = Vector2(energy_icon_size, energy_icon_size)
	if energy_textures.size() > 0:
		energy_sprite.texture = energy_textures[0]
	add_child(energy_sprite)

	# Position energy in bottom-left (will be updated in _process or use anchors)
	_position_energy_sprite()

func _position_energy_sprite():
	if energy_sprite == null:
		return
	# Position at bottom-left corner using viewport size
	var viewport_size = get_viewport_rect().size
	energy_sprite.position = Vector2(margin, viewport_size.y - energy_icon_size - margin)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_position_energy_sprite()

func _process(_delta):
	# Continuously update energy sprite position to handle viewport changes
	_position_energy_sprite()

func _setup_treasure_slots():
	# Clear existing slots
	for slot in treasure_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	treasure_slots.clear()

	# Create new slots based on total treasures (max 3)
	for i in range(total_treasures):
		var slot = TextureRect.new()
		slot.name = "TreasureSlot_%d" % i
		slot.texture = question_treasure_texture
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.custom_minimum_size = Vector2(treasure_icon_size, treasure_icon_size)
		treasure_container.add_child(slot)
		treasure_slots.append(slot)

func _update_health_display():
	# Clear existing hearts
	for child in health_container.get_children():
		child.queue_free()

	# Create hearts for max HP
	for i in range(max_hp):
		var heart = TextureRect.new()
		heart.name = "Heart_%d" % i
		heart.texture = heart_texture
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(heart_icon_size, heart_icon_size)

		# Gray out lost hearts
		if i >= current_hp:
			heart.modulate = Color(0.3, 0.3, 0.3, 0.5)

		health_container.add_child(heart)

func _update_energy_display():
	if energy_sprite == null or energy_textures.size() < 4:
		return

	# Determine which frame to show based on energy level
	# 0: empty (0-9)
	# 1: 1/3 (10-19)
	# 2: 2/3 (20-29)
	# 3: full (30)
	var frame_index = 0
	if current_energy >= 30:
		frame_index = 3
	elif current_energy >= 20:
		frame_index = 2
	elif current_energy >= 10:
		frame_index = 1
	else:
		frame_index = 0

	energy_sprite.texture = energy_textures[frame_index]

func _update_treasure_display():
	# Update treasure slots based on collected count
	for i in range(treasure_slots.size()):
		if i < collected_treasures and i < collected_treasure_textures.size():
			# Use the specific treasure texture that was collected
			treasure_slots[i].texture = collected_treasure_textures[i]
			treasure_slots[i].modulate = Color.WHITE
		else:
			treasure_slots[i].texture = question_treasure_texture
			treasure_slots[i].modulate = Color.WHITE

## Signal handlers
func _on_energy_changed(current: int, max_val: int):
	current_energy = current
	max_energy = max_val
	_update_energy_display()

func _on_player_damaged(_amount: int, _reason: String):
	if player != null:
		current_hp = player.current_hp
		_update_health_display()
		# Add damage flash effect
		_play_damage_effect()

func _on_player_died(_reason: String):
	current_hp = 0
	_update_health_display()

func _on_player_respawned():
	# Reset HUD to match player's reset values
	if player != null:
		current_hp = player.current_hp
		current_energy = player.current_energy
	# NOTE: Collected treasures are NOT reset on respawn - player keeps them
	_update_health_display()
	_update_energy_display()
	print("HUD: Player respawned, HP=%d, Energy=%d, Treasures kept: %d" % [current_hp, current_energy, collected_treasures])

func _on_treasure_collected(_position: Vector2i, treasure_data: TreasureData):
	# Load and store the treasure's specific texture
	var treasure_tex: Texture2D = null
	if treasure_data != null and treasure_data.sprite_path != "":
		treasure_tex = load(treasure_data.sprite_path)
	if treasure_tex == null:
		treasure_tex = collected_treasure_texture
	collected_treasure_textures.append(treasure_tex)

	collected_treasures += 1
	print("HUD: Treasure collected! %d/%d" % [collected_treasures, total_treasures])

	# Play celebration effect
	_start_treasure_celebration(treasure_tex, treasure_data)

func _play_damage_effect():
	# Flash the health container red
	var tween = health_container.create_tween()
	tween.tween_property(health_container, "modulate", Color.RED, 0.1)
	tween.tween_property(health_container, "modulate", Color.WHITE, 0.1)

func _play_treasure_collect_effect():
	if collected_treasures <= 0 or collected_treasures > treasure_slots.size():
		return

	var slot = treasure_slots[collected_treasures - 1]
	if slot == null:
		return

	# Scale pop effect
	var tween = slot.create_tween()
	tween.tween_property(slot, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1)

## Start the treasure celebration sequence
func _start_treasure_celebration(treasure_tex: Texture2D, treasure_data: TreasureData):
	if is_celebrating:
		return

	is_celebrating = true

	# Freeze player
	if player != null:
		player.freeze()

	# Get camera reference for shake
	if player != null and player_camera == null:
		player_camera = player.get_node_or_null("Camera2D")

	var viewport_size = get_viewport_rect().size
	var center = viewport_size / 2

	# Create semi-transparent overlay
	celebration_overlay = ColorRect.new()
	celebration_overlay.name = "CelebrationOverlay"
	celebration_overlay.color = Color(0, 0, 0, 0)
	celebration_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	celebration_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celebration_overlay)

	# Create gold particles
	_create_celebration_particles(center)

	# Create treasure sprite in center
	celebration_treasure_sprite = TextureRect.new()
	celebration_treasure_sprite.name = "CelebrationTreasure"
	celebration_treasure_sprite.texture = treasure_tex
	celebration_treasure_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	celebration_treasure_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	celebration_treasure_sprite.custom_minimum_size = Vector2(0, 0)
	celebration_treasure_sprite.size = Vector2(0, 0)
	celebration_treasure_sprite.position = center
	celebration_treasure_sprite.pivot_offset = Vector2(treasure_zoom_size / 2, treasure_zoom_size / 2)
	celebration_treasure_sprite.modulate.a = 0
	add_child(celebration_treasure_sprite)

	# Start camera shake
	_start_camera_shake()

	# Animate the celebration
	_animate_celebration(center, treasure_data)

## Create gold particles for celebration
func _create_celebration_particles(center: Vector2):
	celebration_particles = CPUParticles2D.new()
	celebration_particles.name = "CelebrationParticles"
	celebration_particles.position = center
	celebration_particles.z_index = 100

	# Particle settings
	celebration_particles.emitting = true
	celebration_particles.amount = particle_count
	celebration_particles.lifetime = 1.5
	celebration_particles.one_shot = false
	celebration_particles.explosiveness = 0.3
	celebration_particles.randomness = 0.5

	# Emission from center outward
	celebration_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	celebration_particles.emission_sphere_radius = 20.0

	# Movement - burst outward then fall
	celebration_particles.direction = Vector2(0, -1)
	celebration_particles.spread = 180.0
	celebration_particles.gravity = Vector2(0, 200)
	celebration_particles.initial_velocity_min = 100.0
	celebration_particles.initial_velocity_max = 250.0

	# Size
	celebration_particles.scale_amount_min = 3.0
	celebration_particles.scale_amount_max = 6.0

	# Gold color with variation
	celebration_particles.color = Color(1.0, 0.85, 0.0, 1.0)

	# Color ramp for sparkle effect
	var color_ramp = Gradient.new()
	color_ramp.set_offset(0, 0.0)
	color_ramp.set_color(0, Color(1.0, 1.0, 0.5, 1.0))  # Bright yellow
	color_ramp.set_offset(1, 1.0)
	color_ramp.set_color(1, Color(1.0, 0.7, 0.0, 0.0))  # Fade to orange then transparent
	celebration_particles.color_ramp = color_ramp

	add_child(celebration_particles)

## Start camera shake effect
func _start_camera_shake():
	if player_camera == null:
		return

	var original_offset = player_camera.offset
	var shake_tween = create_tween()

	# Shake for a short duration
	for i in range(10):
		var random_offset = Vector2(
			randf_range(-camera_shake_intensity, camera_shake_intensity),
			randf_range(-camera_shake_intensity, camera_shake_intensity)
		)
		shake_tween.tween_property(player_camera, "offset", original_offset + random_offset, 0.05)

	# Return to original
	shake_tween.tween_property(player_camera, "offset", original_offset, 0.1)

## Animate the celebration sequence
func _animate_celebration(center: Vector2, treasure_data: TreasureData):
	var tween = create_tween()

	# Phase 1: Fade in overlay and treasure (0.3s)
	tween.tween_property(celebration_overlay, "color", Color(0, 0, 0, 0.4), 0.3)
	tween.parallel().tween_property(celebration_treasure_sprite, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(celebration_treasure_sprite, "custom_minimum_size", Vector2(treasure_zoom_size, treasure_zoom_size), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(celebration_treasure_sprite, "size", Vector2(treasure_zoom_size, treasure_zoom_size), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(celebration_treasure_sprite, "position", center - Vector2(treasure_zoom_size / 2, treasure_zoom_size / 2), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Phase 2: Hold and pulse (1.2s)
	tween.tween_property(celebration_treasure_sprite, "scale", Vector2(1.1, 1.1), 0.3)
	tween.tween_property(celebration_treasure_sprite, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(celebration_treasure_sprite, "scale", Vector2(1.05, 1.05), 0.3)
	tween.tween_property(celebration_treasure_sprite, "scale", Vector2(1.0, 1.0), 0.3)

	# Phase 3: Shrink to slot position (0.5s)
	var slot_index = collected_treasures - 1
	if slot_index >= 0 and slot_index < treasure_slots.size():
		var target_slot = treasure_slots[slot_index]
		var slot_global_pos = target_slot.global_position
		var slot_size = Vector2(treasure_icon_size, treasure_icon_size)

		tween.tween_property(celebration_treasure_sprite, "position", slot_global_pos, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(celebration_treasure_sprite, "custom_minimum_size", slot_size, 0.4)
		tween.parallel().tween_property(celebration_treasure_sprite, "size", slot_size, 0.4)
		tween.parallel().tween_property(celebration_overlay, "color", Color(0, 0, 0, 0), 0.4)

	# Phase 4: Cleanup
	tween.tween_callback(_end_treasure_celebration)

## End the celebration and cleanup
func _end_treasure_celebration():
	is_celebrating = false

	# Update treasure display to show collected treasure in slot
	_update_treasure_display()

	# Cleanup celebration nodes
	if celebration_overlay != null:
		celebration_overlay.queue_free()
		celebration_overlay = null

	if celebration_treasure_sprite != null:
		celebration_treasure_sprite.queue_free()
		celebration_treasure_sprite = null

	if celebration_particles != null:
		celebration_particles.emitting = false
		# Give particles time to fade out
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(func():
			if is_instance_valid(celebration_particles):
				celebration_particles.queue_free()
		)
		celebration_particles = null

	# Unfreeze player
	if player != null:
		player.unfreeze()

	# Play the slot pop effect
	_play_treasure_collect_effect()

	print("HUD: Treasure celebration ended")

## Public method to update max HP (for power-ups, etc.)
func set_max_hp(new_max: int):
	max_hp = new_max
	_update_health_display()

## Public method to reset HUD (for respawn)
func reset():
	if player != null:
		current_hp = player.max_hp
		current_energy = player.current_energy
	_update_health_display()
	_update_energy_display()
