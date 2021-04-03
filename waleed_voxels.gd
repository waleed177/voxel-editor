tool
extends EditorPlugin

const FILL_LENGTH_MAX = 32

var dock
var mode = "none" setget set_mode
func set_mode(val):
	mode = val
	if mode == "none" and _get_cube_gizmo():
		_get_cube_gizmo().queue_free()
var _undo_redo: UndoRedo
var building_color: Color = Color.white
var _selection: VoxelSelectionInformation = VoxelSelectionInformation.new()
var schema_to_place: VoxelSchematic
var _hold_and_drag_on_top: bool = true
var _single_click_on_top: bool = true

func handles(object):
	return object is VoxelChunk

func _enter_tree():
	add_custom_type("VoxelChunk", "MeshInstance", preload("voxel_chunk.gd"), null)
	add_custom_type("VoxelWorld", "Spatial", preload("voxel_world.gd"), null)
	
	# Dock stuff
	dock = preload("./ui/dock/dock.tscn").instance()
	dock.plugin = self
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	dock.connect("convert_to_mesh_button_pressed", self, "_on_convert_to_mesh_button_pressed")
	dock.connect("schematic_changed", self, "_on_schematic_changed")
	dock.connect("fill_button_pressed", self, "_on_fill_button_pressed")
	dock.connect("hold_and_drag_on_top_changed", self, "_on_hold_and_drag_on_top_changed")
	dock.connect("single_click_on_top_changed", self, "_on_single_click_on_top_changed")
	set_input_event_forwarding_always_enabled()

	_undo_redo = get_undo_redo()

func _on_hold_and_drag_on_top_changed(button_pressed):
	_hold_and_drag_on_top = button_pressed

func _on_single_click_on_top_changed(button_pressed):
	_single_click_on_top = button_pressed

func _on_schematic_changed(schema):
	self.schema_to_place = schema
	mode = "place_schematic"

func _on_convert_to_mesh_button_pressed():
	_undo_redo.create_action("convert to mesh")
	var mesh = make_region_a_mesh_instance(_selection.voxel_world, _selection.first_corner, _selection.second_corner)
	_undo_redo.add_do_method(get_editor_interface().get_edited_scene_root(), "add_child", mesh)
	_undo_redo.add_undo_method(get_editor_interface().get_edited_scene_root(), "remove_child", mesh)
	
	_undo_redo.add_do_reference(mesh)
	_undo_redo.add_do_property(mesh, "owner", get_editor_interface().get_edited_scene_root())
	_undo_redo.add_undo_property(mesh, "owner", mesh.owner)

	_undoable_fill(_selection.voxel_world, _selection.first_corner, _selection.second_corner, 0, true, Color.white, false)
	
	_undo_redo.add_do_method(self, "_change_position_of_object", mesh, VoxelUtils.vector_min_coord(_selection.first_corner, _selection.second_corner) * _selection.voxel_world.BLOCK_SIZE)
	_undo_redo.commit_action()

func _on_fill_button_pressed():
	_undoable_fill(_selection.voxel_world, _selection.first_corner, _selection.second_corner, 1, true, building_color)
	

func _change_position_of_object(obj, position):
	obj.global_transform.origin = position

func _exit_tree():
	remove_custom_type("VoxelChunk")
	remove_custom_type("VoxelWorld")
	remove_control_from_docks(dock)
	dock.free()

