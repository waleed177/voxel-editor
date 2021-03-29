tool
extends Tabs

var Palette = preload("../../palette.gd")
onready var palette_container = $MarginContainer/VBoxContainer/GridContainer
onready var color_picker_popup = $ColorPickerPopup

signal color_changed

const MAX_PALETTE_SIZE = 16
const DEFAULT_PALETTE_PATH = "res://addons/waleed_voxels/default_palette.tres"
var _selected_button: TextureButton = null
var _selected_button_index: int = -1

var _palette_colors: PoolColorArray

func _ready():
	if ResourceLoader.exists(DEFAULT_PALETTE_PATH):
		var _palette = load(DEFAULT_PALETTE_PATH)
		_palette_colors = _palette.colors
	else:
		_palette_colors = PoolColorArray()
		for i in MAX_PALETTE_SIZE:
			_palette_colors.append(Color.white)
	for i in MAX_PALETTE_SIZE:
		var texture_button = TextureButton.new()
		texture_button.texture_normal = preload("res://addons/waleed_voxels/images/16.png")
		texture_button.modulate = _palette_colors[i]
		texture_button.connect("gui_input", self, "_on_texture_button_gui_input", [texture_button, i])
		palette_container.add_child(texture_button)

func _on_texture_button_gui_input(event, texture_button: TextureButton, i):
	if event is InputEventMouseButton and event.pressed:
		_selected_button_index = i
		match event.button_index:
			BUTTON_LEFT:
				emit_signal("color_changed", texture_button.modulate)
			BUTTON_RIGHT:
				color_picker_popup.rect_global_position = texture_button.rect_global_position
				color_picker_popup.popup()
				_selected_button = texture_button

func _on_ColorPicker_color_changed(color):
	_selected_button.modulate = color
	_palette_colors[_selected_button_index] = color
	var palette = Palette.new()
	palette.name = "default"
	palette.colors = _palette_colors
	ResourceSaver.save(DEFAULT_PALETTE_PATH, palette)
