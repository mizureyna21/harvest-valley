extends CharacterBody2D

var speed = 150.0
var max_health = 100
var health = max_health

# --- Invincibility (kebal setelah kena damage) ---
@export var invincibility_duration: float = 1.0
var is_invincible = false
var blink_tween: Tween = null

# --- Knockback ---
var knockback_velocity = Vector2.ZERO
var knockback_friction = 600.0  # pakai nilai yang sudah kamu atur sebelumnya

# Menyimpan posisi awal untuk respawn
@onready var spawn_position = global_position

# Referensi node
@onready var anim = $"main character"
@onready var body_shape = $CollisionShape2D
@onready var health_bar = get_node_or_null("../HUD/Control/HealthLabel")
@onready var death_screen = get_node_or_null("../HUD/DeathScreen")
@onready var respawn_button = get_node_or_null("../HUD/DeathScreen/VBoxContainer/RespawnButton")


func _ready():
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


func _physics_process(delta):
	var direction = Vector2.ZERO

	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction.length() > 0:
		direction = direction.normalized()

	# Gerakan normal + dorongan knockback
	velocity = direction * speed + knockback_velocity
	move_and_slide()

	# Knockback melambat sampai berhenti
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

	update_animation(direction)


func update_animation(dir: Vector2):
	if dir.x > 0:
		anim.play("walk_right")
	elif dir.x < 0:
		anim.play("walk_left")
	elif dir.y > 0:
		anim.play("walk_bottom")
	elif dir.y < 0:
		anim.play("walk_top")
	else:
		anim.play("idle_front")


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
		respawn_button.grab_focus()  # bisa ditekan dengan Enter/Spasi


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
	is_invincible = false

	# Nyalakan kembali player dan collision-nya
	body_shape.set_deferred("disabled", false)
	visible = true
	set_physics_process(true)

	# Kebal sebentar setelah respawn supaya tidak langsung dipukul lagi
	start_invincibility()