func forward_spatial_gui_input(camera, event):
	var res = false
	if mode == "none":
		return false
	if event is InputEventMouseButton:
		if event.pressed && event.button_index == 1:
			var from = camera.project_ray_origin(event.position)
			var to = from + camera.project_ray_normal(event.position) * 100
			var result = get_viewport().world.direct_space_state.intersect_ray(from, to)
			if not result: return false
			
			var obj = result.collider.get_parent()
			
			var local_position = result.position - obj.global_transform.origin - result.normal
			var block_position = Vector3(int(local_position.x/2), int(local_position.y/2), int(local_position.z/2))
			if obj is VoxelChunk:
				_selection.ray_normal = result.normal
				_selection.ray_hit = result.position 
				_selection.voxel_chunk = obj
				_selection.voxel_world = obj.get_parent()
				_selection.should_perform_filling = false
				_selection.block_position = obj.chunk_position*_selection.voxel_world.CHUNK_SIZE + block_position

				if mode == "place":
					if _single_click_on_top:
						_selection.block_position += result.normal
					_selection.block_data = _selection.voxel_world.get_block_data(_selection.block_position)
					_undoable_set_block(_selection.voxel_world, _selection.block_position, 1, true, building_color)
					res = true
				elif mode == "clear":
					_selection.block_data = _selection.voxel_world.get_block_data(_selection.block_position)
					_undoable_set_block(_selection.voxel_world, _selection.block_position, 0, true, building_color)
					res = true
				elif mode == "place_schematic":
					if _single_click_on_top:
						_selection.block_position += result.normal
					_undoable_place_chunk(_selection.voxel_world, schema_to_place, _selection.block_position)
					res = true
					
				
				if mode != "none":
					var cube = CSGBox.new()
					cube.name = "__waleed_cube_gizmo"
					cube.visible = false
					var mat = SpatialMaterial.new()
					mat.albedo_color = building_color
					mat.albedo_color.a = 0.5
					mat.flags_transparent = true
					cube.material_override = mat
					get_editor_interface().get_edited_scene_root().add_child(cube)
		if event is InputEventMouseButton and mode == "select":
			if event.button_index == BUTTON_WHEEL_UP:
				if event.pressed:
					_selection.second_corner += _selection.ray_normal
					_update_selection()
				res = true
			if event.button_index == BUTTON_WHEEL_DOWN:
				if event.pressed:
					_selection.second_corner -= _selection.ray_normal
					_update_selection()
				res = true
	if not Input.is_mouse_button_pressed(1) and _selection.voxel_world:
		var cube = _get_cube_gizmo()
		
		if  _selection.should_perform_filling:
			if mode == "place" or mode == "clear":
				_undoable_fill(_selection.voxel_world, _selection.first_corner, _selection.second_corner, 1 if mode == "place" else 0, true, building_color)
			elif mode == "walls":
				_undoable_make_four_walls(_selection.voxel_world, _selection.first_corner, _selection.second_corner, dock.wall_height, 1, true, building_color)
		
		if mode == "select":
			pass
		else:
			if cube:
				cube.queue_free()
			_selection.voxel_world = null
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(1) and _selection.voxel_world:
		var hit_offset = (_selection.voxel_world.BLOCK_SIZE/2) * _selection.ray_normal
		if not _hold_and_drag_on_top or mode == "clear":
			hit_offset *= -1
		var plane = Plane(
			_selection.ray_normal, 
			_selection.ray_normal.dot(
				_selection.ray_hit + hit_offset
			)
		)
		var cube = _get_cube_gizmo()
		var from = camera.project_ray_origin(event.position)
		
		var intersection = plane.intersects_ray(from, camera.project_ray_normal(event.position))
		if not intersection:
			print("No intersection while dragging")
			return false
		var block_pos = _vector_to_block_pos(intersection)
		
		_selection.should_perform_filling = mode != "none" and intersection and (_selection.ray_hit - intersection).length() > 2
		
		if _selection.should_perform_filling:
			if cube and not cube.visible:
				if mode == "place":
					_undo_redo.undo()
				cube.visible = true
			_selection.first_corner = _selection.block_position
			if mode == "place" and not _hold_and_drag_on_top:
				_selection.first_corner -= _selection.ray_normal
			_selection.second_corner = block_pos
			_update_selection()
		else:
			if cube and cube.visible:
				if mode == "place":
					_undo_redo.redo()
				cube.visible = false
		res = true
	return res

func _update_selection():
	var cube = _get_cube_gizmo()
	var size = VoxelUtils.vector_comp_abs_add(_selection.second_corner-_selection.first_corner, 1)*_selection.voxel_world.BLOCK_SIZE
	cube.width = size.x + sign(size.x)*0.2
	cube.height = size.y + sign(size.y)*0.2
	cube.depth = size.z + sign(size.z)*0.2
	cube.invert_faces = sign(cube.width) * sign(cube.height) * sign(cube.depth) < 0
	cube.global_transform.origin = (_selection.second_corner + _selection.first_corner) + Vector3(0.5, 0.5, 0.5)*_selection.voxel_world.BLOCK_SIZE #new__selection.block_position*_selection.voxel_world.BLOCK_SIZE + size/2

func _get_cube_gizmo():
	return get_editor_interface().get_edited_scene_root().get_node_or_null("__waleed_cube_gizmo")

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

func make_region_a_mesh_instance(world, from: Vector3, to: Vector3, as_chunk: bool = false):
	var size = VoxelUtils.vector_abs(to-from) + Vector3(1,1,1)
	var chunk = VoxelChunk.new()
	chunk.setup(size)
	var origin = Vector3(min(from.x, to.x), min(from.y, to.y), min(from.z, to.z))
	print(_better_range(from.z, to.z, FILL_LENGTH_MAX))
	
	for z in _better_range(from.z, to.z, FILL_LENGTH_MAX):
		for y in _better_range(from.y, to.y, FILL_LENGTH_MAX):
			for x in _better_range(from.x, to.x, FILL_LENGTH_MAX):
				var v = Vector3(x,y,z)
				var _v = v - origin
				chunk.set_block_data(_v, world.get_block_data(v), false)
	chunk.update_mesh()
	if not as_chunk:
		chunk.set_script(null)
	return chunk

func _undoable_place_chunk(world, chunk, position: Vector3, commit_action = true):
	if commit_action:
		_undo_redo.create_action("Place Schematic")
	
	for z in range(0, chunk.chunk_size.z):
		for y in range(0, chunk.chunk_size.y):
			for x in range(0, chunk.chunk_size.x):
				var v = Vector3(x,y,z)
				var block = chunk.get_block_data(v)
				_undoable_set_block(world, v+position, block.id, false, block.color)
	
	_undo_redo.add_do_method(world, "update_mesh")
	_undo_redo.add_undo_method(world, "update_mesh")
	
	if commit_action:
		_undo_redo.commit_action()

func convert_selection_to_mesh(as_chunk: bool= false):
	return make_region_a_mesh_instance(_selection.voxel_world, _selection.first_corner, _selection.second_corner, as_chunk)

func _vector_to_block_pos(v: Vector3):
	return Vector3(floor(v.x/_selection.voxel_world.BLOCK_SIZE), floor(v.y/_selection.voxel_world.BLOCK_SIZE), floor(v.z/_selection.voxel_world.BLOCK_SIZE))

func _better_range(from: int, to: int, max_range: int):
	if from == to:
		return [from]
	var dir = sign(to - from)
	if abs(from-to) > max_range:
		to = from + max_range*dir
	return range(from, to+dir, dir)

