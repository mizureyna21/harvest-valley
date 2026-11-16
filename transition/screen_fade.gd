class_name ScreenFade
extends CanvasLayer

# Layar hitam penuh untuk transisi antar-map (fade out -> teleport -> fade in).
# Satu instance di scene (grup "screen_fade"). Kalau belum ada, MapTransition membuatnya otomatis.

@export var color := Color.BLACK

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	add_to_group("screen_fade")
	layer = 5  # di atas HUD (layer 1) supaya seluruh layar ikut gelap
	_rect = ColorRect.new()
	_rect.color = color
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


# Ubah kegelapan layar ke `alpha` (0 = terang, 1 = gelap) dalam `duration` detik
func fade_to(alpha: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", alpha, duration)
	await _tween.finished


static func get_instance(tree: SceneTree) -> ScreenFade:
	var existing := tree.get_first_node_in_group("screen_fade") as ScreenFade
	if existing:
		return existing
	var fade := ScreenFade.new()
	tree.current_scene.add_child(fade)
	return fade
