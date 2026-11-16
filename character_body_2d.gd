extends CharacterBody2D

@export var speed: float = 40.0
@export var detection_radius: float = 120.0
@export var stop_distance: float = 14.0
@export var knockback_force: float = 300.0
@export var attack_cooldown: float = 0.8

# --- Bisa diserang (interface sama dengan ghost.gd: take_damage + die) ---
@export var max_health: int = 2
@export var score_value: int = 5          # skor yang didapat player saat slime mati
@export var knockback_friction: float = 600.0

var player = null
var is_attacking = false
var is_dead = false
var health = 2
var knockback_velocity = Vector2.ZERO

# --- Variabel untuk jalan acak ---
var wander_direction = Vector2.ZERO
var wander_timer = 0.0
var is_wandering = false

@onready var anim = $slime
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


func _physics_process(delta):
	if is_dead:
		return

	if is_attacking:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
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
		else:
			velocity = Vector2.ZERO

		anim.flip_h = direction.x < 0
		anim.play("move")
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
			if velocity.x < 0:
				anim.flip_h = true
			elif velocity.x > 0:
				anim.flip_h = false
			anim.play("move")
		else:
			anim.play("idle")

	# Dorongan knockback (saat kena pedang) ditambahkan ke gerak normal lalu melambat
	velocity += knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)


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
		anim.play("attack")

		if body.has_method("take_damage"):
			# Arah dorongan: dari slime menuju Player
			var from_pos = my_shape.global_position
			var to_pos = body.get_node("CollisionShape2D").global_position
			var knock_dir = from_pos.direction_to(to_pos)
			body.take_damage(10, knock_dir, knockback_force)

		await get_tree().create_timer(attack_cooldown).timeout
		is_attacking = false


# --- KALAU SLIME DISERANG (dipanggil pedang player) ---
func take_damage(amount := 1, knock_dir := Vector2.ZERO, force := 0.0):
	if is_dead:
		return
	health -= amount
	knockback_velocity = knock_dir * force

	# Kedip merah singkat
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(1, 0.3, 0.3, 0.6), 0.05)
	tw.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)

	if health <= 0:
		die()


func die():
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$DetectionArea.set_deferred("monitoring", false)
	$HitboxArea.set_deferred("monitoring", false)
	GameManager.add_score(score_value)

	# Animasi mati di SpriteFrames di-set loop, jadi animation_finished tidak pernah terpancar.
	# Tunggu sesuai durasi satu putaran animasi, lalu hapus.
	var wait := 0.3
	if anim.sprite_frames and anim.sprite_frames.has_animation("death_animation"):
		anim.play("death_animation")
		wait = _animation_length(anim, "death_animation")
	await get_tree().create_timer(wait).timeout
	queue_free()


static func _animation_length(sprite: AnimatedSprite2D, anim_name: StringName) -> float:
	var frames := sprite.sprite_frames
	var fps := frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.3
	var total := 0.0
	for i in frames.get_frame_count(anim_name):
		total += frames.get_frame_duration(anim_name, i)
	return total / (fps * absf(sprite.speed_scale if sprite.speed_scale != 0.0 else 1.0))
