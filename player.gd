extends CharacterBody2D

var speed = 100.0
var max_health = 100
var health = max_health

# --- Invincibility (kebal setelah kena damage) ---
@export var invincibility_duration: float = 1.0
var is_invincible = false
var blink_tween: Tween = null

# --- Knockback ---
var knockback_velocity = Vector2.ZERO
var knockback_friction = 600.0

# --- Damage dari tile (kaktus, dll) ---
@export var tile_knockback_force: float = 150.0

# Menyimpan posisi awal untuk respawn.
# Player di node_2d.tscn mulai di dalam rumah (samping kasur), jadi setelah mati player
# respawn di dalam rumah juga — itu perilaku yang diinginkan (seperti Stardew).
@onready var spawn_position = global_position

# Variabel untuk menyimpan arah terakhir (default menghadap depan)
var last_anim_direction: String = "front"

# Referensi node
@onready var anim = $"main character"
@onready var body_shape = $CollisionShape2D
@onready var interact_area = $InteractArea
@onready var health_bar = get_node_or_null("../HUD/Control/HealthLabel")
@onready var death_screen = get_node_or_null("../HUD/DeathScreen")
@onready var respawn_button = get_node_or_null("../HUD/DeathScreen/VBoxContainer/RespawnButton")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

# Batas kamera area spawn (farm), dipulihkan saat respawn kalau player mati di goa
var spawn_camera_limits := Rect2i()

# --- Pedang (slot alat ke-4) ---
# Combat milik player, bukan FarmingManager: FarmingManager tetap murni urusan tanah/tanaman,
# player hanya menanyakan alat aktif lalu memutuskan menebas atau meneruskan ke farming.
const SWORD_ID := &"sword"
const ENEMY_LAYER := 4                      # physics layer 3 "enemy" (nilai bit 4)
const BODY_CENTER := Vector2(436, 304)      # tengah badan relatif root Player (anak-anak Player ber-offset)
@export var sword_damage := 1
@export var sword_cooldown := 0.4
@export var sword_knockback := 160.0
@export var sword_reach := 16.0             # jarak tengah hitbox dari tengah badan
var _can_attack := true
var _is_swinging := false                   # true selama animasi aksi (attack_/hoe_/water_) diputar

# Animasi badan per alat farming (frame dari NEWCHAR.png, lihat tools/genattackanim.js).
# Bibit tidak punya animasi, jadi langsung ditanam.
const TOOL_ANIM_PREFIX := {&"hoe": "hoe_", &"watering_can": "water_"}
# Jeda dari klik sampai efek ke tile: cangkul menyentuh tanah di frame ke-3, air keluar di frame ke-2
const TOOL_IMPACT_DELAY := {&"hoe": 0.2, &"watering_can": 0.17}
var sword_area: Area2D
var _sword_shape: CollisionShape2D
var _sword_sprite: Sprite2D


func _ready():
	add_to_group("player")

	# Mode top-down
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	if health_bar:
		health_bar.max_value = max_health
	update_health_bar()

	# Sembunyikan layar kematian dan sambungkan tombol lewat kode
	if death_screen:
		death_screen.hide()
	if respawn_button:
		respawn_button.pressed.connect(respawn)

	if camera:
		spawn_camera_limits = Rect2i(camera.limit_left, camera.limit_top,
				camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)

	_setup_sword()


func _physics_process(delta):
	var direction = Vector2.ZERO

	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction.length() > 0:
		direction = direction.normalized()

	# Selama mengayun pedang player berhenti sebentar (seperti Stardew), knockback tetap jalan
	if _is_swinging:
		direction = Vector2.ZERO

	# Gerakan normal + dorongan knockback
	velocity = direction * speed + knockback_velocity
	move_and_slide()

	# Cek apakah menabrak tile yang bisa memberi damage (kaktus)
	check_tile_damage()

	# Knockback melambat sampai berhenti
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

	update_animation(direction)


