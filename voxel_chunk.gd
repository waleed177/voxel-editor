tool
extends MeshInstance
class_name VoxelChunk

export(Array) var _block_ids = null
export(Array) var _block_colors = null
var camera: Camera

export(Vector3) var chunk_position: Vector3
var _indicies = {} #(x,y,z)face -> [v1,v2,v3,v4]
var _free_index = 0

func get_indicies(v: Vector3, face: String):
	var key = str(v) + face
	return _indicies[key] if key in _indicies else null

func set_indicies(v: Vector3, face: String, indicies: Array):
	_indicies[str(v) + face] = indicies

func alloc_indicies(v: Vector3, face: String):
	var indicies = get_indicies(v, face)
	if indicies: return indicies

func _ready():
	if _block_ids == null:
		clear()
	update_mesh()
	material_override = preload("res://materials/vertex_color2.tres")
	

func check_position_in_bounds(v: Vector3):
	return v.x < 0 or v.x >= get_parent().CHUNK_SIZE \
			or v.y < 0 or v.y >= get_parent().CHUNK_SIZE \
			or v.z < 0 or v.z >= get_parent().CHUNK_SIZE

func get_block_index(v: Vector3):
	return v.x + get_parent().CHUNK_SIZE*(v.y + get_parent().CHUNK_SIZE*v.z)

func set_block(v: Vector3, value: int, update_mesh: bool, color: Color = Color.white):
	var world = get_parent()
	var global_pos = get_parent().get_global_block_position(chunk_position, v)
	if check_position_in_bounds(v): 
		world.set_block(global_pos, value, update_mesh, color)
	else:
		var i = get_block_index(v)
		_block_ids[i] = value
		_block_colors[i] = color
		world.mark_as_dirty(self)
		if v.x == 0:
			world.mark_as_dirty(world.get_chunk_block_in(global_pos+Vector3(-1,0,0)))
		if v.y == 0:
			world.mark_as_dirty(world.get_chunk_block_in(global_pos+Vector3(0,-1,0)))
		if v.z == 0:
			world.mark_as_dirty(world.get_chunk_block_in(global_pos+Vector3(0,0,-1)))
		if v.x == world.CHUNK_SIZE-1:
			world.mark_as_dirty(world.get_chunk_block_in(global_pos+Vector3(1,0,0)))
		if v.y == world.CHUNK_SIZE-1:
			world.mark_as_dirty(world.get_chunk_block_in(global_pos+Vector3(0,1,0)))
		if v.z == world.CHUNK_SIZE-1:
			world.mark_as_dirty(world.get_chunk_block_in(global_pos+ Vector3(0,0,1)))
		if update_mesh:
			world.update_dirty_chunks()
		
		#or v.y == 0 or v.z == 0 or v.x == world.CHUNK_SIZE-1 or v.y == world.CHUNK_SIZE-1 or v.z == world.CHUNK_SIZE-1:
	

func get_block(v: Vector3):
	if check_position_in_bounds(v): 
		return get_parent().get_block(get_parent().get_global_block_position(chunk_position, v))
	else:
		return _block_ids[get_block_index(v)]

func get_block_data(v: Vector3):
	if check_position_in_bounds(v): 
		return get_parent().get_block_data(get_parent().get_global_block_position(chunk_position, v))
	else:
		var i = get_block_index(v)
		return {
			id = _block_ids[i],
			color = _block_colors[i]
		}

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
	for i in get_parent().CHUNK_SIZE * get_parent().CHUNK_SIZE * get_parent().CHUNK_SIZE:
		_block_ids.append(0)
		_block_colors.append(Color.white)

func update_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var i = -1
	for z in range(0, 8):
		for y in range(0, 8):
			for x in range(0, 8):
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
