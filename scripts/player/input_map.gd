## Input Map Configuration for Memory Mine
## Memory Mine 的输入映射配置
##
## Add these to your project's Input Map in Project Settings:
##
## Action Name: move_left
##   - Keyboard: Left Arrow, A
##
## Action Name: move_right
##   - Keyboard: Right Arrow, D
##
## Action Name: dig
##   - Keyboard: Space, Down Arrow, S
##
## Action Name: scan
##   - Keyboard: E
##
## Action Name: bomb
##   - Keyboard: B
##
## Action Name: restart
##   - Keyboard: R

## Alternatively, you can set up input map programmatically:
class_name InputMapConfig

static func setup_input_map():
	# Move Left
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	var left_arrow = InputEventKey.new()
	left_arrow.keycode = KEY_LEFT
	InputMap.action_add_event("move_left", left_arrow)
	var key_a = InputEventKey.new()
	key_a.keycode = KEY_A
	InputMap.action_add_event("move_left", key_a)
	
	# Move Right
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
	var right_arrow = InputEventKey.new()
	right_arrow.keycode = KEY_RIGHT
	InputMap.action_add_event("move_right", right_arrow)
	var key_d = InputEventKey.new()
	key_d.keycode = KEY_D
	InputMap.action_add_event("move_right", key_d)

	# Move Down (for digging direction)
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
	var down_arrow = InputEventKey.new()
	down_arrow.keycode = KEY_DOWN
	InputMap.action_add_event("move_down", down_arrow)
	var key_s = InputEventKey.new()
	key_s.keycode = KEY_S
	InputMap.action_add_event("move_down", key_s)

	# Dig
	if not InputMap.has_action("dig"):
		InputMap.add_action("dig")
	var space = InputEventKey.new()
	space.keycode = KEY_SPACE
	InputMap.action_add_event("dig", space)
	
	# Scan
	if not InputMap.has_action("scan"):
		InputMap.add_action("scan")
	var key_e = InputEventKey.new()
	key_e.keycode = KEY_E
	InputMap.action_add_event("scan", key_e)
	
	# Bomb
	if not InputMap.has_action("bomb"):
		InputMap.add_action("bomb")
	var key_b = InputEventKey.new()
	key_b.keycode = KEY_B
	InputMap.action_add_event("bomb", key_b)
	
	# Restart
	if not InputMap.has_action("restart"):
		InputMap.add_action("restart")
	var key_r = InputEventKey.new()
	key_r.keycode = KEY_R
	InputMap.action_add_event("restart", key_r)
