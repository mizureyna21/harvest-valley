class_name Forageable
extends Area2D

@export var item: ItemData
@export var amount := 1

var collected := false

func _ready() -> void:
	add_to_group("forageable")
	if item:
		$Sprite2D.texture = item.icon

func collect() -> void:
	if collected:
		return
	collected = true
	Inventory.add_item(item, amount)
	GameManager.add_score(item.score_value * amount)
	set_deferred("monitorable", false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 12, 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
