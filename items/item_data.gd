class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var max_stack := 99
@export var heal_amount := 10
# Harga jual di Shipping Bin (gold per item). 0 = tidak bisa dijual (alat, bibit).
@export var sell_price := 0
