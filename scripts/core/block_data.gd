class_name BlockData
extends RefCounted

## Represents a single block in the grid
## 表示网格中的单个方块

var type: BlockType.Type
var durability: int
var is_visible: bool = true  # All blocks are always visible
var is_scanned: bool = false
var treasure_data: TreasureData = null  # Only for treasure blocks
var grid_position: Vector2i  # (column, row)

## Constructor
func _init(p_type: BlockType.Type, p_position: Vector2i):
	type = p_type
	grid_position = p_position
	durability = BlockType.get_hits_to_break(p_type)

	# All blocks are visible - hidden treasures/crystals appear as soft_dirt until scanned
	# The is_scanned flag controls whether to show true texture or disguised texture
	is_visible = true

## Take damage from mining
## Returns true if block is destroyed
func take_damage(amount: int = 1) -> bool:
	if not BlockType.is_breakable(type):
		return false
	
	durability -= amount
	return durability <= 0

## Check if block is destroyed
func is_destroyed() -> bool:
	return durability <= 0

## Get remaining hits to break
func get_remaining_hits() -> int:
	return max(0, durability)

## Set as scanned (reveals hidden blocks)
func set_scanned():
	is_scanned = true
	is_visible = true

## Clone this block data
func clone() -> BlockData:
	var new_block = BlockData.new(type, grid_position)
	new_block.durability = durability
	new_block.is_visible = is_visible
	new_block.is_scanned = is_scanned
	new_block.treasure_data = treasure_data
	return new_block
