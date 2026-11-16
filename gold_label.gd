extends Label

# Label HUD "Gold: X". File ini hasil rename label skor lama supaya nama sesuai isinya
# (UID file tetap sama, jadi referensi di node_2d.tscn cukup ganti path).

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(GameManager.gold)

func _on_gold_changed(new_gold: int) -> void:
	text = "Gold: %d" % new_gold
