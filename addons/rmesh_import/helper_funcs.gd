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
