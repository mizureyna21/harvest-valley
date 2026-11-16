class_name Forageable
extends Area2D

@export var item: ItemData
@export var amount := 1
# false = pakai texture Sprite2D dari scene (mis. kado.tscn bergambar kotak kado), bukan icon item
@export var use_item_icon := true

var collected := false

func _ready() -> void:
	add_to_group("forageable")
	if item and use_item_icon:
		$Sprite2D.texture = item.icon

func collect() -> void:
	if collected:
		return
	collected = true
	Inventory.add_item(item, amount)
	var player := get_tree().get_first_node_in_group("player")
	# Item tanpa heal (mis. bibit dari kado) tidak memicu efek heal
	if player and item.heal_amount > 0:
		player.heal(item.heal_amount * amount)
	set_deferred("monitorable", false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 12, 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
