tool
extends EditorPlugin

const FILL_LENGTH_MAX = 32

var dock
var color_picker: ColorPickerButton
var mode = "none"
var _undo_redo 

func handles(object):
	return object is VoxelChunk

func _enter_tree():
	add_custom_type("VoxelChunk", "MeshInstance", preload("voxel_chunk.gd"), preload("icon.png"))
	add_custom_type("VoxelWorld", "Spatial", preload("voxel_world.gd"), preload("icon.png"))
	
	# Dock stuff
	dock = preload("./dock.tscn").instance()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	set_input_event_forwarding_always_enabled()
	
	dock.plugin = self
	dock.get_node("Place").connect("pressed", self, "_on_place_btn_pressed")
	dock.get_node("Remove").connect("pressed", self, "_on_remove_btn_pressed")
	dock.get_node("Clear").connect("pressed", self, "_on_clear_btn_pressed")
	dock.get_node("Walls").connect("pressed", self, "_on_walls_btn_pressed")
	dock.get_node("NoTool").connect("pressed", self, "_on_no_tools_btn_pressed")
	color_picker = dock.get_node("ColorPickerButton") as ColorPickerButton
	
	_undo_redo = get_undo_redo()

func _exit_tree():
	remove_custom_type("VoxelChunk")
	remove_custom_type("VoxelWorld")
	remove_control_from_docks(dock)
	dock.free()

func _on_place_btn_pressed():
	mode = "place"

func _on_remove_btn_pressed():
	mode = "clear"

func _on_clear_btn_pressed():
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	for node in selected_nodes:
		if node is VoxelWorld:
			node.clear_world()

func _on_walls_btn_pressed():
	mode = "walls"

#RENAME THEM ALL PLS.
var last_block_position: Vector3
var last_ray_hit: Vector3
var last_normal: Vector3
var last_voxel_chunk: VoxelChunk
var last_voxel_world: VoxelWorld
var last_block_data: Dictionary
var _should_perform_filling: bool
var _block_position_first_corner: Vector3
var _block_position_second_corner: Vector3

func forward_spatial_gui_input(camera, event):
	var res = false
	if event is InputEventMouseButton:
		if event.pressed && event.button_index == 1:
			var from = camera.project_ray_origin(event.position)
			var to = from + camera.project_ray_normal(event.position) * 100
			var result = get_viewport().world.direct_space_state.intersect_ray(from, to)
			if not result: return
			
			var obj = result.collider.get_parent()
			
			var local_position = result.position - obj.global_transform.origin - result.normal
			var block_position = Vector3(int(local_position.x/2), int(local_position.y/2), int(local_position.z/2))
			if obj is VoxelChunk:
				last_normal = result.normal
				last_voxel_chunk = obj
				last_voxel_world = obj.get_parent()
				_should_perform_filling = false
				last_ray_hit = result.position 
				if mode == "place":
					block_position += result.normal
					last_block_data = obj.get_block_data(block_position)
					_undoable_set_block(obj, block_position, 1, true, color_picker.color)
				elif mode == "clear":
					last_block_data = obj.get_block_data(block_position)
					_undoable_set_block(obj, block_position, 0, true, color_picker.color)
				last_block_position = obj.chunk_position*last_voxel_world.CHUNK_SIZE + block_position
				res = true
				
				var cube = CSGBox.new()
				cube.name = "__waleed_cube_gizmo"
				cube.visible = false
				var mat = SpatialMaterial.new()
				mat.albedo_color = color_picker.color
				mat.albedo_color.a = 0.5
				mat.flags_transparent = true
				cube.material_override = mat
				get_editor_interface().get_edited_scene_root().add_child(cube)
	if not Input.is_mouse_button_pressed(1) and last_voxel_world:
		var cube = get_editor_interface().get_edited_scene_root().get_node("__waleed_cube_gizmo") as CSGBox
		
		if  _should_perform_filling:
			if mode == "place" or mode == "clear":
				_undo_redo.undo()
				_undoable_fill(last_voxel_world, _block_position_first_corner, _block_position_second_corner, 1 if mode == "place" else 0, true, color_picker.color)
			elif mode == "walls":
				_undoable_make_four_walls(last_voxel_world, _block_position_first_corner, _block_position_second_corner, int(dock.get_node("WallHeight").text), 1, true, color_picker.color)
		if cube:
			cube.queue_free()
		last_voxel_world = null
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(1) and last_voxel_world:
		var plane = Plane(last_normal, last_normal.dot(last_ray_hit-last_normal))
		var cube = get_editor_interface().get_edited_scene_root().get_node("__waleed_cube_gizmo") as CSGBox
		var from = camera.project_ray_origin(event.position)
		
		var intersection = plane.intersects_ray(from, camera.project_ray_normal(event.position))
		var block_pos = _vector_to_block_pos(intersection)
		
		_should_perform_filling = intersection and (last_ray_hit - intersection).length() > 2
		
		if _should_perform_filling:
			cube.visible = true
			var new_last_block_position = last_block_position
			if mode == "place":
				new_last_block_position -= last_normal
			var size =  _vector_comp_abs_add(block_pos-new_last_block_position, 1)*last_voxel_world.BLOCK_SIZE
			cube.width = size.x
			cube.height = size.y
			cube.depth = size.z
			cube.global_transform.origin = (block_pos + new_last_block_position) + Vector3(0.5, 0.5, 0.5)*last_voxel_world.BLOCK_SIZE #new_last_block_position*last_voxel_world.BLOCK_SIZE + size/2
			_block_position_first_corner = new_last_block_position
			_block_position_second_corner = block_pos
			
		res = true
	return res

