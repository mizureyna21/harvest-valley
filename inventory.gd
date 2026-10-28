extends Node

signal changed

var items: Dictionary = {}  # id -> jumlah

func add_item(data: ItemData, amount := 1) -> void:
	var current: int = items.get(data.id, 0)
	items[data.id] = mini(current + amount, data.max_stack)
	changed.emit()
	print("Dapat: %s x%d (total %d)" % [data.display_name, amount, items[data.id]])
