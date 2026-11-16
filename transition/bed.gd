class_name Bed
extends Area2D

# Kasur: tekan E di dekatnya -> layar gelap -> hari berganti -> bangun di samping kasur.
# Collision layer 16 (sama dengan Forageable/Crop) supaya terdeteksi InteractArea player;
# player.try_collect() memanggil interact() pada area terdekat yang punya method itu.
# Tidur boleh kapan saja (tidak menunggu malam).

signal slept(new_day: int)

# Posisi KAKI player (CollisionShape2D) saat bangun, koordinat global
@export var wake_position := Vector2.ZERO
@export var fade_time := 0.6
@export var dark_hold := 0.4   # lama layar tetap gelap sebelum terang lagi

var _sleeping := false


func _ready() -> void:
	add_to_group("bed")
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true


func interact(player: CharacterBody2D) -> void:
	if _sleeping or player.health <= 0:
		return
	_sleeping = true

	# Blokir gerak & input player (pola sama dengan MapTransition)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector2.ZERO
	player.knockback_velocity = Vector2.ZERO

	var fade := ScreenFade.get_instance(get_tree())
	await fade.fade_to(1.0, fade_time)

	# Penjualan overnight ala Stardew: isi shipping bin dijual saat layar gelap, SEBELUM hari berganti
	var earned := 0
	var bin := get_tree().get_first_node_in_group("shipping_bin") as ShippingBin
	if bin:
		earned = bin.sell_overnight()

	var farming := get_tree().get_first_node_in_group("farming_manager") as FarmingManager
	if farming:
		farming.skip_to_next_day()

	# Bangun di samping kasur
	var feet := player.get_node("CollisionShape2D") as Node2D
	player.global_position += wake_position - feet.global_position
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()
	player.last_anim_direction = "front"

	await get_tree().create_timer(dark_hold).timeout
	await fade.fade_to(0.0, fade_time)

	if player.health > 0:
		player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	_sleeping = false
	slept.emit(farming.day if farming else 0)

	# Ringkasan hasil jual semalam (tidak muncul kalau bin kosong)
	if earned > 0:
		_show_earnings_popup(earned)


# Label sementara di tengah atas layar: "Hasil semalam: +70g", lalu memudar (~2 detik)
func _show_earnings_popup(amount: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4   # di atas HUD (1), di bawah ScreenFade (5)
	get_tree().current_scene.add_child(layer)

	var label := Label.new()
	label.text = "Hasil semalam: +%dg" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("ffd54f"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(label)

	var tw := label.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)
