# https://github.com/AnalogFeelings/cbre-ex/blob/main/Source/CBRE.Editor/Compiling/RMeshExport.cs
@tool
extends EditorImportPlugin

enum PRESETS {
	DEFAULT
}

const _LIGHTMAP_SHADER: Shader = preload(
		"res://addons/rmesh_import/lightmap.gdshader"
)
const _UTILS := preload("res://addons/rmesh_import/utils.gd")


# Fix crash when importing multiple files with threads.
# Hopefully this will be resolved in Godot 4.4.
func _can_import_threaded() -> bool:
	return false


func _get_importer_name() -> String:
	return "rmesh.cbre-ex.scene"


func _get_visible_name() -> String:
	return "CBRE-EX RMesh as PackedScene"


func _get_recognized_extensions() -> PackedStringArray:
	return ["rmesh"]


func _get_save_extension() -> String:
	return "tscn"


func _get_priority() -> float:
	return 1.0


func _get_resource_type() -> String:
	return "PackedScene"


func _get_preset_count():
	return PRESETS.size()


func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		PRESETS.DEFAULT:
			return "Default"
		_:
			return "Unknown"


func _get_import_order() -> ImportOrder:
	return IMPORT_ORDER_DEFAULT


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	
	# The options here have been ordered from what I thought the user would
	# find the most important to the least important.
	
	options.push_back({
			"name": _UTILS.OPTION_SCALE_MESH,
			"default_value": Vector3(1, 1, 1),
			"property_hint": PROPERTY_HINT_LINK,
	})
	
	# Materials.
	
	options.push_back({
			"name": _UTILS.OPTION_MATERIAL_PATH,
			"default_value": "",
			"property_hint": PROPERTY_HINT_DIR,
	})
	
	# Lightmaps.
	
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_LIGHTMAPS,
			"default_value": false,
			"usage": (
					PROPERTY_USAGE_DEFAULT |
					PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED
			)
	})
	options.push_back({
			"name": _UTILS.OPTION_LIGHT_MULTIPLIER,
			"default_value": 1.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0, 0, 0.001, or_greater, hide_slider",
	})
	options.push_back({
			"name": _UTILS.OPTION_LIGHTMAP_PATH,
			"default_value": "",
			"property_hint": PROPERTY_HINT_DIR,
	})
	
	# Collisions.
	
	options.push_back({
			"name": _UTILS.OPTION_GENERATE_COLLISION_MESH,
			"default_value": false,
			"usage": (
					PROPERTY_USAGE_DEFAULT |
					PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED
			)
	})
	options.push_back({
			"name": _UTILS.OPTION_SPLIT_COLLISION_MESH,
			"default_value": false,
	})
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_INVISIBLE_COLLISIONS,
			"default_value": true
	})
	
	# Entities.
	
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_ENTITIES,
			"default_value": true,
			"usage": (
					PROPERTY_USAGE_DEFAULT |
					PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED
			)
	})
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_LIGHTS,
			"default_value": true,
			"usage": (
					PROPERTY_USAGE_DEFAULT |
					PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED
			)
	})
	options.push_back({
			"name": _UTILS.OPTION_LIGHT_RANGE_SCALE,
			"default_value": 1.0,
	})
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_MODELS,
			"default_value": true,
	})
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_WAYPOINTS,
			"default_value": true,
	})
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_SOUND_EMITTERS,
			"default_value": true,
			"usage": (
					PROPERTY_USAGE_DEFAULT |
					PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED
			)
	})
	options.push_back({
			"name": _UTILS.OPTION_SOUND_RANGE_SCALE,
			"default_value": 1.0,
	})
	options.push_back({
			"name": _UTILS.OPTION_INCLUDE_SCREENS,
			"default_value": true,
	})
	
	return options


