extends Control
# Works for Label, TextureRect, Button, etc.

# FLOAT SETTINGS
@export var float_height := 8.0
@export var float_speed := 2.0

# ROCK SETTINGS
@export var rock_angle := 3.0
@export var rock_speed := 1.4

# STYLE OFFSET
@export var base_rotation := -3.0

var time := 0.0
var start_y := 0.0

func _ready():
	start_y = position.y
	rotation_degrees = base_rotation

func _process(delta):
	time += delta

	# Float up/down
	position.y = start_y + sin(time * float_speed) * float_height

	# Rock side-to-side
	rotation_degrees = base_rotation + cos(time * rock_speed) * rock_angle
