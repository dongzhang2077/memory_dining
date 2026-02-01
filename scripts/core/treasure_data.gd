class_name TreasureData
extends Resource

## Treasure data for collectible items
## 宝藏数据

enum Era {
	ERA_1990S,
	ERA_1980S,
	ERA_1970S,
	ERA_1960S
}

enum Rarity {
	COMMON,      # 60% - 50-100 coins
	UNCOMMON,    # 25% - 150-250 coins
	RARE,        # 12% - 300-500 coins
	LEGENDARY    # 3% - 800-1500 coins
}

## All available treasure sprite paths
const TREASURE_SPRITES: Array[String] = [
	"res://assets/sprites/treatures/treasure_arcade_80s_nobg.png",
	"res://assets/sprites/treatures/treasure_boombox_80s_nobg.png",
	"res://assets/sprites/treatures/treasure_camera_60s_nobg.png",
	"res://assets/sprites/treatures/treasure_cd_90s_nobg.png",
	"res://assets/sprites/treatures/treasure_floppy_90s_nobg.png",
	"res://assets/sprites/treatures/treasure_gameboy_90s_nobg.png",
	"res://assets/sprites/treatures/treasure_pager_90s_nobg.png",
	"res://assets/sprites/treatures/treasure_radio_60s_nobg.png",
	"res://assets/sprites/treatures/treasure_robot_70s_nobg.png",
	"res://assets/sprites/treatures/treasure_rotary_phone_80s_nobg.png",
	"res://assets/sprites/treatures/treasure_tubes_60s_nobg.png",
	"res://assets/sprites/treatures/treasure_vinyl_80s_nobg.png",
]

## Track used sprites for current level to avoid duplicates
static var _used_sprites_this_level: Array[String] = []

var id: String
var name: String
var description: String
var era: Era
var rarity: Rarity
var value: int
var sprite_path: String

## Constructor
func _init(p_id: String, p_name: String, p_description: String, p_era: Era, p_rarity: Rarity, p_value: int, p_sprite_path: String = ""):
	id = p_id
	name = p_name
	description = p_description
	era = p_era
	rarity = p_rarity
	value = p_value
	sprite_path = p_sprite_path

## Get era name as string
static func get_era_name(era: Era) -> String:
	match era:
		Era.ERA_1990S:
			return "1990s"
		Era.ERA_1980S:
			return "1980s"
		Era.ERA_1970S:
			return "1970s"
		Era.ERA_1960S:
			return "1960s"
		_:
			return "Unknown"

## Get rarity name as string
static func get_rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"

## Get rarity color for UI
static func get_rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.BLUE
		Rarity.LEGENDARY:
			return Color.GOLD
		_:
			return Color.WHITE

## Reset used sprites for a new level
static func reset_level_sprites():
	_used_sprites_this_level.clear()

## Get a unique random sprite path (not used in this level yet)
static func _get_unique_sprite_path() -> String:
	# Get available sprites (not used yet)
	var available: Array[String] = []
	for sprite in TREASURE_SPRITES:
		if sprite not in _used_sprites_this_level:
			available.append(sprite)

	# If all sprites used, reset and use any
	if available.is_empty():
		available = TREASURE_SPRITES.duplicate()

	# Pick random from available
	var sprite_path = available[randi() % available.size()]
	_used_sprites_this_level.append(sprite_path)
	return sprite_path

## Generate random treasure for a specific era
static func generate_random(era: Era) -> TreasureData:
	var rand_rarity = _generate_random_rarity()
	var rand_value = _generate_value_for_rarity(rand_rarity)

	# Generate name based on era and rarity
	var treasure_name = _generate_treasure_name(era, rand_rarity)
	var treasure_id = "treasure_%s_%d" % [get_era_name(era).to_lower(), randi()]

	# Get unique sprite for this level
	var sprite = _get_unique_sprite_path()

	return TreasureData.new(
		treasure_id,
		treasure_name,
		"A vintage item from the %s" % get_era_name(era),
		era,
		rand_rarity,
		rand_value,
		sprite
	)

## Generate random rarity based on probability
static func _generate_random_rarity() -> Rarity:
	var roll = randf() * 100.0
	if roll < 60.0:
		return Rarity.COMMON
	elif roll < 85.0:
		return Rarity.UNCOMMON
	elif roll < 97.0:
		return Rarity.RARE
	else:
		return Rarity.LEGENDARY

## Generate value based on rarity
static func _generate_value_for_rarity(rarity: Rarity) -> int:
	match rarity:
		Rarity.COMMON:
			return randi_range(50, 100)
		Rarity.UNCOMMON:
			return randi_range(150, 250)
		Rarity.RARE:
			return randi_range(300, 500)
		Rarity.LEGENDARY:
			return randi_range(800, 1500)
		_:
			return 50

## Generate treasure name based on era and rarity
static func _generate_treasure_name(era: Era, rarity: Rarity) -> String:
	var era_items = []
	
	match era:
		Era.ERA_1990S:
			era_items = ["Game Console", "CD Player", "Pager", "Floppy Disk", "Tamagotchi"]
		Era.ERA_1980S:
			era_items = ["Walkman", "Cassette Tape", "Arcade Cabinet", "Boom Box", "VCR"]
		Era.ERA_1970S:
			era_items = ["Vinyl Record", "Rotary Phone", "Film Camera", "8-Track Player", "Disco Ball"]
		Era.ERA_1960S:
			era_items = ["Transistor Radio", "Vintage Toy", "Analog Watch", "Typewriter", "Lava Lamp"]
	
	var base_name = era_items[randi() % era_items.size()]
	
	# Add rarity prefix
	match rarity:
		Rarity.UNCOMMON:
			return "Fine " + base_name
		Rarity.RARE:
			return "Rare " + base_name
		Rarity.LEGENDARY:
			return "Legendary " + base_name
		_:
			return base_name
