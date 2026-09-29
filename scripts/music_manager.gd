extends Node

## Carregada no _ready, e não com preload: este script é um autoload, e o
## Godot 3 lê os autoloads ANTES de importar os sons numa pasta nova (a
## primeira geração do APK). Com preload, a primeira importação acusava
## "Can't preload resource" e o script ficava quebrado.
const CAMINHO_MUSICA := "res://songs/song.ogg"
var MENU_MUSIC: AudioStream = null

var player: AudioStreamPlayer = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS

	player = AudioStreamPlayer.new()
	player.name = "GlobalMenuMusic"
	player.bus = "Master"
	player.volume_db = -4.0
	if ResourceLoader.exists(CAMINHO_MUSICA):
		MENU_MUSIC = load(CAMINHO_MUSICA)
	player.stream = MENU_MUSIC
	add_child(player)


func play_menu_music() -> void:
	if player == null:
		return

	if player.stream == null:
		player.stream = MENU_MUSIC

	if not player.playing:
		player.play()


func stop_menu_music() -> void:
	if player != null and player.playing:
		player.stop()


func restart_menu_music() -> void:
	if player == null:
		return

	player.stop()
	player.play()
	