# --- Interaksi: memungut item foraging / panen, dan memakai alat ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_collect()
	elif event.is_action_pressed("attack"):
		use_tool()


func try_collect() -> void:
	# Tidak bisa memungut saat sudah mati
	if health <= 0:
		return

	# Ambil forageable / tanaman matang / objek interaktif (mis. kasur) terdekat.
	# Objek interaktif = area apa pun yang punya method interact(player) (duck typing).
	# Jarak diukur dari body_shape karena node Player sendiri ada di (0, 0).
	var nearest: Area2D = null
	var best := INF
	for area in interact_area.get_overlapping_areas():
		var can_take: bool = (area is Forageable and not area.collected) \
				or (area is Crop and area.can_harvest()) \
				or area.has_method("interact")
		if can_take:
			var d: float = body_shape.global_position.distance_to(area.global_position)
			if d < best:
				best = d
				nearest = area

	if nearest is Crop:
		nearest.harvest()
	elif nearest is Forageable:
		nearest.collect()
	elif nearest:
		nearest.interact(self)


# --- Klik kiri: pakai alat aktif (farming) atau menebas kalau pedang aktif ---
func use_tool() -> void:
	if health <= 0:
		return
	var farming := get_tree().get_first_node_in_group("farming_manager") as FarmingManager
	if farming == null:
		return
	# Satu aksi sekaligus: klik saat animasi aksi masih jalan diabaikan
	if _is_swinging:
		return
	var item := farming.get_active_item()
	if item and item.id == SWORD_ID:
		if Inventory.get_count(SWORD_ID) > 0:
			sword_attack(item)
		return

	# Posisi kaki = collision shape (node Player sendiri ada di (0, 0)).
	# Diambil sekarang supaya target tile tetap sama walau efeknya baru diterapkan saat alat "kena".
	var feet: Vector2 = body_shape.global_position
	var facing := get_facing_vector()
	var prefix: String = TOOL_ANIM_PREFIX.get(item.id, "") if item else ""
	if prefix != "" and Inventory.get_count(item.id) > 0 and play_action_anim(prefix):
		# Tunggu sampai cangkul menyentuh tanah / air gembor keluar, baru ubah tile
		await get_tree().create_timer(TOOL_IMPACT_DELAY.get(item.id, 0.0)).timeout
		if health <= 0:
			return
	farming.use_active_tool(feet, facing)


# --- Pedang ---
# Hitbox (Area2D) dan sprite tebasan dibuat lewat kode supaya tidak perlu menyentuh scene.
# Hitbox hanya monitoring sesaat saat menebas; mask = layer "enemy" (badan musuh ada di layer 3).
func _setup_sword() -> void:
	sword_area = Area2D.new()
	sword_area.name = "SwordArea"
	sword_area.collision_layer = 0
	sword_area.collision_mask = ENEMY_LAYER
	sword_area.monitorable = false
	sword_area.monitoring = false
	_sword_shape = CollisionShape2D.new()
	_sword_shape.shape = RectangleShape2D.new()
	sword_area.add_child(_sword_shape)
	add_child(sword_area)

	# Visual tebasan: animasi badan "attack_front/top/left/right" di SpriteFrames (frame ayunan pedang
	# dari NEWCHAR.png, ditambahkan oleh tools/genattackanim.js). Sprite icon pedang yang diputar di bawah
	# hanya cadangan kalau animasi attack_* untuk arah itu tidak ada.
	anim.animation_finished.connect(_on_body_animation_finished)
	_sword_sprite = Sprite2D.new()
	_sword_sprite.name = "SwordSwing"
	_sword_sprite.visible = false
	_sword_sprite.offset = Vector2(8, -8)   # pivot di gagang (pojok kiri-bawah icon)
	add_child(_sword_sprite)


