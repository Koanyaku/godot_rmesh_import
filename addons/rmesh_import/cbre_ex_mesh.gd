@tool
extends EditorImportPlugin

enum PRESETS { DEFAULT }

func _get_importer_name() -> String:
	return "rmesh.cbre-ex.mesh"

func _get_visible_name() -> String:
	return "CBRE-EX RMesh as Mesh"

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
					"name": "mesh/merge_duplicated_surfaces",
					"default_value": true,
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
	var file: FileAccess = FileAccess.open(source_file, FileAccess.READ)
	if !file:
		return FileAccess.get_open_error()
	
	# Get the header.
	var header: String = read_b3d_string(file) as String
	if header != "RoomMesh":
		return ERR_FILE_UNRECOGNIZED
	
	var saved_scene_root: Node3D = Node3D.new()
	var saved_scene_root_name: String = source_file.get_file().trim_suffix(".rmesh").rstrip(".") as String
	saved_scene_root.name = saved_scene_root_name
	
	# Initialize the ArrayMesh and SurfaceTool.
	var arr_mesh: ArrayMesh = ArrayMesh.new() as ArrayMesh
	var st: SurfaceTool = SurfaceTool.new() as SurfaceTool
	
	# Get the texture count.
	var tex_count: int = file.get_32() as int
	
	# Just so removing duplicated surfaces works.
	var st_has_begun: bool = false as bool 
	var prev_tex_name: String = "" as String
	
	# Each texture has a set amount of faces associated with it.
	# In the RMesh file, faces are just stored as a sequence of vertices for each texture.
	for i in tex_count:
		var lm_flag: int = file.get_8() as int
		var lm_name: String
		# If the lightmap flag is 0, a lightmap isn't generated for this texture.
		if lm_flag == 1:
			lm_name = read_b3d_string(file) as String
		
		# If the texture flag is 3, the texture is without a lightmap.
		var tex_flag = file.get_8() as int
		var tex_name: String = read_b3d_string(file) as String
		
		# Merging duplicated surfaces.
		if bool(options.get("mesh/merge_duplicated_surfaces")):
			# If the previous texture name is the same as the current texture name,
			# we know that we can merge the two surfaces.
			if (prev_tex_name != "") and (prev_tex_name != tex_name):
				st.generate_normals()
				st.commit(arr_mesh)
				st.clear()
				st_has_begun = false
				var surf_name: String = prev_tex_name.get_file().trim_suffix(prev_tex_name.get_extension()).rstrip(".") as String
				arr_mesh.surface_set_name(arr_mesh.get_surface_count() - 1, surf_name)
		
		prev_tex_name = tex_name
		
		# Get the vertex count.
		var vertex_count: int = file.get_32() as int
		
		# Initialize arrays for texture and lightmap UVs.
		# NOTE: Lightmap UVs are not used.
		var tex_uvs: Array
		var lm_uvs: Array
		
		# Get the vertices.
		var vertices: PackedVector3Array = PackedVector3Array() as PackedVector3Array
		for j in vertex_count:
			# The actual data for each vertex takes up 28 bytes.
			var vertex_data: PackedByteArray = file.get_buffer(28) as PackedByteArray
			
			# Each vertex X, Y and Z position takes up 4 bytes.
			# In CBRE-EX, X and Y are horizontal positions, while Z is vertical.
			# This means that a vertex location is technically X Z Y.
			# This is how they are stored in the file, however, in Godot, X and Z are
			# horizontal, while Y is vertical.
			var pos_x: float = vertex_data.decode_float(0) # CBRE-EX 'X' position
			var pos_y: float = vertex_data.decode_float(4) # CBRE-EX 'Z' position
			var pos_z: float = vertex_data.decode_float(8) # CBRE-EX 'Y' position
			# In CBRE-EX, the positive 'Y' axis (Godot's positive Z axis) is in the opposite 
			# direction to Godot's positive Z axis, so we have to flip it here.
			vertices.append(Vector3(pos_x, pos_y, -pos_z) * Vector3(options.get("mesh/scale_mesh")))
			
			# Get the texture and lightmap UVs.
			var texU = vertex_data.decode_float(12)
			var texV = vertex_data.decode_float(16)
			var lmU = vertex_data.decode_float(20)
			var lmV = vertex_data.decode_float(24)
			tex_uvs.append(Vector2(texU, texV))
			lm_uvs.append(Vector2(lmU, lmV))
			
			# The data for each vertex ends with three FF bytes.
			file.get_buffer(3)
		
		# Get the triangle count.
		var tri_count: int = file.get_32() as int
		
		# Get the triangle indices.
		var tri_indices: PackedInt32Array = PackedInt32Array() as PackedInt32Array
		for j in tri_count * 3:
			# Each indice is stored as 4 bytes.
			tri_indices.append(file.get_32() as int)
		
		# The triangle indice count must be a multiple of the triangle count.
		if tri_indices.size() % tri_count:
			return FAILED
		
		# For each indice, give it it's corresponding vertex,
		# texture UV and (unused) lightmap UV.
		var vert_ind_pairs: Dictionary = {} as Dictionary
		var pos_in_ind_arr: int = -1 as int
		for j in tri_indices.size() as int:
			pos_in_ind_arr += 1
			# If an indice already has vertex data associated with it, 
			# we know we can just skip it.
			if !vert_ind_pairs.has(tri_indices[j]):
				vert_ind_pairs[tri_indices[j]] = {
					"vertex": vertices[pos_in_ind_arr],
					"tex_uv": tex_uvs[pos_in_ind_arr],
					"lm_uv": lm_uvs[pos_in_ind_arr]
				}
			else:
				pos_in_ind_arr -= 1
		
		# Every vertex should have only one indice associated with it.
		if vert_ind_pairs.size() != vertices.size():
			return FAILED
		
		if !st_has_begun:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st_has_begun = true
		# Add data associated with each indice to the SurfaceTool.
		for j in tri_indices as PackedInt32Array:
			st.set_uv(vert_ind_pairs.get(j).get("tex_uv"))
			var mat_path = options.get("materials/material_path") as String
			if mat_path != "":
				# Fix up material path so it works.
				if mat_path.right(1) != "/":
					mat_path += "/"
				mat_path += tex_name.trim_suffix(tex_name.get_extension()) + "tres"
				if ResourceLoader.exists(mat_path, "Material"):
					st.set_material(load(mat_path))
			st.add_vertex(vert_ind_pairs.get(j).get("vertex"))
		
		# If we want to merge duplicated surfaces, we don't allow the SurfaceTool
		# to add a surface to the ArrayMesh just yet. Instead, we do the duplication
		# checking when we begin analyzing a new texture. However, when we are
		# analyzing the last texture, we create the last surface, and aren't going
		# to be checking another texture, so we commit the surface anyway.
		if !bool(options.get("mesh/merge_duplicated_surfaces")) or i == tex_count - 1:
			st.generate_normals()
			st.commit(arr_mesh)
			st.clear()
			st_has_begun = false
			var surf_name: String = prev_tex_name.get_file().trim_suffix(prev_tex_name.get_extension()).rstrip(".") as String
			arr_mesh.surface_set_name(arr_mesh.get_surface_count() - 1, surf_name)
	
	var has_invis_coll: bool = file.get_32() as bool
	
	# Handle invisible collisions. We mostly have to repeat the same processes
	# as with the normal face data.
	# NOTE: I feel like this could be simplified. Maybe will look into it later.
	if has_invis_coll and bool(options.get("mesh/include_invisible_collisions")):
		var invis_coll_vert_count: int = file.get_32() as int
		
		# Get the invisible collision vertices.
		var invis_coll_vertices: PackedVector3Array = PackedVector3Array() as PackedVector3Array
		for j in invis_coll_vert_count:
			# The actual data for each invisible collision vertex takes up 12 bytes.
			# Only the X, Y and Z positions get saved with invisible collision vertices.
			# Other than that, we do mostly the same things as with normal face vertices.
			var invis_coll_vertex_data: PackedByteArray = file.get_buffer(12) as PackedByteArray
			
			var pos_x: float = invis_coll_vertex_data.decode_float(0) # CBRE-EX 'X' position
			var pos_y: float = invis_coll_vertex_data.decode_float(4) # CBRE-EX 'Z' position
			var pos_z: float = invis_coll_vertex_data.decode_float(8) # CBRE-EX 'Y' position
			invis_coll_vertices.append(Vector3(pos_x, pos_y, -pos_z) * Vector3(options.get("mesh/scale_mesh")))
			
			# The data for each invisible collision vertex doesn't end with any extra bytes.
		
		# Get the invisible collision triangle count.
		var invis_coll_tri_count: int = file.get_32() as int
		
		# Get the invisible collision triangle indices.
		var invis_coll_tri_indices: PackedInt32Array = PackedInt32Array() as PackedInt32Array
		for j in invis_coll_tri_count * 3:
			# Each indice is stored as 4 bytes.
			invis_coll_tri_indices.append(file.get_32() as int)
		
		# For each invisible collision indice, give it it's corresponding vertex.
		var invis_coll_vert_ind_pairs: Dictionary = {} as Dictionary
		var pos_in_invis_coll_ind_arr: int = -1 as int
		for j in invis_coll_tri_indices.size() as int:
			pos_in_invis_coll_ind_arr += 1
			# If an indice already has vertex data associated with it, 
			# we know we can just skip it.
			if !invis_coll_vert_ind_pairs.has(invis_coll_tri_indices[j]):
				invis_coll_vert_ind_pairs[invis_coll_tri_indices[j]] = invis_coll_vertices[pos_in_invis_coll_ind_arr]
			else:
				pos_in_invis_coll_ind_arr -= 1
		
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_has_begun = true
		for j in invis_coll_tri_indices as PackedInt32Array:
			st.add_vertex(invis_coll_vert_ind_pairs.get(j))
		
		st.generate_normals()
		st.commit(arr_mesh)
		st.clear()
		st_has_begun = false
		arr_mesh.surface_set_name(arr_mesh.get_surface_count() - 1, "invisible_collision")
	
	return ResourceSaver.save(arr_mesh, "%s.%s" % [save_path, _get_save_extension()])

func read_b3d_string(file: FileAccess) -> String:
	var len: int = file.get_32() as int
	var string: String = file.get_buffer(len).get_string_from_utf8()
	return string
