extends Control

func _ready():
	# The % symbol finds the node instantly, even if you moved it!
	%StartButton.pressed.connect(_on_start_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	print("Starting game...")
	# TODO: Create game level scene
	# Temporarily load test scene
	get_tree().change_scene_to_file("res://tests/test_player.tscn") 

func _on_quit_pressed():
	print("Quitting Game")
	get_tree().quit()
