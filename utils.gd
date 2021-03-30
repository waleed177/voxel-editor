extends Node

class_name VoxelUtils

static func vector_comp_abs_add(v: Vector3, i: int):
	return Vector3(v.x + sign_zero(v.x)*i, v.y + sign_zero(v.y)*i, v.z + sign_zero(v.z)*i)

static func vector_abs(v: Vector3):
	return Vector3(abs(v.x), abs(v.y), abs(v.z))

static func vector_min_coord(v1: Vector3, v2: Vector3):
	return Vector3(min(v1.x, v2.x), min(v1.y, v2.y), min(v1.z, v2.z))

static func sign_zero(x, num = 1):
	return num if x == 0 else sign(x)