func _get_option_visibility(
		path: String, option_name: StringName, options: Dictionary
) -> bool:
	if (
			option_name == _UTILS.OPTION_LIGHT_MULTIPLIER
			or option_name == _UTILS.OPTION_LIGHTMAP_PATH
	):
		return options.get(_UTILS.OPTION_INCLUDE_LIGHTMAPS)
	
	if (
			option_name == _UTILS.OPTION_SPLIT_COLLISION_MESH
			or option_name == _UTILS.OPTION_INCLUDE_INVISIBLE_COLLISIONS
	):
		return options.get(_UTILS.OPTION_GENERATE_COLLISION_MESH)
	
	if options.get(_UTILS.OPTION_INCLUDE_ENTITIES):
		match option_name:
			_UTILS.OPTION_LIGHT_RANGE_SCALE:
				return options.get(_UTILS.OPTION_INCLUDE_LIGHTS)
			_UTILS.OPTION_SOUND_RANGE_SCALE:
				return options.get(_UTILS.OPTION_INCLUDE_SOUND_EMITTERS)
	elif (
			option_name == _UTILS.OPTION_INCLUDE_LIGHTS
			or option_name == _UTILS.OPTION_LIGHT_RANGE_SCALE
			or option_name == _UTILS.OPTION_INCLUDE_MODELS
			or option_name == _UTILS.OPTION_INCLUDE_WAYPOINTS
			or option_name == _UTILS.OPTION_INCLUDE_SOUND_EMITTERS
			or option_name == _UTILS.OPTION_SOUND_RANGE_SCALE
			or option_name == _UTILS.OPTION_INCLUDE_SCREENS
	):
		return options.get(_UTILS.OPTION_INCLUDE_ENTITIES)
	
	return true


