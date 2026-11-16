extends Node

# Ekonomi ala Stardew: yang dikumpulkan player adalah GOLD (uang), bukan skor.
# Gold didapat dari menjual barang lewat Shipping Bin (dijual saat tidur) dan drop musuh.
# Semua sumber uang lewat add_gold() supaya HUD cukup mendengarkan satu sinyal.

signal gold_changed(new_gold: int)

var gold: int = 0

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	print("Gold: ", gold)

func reset_gold() -> void:
	gold = 0
	gold_changed.emit(gold)
