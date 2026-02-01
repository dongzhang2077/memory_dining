extends Node

## Audio Manager - Centralized audio playback system
## 音频管理器 - 集中式音频播放系统
##
## Usage: AudioManager.play_sfx("dig") or AudioManager.play_music("background")

## Audio players for sound effects (multiple for overlapping sounds)
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_PLAYER_COUNT: int = 8  # Pool of 8 players for overlapping sounds

## Music player (only one music plays at a time)
var music_player: AudioStreamPlayer

## Volume settings (0.0 to 1.0)
@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 0.8

## Auto-play background music on startup
@export var auto_play_bgm: bool = true

## Audio resources - preloaded for instant playback
var sounds: Dictionary = {}
var music: Dictionary = {}

## Current music track name
var current_music: String = ""

func _ready():
	_initialize_audio_players()
	_load_audio_resources()
	print("AudioManager initialized with %d SFX players" % SFX_PLAYER_COUNT)

	# Auto-play background music
	if auto_play_bgm:
		play_music("background", 2.0)
		print("Background music auto-started")

## Initialize audio players (pool for SFX, single for music)
func _initialize_audio_players():
	# Create SFX player pool
	for i in range(SFX_PLAYER_COUNT):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "SFX"  # Route to SFX bus (create in Audio settings if needed)
		add_child(player)
		sfx_players.append(player)

	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"  # Route to Music bus
	add_child(music_player)

## Load all audio resources from assets/sounds folder
func _load_audio_resources():
	# Sound effects
	sounds["dig"] = load("res://assets/sounds/rock_destroy.wav")
	sounds["bomb_explode"] = load("res://assets/sounds/bomb.mp3")
	sounds["treasure_get"] = load("res://assets/sounds/treasure.wav")
	sounds["item_get"] = load("res://assets/sounds/item_get.wav")
	sounds["scan"] = load("res://assets/sounds/stone_hint.wav")
	sounds["game_over"] = load("res://assets/sounds/game-over.wav")

	# Background music
	music["background"] = load("res://assets/sounds/bgm-background.mp3")

	print("Loaded %d sound effects and %d music tracks" % [sounds.size(), music.size()])

## Play a sound effect by name
## Returns the AudioStreamPlayer that's playing the sound (or null if sound not found)
func play_sfx(sound_name: String, volume_scale: float = 1.0) -> AudioStreamPlayer:
	if not sounds.has(sound_name):
		push_warning("Sound effect '%s' not found!" % sound_name)
		return null

	# Find available SFX player
	var player = _get_available_sfx_player()
	if player == null:
		push_warning("No available SFX players! (all busy)")
		return null

	# Configure and play
	player.stream = sounds[sound_name]
	player.volume_db = linear_to_db(sfx_volume * volume_scale * master_volume)
	player.play()

	return player

## Play background music by name (loops)
func play_music(music_name: String, fade_in_duration: float = 1.0):
	if not music.has(music_name):
		push_warning("Music track '%s' not found!" % music_name)
		return

	# Don't restart if already playing
	if current_music == music_name and music_player.playing:
		return

	# Stop current music
	if music_player.playing:
		stop_music(fade_in_duration * 0.5)
		await get_tree().create_timer(fade_in_duration * 0.5).timeout

	# Play new music
	current_music = music_name
	music_player.stream = music[music_name]

	# Enable looping for music
	if music_player.stream is AudioStreamMP3:
		music_player.stream.loop = true
	elif music_player.stream is AudioStreamWAV:
		music_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	music_player.volume_db = linear_to_db(music_volume * master_volume)
	music_player.play()

	# Fade in
	if fade_in_duration > 0:
		var start_volume = music_player.volume_db - 20  # Start quieter
		music_player.volume_db = start_volume
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume * master_volume), fade_in_duration)

## Stop currently playing music
func stop_music(fade_out_duration: float = 1.0):
	if not music_player.playing:
		return

	if fade_out_duration > 0:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, fade_out_duration)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

	current_music = ""

## Pause music
func pause_music():
	if music_player.playing:
		music_player.stream_paused = true

## Resume music
func resume_music():
	if music_player.stream and music_player.stream_paused:
		music_player.stream_paused = false

## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float):
	master_volume = clampf(volume, 0.0, 1.0)
	_update_all_volumes()

## Set music volume (0.0 to 1.0)
func set_music_volume(volume: float):
	music_volume = clampf(volume, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)

## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float):
	sfx_volume = clampf(volume, 0.0, 1.0)

## Update all currently playing audio volumes
func _update_all_volumes():
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)

## Find an available (not playing) SFX player from the pool
func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player

	# All busy - return the first one (will interrupt oldest sound)
	return sfx_players[0]

## Play a one-shot sound at a specific position (for spatial audio in future)
## For now, just plays normally since we're 2D without spatial audio
func play_sfx_at_position(sound_name: String, position: Vector2, volume_scale: float = 1.0):
	# TODO: Implement spatial audio if needed
	play_sfx(sound_name, volume_scale)

## Preload and cache a sound effect
func preload_sound(sound_name: String, file_path: String):
	sounds[sound_name] = load(file_path)

## Preload and cache a music track
func preload_music(music_name: String, file_path: String):
	music[music_name] = load(file_path)
