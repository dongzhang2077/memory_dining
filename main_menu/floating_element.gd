extends Control # Works for Buttons AND Labels

# Settings
@export var speed = 2.0
@export var height = 5.0
var time = 0.0
var start_y = 0.0

func _ready():
	# 1. Remember starting height
	start_y = position.y
	
	# 2. Set the Pivot to the center (Crucial for rotation!)
	# This ensures it tilts around its middle, not the top-left corner.
	pivot_offset = size / 2
	
	# 3. Apply the "Jaunty Tilt"
	rotation_degrees = -3 

func _process(delta):
	time += delta
	# The Float Animation
	position.y = start_y + (sin(time * speed) * height)
