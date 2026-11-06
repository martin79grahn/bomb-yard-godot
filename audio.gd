extends Node
## Music and sound effects. The songs are the Mega Drive's VGM tracks rendered to OGG
## (tools/render_music.py); the effects are its WAV samples. Like the XGM2 driver, effects play
## on three channels and a new sound on a channel cuts the one before.

const SONGS := ["title", "yard", "sand", "frost", "lava", "cloud", "sea", "boss", "clear", "gameover", "victory"]
const JINGLES := ["clear", "gameover", "victory"]
const CHANNEL := {"boom": 0, "place": 1, "pickup": 1, "heart": 1, "die": 2, "bosshit": 2, "tick": 2, "menu": 2, "select": 2}
const STRESS_TEMPO := 1.12   # the last 20 seconds: a little faster (the MD sets tempo 72)

var music: AudioStreamPlayer
var channels: Array[AudioStreamPlayer] = []
var streams := {}
var sfx := {}
var current := ""
var muted := false


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -3.0
	add_child(music)
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		channels.append(p)
	var loops := {}
	var f := FileAccess.open("res://assets/music/loops.json", FileAccess.READ)
	if f:
		loops = JSON.parse_string(f.get_as_text())
	for s in SONGS:
		var st: AudioStreamOggVorbis = load("res://assets/music/%s.ogg" % s)
		st.loop = not s in JINGLES
		st.loop_offset = loops.get(s, 0.0)
		streams[s] = st
	for s in CHANNEL:
		sfx[s] = load("res://assets/sfx/%s.wav" % s)


func play_music(song: String) -> void:
	if song == current and music.playing:
		return
	current = song
	music.pitch_scale = 1.0
	music.stream = streams[song]
	if not muted:
		music.play()


## A jingle always starts over, even if the same one just played.
func jingle(song: String) -> void:
	current = ""
	play_music(song)


func stop_music() -> void:
	current = ""
	music.stop()


func hurry(on: bool) -> void:
	music.pitch_scale = STRESS_TEMPO if on else 1.0


func pause_music(on: bool) -> void:
	music.stream_paused = on


func play(name: String) -> void:
	if muted:
		return
	var ch: AudioStreamPlayer = channels[CHANNEL[name]]
	ch.stream = sfx[name]
	ch.play()


func toggle_mute() -> void:
	muted = not muted
	if muted:
		music.stop()
	elif current != "":
		music.play()
