extends Node

## Game Manager - Controls game flow and background music
## 游戏管理器 - 控制游戏流程和背景音乐

signal game_started()
signal game_paused()
signal game_resumed()
signal level_completed()

@export var start_music_on_ready: bool = true
@export var music_track: String = "background"

var is_paused: bool = false

func _ready():
	# Start background music automatically
	if start_music_on_ready:
		AudioManager.play_music(music_track, 2.0)
		print("Background music started")

## Start the game
func start_game():
	game_started.emit()
	if not AudioManager.music_player.playing:
		AudioManager.play_music(music_track, 1.0)

## Pause the game
func pause_game():
	if not is_paused:
		is_paused = true
		get_tree().paused = true
		AudioManager.pause_music()
		game_paused.emit()
		print("Game paused")

## Resume the game
func resume_game():
	if is_paused:
		is_paused = false
		get_tree().paused = false
		AudioManager.resume_music()
		game_resumed.emit()
		print("Game resumed")

## Complete current level
func complete_level():
	level_completed.emit()
	print("Level completed!")

## Toggle pause
func toggle_pause():
	if is_paused:
		resume_game()
	else:
		pause_game()

func _input(event):
	# Press ESC to pause/resume
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
