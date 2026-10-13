extends CharacterBody2D

@export var speed: float = 40.0
@export var detection_radius: float = 120.0
@export var stop_distance: float = 14.0
@export var knockback_force: float = 300.0
@export var attack_cooldown: float = 0.8

var player = null
var is_attacking = false

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

	# Buat shape unik lalu atur radius deteksi dari variabel
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	detection_shape.shape = circle


func _physics_process(delta):
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

	move_and_slide()


# --- SINYAL DETECTION AREA ---
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player = body


func _on_detection_area_body_exited(body):
	if body == player:
		player = null


# --- SINYAL HITBOX AREA ---
func _on_hitbox_area_body_entered(body):
	if body.name == "Player" and not is_attacking:
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