func sword_attack(item: ItemData) -> void:
	if not _can_attack:
		return
	_can_attack = false

	var dir := Vector2(get_facing_vector())
	# Hitbox ~22x24 px di depan badan sesuai arah hadap
	sword_area.position = BODY_CENTER + dir * sword_reach
	var rect := _sword_shape.shape as RectangleShape2D
	rect.size = Vector2(22, 24) if dir.x != 0 else Vector2(24, 22)
	sword_area.monitoring = true
	_play_sword_swing(item, dir)

	# Tunggu 2 frame fisika supaya overlap terhitung, lalu kumpulkan musuh yang kena
	await get_tree().physics_frame
	await get_tree().physics_frame
	var from_pos: Vector2 = body_shape.global_position
	for body in sword_area.get_overlapping_bodies():
		if body == self or not body.has_method("take_damage"):
			continue
		var target := body.get_node_or_null("CollisionShape2D") as Node2D
		var to_pos: Vector2 = target.global_position if target else body.global_position
		var knock_dir := from_pos.direction_to(to_pos)
		if knock_dir == Vector2.ZERO:
			knock_dir = dir
		body.take_damage(sword_damage, knock_dir, sword_knockback)
	sword_area.set_deferred("monitoring", false)

	await get_tree().create_timer(sword_cooldown).timeout
	_can_attack = true


# Mainkan animasi aksi badan "<prefix><arah>" (attack_/hoe_/water_ + front/top/left/right).
# Return false kalau animasinya tidak ada (pemanggil bisa pakai cadangan).
func play_action_anim(prefix: String) -> bool:
	var anim_name := prefix + last_anim_direction
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		return false
	_is_swinging = true
	anim.play(anim_name)
	# Jaga-jaga kalau animation_finished tidak terpancar (mis. animasi di-set loop di editor)
	var length := float(anim.sprite_frames.get_frame_count(anim_name)) / maxf(anim.sprite_frames.get_animation_speed(anim_name), 1.0)
	get_tree().create_timer(length + 0.05).timeout.connect(_end_swing)
	return true


func _play_sword_swing(item: ItemData, dir: Vector2) -> void:
	if play_action_anim("attack_"):
		return

	# Cadangan: sprite icon pedang diputar ~120 derajat
	_sword_sprite.texture = item.icon
	_sword_sprite.position = BODY_CENTER + dir * 4.0
	# Saat menghadap atas pedang digambar di belakang badan, selain itu di depan
	move_child(_sword_sprite, 0 if last_anim_direction == "top" else get_child_count() - 1)
	# Mata pedang di icon mengarah ke kanan-atas (-45 derajat); putar supaya searah hadap, lalu sapu 120 derajat
	var center := dir.angle() + PI / 4.0
	_sword_sprite.rotation = center - deg_to_rad(60)
	_sword_sprite.visible = true
	var tw := create_tween()
	tw.tween_property(_sword_sprite, "rotation", center + deg_to_rad(60), 0.16)
	tw.tween_callback(func(): _sword_sprite.visible = false)


func _on_body_animation_finished() -> void:
	var a := String(anim.animation)
	if a.begins_with("attack_") or a.begins_with("hoe_") or a.begins_with("water_"):
		_end_swing()


func _end_swing() -> void:
	if not _is_swinging:
		return
	_is_swinging = false
	anim.play("idle_" + last_anim_direction)


func get_facing_vector() -> Vector2i:
	match last_anim_direction:
		"left":
			return Vector2i.LEFT
		"right":
			return Vector2i.RIGHT
		"top":
			return Vector2i.UP
		_:
			return Vector2i.DOWN


func check_tile_damage():
	if is_invincible or health <= 0:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is TileMapLayer:
			if collider.tile_set == null:
				continue
			if collider.tile_set.get_custom_data_layer_by_name("damage") == -1:
				continue

			var point = collision.get_position() - collision.get_normal() * 2.0
			var cell = collider.local_to_map(collider.to_local(point))
			var data = collider.get_cell_tile_data(cell)
			print("Cell: ", cell, " | data: ", data)
			if data == null:
				continue

			var tile_damage = data.get_custom_data("damage")
			print("Damage tile: ", tile_damage)
			if tile_damage > 0:
				take_damage(tile_damage, collision.get_normal(), tile_knockback_force)
				return

