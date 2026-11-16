class_name SeedData
extends ItemData

# Bibit = ItemData biasa + info tanaman yang tumbuh darinya.
# Dengan begitu Crop cukup satu scene generik; jenis tanaman ditentukan oleh .tres bibitnya.

@export var product: ItemData            # hasil panen (mis. parsnip.tres)
@export var harvest_amount := 1          # jumlah hasil panen per tanaman
@export var score_value := 10            # skor yang ditambahkan saat panen

@export_group("Sprite Tanaman")
@export var crop_texture: Texture2D      # spritesheet tanaman (map/crops.png)
@export var frame_size := Vector2i(16, 32)
@export var sprite_origin := Vector2i(0, 0)  # pojok kiri-atas baris tanaman ini di spritesheet
# Index frame untuk tiap tahap: seed, sprout, growing, mature
@export var stage_frames: PackedInt32Array = [0, 2, 4, 5]
