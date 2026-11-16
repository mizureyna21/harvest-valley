extends Node

signal changed

var items: Dictionary = {}  # id -> jumlah

func add_item(data: ItemData, amount := 1) -> void:
	var current: int = items.get(data.id, 0)
	items[data.id] = mini(current + amount, data.max_stack)
	changed.emit()
	print("Dapat: %s x%d (total %d)" % [data.display_name, amount, items[data.id]])


func get_count(id: StringName) -> int:
	return items.get(id, 0)


# Mengurangi item; return false (dan tidak mengubah apa pun) jika stok kurang
func remove_item(data: ItemData, amount := 1) -> bool:
	var current := get_count(data.id)
	if current < amount:
		return false
	current -= amount
	if current <= 0:
		items.erase(data.id)
	else:
		items[data.id] = current
	changed.emit()
	print("Pakai: %s x%d (sisa %d)" % [data.display_name, amount, current])
	return true
