class_name FarmingManager
extends Node

# Pusat logika bercocok tanam: alat aktif, cangkul/siram/tanam, daftar Crop, dan sistem hari.
#
# Kenapa Node manager terpisah (bukan script di TileMapLayer farmland)?
# - Logika tanah butuh membaca beberapa layer sekaligus: terrain (custom data "tillable"),
#   farmland (custom data "tilled"/"watered"), dan layer penghalang (bangunan/obstacle).
# - Sistem hari dan alat aktif tidak ada hubungannya dengan menggambar tile.
# Jadi TileMapLayer tetap murni data/visual, dan semua aturan main ada di satu tempat.
#
# Sistem hari: pakai Timer real (default 120 detik = 1 hari). Dipilih karena paling sederhana:
# tidak butuh kasur/scene tidur. Ubah day_length_seconds di Inspector (mis. 10) untuk testing.
#
# Aturan tanam: bibit boleh ditanam di tile tilled yang KERING maupun BASAH.
# Kalau ditanam di tile kering, siram setelahnya supaya tumbuh di hari berikutnya.

signal tool_changed(slot: int, item: ItemData)
signal day_changed(day: int)
signal farm_action(action: StringName, cell: Vector2i)  # &"till", &"water", &"plant", &"harvest"

const HOE_ID := &"hoe"
const WATERING_CAN_ID := &"watering_can"

# Tile di farmland_tileset.tres (source 0)
const FARMLAND_SOURCE := 0
const TILE_TILLED := Vector2i(0, 0)
const TILE_WATERED := Vector2i(1, 0)

@export var terrain_layer: TileMapLayer            # layer tanah dasar (punya custom data "tillable")
@export var farmland_layer: TileMapLayer           # layer tanah olahan (custom data "tilled"/"watered")
@export var blocking_layers: Array[TileMapLayer] = []  # tile di layer ini = tidak bisa dicangkul
@export var crop_scene: PackedScene
@export var crop_parent: Node2D                    # wadah node Crop (kosong = parent manager)

@export_group("Alat")
@export var tool_slots: Array[ItemData] = []       # slot 1, 2, 3 (cangkul, gembor, bibit)
@export var starter_seed_amount := 5               # bibit awal yang diberikan sekali

@export_group("Hari")
@export var day_length_seconds := 120.0

var active_slot := 0
var day := 1
var crops: Dictionary = {}  # Vector2i -> Crop

var _day_timer: Timer


func _ready() -> void:
	add_to_group("farming_manager")

	_day_timer = Timer.new()
	_day_timer.wait_time = day_length_seconds
	_day_timer.autostart = true
	_day_timer.timeout.connect(start_new_day)
	add_child(_day_timer)

	_give_starter_items()
	tool_changed.emit(active_slot, get_active_item())
	day_changed.emit(day)


# --- Ganti alat aktif: tombol 1 / 2 / 3 ---
func _unhandled_input(event: InputEvent) -> void:
	for i in tool_slots.size():
		var action := "tool_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return


func select_slot(slot: int) -> void:
	if slot < 0 or slot >= tool_slots.size() or slot == active_slot:
		return
	active_slot = slot
	tool_changed.emit(active_slot, get_active_item())


func get_active_item() -> ItemData:
	if active_slot < tool_slots.size():
		return tool_slots[active_slot]
	return null


func get_day_time_left() -> float:
	return _day_timer.time_left if _day_timer else 0.0


# --- Dipanggil player saat klik kiri ("attack") ---
# from_world = posisi kaki player, facing = arah hadap (Vector2i satu tile)
func use_active_tool(from_world: Vector2, facing: Vector2i) -> bool:
	if farmland_layer == null:
		return false

	var cell := farmland_layer.local_to_map(farmland_layer.to_local(from_world)) + facing
	var item := get_active_item()
	if item == null:
		return false
	if Inventory.get_count(item.id) <= 0:
		print("Tidak punya %s" % item.display_name)
		return false

	if item is SeedData:
		return try_plant(cell, item)
	elif item.id == HOE_ID:
		return try_till(cell)
	elif item.id == WATERING_CAN_ID:
		return try_water(cell)
	return false


func try_till(cell: Vector2i) -> bool:
	if is_tilled(cell):
		return false
	if not is_tillable(cell):
		print("Tile ", cell, " tidak bisa dicangkul")
		return false
	farmland_layer.set_cell(cell, FARMLAND_SOURCE, TILE_TILLED)
	farm_action.emit(&"till", cell)
	return true


