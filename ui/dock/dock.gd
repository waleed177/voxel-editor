tool
extends Control

signal convert_to_mesh_button_pressed
signal schematic_changed
signal fill_button_pressed
signal single_click_on_top_changed
signal hold_and_drag_on_top_changed

var plugin
var wall_height setget ,_get_wall_height

func _get_wall_height():
	return int($VBoxContainer/WallHeight.text)

func _on_Place_pressed():
	plugin.mode = "place"
	plugin._selection.reset()

func _on_Remove_pressed():
	plugin.mode = "clear"
	plugin._selection.reset()

func _on_Clear_pressed():
	var selected_nodes = plugin.get_editor_interface().get_selection().get_selected_nodes()
	for node in selected_nodes:
		if node is VoxelWorld:
			node.clear_world()
	plugin._selection.reset()

func _on_Walls_pressed():
	plugin.mode = "walls"
	plugin._selection.reset()

func _on_NoTool_pressed():
	plugin.mode = "none"
	plugin._selection.reset()

func _on_Palette_color_changed(color):
	plugin.building_color = color

func _on_SelectionTool_pressed():
	plugin.mode = "select"
	plugin._selection.reset()

func _on_ConvertToMesh_pressed():
	emit_signal("convert_to_mesh_button_pressed")

func _on_Schematics_schematic_changed(schema):
	emit_signal("schematic_changed", schema)

func _on_Fill_pressed():
	emit_signal("fill_button_pressed")

func _on_SingleClickOnTopCheckBox_toggled(button_pressed):
	emit_signal("single_click_on_top_changed", button_pressed)

func _on_HoldAndDragOnTopCheckBox_toggled(button_pressed):
	emit_signal("hold_and_drag_on_top_changed", button_pressed)