func _vector_to_block_pos(v: Vector3):
	return Vector3(floor(v.x/2), floor(v.y/2), floor(v.z/2))

func _better_range(from: int, to: int, max_range: int):
	if from == to:
		return [from]
	var dir = sign(to - from)
	if abs(from-to) > max_range:
		to = from + max_range*dir
	return range(from, to+dir, dir)

func _vector_comp_abs_add(v: Vector3, i: int):
	return Vector3(v.x + _sign_zero_1(v.x)*i, v.y + _sign_zero_1(v.y)*i, v.z + _sign_zero_1(v.z)*i)

func _sign_zero_1(x):
	return 1 if x == 0 else sign(x)





## undoable
# chunk can be chunk or world
func _undoable_set_block(chunk, v: Vector3, id: int, update_mesh: bool, color: Color = Color.white, commit_action: bool = true):
	var block_data = chunk.get_block_data(v)
	if commit_action:
		_undo_redo.create_action("Set block")
	_undo_redo.add_do_method(chunk, "set_block", v, id, update_mesh, color)
	_undo_redo.add_undo_method(chunk, "set_block", v, block_data.id, update_mesh, block_data.color)
	if commit_action:
		_undo_redo.commit_action()

func _undoable_fill(chunk, from: Vector3, to: Vector3, id: int, update_mesh: bool, color: Color = Color.white, commit_action: bool = true):
	if commit_action:
		_undo_redo.create_action("Fill")
	for x in _better_range(from.x, to.x, FILL_LENGTH_MAX):
		for y in _better_range(from.y, to.y, FILL_LENGTH_MAX):
			for z in _better_range(from.z, to.z, FILL_LENGTH_MAX):
				_undoable_set_block(chunk, Vector3(x,y,z), id, false, color)
	if update_mesh:
		_undo_redo.add_do_method(chunk, "update_dirty_chunks")
		_undo_redo.add_undo_method(chunk, "update_dirty_chunks")
	if commit_action:
		_undo_redo.commit_action()

func _undoable_make_four_walls(chunk, from: Vector3, to: Vector3, height: int, id: int, update_mesh: bool, color: Color = Color.white, commit_action: bool = true):
	if commit_action:
		_undo_redo.create_action("Make four walls")
	var y = from.y + height -1 
	_undoable_fill(chunk, from, Vector3(from.x, y, to.z), id, false, color, false)
	_undoable_fill(chunk, from, Vector3(to.x, y, from.z), id, false, color, false)
	_undoable_fill(chunk, to, Vector3(to.x, y, from.z), id, false, color, false)
	_undoable_fill(chunk, to, Vector3(from.x, y, to.z), id, false, color, false)
	if update_mesh:
		_undo_redo.add_do_method(chunk, "update_dirty_chunks")
		_undo_redo.add_undo_method(chunk, "update_dirty_chunks")
	if commit_action:
		_undo_redo.commit_action()

#func _fill(chunk, from: Vector3, to: Vector3):
#	for x in _better_range(from.x, to.x, FILL_LENGTH_MAX):
#		for y in _better_range(from.y, to.y, FILL_LENGTH_MAX):
#			for z in _better_range(from.z, to.z, FILL_LENGTH_MAX):
#				chunk.set_block(Vector3(x,y,z), 1 if mode == "place" else 0, false, color_picker.color)
#	chunk.update_dirty_chunks()

#func _build(chunk, building, from: Vector3):
#	pass

#func _copy_blocks(chunk, from: Vector3, to: Vector3):
#	var res = 













