# https://github.com/Regalis11/scpcb/blob/master/Converter.bb
@tool
extends EditorImportPlugin

enum PRESETS { DEFAULT }

const LIGHTMAP_SHADER: Shader = preload(
	"res://addons/rmesh_import/lightmap.gdshader"
)

var helper_funcs = preload(
	"res://addons/rmesh_import/helper_funcs.gd"
).new()


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
					"name": "lightmaps/include_lightmaps",
					"default_value": false,
				},
				{
					"name": "lightmaps/light_multiplier",
					"default_value": 1.0,
					"property_hint": PROPERTY_HINT_RANGE,
					"hint_string": "0,0,0.001,or_greater,hide_slider",
				},
				{
					"name": "lightmaps/lightmap_path",
					"default_value": "",
					"property_hint": PROPERTY_HINT_DIR,
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
	var header: String = file.get_pascal_string()
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
	
	var include_lm: bool = options.get(
		"lightmaps/include_lightmaps"
	) as bool
	
	var saved_scene_root: Node3D = Node3D.new()
	var saved_scene_root_name: String = (
		source_file.get_file()
		.trim_suffix(".rmesh")
	)
	saved_scene_root.name = saved_scene_root_name
	
	# Get the texture count.
	var tex_count: int = file.get_32()
	
	# We accumulate all the data about the surfaces into this
	# surface dictionary.
	var surf_dict: Dictionary = {}
	
	# Array of all the textures used in the file. There's only
	# one of each texture used. Helpful when constructing the
	# mesh later.
	var used_tex: PackedStringArray = PackedStringArray()
	
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
			lm_name = file.get_pascal_string()
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
		
		# Get the texture name.
		var tex_name: String = file.get_pascal_string()
		
		# Add the lightmap name as a dictionary to the
		# surface dictionary if it was not yet added.
		if not surf_dict.has(lm_name):
			surf_dict[lm_name] = {}
		
		# Add the texture name to the lightmap name dictionary
		# as a dictionary if it was not yet added.
		if not surf_dict.get(lm_name).has(tex_name):
			surf_dict.get(lm_name)[tex_name] = {}
		
		# Add the texture name to the list of used textures
		# if it was not yet added.
		if not used_tex.has(tex_name):
			used_tex.append(tex_name)
		
		# Get the vertex count.
		var vertex_count: int = file.get_32()
		
		# Initialize arrays for texture and lightmap UVs.
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
			# We don't care about lightmap UVs if we don't
			# include lightmaps.
			if include_lm:
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
		if not helper_funcs.check_tri_ind_count(
			tri_indices,
			tri_count
		):
			return FAILED
		
		# For each indice, give it it's corresponding vertex,
		# texture UV and lightmap UV.
		var vert_ind_pairs: Dictionary = {}
		if include_lm:
			vert_ind_pairs = helper_funcs.create_vert_ind_pairs(
				vertices,
				tri_indices,
				[tex_uvs, lm_uvs]
			)
		else:
			vert_ind_pairs = helper_funcs.create_vert_ind_pairs(
				vertices,
				tri_indices,
				[tex_uvs]
			)
		
		# Check if the vertice-indice pairs creation
		# process succeeded.
		if vert_ind_pairs.is_empty():
			return FAILED
		
		surf_dict.get(lm_name).get(tex_name)[
			"indices"
		] = tri_indices
		surf_dict.get(lm_name).get(tex_name)[
			"pairs"
		] = vert_ind_pairs
	
	# Get the invisible collision face count.
	var invis_coll_count: int = file.get_32()
	
	var include_invis_coll: bool = options.get(
		"mesh/include_invisible_collisions"
	) as bool
	
	# Handle invisible collisions. We mostly have to repeat
	# the same processes as with the normal face data.
	var invis_coll_arr: Array[Dictionary] = []
	
	if invis_coll_count > 0 and include_invis_coll:
		for i in invis_coll_count:
			# Get the invisible collision vertex count.
			var invis_coll_vert_count: int = file.get_32()
			
			# Get the invisible collision vertices.
			var invis_coll_vertices: PackedVector3Array = (
				PackedVector3Array()
			)
			for j in invis_coll_vert_count:
				# The actual data for each invisible 
				# collision vertex takes up 12 bytes. 
				# Only the X, Y and Z positions get saved
				# with invisible collision vertices.
				# Other than that, we do mostly the same
				# things as with normal face vertices.
				var invis_coll_vertex_data: PackedByteArray = (
					file.get_buffer(12)
				)
				
				var pos_x: float = (
					invis_coll_vertex_data.decode_float(0)
				)
				var pos_y: float = (
					invis_coll_vertex_data.decode_float(4)
				)
				var pos_z: float = (
					invis_coll_vertex_data.decode_float(8)
				)
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
			for j in invis_coll_tri_count * 3:
				# Each indice is stored as 4 bytes.
				invis_coll_tri_indices.append(file.get_32())
			
			# The triangle indice count must be a multiple
			# of the triangle count.
			if not helper_funcs.check_tri_ind_count(
				invis_coll_tri_indices,
				invis_coll_tri_count
			):
				return FAILED
			
			# For each invisible collision indice, give it
			# it's corresponding vertice.
			var invis_coll_vert_ind_pairs: Dictionary = (
				helper_funcs.create_vert_ind_pairs(
					invis_coll_vertices,
					invis_coll_tri_indices
				)
			)
			
			# Check if the vertice-indice pairs creation
			# process succeeded.
			if invis_coll_vert_ind_pairs.is_empty():
				return FAILED
			
			invis_coll_arr.append(
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
	
	var lm_path: String = options.get(
		"lightmaps/lightmap_path"
	) as String
	
	if not include_lm:
		# If we don't include lightmaps.
		
		var curr_mat_checked: bool = false
		var curr_loaded_mat: Material = null
		
		for curr_tex in used_tex:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for lm in surf_dict:
				var lmd: Dictionary = surf_dict.get(
					lm
				) as Dictionary
				if lmd.has(curr_tex):
					var td: Dictionary = lmd.get(
						curr_tex
					) as Dictionary
					var indices: PackedInt32Array = td.get(
						"indices"
					) as PackedInt32Array
					var pairs: Dictionary = td.get(
						"pairs"
					) as Dictionary
					
					for i in indices:
						var pairs_ind: Array = pairs.get(i) as Array
						
						st.set_uv(pairs_ind[1])
						
						# Set the material.
						if (
							not mat_path == "" 
							and not curr_mat_checked 
							and not curr_loaded_mat
						):
							# Fix up material path so it works.
							var n_mat_path: String = mat_path
							if not n_mat_path.right(1) == "/":
								n_mat_path += "/"
							n_mat_path += curr_tex.trim_suffix(
								curr_tex.get_extension()
							) + "tres"
							
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
							st.set_material(curr_loaded_mat)
						
						st.add_vertex(pairs_ind[0])
			
			st.generate_normals()
			st.commit(arr_mesh)
			st.clear()
			# WARNING: Textures that are from different
			# folders but share the same filename will
			# not be differentiated, and will be treated
			# as the same texture.
			arr_mesh.surface_set_name(
				arr_mesh.get_surface_count() - 1, 
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
		for lm in surf_dict:
			var lmd: Dictionary = surf_dict.get(
				lm
			) as Dictionary
			for tex: String in lmd:
				var lm_mat: ShaderMaterial = null
				
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var td: Dictionary = lmd.get(
					tex
				) as Dictionary
				var indices: PackedInt32Array = td.get(
					"indices"
				) as PackedInt32Array
				var pairs: Dictionary = td.get(
					"pairs"
				) as Dictionary
				
				for i in indices:
					var pairs_ind: Array = pairs.get(
						i
					) as Array
					
					st.set_uv(pairs_ind[1])
					st.set_uv2(pairs_ind[2])
					
					if (
						not mat_path == "" 
						and not curr_mat_checked 
						and not curr_loaded_mat
					):
						# Fix up material path so it works.
						var n_mat_path: String = mat_path
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
								lm_mat.shader = LIGHTMAP_SHADER
							
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
							
							st.set_material(lm_mat)
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
								lm_mat.shader = LIGHTMAP_SHADER
							
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
							st.set_material(lm_mat)
						elif (
							curr_loaded_mat
							and not curr_loaded_lm_tex
						):
							# If the surface has a lightmap
							# associated with it, but we can't
							# load it, we give it the normal
							# material, if we have one.
							st.set_material(curr_loaded_mat)
					elif curr_loaded_mat:
						# If the surface doesn't have a
						# lightmap associated with it, we give
						# it the normal material, if we have one.
						st.set_material(curr_loaded_mat)
					
					st.add_vertex(pairs_ind[0])
				
				st.generate_normals()
				st.commit(arr_mesh)
				st.clear()
				
				# WARNING: Textures that are from different
				# folders but share the same filename will
				# not be differentiated, and will be treated
				# as the same texture.
				if not lm == "none":
					arr_mesh.surface_set_name(
						arr_mesh.get_surface_count() - 1,
						tex.get_file().trim_suffix(
							tex.get_extension()
						).rstrip(".")
						+ "_lm" + str(lm_index)
					)
				else:
					arr_mesh.surface_set_name(
						arr_mesh.get_surface_count() - 1,
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
	
	# Add invisible collisions to the mesh.
	if not invis_coll_arr.is_empty():
		for surf in invis_coll_arr:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var indices: PackedInt32Array = surf.get(
				"indices"
			) as PackedInt32Array
			var pairs: Dictionary = surf.get(
				"pairs"
			) as Dictionary
			
			for i in indices:
				st.add_vertex(pairs.get(i)[0])
			
			st.generate_normals()
			st.commit(arr_mesh)
			st.clear()
			
			arr_mesh.surface_set_name(
				arr_mesh.get_surface_count() - 1,
				"invis_coll"
			)
	
	return ResourceSaver.save(
		arr_mesh,
		"%s.%s" % [save_path, _get_save_extension()]
	)