func _import(
		source_file: String, save_path: String, options: Dictionary, 
		platform_variants: Array[String], gen_files: Array[String]
) -> Error:
	var source: FileAccess = FileAccess.open(source_file, FileAccess.READ)
	if not is_instance_valid(source):
		return FileAccess.get_open_error()
	
	# Get the header. It's always "RoomMesh".
	var header := source.get_pascal_string()
	if not header == "RoomMesh":
		push_error(
			"CBRE-EX Scene import - Header must be \"RoomMesh\","
			+ " instead is \"" + header + "\"."
		)
		return FAILED
	
	var scale_mesh: Vector3 = options.get(_UTILS.OPTION_SCALE_MESH)
	var include_lightmaps: bool = options.get(_UTILS.OPTION_INCLUDE_LIGHTMAPS)
	
	var saved_scene_root := Node3D.new()
	var saved_scene_root_name: String = (
			source_file.get_file().trim_suffix(".rmesh")
	)
	saved_scene_root.name = saved_scene_root_name
	
	# Get the texture count.
	var texture_count: int = source.get_32()
	
	# We accumulate all the data about the surfaces into this surface 
	# dictionary.
	var surface_data: Dictionary[String, Dictionary] = {}
	
	# Array of all the textures used in the file. There's only one of each 
	# texture used. Helpful when constructing the mesh later.
	var used_textures := PackedStringArray()
	
	# Each texture has a set amount of faces associated with it.
	# In the RMesh file, faces are just stored as a sequence of vertices for 
	# each texture.
	for i in texture_count:
		var lightmap_flag: int = source.get_8()
		var lightmap_name := ""
		# If the lightmap flag is 0, a lightmap isn't generated for this 
		# texture.
		if lightmap_flag == 1:
			lightmap_name = source.get_pascal_string()
		
		# If the texture flag is 3, the texture is without a lightmap.
		var texture_flag = source.get_8()
		# If the texture flag is 3, then in CBRE-EX RMesh files, the lightmap 
		# flag must always be 0.
		if texture_flag == 3 and not lightmap_flag == 0:
			push_error(
					"CBRE-EX Scene import - Texture flag is 3, but lightmap "
					+ "flag is not 0."
			)
			return FAILED
		
		# Get the texture name.
		var texture_name: String = source.get_pascal_string()
		
		# Add the lightmap name as a dictionary to the surface dictionary if 
		# it was not yet added.
		if not surface_data.has(lightmap_name):
			surface_data[lightmap_name] = {}
		
		# Add the texture name to the lightmap name dictionary as a dictionary 
		# if it was not yet added.
		if not surface_data.get(lightmap_name).has(texture_name):
			surface_data.get(lightmap_name)[texture_name] = {}
		
		# Add the texture name to the list of used textures if it was not yet 
		# added.
		if not used_textures.has(texture_name):
			used_textures.push_back(texture_name)
		
		# Get the vertex count.
		var vertex_count: int = source.get_32()
		
		# Initialize arrays for texture and lightmap UVs.
		var tex_uvs := PackedVector2Array()
		var lm_uvs := PackedVector2Array()
		
		# Get the vertices.
		var vertices := PackedVector3Array()
		for j in vertex_count:
			# The data for each vertex takes up 31 bytes.
			var vertex_data: PackedByteArray = source.get_buffer(31)
			
			# Each vertex X, Y and Z position takes up 4 bytes.
			# In CBRE-EX, X and Y are horizontal positions, while Z is vertical.
			# This means that a vertex location is technically X Z Y. 
			# This is how they are stored in the file, however, in Godot, 
			# X and Z are horizontal, while Y is vertical.
			
			# CBRE-EX 'X' position
			var pos_x := vertex_data.decode_float(0)
			# CBRE-EX 'Z' position
			var pos_y := vertex_data.decode_float(4)
			# CBRE-EX 'Y' position
			var pos_z := vertex_data.decode_float(8)
			
			# In CBRE-EX, the positive 'Y' axis (Godot's positive Z axis) is 
			# in the opposite direction to Godot's positive Z axis, so we have
			# to flip it here.
			vertices.push_back(Vector3(pos_x, pos_y, -pos_z) * scale_mesh)
			
			# Get the texture and lightmap UVs.
			var tex_u = vertex_data.decode_float(12)
			var tex_v = vertex_data.decode_float(16)
			var lm_u = vertex_data.decode_float(20)
			var lm_v = vertex_data.decode_float(24)
			
			tex_uvs.push_back(Vector2(tex_u, tex_v))
			# We don't care about lightmap UVs if we don't include lightmaps.
			if include_lightmaps:
				lm_uvs.push_back(Vector2(lm_u, lm_v))
			
			# The data for each vertex ends with three
			# 'RGB' bytes. Usually, they are just three FF bytes.
			# We don't really care about these.
		
		var triangle_count: int = source.get_32()
		var triangle_indices := PackedInt32Array()
		for j in triangle_count * 3:
			# Each indice is stored as 4 bytes.
			triangle_indices.push_back(source.get_32())
		
		# The triangle indice count must be a multiple
		# of the triangle count.
		if not _UTILS.check_tri_ind_count(
				triangle_indices, triangle_count
		):
			return FAILED
		
		# For each indice, give it it's corresponding vertice,
		# texture UV and lightmap UV.
		var vert_ind_pairs := Dictionary()
		if include_lightmaps:
			vert_ind_pairs = _UTILS.create_vert_ind_pairs(
					vertices, triangle_indices, [tex_uvs, lm_uvs]
			)
		else:
			vert_ind_pairs = _UTILS.create_vert_ind_pairs(
					vertices, triangle_indices, [tex_uvs]
			)
		
		# Check if the vertice-indice pairs creation
		# process succeeded.
		if vert_ind_pairs.is_empty():
			return FAILED
		
		surface_data.get(lightmap_name).get(texture_name)["indices"] = (
				triangle_indices
		)
		surface_data.get(lightmap_name).get(texture_name)["pairs"] = (
				vert_ind_pairs
		)
	
	var has_invis_coll: bool = source.get_32()
	
	var include_invis_coll: bool = options.get(
			_UTILS.OPTION_INCLUDE_INVISIBLE_COLLISIONS
	)
	var generate_coll: bool = options.get(_UTILS.OPTION_GENERATE_COLLISION_MESH)
	
	# Handle invisible collisions. We mostly have to repeat the same processes 
	# as with the normal face data.
	var invis_coll_arr: Array[Dictionary] = []
	
	if has_invis_coll:
		if generate_coll and include_invis_coll:
			var invis_coll_vert_count: int = source.get_32()
			
			# Get the invisible collision vertices.
			var invis_coll_vertices := PackedVector3Array()
			for i in invis_coll_vert_count:
				# The actual data for each invisible collision vertex
				# takes up 12 bytes. Only the X, Y and Z positions get
				# saved with invisible collision vertices. Other than
				# that, we do mostly the same things as with normal
				# face vertices.
				var invis_coll_vertex_data: PackedByteArray = (
						source.get_buffer(12)
				)
				
				# CBRE-EX 'X' position
				var pos_x := invis_coll_vertex_data.decode_float(0)
				# CBRE-EX 'Z' position 
				var pos_y := invis_coll_vertex_data.decode_float(4)
				# CBRE-EX 'Y' position
				var pos_z := invis_coll_vertex_data.decode_float(8)
				
				invis_coll_vertices.push_back(
						Vector3(pos_x, pos_y, -pos_z) * scale_mesh
				)
				
				# The data for each invisible collision vertex doesn't end with 
				# any extra bytes.
			
			# Get the invisible collision triangle count.
			var invis_coll_tri_count: int = source.get_32()
			
			# Get the invisible collision triangle indices.
			var invis_coll_triangle_indices := PackedInt32Array()
			for i in invis_coll_tri_count * 3:
				# Each indice is stored as 4 bytes.
				invis_coll_triangle_indices.append(source.get_32())
			
			# The triangle indice count must be a multiple of the triangle 
			# count.
			if not _UTILS.check_tri_ind_count(
					invis_coll_triangle_indices,
					invis_coll_tri_count
			):
				return FAILED
			
			# For each invisible collision indice, give it it's corresponding 
			# vertice.
			var invis_coll_vert_ind_pairs := Dictionary(
					_UTILS.create_vert_ind_pairs(
							invis_coll_vertices, invis_coll_triangle_indices
					)
			)
			
			# Check if the vertice-indice pairs creation process succeeded.
			if invis_coll_vert_ind_pairs.is_empty():
				return FAILED
			
			invis_coll_arr.push_back({
					"indices": invis_coll_triangle_indices,
					"pairs": invis_coll_vert_ind_pairs
			})
		else:
			# If the RMesh has invisible collisions but we choose to ignore 
			# them, we still have to move forward in the file so that we don't 
			# read the wrong data afterwards.
			var invis_coll_vert_count: int = source.get_32()
			
			# Skip through all the vertices.
			for i in invis_coll_vert_count * 3:
				source.get_32()
			
			# Skip through all the indices.
			var invis_coll_tri_count: int = source.get_32()
			for i in invis_coll_tri_count * 3:
				source.get_32()
	
	# Initialize the ArrayMesh and SurfaceTool.
	var array_mesh := ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	
	var mat_path: String = options.get(
		"materials/material_path"
	) as String
	
	var lm_path: String = options.get(
		"lightmaps/lightmap_path"
	) as String
	
	# Mesh construction.
	if not include_lightmaps:
		# If we don't include lightmaps.
		
		var curr_mat_checked: bool = false
		var curr_loaded_mat: Material = null
		
		for curr_tex in used_textures:
			surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for lm in surface_data:
				var lmd: Dictionary = surface_data.get(lm)
				if lmd.has(curr_tex):
					var td: Dictionary = lmd.get(curr_tex)
					var indices: PackedInt32Array = td.get("indices")
					var pairs: Dictionary = td.get("pairs")
					
					for i in indices:
						var pairs_ind: Array = pairs.get(i)
						
						surface_tool.set_uv(pairs_ind[1])
						
						# Set the material.
						if (
							not curr_mat_checked 
							and not curr_loaded_mat
						):
							# Fix up material path so it works.
							var n_mat_path: String = mat_path
							if mat_path == "":
								n_mat_path += source_file.get_base_dir() + "/"
							if not n_mat_path.right(1) == "/":
								n_mat_path += "/"
							n_mat_path += curr_tex.trim_suffix(
								curr_tex.get_extension()
							) + "tres"
							print(n_mat_path)
							
							# If we don't have a material loaded,
							# we can check if it exists and load it.
							# Then we say the material was checked.
							# We only need to check it once to know
							# if it exists or not.
							if FileAccess.file_exists(
								n_mat_path
							):
								curr_loaded_mat = load(
									n_mat_path
								)
							curr_mat_checked = true
						# We then check if we have a material
						# loaded after that process.
						if curr_loaded_mat:
							surface_tool.set_material(curr_loaded_mat)
						
						surface_tool.add_vertex(pairs_ind[0])
			
			surface_tool.generate_normals()
			surface_tool.commit(array_mesh)
			surface_tool.clear()
			# WARNING: Textures that are from different
			# folders but share the same filename will
			# not be differentiated, and will be treated
			# as the same texture.
			array_mesh.surface_set_name(
				array_mesh.get_surface_count() - 1, 
				curr_tex.get_file().trim_suffix(
					curr_tex.get_extension()
				).rstrip(".")
			)
			
			curr_loaded_mat = null
			curr_mat_checked = false
	else:
		# If we include lightmaps.
		
		var curr_mat_checked: bool = false
		var curr_loaded_mat: StandardMaterial3D = null
		
		var curr_lm_tex_checked: bool = false
		var curr_loaded_lm_tex: Texture2D = null
		
		var lm_index = 1
		for lm in surface_data:
			var lmd: Dictionary = surface_data.get(
				lm
			) as Dictionary
			for tex: String in lmd:
				var lm_mat: ShaderMaterial = null
				
				surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				var td: Dictionary = lmd.get(tex)
				var indices: PackedInt32Array = td.get("indices")
				var pairs: Dictionary = td.get("pairs")
				
				for i in indices:
					var pairs_ind: Array = pairs.get(
						i
					) as Array
					
					surface_tool.set_uv(pairs_ind[1])
					surface_tool.set_uv2(pairs_ind[2])
					
					if (
						not curr_mat_checked 
						and not curr_loaded_mat
					):
						# Fix up material path so it works.
						var n_mat_path: String = mat_path
						if mat_path == "":
							n_mat_path += source_file.get_base_dir() + "/"
						if not n_mat_path.right(1) == "/":
							n_mat_path += "/"
						n_mat_path += tex.trim_suffix(
							tex.get_extension()
						) + "tres"
						
						# If we don't have a material loaded, we can
						# check if it exists and load it. Then we say
						# the material was checked. We only need to
						# check it once to know if it exists or not.
						if FileAccess.file_exists(
							n_mat_path
						):
							curr_loaded_mat = load(
								n_mat_path
							)
						curr_mat_checked = true
					
					if not lm == "none":
						if (
							not curr_lm_tex_checked
							and not curr_loaded_lm_tex
						):
							# Fix up lightmap texture path
							# so it works. If a lightmap
							# path is set, the texture files
							# will be read from there, otherwise,
							# they will be read from the RMesh
							# file's directory.
							var new_lm_tex_path: String = ""
							if lm_path == "":
								new_lm_tex_path = (
									source_file.get_base_dir()
									+ "/" + lm
								)
							else:
								new_lm_tex_path = (
									lm_path + "/" + lm
								)
							
							# If we don't have a lightmap texture
							# loaded, we can check if it exists and
							# load it. Then we say the texture was
							# checked. We only need to check it once
							# to know if it exists or not.
							if FileAccess.file_exists(
								new_lm_tex_path
							):
								curr_loaded_lm_tex = load(
									new_lm_tex_path
								)
							curr_lm_tex_checked = true
						
						if (
							curr_loaded_lm_tex
							and curr_loaded_mat
						):
							# If the surface has a lightmap
							# associated with it and we loaded
							# both the lightmap and the normal
							# texture, we give it the lightmap
							# material with both textures applied.
							if not lm_mat:
								lm_mat = ShaderMaterial.new()
								lm_mat.shader = _LIGHTMAP_SHADER
							
							if curr_loaded_mat.albedo_texture:
								lm_mat.set_shader_parameter(
									"texture_albedo",
									curr_loaded_mat.albedo_texture
								)
							
							if curr_loaded_mat.normal_texture:
								lm_mat.set_shader_parameter(
									"texture_normal",
									curr_loaded_mat.normal_texture
								)
								lm_mat.set_shader_parameter(
									"normal_scale",
									curr_loaded_mat.normal_scale
								)
							
							lm_mat.set_shader_parameter(
								"texture_lightmap",
								curr_loaded_lm_tex
							)
							
							lm_mat.set_shader_parameter(
								"light_multiplier",
								options.get(
									"lightmaps/light_multiplier"
								)
							)
							
							surface_tool.set_material(lm_mat)
						elif (
							curr_loaded_lm_tex
							and not curr_loaded_mat
						):
							# If the surface has a lightmap
							# associated with it and we loaded
							# it, but we couldn't load the normal
							# texture, we give it the lightmap
							# material but only with the lightmap
							# texture applied.
							if not lm_mat:
								lm_mat = ShaderMaterial.new()
								lm_mat.shader = _LIGHTMAP_SHADER
							
							lm_mat.set_shader_parameter(
								"texture_lightmap",
								curr_loaded_lm_tex
							)
							
							lm_mat.set_shader_parameter(
								"light_multiplier",
								options.get(
									"lightmaps/light_multiplier"
								)
							)
							surface_tool.set_material(lm_mat)
						elif (
							curr_loaded_mat
							and not curr_loaded_lm_tex
						):
							# If the surface has a lightmap
							# associated with it, but we can't
							# load it, we give it the normal
							# material, if we have one.
							surface_tool.set_material(curr_loaded_mat)
					elif curr_loaded_mat:
						# If the surface doesn't have a
						# lightmap associated with it, we give
						# it the normal material, if we have one.
						surface_tool.set_material(curr_loaded_mat)
					
					surface_tool.add_vertex(pairs_ind[0])
				
				surface_tool.generate_normals()
				surface_tool.commit(array_mesh)
				surface_tool.clear()
				
				# WARNING: Textures that are from different
				# folders but share the same filename will
				# not be differentiated, and will be treated
				# as the same texture.
				if not lm == "none":
					array_mesh.surface_set_name(
						array_mesh.get_surface_count() - 1,
						tex.get_file().trim_suffix(
							tex.get_extension()
						).rstrip(".")
						+ "_lm" + str(lm_index)
					)
				else:
					array_mesh.surface_set_name(
						array_mesh.get_surface_count() - 1,
						tex.get_file().trim_suffix(
							tex.get_extension()
						).rstrip(".")
					)
				
				curr_loaded_lm_tex = null
				curr_lm_tex_checked = false
				
				curr_loaded_mat = null
				curr_mat_checked = false
			
			if not lm == "none":
				lm_index += 1
	
	# Add the mesh to the scene as a MeshInstance3D.
	var arr_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	arr_mesh_instance.name = saved_scene_root_name
	arr_mesh_instance.mesh = array_mesh
	saved_scene_root.add_child(arr_mesh_instance)
	arr_mesh_instance.owner = saved_scene_root
	
	# Generating the collision mesh.
	if generate_coll:
		if bool(options.get("collision/split_collision_mesh")):
			# We have to iterate through each used texture.
			# We can't just iterate through each surface in
			# the mesh due to lightmaps, since with them,
			# there can be multiple surfaces using the
			# same texture. 
			for tex in used_textures:
				# Get only the texture filename without
				# the extension.
				# WARNING: Textures that are from different
				# folders but share the same filename will
				# not be differentiated, and will be treated
				# as the same texture.
				var texture_name = tex.get_file().trim_suffix(
					tex.get_extension()
				).rstrip(".")
				
				# The array that will hold the surface arrays
				# from all the different surfaces using
				# the current texture.
				var surf_arrays: Array[Array] = []
				for i in array_mesh.get_surface_count():
					var surf_name: String = (
						array_mesh.surface_get_name(i)
					)
					# Get the surface name's suffix.
					# Surface names of meshes with lightmaps
					# end with something like "_lm".
					var surf_name_suffix: String = (
						surf_name.split("_") as Array
					).back() as String
					
					if (
						surf_name_suffix.begins_with("lm")
						and surf_name.trim_suffix(
							"_" + surf_name_suffix
						) == texture_name
					):
						# We don't care about lightmaps when
						# getting all the surfaces with a specific
						# texture, so we need to check against
						# a surface name that's without the
						# lightmap suffix. If this fixed surface
						# name the texture name, we add it to
						# the array.
						surf_arrays.append(
							array_mesh.surface_get_arrays(i)
						)
					elif surf_name == texture_name:
						# If the surface name the texture name,
						# we add it to the array.
						surf_arrays.append(
							array_mesh.surface_get_arrays(i)
						)
				
				var new_arr_mesh: ArrayMesh = ArrayMesh.new()
				for surf in surf_arrays:
					new_arr_mesh.add_surface_from_arrays(
						Mesh.PRIMITIVE_TRIANGLES, surf
					)
				
				var coll_body: StaticBody3D = StaticBody3D.new()
				var coll_body_name: String = texture_name
				if not coll_body_name.ends_with("_coll"):
					coll_body_name += "_coll"
				coll_body.name = coll_body_name
				saved_scene_root.add_child(coll_body)
				coll_body.owner = saved_scene_root
				
				var coll_shape: CollisionShape3D = (
					CollisionShape3D.new()
				)
				coll_shape.name = "CollisionShape3D"
				
				var coll_polygon: ConcavePolygonShape3D = (
					new_arr_mesh.create_trimesh_shape()
				)
				coll_shape.shape = coll_polygon
				
				coll_body.add_child(coll_shape)
				coll_shape.owner = saved_scene_root
		else:
			var coll_body: StaticBody3D = StaticBody3D.new()
			coll_body.name = saved_scene_root_name + "_coll"
			saved_scene_root.add_child(coll_body)
			coll_body.owner = saved_scene_root
			
			var coll_shape: CollisionShape3D = CollisionShape3D.new()
			coll_shape.name = "CollisionShape3D"
			
			var coll_polygon: ConcavePolygonShape3D = (
				array_mesh.create_trimesh_shape()
			)
			coll_shape.shape = coll_polygon
			
			coll_body.add_child(coll_shape)
			coll_shape.owner = saved_scene_root
		
		if include_invis_coll and not invis_coll_arr.is_empty():
			var invis_st: SurfaceTool = SurfaceTool.new()
			invis_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in invis_coll_arr as Array[Dictionary]:
				var pairs: Dictionary = i.get(
					"pairs"
				) as Dictionary
				
				for j in i.get("indices"):
					invis_st.add_vertex(pairs.get(j)[0])
			
			invis_st.generate_normals()
			var invis_arr_mesh: ArrayMesh = invis_st.commit()
			
			var coll_body: StaticBody3D = StaticBody3D.new()
			coll_body.name = "invis_coll"
			saved_scene_root.add_child(coll_body)
			coll_body.owner = saved_scene_root
			
			var coll_shape: CollisionShape3D = CollisionShape3D.new()
			coll_shape.name = "CollisionShape3D"
			
			var coll_polygon: ConcavePolygonShape3D = (
				invis_arr_mesh.create_trimesh_shape()
			)
			coll_shape.shape = coll_polygon
			
			coll_body.add_child(coll_shape)
			coll_shape.owner = saved_scene_root
	
	var include_lights: bool = options.get(
		"entities/lights/include_lights"
	) as bool
	var include_waypoints: bool = options.get(
		"entities/waypoints/include_waypoints"
	) as bool
	var include_snd_em: bool = options.get(
		"entities/sound_emitters/include_sound_emitters"
	) as bool
	var include_models: bool = options.get(
		"entities/models/include_models"
	) as bool
	var include_screens: bool = options.get(
		"entities/screens/include_screens"
	) as bool
	
	if (
		bool(options.get("entities/include_entities")) 
		and (
			include_lights 
			or include_waypoints 
			or include_snd_em
			or include_models 
			or include_screens
		)
	):
		var lights_folder_node: Node3D = null
		var waypoints_folder_node: Node3D = null
		var snd_em_folder_node: Node3D = null
		var models_folder_node: Node3D = null
		var screens_folder_node: Node3D = null
		
		var light_range_scale: float = options.get(
			"entities/lights/light_range_scale"
		) as float
		var sound_range_scale: float = options.get(
			"entities/sound_emitters/sound_range_scale"
		) as float
		
		var ent_count: int = source.get_32()
		for i in ent_count as int:
			var ent_name: String = source.get_pascal_string()
			match(ent_name):
				"light":
					# NOTICE: CBRE-EX doesn't distinguish
					# between normal lights and spotlights when
					# exporting. All imported lights will always
					# be OmniLight3Ds, never SpotLight3D.
					
					# Get light position.
					var pos: Vector3 = _UTILS.get_entity_position(
						source, scale_mesh
					)
					
					# Get light range. 4-byte float.
					var range: float = (
						source.get_float()
						* light_range_scale
					)
					
					# Get light color string.
					var color_string = source.get_pascal_string()
					var actual_color: Color = (
						_UTILS.get_color_from_string(
							color_string
						)
					)
					
					# Get light intensity. 4-byte float.
					var intensity: float = source.get_float()
					
					if include_lights:
						if not lights_folder_node:
							lights_folder_node = Node3D.new()
							lights_folder_node.name = "lights"
							saved_scene_root.add_child(
								lights_folder_node
							)
							lights_folder_node.owner = saved_scene_root
						
						var light_node: OmniLight3D = OmniLight3D.new()
						light_node.name = "light"
						light_node.position = pos
						light_node.omni_range = range
						light_node.light_color = actual_color
						light_node.light_energy = intensity
						lights_folder_node.add_child(
							light_node, true
						)
						light_node.owner = saved_scene_root
				"waypoint":
					# Get waypoint position.
					var pos: Vector3 = _UTILS.get_entity_position(
						source, scale_mesh
					)
					
					if include_waypoints:
						if not waypoints_folder_node:
							waypoints_folder_node = Node3D.new()
							waypoints_folder_node.name = "waypoints"
							saved_scene_root.add_child(
								waypoints_folder_node
							)
							waypoints_folder_node.owner = (
								saved_scene_root
							)
						
						var waypoint_node: Node3D = Node3D.new()
						waypoint_node.name = "waypoint"
						waypoint_node.position = pos
						waypoints_folder_node.add_child(
							waypoint_node, true
						)
						waypoint_node.owner = saved_scene_root
				"soundemitter":
					# Get sound emitter position.
					var pos: Vector3 = _UTILS.get_entity_position(
						source, scale_mesh
					)
					
					# Get ambience index. 4-byte int.
					var amb_ind: int = source.get_32()
					
					# Get sound emitter range. 4-byte float.
					var range: float = source.get_float()
					
					if include_snd_em:
						if not snd_em_folder_node:
							snd_em_folder_node = Node3D.new()
							snd_em_folder_node.name = "sound_emitters"
							saved_scene_root.add_child(
								snd_em_folder_node
							)
							snd_em_folder_node.owner = saved_scene_root
						
						var emitter_node: AudioStreamPlayer3D = (
							AudioStreamPlayer3D.new()
						)
						emitter_node.name = "soundemitter"
						emitter_node.position = pos
						emitter_node.max_distance = (
							range * sound_range_scale
						)
						snd_em_folder_node.add_child(
							emitter_node, true
						)
						emitter_node.owner = saved_scene_root
				"model":
					# Get model file path.
					var model_path: String = source.get_pascal_string()
					
					# Get model position.
					var pos: Vector3 = _UTILS.get_entity_position(
							source, scale_mesh
					)
					
					# Get model rotation.
					var rot: Vector3 = _UTILS.get_entity_rotation(source)
					
					# Get model scale.
					var scale: Vector3 = _UTILS.get_entity_scale(source)
					
					if include_models:
						if not models_folder_node:
							models_folder_node = Node3D.new()
							models_folder_node.name = "models"
							saved_scene_root.add_child(
								models_folder_node
							)
							models_folder_node.owner = saved_scene_root
						
						var model_node: Node3D = Node3D.new()
						model_node.name = "model"
						model_node.position = pos
						model_node.rotation_degrees = rot
						model_node.scale = scale
						models_folder_node.add_child(
							model_node, true
						)
						model_node.owner = saved_scene_root
				"screen":
					# Get screen position.
					var pos: Vector3 = _UTILS.get_entity_position(
						source, scale_mesh
					)
					
					# Get screen image file path.
					var img_path: String = source.get_pascal_string()
					
					if include_screens:
						if not screens_folder_node:
							screens_folder_node = Node3D.new()
							screens_folder_node.name = "screens"
							saved_scene_root.add_child(
								screens_folder_node
							)
							screens_folder_node.owner = saved_scene_root
						
						var screen_node: Node3D = Node3D.new()
						screen_node.name = "screen"
						screen_node.position = pos
						screens_folder_node.add_child(
							screen_node, true
						)
						screen_node.owner = saved_scene_root
				_:
					push_error(
						"CBRE-EX Scene import - Unknown entity"
						+ " detected, probably custom entity ("
						+ ent_name + ")."
					)
					break
	
	#print(JSON.stringify(surface_data, "    "))
	
	var saved_scene := PackedScene.new()
	saved_scene.pack(saved_scene_root)
	
	return ResourceSaver.save(
			saved_scene, "%s.%s" % [save_path, _get_save_extension()]
	)
