tool
extends Control

var plugin

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
