tool
extends Control

signal convert_to_mesh_button_pressed
signal schematic_changed

var plugin
var wall_height setget ,_get_wall_height

func _get_wall_height():
	return int($VBoxContainer/WallHeight.text)

func _on_Place_pressed():
	plugin.mode = "place"

func _on_Remove_pressed():
	plugin.mode = "clear"

func _on_Clear_pressed():
	var selected_nodes = plugin.get_editor_interface().get_selection().get_selected_nodes()
	for node in selected_nodes:
		if node is VoxelWorld:
			node.clear_world()

func _on_Walls_pressed():
	plugin.mode = "walls"

func _on_NoTool_pressed():
	plugin.mode = "none"

func _on_Palette_color_changed(color):
	plugin.building_color = color

func _on_SelectionTool_pressed():
	plugin.mode = "select"

func _on_ConvertToMesh_pressed():
	emit_signal("convert_to_mesh_button_pressed")

func _on_Schematics_schematic_changed(schema):
	emit_signal("schematic_changed", schema)
