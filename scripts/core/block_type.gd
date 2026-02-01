class_name BlockType
extends Resource

## Block type definitions for Memory Mine
## 方块类型定义

enum Type {
	SOFT_DIRT,      # 软土 - 1 hit, 1 energy
	HARD_STONE,     # 硬石 - 3 hits, 2 energy
	UNBREAKABLE,    # 坚固岩石 - ∞ hits, no yield
	TREASURE,       # 宝藏方块 - 1 hit, treasure item
	ENERGY_CRYSTAL  # 能量晶体 - 2 hits, 5 energy
}

## Block properties by type
static func get_hits_to_break(block_type: Type) -> int:
	match block_type:
		Type.SOFT_DIRT:
			return 1
		Type.HARD_STONE:
			return 3
		Type.UNBREAKABLE:
			return -1  # Infinite
		Type.TREASURE:
			return 1
		Type.ENERGY_CRYSTAL:
			return 2
		_:
			return 1

static func get_energy_yield(block_type: Type) -> int:
	match block_type:
		Type.SOFT_DIRT:
			return 1
		Type.HARD_STONE:
			return 2
		Type.UNBREAKABLE:
			return 0
		Type.TREASURE:
			return 0
		Type.ENERGY_CRYSTAL:
			return 5
		_:
			return 0

static func is_breakable(block_type: Type) -> bool:
	return block_type != Type.UNBREAKABLE

## Check if this block type can fall when support is removed
## 检查此方块类型在失去支撑时是否会掉落
## Configure which blocks fall here:
## - UNBREAKABLE: Never falls (anchored to the world)
## - HARD_STONE: Falls (can be changed to false if needed)
## - Others: Fall by default
static func is_fallable(block_type: Type) -> bool:
	match block_type:
		Type.UNBREAKABLE:
			return false  # Unbreakable rocks are anchored, never fall
		Type.HARD_STONE:
			return true   # Hard stone falls (change to false if you want it anchored)
		_:
			return true   # All other blocks fall by default

static func get_type_name(block_type: Type) -> String:
	match block_type:
		Type.SOFT_DIRT:
			return "Soft Dirt"
		Type.HARD_STONE:
			return "Hard Stone"
		Type.UNBREAKABLE:
			return "Unbreakable Rock"
		Type.TREASURE:
			return "Treasure Block"
		Type.ENERGY_CRYSTAL:
			return "Energy Crystal"
		_:
			return "Unknown"
