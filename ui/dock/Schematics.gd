tool
extends Tabs

const SCHEMATICS_PATH = "res://addons/waleed_voxels/schematics/"
onready var _grid_container = $MarginContainer2/VBoxContainer/GridContainer
onready var plugin = get_node("../../../").plugin
onready var _schematic_name_txt = $MarginContainer2/VBoxContainer/SchematicName

signal schematic_changed

func list_files_in_directory(path):
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			files.append(file)

	dir.list_dir_end()

	return files

func _ready():
	refresh()

func refresh():
	var files = list_files_in_directory(SCHEMATICS_PATH)
	for child in _grid_container.get_children():
		child.queue_free()
	for i in len(files):
		var file_name = files[i]
		var button = Button.new()
		button.rect_min_size = Vector2(32, 32)
		button.text = file_name
		_grid_container.add_child(button)
		button.connect("pressed", self, "_on_schematic_button_pressed", [file_name])

func _on_schematic_button_pressed(file_name):
	emit_signal("schematic_changed", ResourceLoader.load(SCHEMATICS_PATH + file_name))

func _on_SaveToSchematic_pressed():
	var chunk = plugin.convert_selection_to_mesh(true)
	var schema = VoxelSchematic.new()
	schema._block_ids = chunk._block_ids
	schema._block_colors = chunk._block_colors
	schema.chunk_size = chunk.chunk_size
	ResourceSaver.save("res://addons/waleed_voxels/schematics/" + _schematic_name_txt.text + ".tres", schema)
	refresh()
	
