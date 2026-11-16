class_name Crop
extends Area2D

# Tanaman di atas satu tile farmland.
# Extends Area2D di collision layer "forageable" (16) supaya terdeteksi oleh
# InteractArea milik player, sama seperti Forageable.

signal harvested(crop: Crop)

enum Stage { SEED, SPROUT, GROWING, MATURE }

@export var seed_data: SeedData

var stage: int = Stage.SEED
var cell := Vector2i.ZERO      # koordinat tile farmland tempat tanaman ini
var is_harvested := false

@onready var sprite: Sprite2D = $Sprite2D


func setup(data: SeedData, at_cell: Vector2i) -> void:
	seed_data = data
	cell = at_cell


func _ready() -> void:
	add_to_group("crop")
	update_sprite()

	# Efek "muncul" kecil saat ditanam
	scale = Vector2(0.6, 0.6)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)


# Dipanggil FarmingManager di awal hari baru (hanya jika tile-nya disiram)
func grow() -> void:
	if stage >= Stage.MATURE:
		return
	stage += 1
	update_sprite()

	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.1)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.15)


func is_mature() -> bool:
	return stage == Stage.MATURE


func can_harvest() -> bool:
	return is_mature() and not is_harvested


func harvest() -> void:
	if not can_harvest():
		return
	is_harvested = true

	# Hasil panen hanya masuk inventory; uang didapat dengan menjualnya lewat Shipping Bin
	if seed_data and seed_data.product:
		Inventory.add_item(seed_data.product, seed_data.harvest_amount)

	harvested.emit(self)

	# Efek panen: naik + memudar, lalu hapus (mengikuti pola Forageable)
	set_deferred("monitorable", false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 12, 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)


func update_sprite() -> void:
	if sprite == null or seed_data == null or seed_data.crop_texture == null:
		return
	if seed_data.stage_frames.is_empty():
		return

	var idx := clampi(stage, 0, seed_data.stage_frames.size() - 1)
	var frame := seed_data.stage_frames[idx]
	var size := Vector2(seed_data.frame_size)

	sprite.texture = seed_data.crop_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(seed_data.sprite_origin) + Vector2(frame * size.x, 0), size)
	# Geser ke atas supaya bagian bawah sprite pas di bawah tile (tile 16px)
	sprite.offset = Vector2(0, 8 - size.y / 2.0)
