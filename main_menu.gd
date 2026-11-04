extends Control

# Ganti jika nama file scene level kamu berbeda
const LEVEL_SCENE := "res://node_2d.tscn"


func _ready() -> void:
	# Pastikan game tidak dalam kondisi pause (misalnya setelah kembali dari Pause Menu)
	get_tree().paused = false
	$StartGame.pressed.connect(_on_start_game_pressed)
	$Quit.pressed.connect(_on_quit_pressed)
	$StartGame.grab_focus()


func _on_start_game_pressed() -> void:
	_reset_progress()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


# Mulai permainan dari nol: skor dan isi inventory dikosongkan
func _reset_progress() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reset_score()
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.items.clear()
