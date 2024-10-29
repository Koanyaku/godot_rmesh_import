extends Node
## Helper functions for RMesh importing.


## Create vertice-indice pairs from [param vertices] and
## [param indices]. Additional [param data] can be passed
## that will be included with the indice.
func create_vert_ind_pairs(vertices: PackedVector3Array, indices: PackedInt32Array, data: Array = []) -> Dictionary:
	var pairs: Dictionary = {}
	
	# This value is the position from which we will read vertice
	# and other data from their respective arrays.
	var correct_arr_pos: int = -1
	
	for i in indices.size():
		correct_arr_pos += 1
		
		# If an indice already has vertice data associated
		# with it in the pairs, we know we can just skip it.
		if not pairs.has(indices[i]):
			pairs[indices[i]] = [] as Array
			Array(pairs[indices[i]]).append(
				vertices[correct_arr_pos]
			)
			
			if not data.is_empty():
				for j in data:
					Array(pairs[indices[i]]).append(
						j[correct_arr_pos]
					)
		else:
			# If the pairs already contain this indice,
			# we have to set back the correct array position
			# by one, basically making it so that it was
			# never increased. 
			
			# This is because, while the vertice array contains
			# each vertice only once, the indice array can contain
			# the same indice more than once. We, however, don't
			# care about these duplicate indices, since we already
			# have data with that particular indice stored in the
			# pairs.
			
			# Basically, we halt the correct position from
			# increasing until we encounter a new indice, 
			# otherwise, this value would keep increasing
			# with each indice in the indice array, and we
			# would read from the incorrect position in the
			# vertice array.
			
			# At the end of the creation process, the correct
			# array position + 1 should be the vertice array size.
			correct_arr_pos -= 1
	
	# Every invisible collision vertice should 
	# have only one indice associated with it.
	if not pairs.size() == vertices.size():
		push_error(
			"Vertice-indice pairs array size doesn't match"
			+ " vertices array size. Every indice should have"
			+ " one set of vertices assigned to it"
			+ " (vertice-indice pairs array size: "
			+ str(pairs.size()) + ", vertices array size: "
			+ str(vertices.size()) + ")"
		)
		return {}
	
	return pairs


func check_tri_ind_count(indices: PackedInt32Array, tri_count: int) -> bool:
	var ind_size: int = indices.size()
	
	# The triangle indice count must be a
	# multiple of the triangle count.
	if (ind_size % tri_count):
		push_error(
			"Triangle indice count is not a multiple of the"
			+ " triangle count (indice count is "
			+ str(ind_size) + ", triangle count is "
			+ str(tri_count) + ", " + str(ind_size)
			+ " mod " + str(tri_count) + " = "
			+ str(ind_size % tri_count) + ")."
		)
		return false
	
	return true

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