func update_animation(dir: Vector2):
	# Animasi serang sedang main -> jangan ditimpa animasi jalan/idle
	if _is_swinging:
		return
	if dir.x > 0:
		anim.play("walk_right")
		last_anim_direction = "right"
	elif dir.x < 0:
		anim.play("walk_left")
		last_anim_direction = "left"
	elif dir.y > 0:
		anim.play("walk_bottom")
		last_anim_direction = "front" # Sesuaikan jika nama idle kamu "idle_bottom"
	elif dir.y < 0:
		anim.play("walk_top")
		last_anim_direction = "top"   # Sesuaikan jika nama idle kamu "idle_back"
	else:
		# Mainkan animasi idle sesuai arah terakhir
		anim.play("idle_" + last_anim_direction)


func update_health_bar():
	if not health_bar:
		return

	health_bar.value = health

	# Warna berdasarkan persentase HP
	var persen = float(health) / max_health
	var warna = Color("4caf50")  # hijau
	if persen <= 0.3:
		warna = Color("e53935")  # merah
	elif persen <= 0.6:
		warna = Color("fbc02d")  # kuning

	var fill = health_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		fill.bg_color = warna


# --- Menambah HP (dipanggil saat memungut item) ---
func heal(amount: int) -> void:
	if health <= 0:
		return
	health = min(health + amount, max_health)
	update_health_bar()
	print("HP Player sekarang: ", health)

	# Kedip hijau singkat sebagai umpan balik
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(0.5, 1, 0.5, 1), 0.1)
	tw.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.2)


func take_damage(amount, knockback_dir = Vector2.ZERO, knockback_force = 0.0):
	# Abaikan damage jika sudah mati atau sedang kebal
	if health <= 0 or is_invincible:
		return

	health -= amount
	update_health_bar()

	knockback_velocity = knockback_dir * knockback_force

	print("Aduh! HP Player sekarang: ", health)

	if health <= 0:
		die()
		return

	start_invincibility()


func start_invincibility():
	is_invincible = true

	# Berkedip merah-transparan selama kebal
	if blink_tween:
		blink_tween.kill()
	blink_tween = create_tween().set_loops(int(invincibility_duration / 0.2))
	blink_tween.tween_property(anim, "modulate", Color(1, 0.4, 0.4, 0.4), 0.1)
	blink_tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)

	await get_tree().create_timer(invincibility_duration).timeout

	if blink_tween:
		blink_tween.kill()
	anim.modulate = Color(1, 1, 1, 1)
	is_invincible = false


func die():
	print("Player Mati!")

	# Hentikan efek kedip dan gerakan
	if blink_tween:
		blink_tween.kill()
	anim.modulate = Color(1, 1, 1, 1)
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	set_physics_process(false)
	visible = false

	# Matikan collision supaya slime berhenti mendeteksi player
	body_shape.set_deferred("disabled", true)

	# Tampilkan layar kematian
	if death_screen:
		death_screen.show()
	if respawn_button:
		respawn_button.grab_focus()


func respawn():
	print("Respawn!")

	# Sembunyikan layar kematian
	if death_screen:
		death_screen.hide()

	# Pulihkan HP dan posisi
	health = max_health
	update_health_bar()
	global_position = spawn_position
	knockback_velocity = Vector2.ZERO
	_is_swinging = false
	if camera:
		MapTransition.apply_camera_limits(camera, spawn_camera_limits)
		camera.reset_smoothing()
	is_invincible = false

	# Nyalakan kembali player dan collision-nya
	body_shape.set_deferred("disabled", false)
	visible = true
	set_physics_process(true)

	# Kebal sebentar setelah respawn supaya tidak langsung dipukul lagi
	start_invincibility()
