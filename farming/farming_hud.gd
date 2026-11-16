extends Control

# HUD bercocok tanam: label "Hari X" + hotbar 3 slot (ikon, nama alat, jumlah).
# UI dibangun lewat kode supaya di scene cukup satu node Control.
# Semua node memakai MOUSE_FILTER_IGNORE agar klik kiri tetap sampai ke player (_unhandled_input).

@export var farming_manager: FarmingManager

var _day_label: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_names: Array[Label] = []
var _slot_counts: Array[Label] = []
var _slot_icons: Array[TextureRect] = []

var _style_normal := StyleBoxFlat.new()
var _style_active := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_style_normal.bg_color = Color(0, 0, 0, 0.55)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.3, 0.3, 0.3, 0.8)
	_style_normal.set_corner_radius_all(4)
	_style_normal.set_content_margin_all(4)
	_style_active = _style_normal.duplicate()
	_style_active.border_color = Color("fbc02d")
	_style_active.bg_color = Color(0.25, 0.2, 0.05, 0.75)

	_build_ui()

	Inventory.changed.connect(_refresh_slots)
	if farming_manager:
		farming_manager.tool_changed.connect(_on_tool_changed)
		farming_manager.day_changed.connect(_on_day_changed)
		_on_day_changed(farming_manager.day)
	_refresh_slots()


func _process(_delta: float) -> void:
	if farming_manager and _day_label:
		var left := int(ceil(farming_manager.get_day_time_left()))
		_day_label.text = "Hari %d   %02d:%02d" % [farming_manager.day, floori(left / 60.0), left % 60]


func _build_ui() -> void:
	# Label hari di bawah bar HP (kiri atas)
	_day_label = Label.new()
	_day_label.position = Vector2(12, 46)
	_day_label.add_theme_font_size_override("font_size", 18)
	_day_label.add_theme_constant_override("outline_size", 4)
	_day_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_day_label)

	# Hotbar di tengah bawah
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 6)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)

	var slot_count := farming_manager.tool_slots.size() if farming_manager else 0
	for i in slot_count:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(76, 0)
		bar.add_child(panel)

		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)

		var key_label := _make_label("[%d]" % (i + 1), 11)
		box.add_child(key_label)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(icon)

		var name_label := _make_label("", 12)
		box.add_child(name_label)
		var count_label := _make_label("", 12)
		box.add_child(count_label)

		_slot_panels.append(panel)
		_slot_icons.append(icon)
		_slot_names.append(name_label)
		_slot_counts.append(count_label)

	# Ukuran hotbar baru diketahui setelah anak-anaknya masuk
	bar.reset_size()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)


func _make_label(t: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _refresh_slots() -> void:
	if farming_manager == null:
		return
	for i in _slot_panels.size():
		var item: ItemData = farming_manager.tool_slots[i]
		var active := i == farming_manager.active_slot
		_slot_panels[i].add_theme_stylebox_override("panel", _style_active if active else _style_normal)
		if item == null:
			continue
		var count := Inventory.get_count(item.id)
		_slot_icons[i].texture = item.icon
		_slot_icons[i].modulate = Color.WHITE if count > 0 else Color(1, 1, 1, 0.3)
		_slot_names[i].text = item.display_name
		# Jumlah hanya relevan untuk bibit; alat cukup tampil nama
		_slot_counts[i].text = "x%d" % count if item is SeedData else ""


func _on_tool_changed(_slot: int, _item: ItemData) -> void:
	_refresh_slots()


func _on_day_changed(_day: int) -> void:
	_refresh_slots()
