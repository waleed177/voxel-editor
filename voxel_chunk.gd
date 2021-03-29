tool
extends MeshInstance
class_name VoxelChunk

export(Array) var _block_ids = null
export(Array) var _block_colors = null
var camera: Camera

export(Vector3) var chunk_position: Vector3
var _indicies = {} #(x,y,z)face -> [v1,v2,v3,v4]
var _free_index = 0
var _chunk_size: Vector3 = Vector3(8,8,8)
var _world#: VoxelWorld

func get_indicies(v: Vector3, face: String):
	var key = str(v) + face
	return _indicies[key] if key in _indicies else null

func set_indicies(v: Vector3, face: String, indicies: Array):
	_indicies[str(v) + face] = indicies

func alloc_indicies(v: Vector3, face: String):
	var indicies = get_indicies(v, face)
	if indicies: return indicies

func setup(chunk_size):
	_chunk_size = chunk_size
	print("Chunk " + str(chunk_position) + " setup with size " + str(chunk_size))
	if _block_ids == null:
		clear()
	update_mesh()
	material_override = preload("./materials/chunk_material.tres")

func _ready():
	if _block_ids == null:
		clear()
	update_mesh()
	material_override = preload("./materials/chunk_material.tres")
	_world = get_parent()
	print("chunk " + str(chunk_position) + " is ready.")
	

func check_position_in_bounds(v: Vector3):
	return not (v.x < 0 or v.x >= _chunk_size.x \
			or v.y < 0 or v.y >=_chunk_size.y \
			or v.z < 0 or v.z >= _chunk_size.z)

func get_block_index(v: Vector3):
	return v.x + _chunk_size.x*v.y + _chunk_size.x*_chunk_size.y*v.z

func set_block(v: Vector3, value: int, update_mesh: bool, color: Color = Color.white):
	var global_pos = _world.get_global_block_position(chunk_position, v) if _world else null
	if not check_position_in_bounds(v): 
		_world.set_block(global_pos, value, update_mesh, color)
	else:
		var i = get_block_index(v)
		_block_ids[i] = value
		_block_colors[i] = color
		if _world:
			_world.mark_as_dirty(self)
			if v.x == 0:
				_world.mark_as_dirty(_world.get_chunk_block_in(global_pos+Vector3(-1,0,0)))
			if v.y == 0:
				_world.mark_as_dirty(_world.get_chunk_block_in(global_pos+Vector3(0,-1,0)))
			if v.z == 0:
				_world.mark_as_dirty(_world.get_chunk_block_in(global_pos+Vector3(0,0,-1)))
			if v.x == _world.CHUNK_SIZE-1:
				_world.mark_as_dirty(_world.get_chunk_block_in(global_pos+Vector3(1,0,0)))
			if v.y == _world.CHUNK_SIZE-1:
				_world.mark_as_dirty(_world.get_chunk_block_in(global_pos+Vector3(0,1,0)))
			if v.z == _world.CHUNK_SIZE-1:
				_world.mark_as_dirty(_world.get_chunk_block_in(global_pos+ Vector3(0,0,1)))
			if update_mesh:
				_world.update_dirty_chunks()
		else:
			update_mesh()
		
		#or v.y == 0 or v.z == 0 or v.x == world.CHUNK_SIZE-1 or v.y == world.CHUNK_SIZE-1 or v.z == world.CHUNK_SIZE-1:
	

func get_block(v: Vector3):
	if  not check_position_in_bounds(v): 
		return _world.get_block(_world.get_global_block_position(chunk_position, v)) if _world else 0
	else:
		return _block_ids[get_block_index(v)]

func get_block_data(v: Vector3):
	if not check_position_in_bounds(v): 
		return _world.get_block_data(_world.get_global_block_position(chunk_position, v))
	else:
		var i = get_block_index(v)
		return {
			id = _block_ids[i],
			color = _block_colors[i]
		}

func set_block_data(v: Vector3, block_data, update_mesh: bool = true):
	set_block(v, block_data.id, update_mesh, block_data.color)

