extends Node
## Helper functions for RMesh importing.


## Create vertice-indice pairs from [param vertices] and
## [param indices]. Additional [param data] can be passed
## that will be included with the indice.
func create_vert_ind_pairs(vertices: PackedVector3Array, indices: PackedInt32Array, data: Array = []) -> Dictionary:
	var pairs: Dictionary = {}
	
	var pos_in_arr: int = -1
	for i in indices.size():
		pos_in_arr += 1
		# If an indice already has vertex data associated
		# with it, we know we can just skip it.
		if not pairs.has(indices[i]):
			pairs[indices[i]] = [] as Array
			Array(pairs[indices[i]]).append(
				vertices[pos_in_arr]
			)
			
			if not data.is_empty():
				for j in data:
					Array(pairs[indices[i]]).append(
						j[pos_in_arr]
					)
		else:
			pos_in_arr -= 1
	
	return pairs


func get_entity_position(file: FileAccess, scale: Vector3) -> Vector3:
	# Each X, Y and Z position is a 4-byte float.
	var pos_x: float = file.get_float()
	var pos_y: float = file.get_float()
	var pos_z: float = file.get_float()
	var pos: Vector3 = Vector3(
		pos_x, pos_y, -pos_z
	) * scale
	return pos


func get_entity_rotation(file: FileAccess) -> Vector3:
	# Each X, Y and Z rotation is a 4-byte float.
	var rot_x: float = file.get_float()
	var rot_y: float = file.get_float()
	var rot_z: float = file.get_float()
	var rot: Vector3 = Vector3(
		rot_x, rot_y, -rot_z
	)
	return rot


func get_entity_scale(file: FileAccess) -> Vector3:
	# Each X, Y and Z scale is a 4-byte float.
	var scale_x: float = file.get_float()
	var scale_y: float = file.get_float()
	var scale_z: float = file.get_float()
	var scale: Vector3 = Vector3(
		scale_x, scale_y, -scale_z
	)
	return scale


func get_rotation_from_angles(angles: String) -> Vector3:
	var angles_split: PackedStringArray = (
		angles.split(" ")
	)
	var rot: Vector3 = Vector3(
		-int(angles_split[0]),
		int(angles_split[1]),
		int(angles_split[2])
	)
	return rot


func get_color_from_string(color: String) -> Color:
	var split_color_string: PackedStringArray = (
		color.split(" ")
	)
	var new_color = Color8(
		int(split_color_string[0]),
		int(split_color_string[1]),
		int(split_color_string[2])
	)
	return new_color
