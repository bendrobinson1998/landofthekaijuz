extends Node

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 10

var current_music: AudioStream
var music_volume: float = 0.6
var sfx_volume: float = 0.8
var master_volume: float = 1.0

func _ready():
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Create SFX players pool
	for i in range(max_sfx_players):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.bus = "SFX"
		sfx_players.append(sfx_player)
		add_child(sfx_player)
	
	# Set up audio buses if they don't exist
	_setup_audio_buses()

func _setup_audio_buses():
	# Check if custom buses exist, create if not
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")

func play_music(music_stream: AudioStream, fade_in: bool = true):
	if current_music == music_stream and music_player.playing:
		return
	
	current_music = music_stream
	
	if fade_in and music_player.playing:
		# Fade out current music, then start new one
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, 0.5)
		tween.tween_callback(func(): _start_music(music_stream, true))
	else:
		_start_music(music_stream, fade_in)

func _start_music(music_stream: AudioStream, fade_in: bool = false):
	music_player.stream = music_stream
	
	if fade_in:
		music_player.volume_db = -80.0
		music_player.play()
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume * master_volume), 1.0)
	else:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
		music_player.play()

func stop_music(fade_out: bool = true):
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, 0.5)
		tween.tween_callback(func(): music_player.stop())
	else:
		music_player.stop()

func play_sfx(sfx_stream: AudioStream, volume_modifier: float = 1.0) -> AudioStreamPlayer:
	var available_player = _get_available_sfx_player()
	
	if available_player:
		available_player.stream = sfx_stream
		available_player.volume_db = linear_to_db(sfx_volume * master_volume * volume_modifier)
		available_player.play()
		return available_player
	
	return null

func play_sfx_at_position(sfx_stream: AudioStream, position: Vector2, volume_modifier: float = 1.0):
	# For 2D positional audio, we'd need AudioStreamPlayer2D
	# This is a simplified version
	play_sfx(sfx_stream, volume_modifier)

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	
	# If all players are busy, use the first one (interrupt)
	return sfx_players[0]

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)

func _update_volumes():
	# Update music volume
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
	
	# SFX volumes are set per-play, so they'll use the new values on next play

func mute_all():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)

func unmute_all():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

func is_music_playing() -> bool:
	return music_player.playing

func get_music_position() -> float:
	return music_player.get_playback_position()

func preload_sfx(sfx_paths: Array[String]) -> Dictionary:
	var preloaded_sounds = {}
	
	for path in sfx_paths:
		var sound = load(path)
		if sound is AudioStream:
			var filename = path.get_file().get_basename()
			preloaded_sounds[filename] = sound
		
	
	return preloaded_sounds
