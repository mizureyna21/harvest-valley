extends Control

const MAIN_MENU_SCENE := "res://MainMenu.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # tetap aktif saat game di-pause
	visible = false                          # sembunyikan menu di awal
	$Panel/Resume.pressed.connect(_on_resume_pressed)
	$Panel/MainMenu.pressed.connect(_on_main_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Jangan buka pause saat layar kematian sedang tampil
		var death := get_node_or_null("../DeathScreen")
		if death and death.visible:
			return
		if get_tree().paused:
			_on_resume_pressed()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()


func _pause_game() -> void:
	get_tree().paused = true
	visible = true
	$Panel/Resume.grab_focus()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
