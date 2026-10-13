extends CharacterBody2D

@export var speed: float = 40.0
@export var detection_radius: float = 120.0
@export var stop_distance: float = 14.0
@export var knockback_force: float = 300.0
@export var attack_cooldown: float = 0.8
@export var damage: int = 10
@export var max_health: int = 3

var player = null
var is_attacking = false
var is_dead = false
var health = 3
var last_anim = "walk_bot"

# --- Variabel untuk jalan acak ---
var wander_direction = Vector2.ZERO
var wander_timer = 0.0
var is_wandering = false

# Kalau node sprite lo namanya "slime", biarin begini. Kalau "AnimatedSprite2D", juga kebaca.
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") if has_node("AnimatedSprite2D") else $slime
@onready var my_shape = $CollisionShape2D
@onready var detection_shape = $DetectionArea/CollisionShape2D


func _ready():
	# Mode top-down: tidak ada gravitasi/lantai
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	health = max_health

	# Buat shape unik lalu atur radius deteksi dari variabel
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	detection_shape.shape = circle

	# Sambungin sinyal lewat kode (dicek dulu biar nggak dobel kalau udah nyambung di editor)
	var det = $DetectionArea
	if not det.body_entered.is_connected(_on_detection_area_body_entered):
		det.body_entered.connect(_on_detection_area_body_entered)
	if not det.body_exited.is_connected(_on_detection_area_body_exited):
		det.body_exited.connect(_on_detection_area_body_exited)
	var hit = $HitboxArea
	if not hit.body_entered.is_connected(_on_hitbox_area_body_entered):
		hit.body_entered.connect(_on_hitbox_area_body_entered)

	anim.play(last_anim)
	anim.pause()


func _physics_process(delta):
	if is_dead:
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player:
		# --- LOGIKA MENGEJAR PLAYER ---
		var my_pos = my_shape.global_position
		var target_pos = player.get_node("CollisionShape2D").global_position
		var direction = my_pos.direction_to(target_pos)
		var jarak = my_pos.distance_to(target_pos)

		# Berhenti jika sudah dekat agar tidak menumpuk di Player
		if jarak > stop_distance:
			velocity = direction * speed
			_play_walk(direction)
		else:
			velocity = Vector2.ZERO
			anim.pause()
	else:
		# --- LOGIKA JALAN SENDIRI (WANDER) ACAK ---
		wander_timer -= delta

		if wander_timer <= 0:
			# 50% jalan, 50% diam
			is_wandering = randi() % 2 == 0

			if is_wandering:
				wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			else:
				wander_direction = Vector2.ZERO

			# Durasi aksi 1 sampai 3 detik
			wander_timer = randf_range(1.0, 3.0)

		velocity = wander_direction * (speed / 2)

		if is_wandering:
			_play_walk(wander_direction)
		else:
			anim.pause()   # diam di frame terakhir, hadap arah terakhir

	move_and_slide()


# Pilih animasi sesuai arah gerak dominan
func _play_walk(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		last_anim = "walk_left" if dir.x > 0 else "walk_right"
	else:
		last_anim = "walk_bot" if dir.y > 0 else "walk_top"
	if anim.animation != last_anim or not anim.is_playing():
		anim.play(last_anim)


# --- SINYAL DETECTION AREA ---
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player = body


func _on_detection_area_body_exited(body):
	if body == player:
		player = null


# --- SINYAL HITBOX AREA ---
func _on_hitbox_area_body_entered(body):
	if body.name == "Player" and not is_attacking and not is_dead:
		is_attacking = true

		if body.has_method("take_damage"):
			# Arah dorongan: dari ghost menuju Player
			var from_pos = my_shape.global_position
			var to_pos = body.get_node("CollisionShape2D").global_position
			var knock_dir = from_pos.direction_to(to_pos)
			body.take_damage(damage, knock_dir, knockback_force)

		await get_tree().create_timer(attack_cooldown).timeout
		is_attacking = false


# --- KALAU GHOST DISERANG ---
func take_damage(amount := 1, _knock_dir := Vector2.ZERO, _force := 0.0):
	if is_dead:
		return
	health -= amount
	anim.modulate = Color(1, 1, 1, 0.4)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = Color(1, 1, 1, 1)
	if health <= 0:
		die()


func die():
	is_dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$DetectionArea.set_deferred("monitoring", false)
	$HitboxArea.set_deferred("monitoring", false)
	anim.play("death_animation")
	await anim.animation_finished
	queue_free()
