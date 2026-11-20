extends RefCounted
## Match the 2D map to the orthographic camera's ground-plane foreshortening.
const DRAW_SIZE = Vector2(400,400)
const CAMERA_SIZE = 5.2
const CAMERA_POSITION = Vector3(0,6.4,7.5)
const CAMERA_TARGET = Vector3(0,1.55,0)
const GROUND_Y = 0.543045
static func ground(direction: Vector2) -> Vector3:
	return Vector3(direction.x,0,direction.y/GROUND_Y)
static func heading(direction: Vector2) -> float:
	var vector := ground(direction)
	return atan2(-vector.x,-vector.z)
static func stride_projection(direction: Vector2) -> float:
	var vector := ground(direction).normalized()
	return Vector2(vector.x,vector.z*GROUND_Y).length()