func build_block(st, v, color: Color = Color.white):
	if get_block(v) == 0: return
	
	var up = get_block(v + Vector3.UP)
	var down = get_block(v + Vector3.DOWN)
	var left = get_block(v + Vector3.LEFT)
	var right = get_block(v + Vector3.RIGHT)
	var forward = get_block(v + Vector3.FORWARD)
	var back = get_block(v + Vector3.BACK)
	v *= 2
	v.x += 1
	v.y += 1
	if up == 0:
		make_plane(st, "xz", v.x, 1+v.y, 1+v.z, color)
	if down == 0:
		make_plane(st, "xz'", v.x, -1+v.y, 1+v.z, color)
	if right == 0:
		make_plane(st, "yz", 1+v.x, v.y, 1+v.z, color)
	if left == 0:
		make_plane(st, "yz'", -1+v.x, v.y, 1+v.z, color)
	if forward == 0:
		make_plane(st, "xy'", v.x, v.y, v.z, color)
	if back == 0:
		make_plane(st, "xy", v.x, v.y, 2+v.z, color)



func clear():
	_block_ids = []
	_block_colors = []
	_indicies = {}
	for i in _chunk_size.x * _chunk_size.y * _chunk_size.z:
		_block_ids.append(0)
		_block_colors.append(Color.white)

func update_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var i = -1
	for z in range(0, _chunk_size.z):
		for y in range(0, _chunk_size.y):
			for x in range(0, _chunk_size.x):
				i += 1
				var pos = Vector3(x,y,z)
				build_block(st, pos, _block_colors[i])
	
	st.index()

	# Commit to a mesh.
	var mesh = st.commit()
	self.mesh = mesh
	
	for child in get_children():
		child.queue_free()
	
	if mesh.get_faces().size() > 0:
		create_trimesh_collision()
		
	visible = false
	visible = true
	

#
func make_plane(st: SurfaceTool, axis: String, x, y, z, color: Color = Color.white):
	if axis == "xy":
		st.add_normal(Vector3(0, 0, 1))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, -1+y, z))
		st.add_normal(Vector3(0, 0, 1))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, 1+y, z))
		st.add_normal(Vector3(0, 0, 1))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, 1+y, z))

		st.add_normal(Vector3(0, 0, 1))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, 1+y, z))
		st.add_normal(Vector3(0, 0, 1))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, -1+y, z))
		st.add_normal(Vector3(0, 0, 1))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, -1+y, z))
	elif axis == "xy'":
		st.add_normal(Vector3(0, 0, -1))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, 1+y, z))
		st.add_normal(Vector3(0, 0, -1))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, 1+y, z))
		st.add_normal(Vector3(0, 0, -1))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, -1+y, z))

		st.add_normal(Vector3(0, 0, -1))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, -1+y, z))
		st.add_normal(Vector3(0, 0, -1))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, -1+y, z))
		st.add_normal(Vector3(0, 0, -1))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, 1+y, z))
	elif axis == "xz":
		st.add_normal(Vector3(0, 1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, y, 1+z))
		st.add_normal(Vector3(0, 1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, y, 1+z))
		st.add_normal(Vector3(0, 1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, y, -1+z))

		st.add_normal(Vector3(0, 1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, y, -1+z))
		st.add_normal(Vector3(0, 1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, y, -1+z))
		st.add_normal(Vector3(0, 1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, y, 1+z))
	elif axis == "xz'":
		st.add_normal(Vector3(0, -1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, y, -1+z))
		st.add_normal(Vector3(0, -1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, y, 1+z))
		st.add_normal(Vector3(0, -1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, y, 1+z))

		st.add_normal(Vector3(0, -1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, y, 1+z))
		st.add_normal(Vector3(0, -1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(1+x, y, -1+z))
		st.add_normal(Vector3(0, -1, 0))
		st.add_color(color)
		st.add_vertex(Vector3(-1+x, y, -1+z))
	elif axis == "yz":
		st.add_normal(Vector3(1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, -1+y, -1+z))
		st.add_normal(Vector3(1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, -1+y, 1+z))
		st.add_normal(Vector3(1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, 1+y, 1+z))

		st.add_normal(Vector3(1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, 1+y, 1+z))
		st.add_normal(Vector3(1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, 1+y, -1+z))
		st.add_normal(Vector3(1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, -1+y, -1+z))
	elif axis == "yz'":
		st.add_normal(Vector3(-1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, 1+y, 1+z))
		st.add_normal(Vector3(-1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, -1+y, 1+z))
		st.add_normal(Vector3(-1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, -1+y, -1+z))

		st.add_normal(Vector3(-1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, -1+y, -1+z))
		st.add_normal(Vector3(-1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, 1+y, -1+z))
		st.add_normal(Vector3(-1, 0, 0))
		st.add_color(color)
		st.add_vertex(Vector3(x, 1+y, 1+z))
