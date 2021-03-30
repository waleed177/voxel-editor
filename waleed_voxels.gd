tool
extends EditorPlugin

const FILL_LENGTH_MAX = 32

var dock
var mode = "none"
var _undo_redo: UndoRedo
var building_color: Color = Color.white

func handles(object):
	return object is VoxelChunk

func _enter_tree():
	add_custom_type("VoxelChunk", "MeshInstance", preload("voxel_chunk.gd"), preload("icon.png"))
	add_custom_type("VoxelWorld", "Spatial", preload("voxel_world.gd"), preload("icon.png"))
	
	# Dock stuff
	dock = preload("./ui/dock/dock.tscn").instance()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	set_input_event_forwarding_always_enabled()
	dock.connect("convert_to_mesh_button_pressed", self, "_on_convert_to_mesh_button_pressed")
	
	dock.plugin = self

	_undo_redo = get_undo_redo()

func _print(st):
	print(st)

func _on_convert_to_mesh_button_pressed():
	_undo_redo.create_action("convert to mesh")
	var mesh = make_region_a_mesh_instance(last_voxel_world, _block_position_first_corner, _block_position_second_corner)
	_undo_redo.add_do_method(get_editor_interface().get_edited_scene_root(), "add_child", mesh)
	_undo_redo.add_undo_method(get_editor_interface().get_edited_scene_root(), "remove_child", mesh)
	
	_undo_redo.add_do_reference(mesh)
	_undo_redo.add_do_property(mesh, "owner", get_editor_interface().get_edited_scene_root())
	_undo_redo.add_undo_property(mesh, "owner", mesh.owner)

	_undoable_fill(last_voxel_world, _block_position_first_corner, _block_position_second_corner, 0, true, Color.white, false)
	
	_undo_redo.add_do_method(self, "_change_position_of_object", mesh, _vector_min_coord(_block_position_first_corner, _block_position_second_corner) * last_voxel_world.BLOCK_SIZE)
	_undo_redo.commit_action()

func _change_position_of_object(obj, position):
	obj.global_transform.origin = position


func _exit_tree():
	remove_custom_type("VoxelChunk")
	remove_custom_type("VoxelWorld")
	remove_control_from_docks(dock)
	dock.free()

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
					_undoable_set_block(obj, block_position, 1, true, building_color)
				elif mode == "clear":
					last_block_data = obj.get_block_data(block_position)
					_undoable_set_block(obj, block_position, 0, true, building_color)
				last_block_position = obj.chunk_position*last_voxel_world.CHUNK_SIZE + block_position
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
					_block_position_second_corner += last_normal
					_update_selection()
				res = true
			if event.button_index == BUTTON_WHEEL_DOWN:
				if event.pressed:
					_block_position_second_corner -= last_normal
					_update_selection()
				res = true
	if not Input.is_mouse_button_pressed(1) and last_voxel_world:
		var cube = _get_cube_gizmo()
		
		if  _should_perform_filling:
			if mode == "place" or mode == "clear":
				_undo_redo.undo()
				_undoable_fill(last_voxel_world, _block_position_first_corner, _block_position_second_corner, 1 if mode == "place" else 0, true, building_color)
			elif mode == "walls":
				_undoable_make_four_walls(last_voxel_world, _block_position_first_corner, _block_position_second_corner, dock.wall_height, 1, true, building_color)
		
		if mode == "select":
			pass
		else:
			if cube:
				cube.queue_free()
			last_voxel_world = null
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(1) and last_voxel_world:
		var plane = Plane(last_normal, last_normal.dot(last_ray_hit-last_normal))
		var cube = _get_cube_gizmo()
		var from = camera.project_ray_origin(event.position)
		
		var intersection = plane.intersects_ray(from, camera.project_ray_normal(event.position))
		if not intersection:
			print("No intersection while dragging")
			return true
		var block_pos = _vector_to_block_pos(intersection)
		
		_should_perform_filling = mode != "none" and intersection and (last_ray_hit - intersection).length() > 2
		
		if _should_perform_filling:
			if cube:
				cube.visible = true
			var new_last_block_position = last_block_position
			if mode == "place":
				new_last_block_position -= last_normal
			_block_position_first_corner = new_last_block_position
			_block_position_second_corner = block_pos
			_update_selection()
			
		res = true
	return res

func _update_selection():
	var cube = _get_cube_gizmo()
	var size = _vector_comp_abs_add(_block_position_second_corner-_block_position_first_corner, 1)*last_voxel_world.BLOCK_SIZE
	cube.width = size.x + sign(size.x)*0.2
	cube.height = size.y + sign(size.y)*0.2
	cube.depth = size.z + sign(size.z)*0.2
	cube.invert_faces = sign(cube.width) * sign(cube.height) * sign(cube.depth) < 0
	cube.global_transform.origin = (_block_position_second_corner + _block_position_first_corner) + Vector3(0.5, 0.5, 0.5)*last_voxel_world.BLOCK_SIZE #new_last_block_position*last_voxel_world.BLOCK_SIZE + size/2

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

func _vector_abs(v: Vector3):
	return Vector3(abs(v.x), abs(v.y), abs(v.z))

func _vector_min_coord(v1: Vector3, v2: Vector3):
	return Vector3(min(v1.x, v2.x), min(v1.y, v2.y), min(v1.z, v2.z))

func _sign_zero_1(x):
	return 1 if x == 0 else sign(x)

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


func make_region_a_mesh_instance(world, from: Vector3, to: Vector3):
	var size = _vector_abs(to-from) + Vector3(1,1,1)
	var chunk = VoxelChunk.new()
	chunk.setup(size)
	var origin = Vector3(min(from.x, to.x), min(from.y, to.y), min(from.z, to.z))
	for x in _better_range(from.x, to.x, FILL_LENGTH_MAX):
		for y in _better_range(from.y, to.y, FILL_LENGTH_MAX):
			for z in _better_range(from.z, to.z, FILL_LENGTH_MAX):
				var v = Vector3(x,y,z)
				var _v = v - origin
				chunk.set_block_data(_v, world.get_block_data(v), false)
	chunk.update_mesh()
	chunk.set_script(null)
	return chunk

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