func try_water(cell: Vector2i) -> bool:
	if not is_tilled(cell):
		print("Hanya tanah yang sudah dicangkul yang bisa disiram")
		return false
	if is_watered(cell):
		return false
	farmland_layer.set_cell(cell, FARMLAND_SOURCE, TILE_WATERED)
	farm_action.emit(&"water", cell)
	return true


func try_plant(cell: Vector2i, seed_item: SeedData) -> bool:
	if not is_tilled(cell):
		print("Cangkul tanahnya dulu sebelum menanam")
		return false
	if crops.has(cell):
		print("Tile ", cell, " sudah ada tanamannya")
		return false
	if crop_scene == null:
		push_warning("FarmingManager: crop_scene belum diisi")
		return false
	if not Inventory.remove_item(seed_item, 1):
		print("Bibit habis!")
		return false

	var crop: Crop = crop_scene.instantiate()
	crop.setup(seed_item, cell)
	var parent: Node = crop_parent if crop_parent else get_parent()
	parent.add_child(crop)
	crop.global_position = farmland_layer.to_global(farmland_layer.map_to_local(cell))
	crop.harvested.connect(_on_crop_harvested)
	crops[cell] = crop
	farm_action.emit(&"plant", cell)
	return true


func _on_crop_harvested(crop: Crop) -> void:
	crops.erase(crop.cell)
	# Tile kembali "tilled" (kering) dan bisa ditanami lagi
	if is_tilled(crop.cell):
		farmland_layer.set_cell(crop.cell, FARMLAND_SOURCE, TILE_TILLED)
	farm_action.emit(&"harvest", crop.cell)


# --- Pergantian hari ---
func start_new_day() -> void:
	day += 1

	# 1. Tanaman di tile basah naik satu tahap (tanaman di tile kering tidak mati, hanya diam)
	for cell in crops:
		var crop: Crop = crops[cell]
		if is_instance_valid(crop) and is_watered(cell):
			crop.grow()

	# 2. Semua tile basah kembali kering (harus disiram lagi)
	for cell in farmland_layer.get_used_cells():
		if is_watered(cell):
			farmland_layer.set_cell(cell, FARMLAND_SOURCE, TILE_TILLED)

	print("Hari ", day, " dimulai")
	day_changed.emit(day)


# Dipanggil saat tidur (Bed): ganti hari sekarang juga, lalu timer hari mulai dari awal
# supaya hari baru tidak langsung habis beberapa detik kemudian.
func skip_to_next_day() -> void:
	start_new_day()
	if _day_timer:
		_day_timer.start(day_length_seconds)


# --- Cek data tile (mengikuti pola custom data "damage" di player.gd) ---
func is_tillable(cell: Vector2i) -> bool:
	if terrain_layer == null:
		return false

	# Tile tertutup bangunan / obstacle tidak bisa dicangkul
	for layer in blocking_layers:
		if layer and layer.get_cell_source_id(_cell_on(layer, cell)) != -1:
			return false

	return _get_tile_bool(terrain_layer, _cell_on(terrain_layer, cell), "tillable")


func is_tilled(cell: Vector2i) -> bool:
	return _get_tile_bool(farmland_layer, cell, "tilled")


func is_watered(cell: Vector2i) -> bool:
	return _get_tile_bool(farmland_layer, cell, "watered")


func _get_tile_bool(layer: TileMapLayer, cell: Vector2i, data_name: String) -> bool:
	if layer == null or layer.tile_set == null:
		return false
	if layer.tile_set.get_custom_data_layer_by_name(data_name) == -1:
		return false
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return false
	return bool(data.get_custom_data(data_name))


# Konversi cell farmland -> cell di layer lain (aman walau posisi layer berbeda)
func _cell_on(layer: TileMapLayer, farmland_cell: Vector2i) -> Vector2i:
	var world := farmland_layer.to_global(farmland_layer.map_to_local(farmland_cell))
	return layer.local_to_map(layer.to_local(world))


# --- Item awal: alat + beberapa bibit, hanya sekali per sesi game ---
func _give_starter_items() -> void:
	if Inventory.has_meta("farming_starter_given"):
		return
	Inventory.set_meta("farming_starter_given", true)
	for item in tool_slots:
		if item == null:
			continue
		var amount := starter_seed_amount if item is SeedData else 1
		Inventory.add_item(item, amount)
