tool
extends Reference
class_name VoxelSelectionInformation

var block_position: Vector3
var ray_hit: Vector3
var ray_normal: Vector3
var voxel_chunk: VoxelChunk
var voxel_world: VoxelWorld
var block_data: Dictionary
var should_perform_filling: bool
var first_corner: Vector3
var second_corner: Vector3

func reset():
	voxel_world = null
