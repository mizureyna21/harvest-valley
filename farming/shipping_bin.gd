class_name ShippingBin
extends Area2D

# Kotak pengiriman ala Stardew Valley.
# - Tekan E di dekatnya: semua item di Inventory yang punya sell_price > 0 dimasukkan ke bin
#   (alat & bibit punya sell_price 0, jadi tidak ikut).
# - Isinya baru TERJUAL saat player tidur (Bed memanggil sell_overnight() sebelum hari berganti),
#   persis alur Stardew. Di proyek ini tidur sudah jadi pembatas hari, jadi penjualan ikut di sana.
#
# Area2D di collision layer 16 supaya terdeteksi InteractArea player (pola sama dengan Bed/Forageable);
# anak StaticBody2D kecil membuat bin tidak bisa ditembus.

signal contents_changed(item_count: int)
signal sold(total_gold: int, summary: Dictionary)

# id -> {"amount": int, "price": int, "name": String}
var contents: Dictionary = {}

var _label: Label


func _ready() -> void:
	add_to_group("shipping_bin")
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true

	# Label kecil di atas bin: jumlah item yang menunggu dijual (dibangun lewat kode)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.size = Vector2(60, 12)
	_label.position = Vector2(-30, -30)
	_label.z_index = 20
	add_child(_label)
	_refresh_label()


func get_item_count() -> int:
	var n := 0
	for id in contents:
		n += int(contents[id]["amount"])
	return n


# Dipanggil player.try_collect() saat tombol E (duck typing interact(player))
func interact(_player: Node) -> void:
	var moved := 0
	for id in Inventory.items.keys():
		var data: ItemData = Inventory.item_data.get(id)
		if data == null or data.sell_price <= 0:
			continue   # alat, bibit, atau item tanpa harga tidak bisa dijual
		var amount: int = Inventory.get_count(id)
		if amount <= 0 or not Inventory.remove_item(data, amount):
			continue
		var entry: Dictionary = contents.get(id, {"amount": 0, "price": data.sell_price, "name": data.display_name})
		entry["amount"] = int(entry["amount"]) + amount
		contents[id] = entry
		moved += amount

	if moved == 0:
		print("Tidak ada barang yang bisa dijual (alat dan bibit tidak bisa masuk shipping bin)")
		return

	print("Masuk shipping bin: %d item (dijual saat tidur)" % moved)
	_refresh_label()
	contents_changed.emit(get_item_count())

	# Efek kecil: bin "menelan" barang
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", Vector2(1.1, 0.9), 0.08)
	tw.tween_property($Sprite2D, "scale", Vector2.ONE, 0.12)


# Dipanggil Bed saat layar sudah gelap, SEBELUM hari berganti. Return total gold.
func sell_overnight() -> int:
	if contents.is_empty():
		return 0
	var total := 0
	for id in contents:
		total += int(contents[id]["amount"]) * int(contents[id]["price"])
	var summary := contents.duplicate(true)
	contents.clear()
	_refresh_label()
	GameManager.add_gold(total)
	print("Shipping bin terjual: +%dg" % total)
	sold.emit(total, summary)
	contents_changed.emit(0)
	return total


func _refresh_label() -> void:
	if _label == null:
		return
	var n := get_item_count()
	_label.visible = n > 0
	_label.text = "%d item" % n
