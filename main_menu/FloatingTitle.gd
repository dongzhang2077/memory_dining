extends Control # Or TextureRect, or Label

# SETTINGS (Tweak these to change the feel)
var float_distance = 10.0 # How many pixels up/down
var float_speed = 2.0     # How fast it bobs
var rock_angle = 2.0      # How many degrees it tilts
var rock_speed = 1.5      # Tilting speed (different from float for randomness)

# Internal variables
var time = 0.0
var start_y = 0.0

func _ready():
	# Remember where we started so we don't float away forever
	start_y = position.y

func _process(delta):
	time += delta
	
	# 1. Float Up and Down (Sine Wave)
	# sin(time) goes from -1 to 1. We multiply by distance.
	var new_y = start_y + (sin(time * float_speed) * float_distance)
	position.y = new_y
	
	# 2. Rock Side to Side (Cosine Wave)
	# We use a slightly different speed so it feels organic, not robotic
	rotation_degrees = cos(time * rock_speed) * rock_angle
