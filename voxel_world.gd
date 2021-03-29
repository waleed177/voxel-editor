tool
extends Spatial
class_name VoxelWorld

const CHUNK_SIZE = 8
const BLOCK_SIZE = 2

var _chunks = {} # Vector3 -> VoxelChunk
export(Dictionary) var _chunks_to_save = {}
var _dirty_chunks: Dictionary = {}
var type = "voxel_world"

func _ready():
	if not _chunks_to_save.empty():
		for position in _chunks_to_save:
			var chunk_data = _chunks_to_save[position]
			var chunk = VoxelChunk.new()
			chunk._chunk_size = Vector3(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
			chunk.chunk_position = chunk_data.chunk_position
			chunk._block_ids = chunk_data.block_ids
			chunk._block_colors = chunk_data.block_colors
			add_child(chunk)
			chunk.global_transform.origin = chunk_data.chunk_position * CHUNK_SIZE * BLOCK_SIZE
			chunk.update_mesh()
			_chunks[str(chunk_data.chunk_position)] = chunk
	if get_child_count() == 0:
		set_block(Vector3(0, 0, 0), 1, true)

func get_chunk_position_of(v: Vector3) -> Vector3:
	v /= CHUNK_SIZE
	return Vector3(floor(v.x), floor(v.y), floor(v.z))

func set_block(v: Vector3, value: int, update_mesh: bool, color: Color = Color.white) -> void:
	var chunk_position = get_chunk_position_of(v)
	var chunk: VoxelChunk
	if _chunks.has(str(chunk_position)):
		chunk = _chunks[str(chunk_position)]
	else:
		chunk = VoxelChunk.new()
		add_child(chunk)
		chunk._chunk_size = Vector3(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
		chunk.global_transform.origin = chunk_position * CHUNK_SIZE * BLOCK_SIZE
		chunk.chunk_position = chunk_position
		_chunks[str(chunk_position)] = chunk
	chunk.set_block(_fix_local_block_position(v - chunk_position * CHUNK_SIZE), value, update_mesh, color)
	_chunks_to_save[str(chunk_position)] = {
		block_ids = chunk._block_ids, #TODO RENAME
		block_colors = chunk._block_colors,
		chunk_position = chunk_position
	}

func _fix_local_block_position(v: Vector3) -> Vector3:
	var res: Vector3 = v
	if res.x < 0: res.x = 8+res.x
	if res.y < 0: res.y = 8+res.y
	if res.z < 0: res.z = 8+res.z
	return res

func get_block(v: Vector3):
	var chunk_position = get_chunk_position_of(v)
	var chunk: VoxelChunk
	if _chunks.has(str(chunk_position)):
		chunk = _chunks[str(chunk_position)]
	else:
		return 0
	return chunk.get_block(_fix_local_block_position(v - chunk_position * CHUNK_SIZE))

func get_block_data(v: Vector3):
	var chunk_position = get_chunk_position_of(v)
	var chunk: VoxelChunk
	if _chunks.has(str(chunk_position)):
		chunk = _chunks[str(chunk_position)]
	else:
		return {
			id = 0,
			color = Color.white
		}
	return chunk.get_block_data(_fix_local_block_position(v - chunk_position * CHUNK_SIZE))

func set_block_data(v: Vector3, block_data, update_mesh: bool = true):
	set_block(v, block_data.id, update_mesh, block_data.color)

func get_global_block_position(chunk_pos: Vector3, block_pos: Vector3) -> Vector3:
	return chunk_pos*CHUNK_SIZE + block_pos

func get_chunk_block_in(v: Vector3):
	var key = str(get_chunk_position_of(v))
	if key in _chunks:
		return _chunks[key]
	else: return null
	

func clear_world():
	for child in get_children():
		child.queue_free()
	_chunks.clear()
	_chunks_to_save.clear()
	_dirty_chunks.clear()
	set_block(Vector3(0, 0, 0), 1, true)

func mark_as_dirty(chunk):
	if chunk:
		_dirty_chunks[str(chunk.chunk_position)] = chunk

func update_dirty_chunks():
	for dirty in _dirty_chunks:
		_dirty_chunks[dirty].update_mesh()
	_dirty_chunks.clear()
