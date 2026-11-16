class_name MapTransition
extends Area2D

# Pemicu pindah sub-map ala Stardew Valley: layar memudar gelap -> player dipindah -> layar terang.
#
# Kenapa farm dan goa ada di SATU scene (node_2d.tscn), bukan scene terpisah?
# FarmingManager, timer hari, Inventory-di-HUD, dan tanaman hidup di scene farm.
# Ganti scene akan me-reset hari, tanaman, dan state alat. Dengan dua sub-map di satu scene
# (goa diletakkan jauh, +2000 px ke bawah) cukup teleport + ganti batas kamera.
#
# Cara pakai: duplikat node ini, atur CollisionShape2D sebagai area pintu, isi target_position
# dan camera_limits tujuan. Letakkan target 2-3 tile menjauh dari pintu tujuan supaya player
# tidak langsung memicu pintu balik.

signal transition_finished(player: Node2D)

# Posisi KAKI player (CollisionShape2D-nya) di tujuan, dalam koordinat global.
# Node Player sendiri berada di (0, 0) dengan offset anak, jadi yang dipindah adalah selisihnya.
@export var target_position := Vector2.ZERO
# Batas kamera di area tujuan: x = limit_left, y = limit_top, w/h = lebar/tinggi area
@export var camera_limits := Rect2i(0, 0, 1151, 657)
@export var fade_time := 0.35
@export var cooldown := 0.6     # jeda minimal sebelum pintu mana pun bisa dipakai lagi

# Dipakai bersama semua pintu: cegah dua transisi bersamaan / langsung memicu balik
static var _busy := false
static var _last_finish_msec := -100000


func _ready() -> void:
	add_to_group("map_transition")
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _busy or not body.is_in_group("player"):
		return
	if Time.get_ticks_msec() - _last_finish_msec < int(cooldown * 1000.0):
		return
	if "health" in body and body.health <= 0:
		return
	_run_transition(body)


func _run_transition(player: CharacterBody2D) -> void:
	_busy = true

	# Blokir gerak & input player selama transisi
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector2.ZERO
	if "knockback_velocity" in player:
		player.knockback_velocity = Vector2.ZERO

	var fade := ScreenFade.get_instance(get_tree())
	await fade.fade_to(1.0, fade_time)

	# Teleport: geser root player sebesar selisih kaki sekarang -> target
	var feet := player.get_node_or_null("CollisionShape2D") as Node2D
	var offset := feet.global_position - player.global_position if feet else Vector2.ZERO
	player.global_position = target_position - offset

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		apply_camera_limits(cam, camera_limits)
		cam.reset_smoothing()

	# Beri satu frame fisika supaya Area2D/kamera membaca posisi baru saat layar masih gelap
	await get_tree().physics_frame
	await get_tree().physics_frame
	await fade.fade_to(0.0, fade_time)

	# Jangan hidupkan lagi kalau player sempat mati di tengah transisi (die() sudah mematikannya)
	if player.health > 0:
		player.set_physics_process(true)
	player.set_process_unhandled_input(true)

	_last_finish_msec = Time.get_ticks_msec()
	_busy = false
	transition_finished.emit(player)


static func apply_camera_limits(cam: Camera2D, r: Rect2i) -> void:
	cam.limit_left = r.position.x
	cam.limit_top = r.position.y
	cam.limit_right = r.position.x + r.size.x
	cam.limit_bottom = r.position.y + r.size.y
