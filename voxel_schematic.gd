tool
extends Resource
class_name VoxelSchematic

export(Array) var _block_ids = null
export(Array) var _block_colors = null
export(Vector3) var chunk_size: Vector3 = Vector3(8,8,8)

func check_position_in_bounds(v: Vector3):
	return not (v.x < 0 or v.x >= chunk_size.x \
			or v.y < 0 or v.y >= chunk_size.y \
			or v.z < 0 or v.z >= chunk_size.z)

func get_block_index(v: Vector3):
	assert(check_position_in_bounds(v))
	return v.x + chunk_size.x*v.y + chunk_size.x*chunk_size.y*v.z

func get_block(v: Vector3):
	assert(check_position_in_bounds(v))
	return _block_ids[get_block_index(v)]

func get_block_data(v: Vector3):
	if not check_position_in_bounds(v):
		print(str(v) + " " + str(chunk_size))
	assert(check_position_in_bounds(v))
	var i = get_block_index(v)
	return {
		id = _block_ids[i],
		color = _block_colors[i]
	}

