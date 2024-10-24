# https://github.com/Regalis11/scpcb/blob/master/Converter.bb
@tool
extends EditorImportPlugin

enum PRESETS { DEFAULT }


# Fix crash when importing multiple files with threads.
# Hopefully this will be resolved in Godot 4.4.
func _can_import_threaded() -> bool:
	return false


func _get_importer_name() -> String:
	return "rmesh.scpcb.mesh"


func _get_visible_name() -> String:
	return "SCP – CB RMesh as Mesh"


func _get_recognized_extensions() -> PackedStringArray:
	return ["rmesh"]


func _get_save_extension() -> String:
	return "mesh"


func _get_priority() -> float:
	return 1.0


func _get_resource_type() -> String:
	return "Mesh"


func _get_preset_count():
	return PRESETS.size()


func _get_preset_name(preset_index) -> String:
	match preset_index:
		PRESETS.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_order() -> ImportOrder:
	return IMPORT_ORDER_DEFAULT


func _get_import_options(path, preset_index) -> Array[Dictionary]:
	match preset_index:
		PRESETS.DEFAULT:
			return [
				{
					"name": "mesh/scale_mesh",
					"default_value": Vector3(1,1,1),
					"property_hint": PROPERTY_HINT_LINK,
				},
				{
					"name": "mesh/include_invisible_collisions",
					"default_value": true,
				},
				{
					"name": "materials/material_path",
					"default_value": "",
					"property_hint": PROPERTY_HINT_DIR,
				},
			]
		_:
			return []


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var file: FileAccess = FileAccess.open(
		source_file, FileAccess.READ
	)
	if not file:
		return FileAccess.get_open_error()
	
	# ATTENTION: We are now heading into the DANGER zone.
	
	# Get the header. It should either be "RoomMesh" 
	# or "RoomMesh.HasTriggerBox".
	var header: String = read_b3d_string(file)
	if (
		not header == "RoomMesh" 
		and not header == "RoomMesh.HasTriggerBox"
	):
		push_error(
			"SCP-CB Mesh import - Importing SCP-CB RMesh,"
			+ " but header is \"" + header 
			+ "\", not \"RoomMesh\" or \"RoomMesh.HasTriggerBox\"."
		)
		return FAILED
	
	var scale_mesh: Vector3 = options.get(
		"mesh/scale_mesh"
	) as Vector3
	
	var saved_scene_root: Node3D = Node3D.new()
	var saved_scene_root_name: String = (
		source_file.get_file()
		.trim_suffix(".rmesh")
	)
	saved_scene_root.name = saved_scene_root_name
	
	# Get the texture count.
	var tex_count: int = file.get_32()
	
	# We accumulate all the data for all the textures in this 
	# texture dictionary. Each texture will store an array of 
	# dictionaries, where each dictionary will store a specific
	# set of indices, where each indice stores an array of values
	# for that indice.
	var tex_dict: Dictionary = {}
	
	# Each texture has a set amount of faces associated with it.
	# In the RMesh file, faces are just stored as a sequence of 
	# vertices for each texture.
	for i in tex_count:
		# Each texture, regular or lightmap, has a flag written
		# with it as a 1-byte number.
		# Here's what they mean:
		# 0 = Texture is not written in the file
		# 1 = Texture is opaque
		# 2 = Texture is a lightmap
		# 3 = Texture has transparency
		var lm_flag: int = 0
		
		# If a lightmap exists for this texture, it's always
		# written before the texture.
		lm_flag = file.get_8()
		var lm_name: String = ""
		if lm_flag == 2:
			lm_name = read_b3d_string(file)
		else:
			# If a lightmap doesn't exist for this texture,
			# there's a 4-byte padding after the flag.
			file.get_32()
		
		var tex_flag = file.get_8()
		# If the texture flag is 3, then in SCP-CB RMesh
		# files, the lightmap flag must always be 1.
		if tex_flag == 3 and not lm_flag == 1:
			push_error(
				"SCP-CB Scene import - Texture flag is 3"
				+ ", but lightmap flag is not 1."
			)
			return FAILED
		
		var tex_name: String = read_b3d_string(file)
		if !tex_dict.has(tex_name):
			tex_dict[tex_name] = [] as Array[Dictionary]
		
		# Get the vertex count.
		var vertex_count: int = file.get_32()
		
		# Initialize arrays for texture and lightmap UVs.
		# NOTE: Lightmap UVs are not used.
		var tex_uvs: PackedVector2Array = PackedVector2Array()
		var lm_uvs: PackedVector2Array = PackedVector2Array()
		
		# Get the vertices.
		var vertices: PackedVector3Array = PackedVector3Array()
		for j in vertex_count:
			# The data for each vertex takes up 31 bytes.
			var vertex_data: PackedByteArray = file.get_buffer(31)
			
			# Each vertex X, Y and Z position takes up 4 bytes.
			# SCP-CB's rooms are made in 3D World Studio, and 
			# since that program is as old as time itself and 
			# won't run on anything higher than Windows 7, 
			# I don't really know how these positions work in it.
			var pos_x: float = vertex_data.decode_float(0)
			var pos_y: float = vertex_data.decode_float(4)
			var pos_z: float = vertex_data.decode_float(8)
			
			# I guess the positive Z direction is still
			# flipped though.
			vertices.append(
				Vector3(pos_x, pos_y, -pos_z)
				* scale_mesh
			)
			
			# Get the texture and lightmap UVs.
			var tex_u = vertex_data.decode_float(12)
			var tex_v = vertex_data.decode_float(16)
			var lm_u = vertex_data.decode_float(20)
			var lm_v = vertex_data.decode_float(24)
			tex_uvs.append(Vector2(tex_u, tex_v))
			lm_uvs.append(Vector2(lm_u, lm_v))
			
			# The data for each vertex ends with three
			# 'RGB' bytes. Usually, they are just three FF bytes.
			# We don't really care about these.
		
		# Get the triangle count.
		var tri_count: int = file.get_32()
		
		# Get the triangle indices.
		var tri_indices: PackedInt32Array = PackedInt32Array()
		for j in tri_count * 3:
			# Each indice is stored as 4 bytes.
			tri_indices.append(file.get_32())
		
		# The triangle indice count must be a multiple
		# of the triangle count.
		if tri_indices.size() % tri_count:
			push_error(
				"SCP-CB Mesh import - Triangle indice count"
				+ " is not a multiple of the triangle count"
				+ " (indice count: " + str(tri_indices.size())
				+ ", triangle count: " + str(tri_count)
				+ ", " + str(tri_indices.size()) + " mod "
				+ str(tri_count) + " = "
				+ str(tri_indices.size() % tri_count) + ")."
			)
			return FAILED
		
		# For each indice, give it it's corresponding vertex,
		# texture UV and lightmap UV.
		var vert_ind_pairs: Dictionary = {}
		var pos_in_ind_arr: int = -1
		for j in tri_indices.size() as int:
			pos_in_ind_arr += 1
			# If an indice already has vertex data associated 
			# with it, we know we can just skip it.
			if not vert_ind_pairs.has(tri_indices[j]):
				vert_ind_pairs[tri_indices[j]] = [
					vertices[pos_in_ind_arr],
					tex_uvs[pos_in_ind_arr],
					lm_uvs[pos_in_ind_arr]
				]
			else:
				pos_in_ind_arr -= 1
		
		# Every vertex should have only one indice
		# associated with it.
		if not vert_ind_pairs.size() == vertices.size():
			push_error(
				"SCP-CB Mesh import - Vertice-indice pairs array size"
				+ " doesn't match vertices array size. Every indice"
				+ " should have one set of vertices assigned to it"
				+ " (vertice-indice pairs array size: " 
				+ str(vert_ind_pairs.size()) 
				+ ", vertices array size: " + str(vertices.size())
				+ ")."
			)
			return FAILED
		
		Array(tex_dict.get(tex_name)).append(
			{
				"indices": tri_indices,
				"pairs": vert_ind_pairs
			}
		)
	
	# Get the invisible collision face count.
	var invis_coll_count: int = file.get_32()
	var include_invis_coll: bool = options.get(
		"mesh/include_invisible_collisions"
	) as bool
	
	# Handle invisible collisions. We mostly have to repeat
	# the same processes as with the normal face data.
	if include_invis_coll and invis_coll_count > 0:
		tex_dict["invisible_collision"] = []
		
		# Get the invisible collision vertex count.
		var invis_coll_vert_count: int = file.get_32()
		
		# Get the invisible collision vertices.
		var invis_coll_vertices: PackedVector3Array = (
			PackedVector3Array()
		)
		for i in invis_coll_vert_count:
			# The actual data for each invisible collision vertex
			# takes up 12 bytes. Only the X, Y and Z positions get
			# saved with invisible collision vertices. Other than
			# that, we do mostly the same things as with normal
			# face vertices.
			var invis_coll_vertex_data: PackedByteArray = (
				file.get_buffer(12)
			)
			
			var pos_x: float = invis_coll_vertex_data.decode_float(0)
			var pos_y: float = invis_coll_vertex_data.decode_float(4)
			var pos_z: float = invis_coll_vertex_data.decode_float(8)
			invis_coll_vertices.append(
				Vector3(pos_x, pos_y, -pos_z)
				* scale_mesh
			)
			
			# The data for each invisible collision vertex
			# doesn't end with any extra bytes.
		
		# Get the invisible collision triangle count.
		var invis_coll_tri_count: int = file.get_32()
		
		# Get the invisible collision triangle indices.
		var invis_coll_tri_indices: PackedInt32Array = (
			PackedInt32Array()
		)
		for i in invis_coll_tri_count * 3:
			# Each indice is stored as 4 bytes.
			invis_coll_tri_indices.append(file.get_32())
		
		# The triangle indice count must be a multiple of the triangle count.
		if invis_coll_tri_indices.size() % invis_coll_tri_count:
			push_error(
				"SCP-CB Mesh import -"
				+ " Invisible collision triangle indice count"
				+ " is not a multiple of the invisible"
				+ " collision triangle count"
				+ " (indice count is " 
				+ str(invis_coll_tri_indices.size())
				+ ", triangle count is " 
				+ str(invis_coll_tri_count) + ", " 
				+ str(invis_coll_tri_indices.size()) + " mod "
				+ str(invis_coll_tri_count) + " = "
				+ str(
					invis_coll_tri_indices.size()
					% invis_coll_tri_count
				)
				+ ")."
			)
			return FAILED
		
		# For each invisible collision indice, give it it's
		# corresponding vertex.
		var invis_coll_vert_ind_pairs: Dictionary = {}
		var pos_in_invis_coll_ind_arr: int = -1
		for i in invis_coll_tri_indices.size():
			pos_in_invis_coll_ind_arr += 1
			# If an indice already has vertex data associated with it, 
			# we know we can just skip it.
			if !invis_coll_vert_ind_pairs.has(
				invis_coll_tri_indices[i]
			):
				invis_coll_vert_ind_pairs[
					invis_coll_tri_indices[i]
				] = [
					invis_coll_vertices[pos_in_invis_coll_ind_arr]
				]
			else:
				pos_in_invis_coll_ind_arr -= 1
		
		# Every invisible collision vertex should have only
		# one indice associated with it.
		if not (
			invis_coll_vert_ind_pairs.size()
			== invis_coll_vertices.size()
		):
			push_error(
				"SCP-CB Mesh import - Invisible collision"
				+ " vertice-indice pairs array size"
				+ " doesn't match invisible collision"
				+ " vertices array size. Every indice"
				+ " should have one set of vertices assigned to it."
				+ " (vertice-indice pairs array size: " 
				+ str(invis_coll_vert_ind_pairs.size()) 
				+ ", vertices array size: "
				+ str(invis_coll_vertices.size())
				+ ")"
			)
			return FAILED
		
		Array(tex_dict.get("invisible_collision")).append(
			{
				"indices": invis_coll_tri_indices,
				"pairs": invis_coll_vert_ind_pairs
			}
		)
	
	# Initialize the ArrayMesh and SurfaceTool.
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	var st: SurfaceTool = SurfaceTool.new()
	
	var mat_path: String = options.get(
		"materials/material_path"
	) as String
	var current_material_checked: bool = false
	var current_loaded_material: Material = null
	
	# For each texture in the texture dictionary.
	for i in tex_dict.keys() as Array[Dictionary]:
		var tex_name: String = tex_dict.find_key(
			tex_dict.get(i)
		) as String
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# For each dictionary stored with the texture.
		for j in Array(tex_dict.get(i)) as Array[Dictionary]:
			# For each indice in the indices array.
			var pairs: Dictionary = j.get("pairs") as Dictionary
			for k in j.get("indices") as Array[int]:
				# Set the texture UV.
				# Invisible collisions don't have UVs or materials.
				if tex_name != "invisible_collision":
					# Set the texture UV.
					st.set_uv(
						Vector2(
							Array(pairs.get(k))[1]
						)
					)
					# Set the lightmap UV.
					st.set_uv2(
						Vector2(
							Array(pairs.get(k))[2]
						)
					)
					
					# Set the material.
					if (
						not mat_path == "" 
						and not current_material_checked 
						and not current_loaded_material
					):
						var n_mat_path: String = mat_path
						# Fix up material path so it works.
						if n_mat_path.right(1) != "/":
							n_mat_path += "/"
						n_mat_path += tex_name.trim_suffix(
							tex_name.get_extension()
						) + "tres"
						# If we don't have a material loaded, we can
						# check if it exists and load it. Then we say
						# the material was checked. We only need to
						# check it once to know if it exists or not.
						if ResourceLoader.exists(
							n_mat_path, "Material"
						):
							current_loaded_material = load(n_mat_path)
						current_material_checked = true
					# We then check if we have a material loaded
					# after that process.
					if current_loaded_material:
						st.set_material(current_loaded_material)
				
				st.add_vertex(
					Vector3(
						Array(pairs.get(k))[0]
					)
				)
		
		st.generate_normals()
		st.commit(arr_mesh)
		st.clear()
		arr_mesh.surface_set_name(
			arr_mesh.get_surface_count() - 1, 
			tex_name.trim_suffix(
				tex_name.get_extension()
			).rstrip(".")
		)
		current_loaded_material = null
		current_material_checked = false
	
	return ResourceSaver.save(
		arr_mesh, 
		"%s.%s" % [save_path, _get_save_extension()]
	)


func read_b3d_string(file: FileAccess) -> String:
	var len: int = file.get_32()
	var string: String = (
		file.get_buffer(len).get_string_from_utf8()
	)
	return string
