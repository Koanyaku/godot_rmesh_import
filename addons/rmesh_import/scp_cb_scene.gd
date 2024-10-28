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
	return "rmesh.scpcb.scene"


func _get_visible_name() -> String:
	return "SCP – CB RMesh as PackedScene"


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
				},
				{
					"name": "collision/generate_collision_mesh",
					"default_value": false,
				},
				{
					"name": "collision/include_invisible_collisions",
					"default_value": false,
				},
				{
					"name": "collision/split_collision_mesh",
					"default_value": false,
				},
				{
					"name": "materials/material_path",
					"default_value": "",
					"property_hint": PROPERTY_HINT_DIR,
				},
				{
					"name": "trigger_boxes/include_trigger_boxes",
					"default_value": true,
				},
				{
					"name": "entities/include_entities",
					"default_value": true,
				},
				{
					"name": "entities/screens/include_screens",
					"default_value": true,
				},
				{
					"name": "entities/waypoints/include_waypoints",
					"default_value": true,
				},
				{
					"name": "entities/lights/include_lights",
					"default_value": true,
				},
				{
					"name": "entities/lights/light_range_scale",
					"default_value": 1.0,
				},
				{
					"name": "entities/spotlights/include_spotlights",
					"default_value": true,
				},
				{
					"name": "entities/spotlights/spotlight_range_scale",
					"default_value": 1.0,
				},
				{
					"name": "entities/sound_emitters/include_sound_emitters",
					"default_value": true,
				},
				{
					"name": "entities/sound_emitters/sound_range_scale",
					"default_value": 1.0,
				},
				{
					"name": "entities/player_starts/include_player_starts",
					"default_value": true,
				},
				{
					"name": "entities/models/include_models",
					"default_value": true,
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
			"SCP-CB Scene import - Importing SCP-CB RMesh,"
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
	
	# We accumulate all the data about the surfaces into this
	# surface dictionary.
	var surf_dict: Dictionary = {}
	
	# Array of all the textures used in the file. There's only
	# one of each texture used. Helpful when constructing the
	# mesh later.
	var used_tex: PackedStringArray = PackedStringArray()
	
	var include_lm: bool = options.get(
		"lightmaps/include_lightmaps"
	) as bool
	
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
			lm_name = "none"
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
		
		var tex_name: String = file.get_pascal_string()
		if not surf_dict.has(lm_name):
			surf_dict[lm_name] = {}
		if not surf_dict.get(lm_name).has(tex_name):
			surf_dict.get(lm_name)[tex_name] = {}
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
		if tri_indices.size() % tri_count:
			push_error(
				"SCP-CB Scene import - Triangle indice count"
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
		
		# Every vertex should have only one indice
		# associated with it.
		if not vert_ind_pairs.size() == vertices.size():
			push_error(
				"SCP-CB Scene import - Vertice-indice pairs array"
				+ " size doesn't match vertices array size."
				+ " Every indice should have one set of vertices"
				+ " assigned to it (vertice-indice pairs array"
				+ " size: " + str(vert_ind_pairs.size())
				+ ", vertices array size: " + str(vertices.size())
				+ ")."
			)
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
		"collision/include_invisible_collisions"
	) as bool
	
	var generate_coll: bool = options.get(
		"collision/generate_collision_mesh"
	) as bool
	
	# Handle invisible collisions. We mostly have to repeat
	# the same processes as with the normal face data.
	var invis_coll_arr: Array[Dictionary] = []
	
	if invis_coll_count > 0:
		if generate_coll and include_invis_coll:
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
				if (
					invis_coll_tri_indices.size()
					% invis_coll_tri_count
				):
					push_error(
						"SCP-CB Scene import -"
						+ " Invisible collision triangle indice"
						+ " count is not a multiple of the"
						+ " invisible collision triangle count"
						+ " (indice count is "
						+ str(invis_coll_tri_indices.size())
						+ ", triangle count is " 
						+ str(invis_coll_tri_count) + ", " 
						+ str(invis_coll_tri_indices.size())
						+ " mod "
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
				var invis_coll_vert_ind_pairs: Dictionary = (
					helper_funcs.create_vert_ind_pairs(
						invis_coll_vertices,
						invis_coll_tri_indices
					)
				)
				
				# Every invisible collision vertex should have only
				# one indice associated with it.
				if not (
					invis_coll_vert_ind_pairs.size() 
					== invis_coll_vertices.size()
				):
					push_error(
						"SCP-CB Scene import - Invisible collision"
						+ " vertice-indice pairs array size"
						+ " doesn't match invisible collision"
						+ " vertices array size. Every indice"
						+ " should have one set of vertices"
						+ " assigned to it."
						+ " (vertice-indice pairs array size: "
						+ str(invis_coll_vert_ind_pairs.size())
						+ ", vertices array size: "
						+ str(invis_coll_vertices.size())
						+ ")"
					)
					return FAILED
				
				invis_coll_arr.append(
					{
						"indices": invis_coll_tri_indices,
						"pairs": invis_coll_vert_ind_pairs
					}
				)
		else:
			# If the RMesh has invisible collisions but we choose to
			# ignore them, we still have to move forward in the file
			# so that we don't read the wrong data afterwards.
			for i in invis_coll_count:
				var invis_coll_vert_count: int = file.get_32()
				for j in invis_coll_vert_count * 3:
					file.get_32()
				var invis_coll_tri_count: int = file.get_32()
				for j in invis_coll_tri_count * 3:
					file.get_32()
	
	# Initialize the ArrayMesh and SurfaceTool.
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	var st: SurfaceTool = SurfaceTool.new()
	
	var mat_path: String = options.get(
		"materials/material_path"
	) as String
	
	if not include_lm:
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
							# Fix up material path so it works.
							var new_lm_tex_path: String = (
								source_file.get_base_dir()
								+ "/"
								+ lm
							)
							
							# If we don't have a lightmap texture
							# loaded, we can check if it exists and
							# load it. Then we say the texture was
							# checked. We only need tocheck it once
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
							st.set_material(curr_loaded_mat)
					elif curr_loaded_mat:
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
	
	# Add the mesh to the scene as a MeshInstance3D.
	var arr_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	arr_mesh_instance.name = saved_scene_root_name
	arr_mesh_instance.mesh = arr_mesh
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
			for tex in used_tex:
				# Get only the texture filename without
				# the extension.
				# WARNING: Textures that are from different
				# folders but share the same filename will
				# not be differentiated, and will be treated
				# as the same texture.
				var tex_name = tex.get_file().trim_suffix(
					tex.get_extension()
				).rstrip(".")
				
				# The array that will hold the surface arrays
				# from all the different surfaces using
				# the current texture.
				var surf_arrays: Array[Array] = []
				for i in arr_mesh.get_surface_count():
					var surf_name: String = (
						arr_mesh.surface_get_name(i)
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
						) == tex_name
					):
						# We don't care about lightmaps when
						# getting all the surfaces with a specific
						# texture, so we need to check against
						# a surface name that's without the
						# lightmap suffix. If this fixed surface
						# name the texture name, we add it to
						# the array.
						surf_arrays.append(
							arr_mesh.surface_get_arrays(i)
						)
					elif surf_name == tex_name:
						# If the surface name the texture name,
						# we add it to the array.
						surf_arrays.append(
							arr_mesh.surface_get_arrays(i)
						)
				
				var new_arr_mesh: ArrayMesh = ArrayMesh.new()
				for surf in surf_arrays:
					new_arr_mesh.add_surface_from_arrays(
						Mesh.PRIMITIVE_TRIANGLES, surf
					)
				
				var coll_body: StaticBody3D = StaticBody3D.new()
				var coll_body_name: String = tex_name
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
				arr_mesh.create_trimesh_shape()
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
	
	var include_trb: bool = options.get(
		"trigger_boxes/include_trigger_boxes"
	) as bool
	
	if header == "RoomMesh.HasTriggerBox":
		var trb_count: int = file.get_32()
		if include_trb:
			var trb_folder_node: Node3D = Node3D.new()
			trb_folder_node.name = "trigger_boxes"
			saved_scene_root.add_child(trb_folder_node)
			trb_folder_node.owner = saved_scene_root
			
			for i in trb_count as int:
				var curr_trb_surf_count: int = file.get_32()
				for j in curr_trb_surf_count as int:
					var curr_trb_vert_count: int = file.get_32()
					var curr_trb_vertices: PackedVector3Array = (
						PackedVector3Array()
					)
					for k in curr_trb_vert_count as int:
						# The actual data for each trigger box
						# vertex takes up 12 bytes. Only the
						# X, Y and Z positions get saved with
						# trigger box vertices. Other than that,
						# we do mostly the same things as with
						# normal face vertices.
						var curr_trb_vertex_data: PackedByteArray = (
							file.get_buffer(12)
						)
						
						var pos_x: float = (
							curr_trb_vertex_data.decode_float(0)
						)
						var pos_y: float = (
							curr_trb_vertex_data.decode_float(4)
						)
						var pos_z: float = (
							curr_trb_vertex_data.decode_float(8)
						)
						curr_trb_vertices.append(
							Vector3(pos_x, pos_y, -pos_z)
							* scale_mesh
						)
					
					# Get the triangle count.
					var curr_trb_tri_count: int = file.get_32()
					
					# Get the triangle indices.
					var curr_trb_tri_indices: PackedInt32Array = (
						PackedInt32Array()
					)
					for k in curr_trb_tri_count * 3:
						# Each indice is stored as 4 bytes.
						curr_trb_tri_indices.append(file.get_32())
					
					# The triangle indice count must be a
					# multiple of the triangle count.
					if (
						curr_trb_tri_indices.size()
						% curr_trb_tri_count
					):
						push_error(
							"SCP-CB Scene import -"
							+ " Trigger box triangle indice count"
							+ " is not a multiple of the trigger"
							+ " box triangle count"
							+ " (indice count is " 
							+ str(curr_trb_tri_indices.size())
							+ ", triangle count is " 
							+ str(curr_trb_tri_count) + ", " 
							+ str(curr_trb_tri_indices.size())
							+ " mod "
							+ str(curr_trb_tri_count) + " = "
							+ str(
								curr_trb_tri_indices.size()
								% curr_trb_tri_count
							)
							+ ")."
						)
						return FAILED
					
					# For each indice, give it it's
					# corresponding vertex.
					var curr_trb_vert_ind_pairs: Dictionary = (
						helper_funcs.create_vert_ind_pairs(
							curr_trb_vertices,
							curr_trb_tri_indices
						)
					)
					
					# Every vertex should have only one indice
					# associated with it.
					if not (
						curr_trb_vert_ind_pairs.size()
						== curr_trb_vertices.size()
					):
						push_error(
							"SCP-CB Scene import - Trigger box"
							+ " vertice-indice pairs array size"
							+ " doesn't match trigger box"
							+ " vertices array size. Every indice"
							+ " should have one set of"
							+ " vertices assigned to it."
							+ " (vertice-indice pairs array size: "
							+ str(curr_trb_vert_ind_pairs.size())
							+ ", vertices array size: "
							+ str(curr_trb_vertices.size())
							+ ")"
						)
						return FAILED
					
					var curr_trb_name: String = file.get_pascal_string()
					
					var curr_trb_area_node: Area3D = Area3D.new()
					curr_trb_area_node.name = curr_trb_name
					trb_folder_node.add_child(
						curr_trb_area_node, true
					)
					curr_trb_area_node.owner = saved_scene_root
					
					var curr_trb_poly: ConvexPolygonShape3D = (
						ConvexPolygonShape3D.new()
					)
					curr_trb_poly.points = curr_trb_vertices
					
					var curr_trb_shape: CollisionShape3D = (
						CollisionShape3D.new()
					)
					curr_trb_shape.name = "CollisionShape3D"
					curr_trb_shape.shape = curr_trb_poly
					curr_trb_area_node.add_child(
						curr_trb_shape, true
					)
					curr_trb_shape.owner = saved_scene_root
		else:
			# If the RMesh has trigger boxes but we choose to
			# ignore them, we still have to move forward in the
			# file so that we don't read the wrong data afterwards.
			for i in trb_count as int:
				var curr_trb_surf_count: int = file.get_32()
				for j in curr_trb_surf_count as int:
					var curr_trb_vert_count: int = file.get_32()
					for k in curr_trb_vert_count * 3:
						file.get_32()
					var curr_trb_tri_count: int = file.get_32()
					for k in curr_trb_tri_count * 3:
						file.get_32()
					# Trigger box name
					file.get_pascal_string() 
	
	var include_screens: bool = options.get(
		"entities/screens/include_screens"
	) as bool
	var include_waypoints: bool = options.get(
		"entities/waypoints/include_waypoints"
	) as bool
	var include_lights: bool = options.get(
		"entities/lights/include_lights"
	) as bool
	var include_spotlights: bool = options.get(
		"entities/spotlights/include_spotlights"
	) as bool
	var include_snd_em: bool = options.get(
		"entities/sound_emitters/include_sound_emitters"
	) as bool
	var include_pl_starts: bool = options.get(
		"entities/player_starts/include_player_starts"
	) as bool
	var include_models: bool = options.get(
		"entities/models/include_models"
	) as bool
	
	if (
		bool(options.get("entities/include_entities"))
		and (
			include_screens 
			or include_waypoints 
			or include_lights 
			or include_spotlights
			or include_snd_em
			or include_pl_starts 
			or include_models
		)
	):
		var screens_folder_node: Node3D = null
		var waypoints_folder_node: Node3D = null
		var lights_folder_node: Node3D = null
		var spotlights_folder_node: Node3D = null
		var snd_em_folder_node: Node3D = null
		var pl_starts_folder_node: Node3D = null
		var models_folder_node: Node3D = null
		
		var light_range_scale: float = options.get(
			"entities/lights/light_range_scale"
		) as float
		var spotlight_range_scale: float = options.get(
			"entities/spotlights/spotlight_range_scale"
		) as float
		var sound_range_scale: float = options.get(
			"entities/sound_emitters/sound_range_scale"
		) as float
		
		var ent_count: int = file.get_32()
		for i in ent_count as int:
			var ent_name: String = file.get_pascal_string()
			match(ent_name):
				"screen":
					# Get screen position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
					)
					
					# Get screen image file path.
					var img_path: String = file.get_pascal_string()
					
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
				"waypoint":
					# Get waypoint position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
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
				"light":
					# NOTICE: Lighting will always look different
					# with imported lights than how it looks
					# in SCP-CB. The lights receive values from
					# the file, but you will have to tweak them
					# more if you want to get them to look the same
					# (or almost the same) as in SCP-CB.
					
					# Get light position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
					)
					
					# Get light range. 4-byte float.
					var range: float = (
						file.get_float()
						* light_range_scale
					)
					
					# Get light color string.
					var color_string = file.get_pascal_string()
					var actual_color: Color = (
						helper_funcs.get_color_from_string(
							color_string
						)
					)
					
					# Get light intensity. 4-byte float.
					var intensity: float = file.get_float()
					
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
				"spotlight":
					# NOTICE: Lighting will always look different
					# with imported spotlights than how it looks
					# in SCP-CB. The spotlights receive values from
					# the file, but you will have to tweak them
					# more if you want to get them to look the same
					# (or almost the same) as in SCP-CB.
					
					# Get spotlight position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
					)
					
					# Get spotlight range. 4-byte float.
					var range: float = (
						file.get_float()
						* spotlight_range_scale
					)
					
					# Get spotlight color string.
					var color_string = file.get_pascal_string()
					var actual_color: Color = (
						helper_funcs.get_color_from_string(
							color_string
						)
					)
					
					# Get spotlight intensity. 4-byte float.
					var intensity: float = file.get_float()
					
					# Get spotlight angles string.
					var angles: String = file.get_pascal_string()
					var rot: Vector3 = (
						helper_funcs.get_rotation_from_angles(
							angles
						)
					)
					
					# Get spotlight inner cone angle. 4-byte int.
					var inner_cone_angle: int = file.get_32()
					# Get spotlight outer cone angle. 4-byte int.
					var outer_cone_angle: int = file.get_32()
					
					if include_spotlights:
						if not spotlights_folder_node:
							spotlights_folder_node = Node3D.new()
							spotlights_folder_node.name = "spotlights"
							saved_scene_root.add_child(
								spotlights_folder_node
							)
							spotlights_folder_node.owner = (
								saved_scene_root
							)
						
						var spotlight_node: SpotLight3D = (
							SpotLight3D.new()
						)
						spotlight_node.name = "spotlight"
						spotlight_node.position = pos
						spotlight_node.rotation_degrees = rot
						spotlight_node.spot_range = range
						spotlight_node.spot_angle = outer_cone_angle
						spotlight_node.light_color = actual_color
						spotlight_node.light_energy = intensity
						spotlights_folder_node.add_child(
							spotlight_node, true
						)
						spotlight_node.owner = saved_scene_root
				"soundemitter":
					# Get sound emitter position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
					)
					
					# Get sound index. 4-byte int.
					var snd_ind: int = file.get_32()
					
					# Get soundemitter range. 4-byte float.
					var range: float = file.get_float()
					
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
				"playerstart":
					# Get player start position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
					)
					
					# Get player start angles string.
					var angles: String = file.get_pascal_string()
					var rot: Vector3 = (
						helper_funcs.get_rotation_from_angles(
							angles
						)
					)
					
					if include_pl_starts:
						if not pl_starts_folder_node:
							pl_starts_folder_node = Node3D.new()
							pl_starts_folder_node.name = "player_starts"
							saved_scene_root.add_child(
								pl_starts_folder_node
							)
							pl_starts_folder_node.owner = (
								saved_scene_root
							)
						
						var pl_start_node: Node3D = Node3D.new()
						pl_start_node.name = "playerstart"
						pl_start_node.position = pos
						pl_start_node.rotation_degrees = rot
						pl_starts_folder_node.add_child(
							pl_start_node, true
						)
						pl_start_node.owner = saved_scene_root
				"model":
					# Get model file path.
					var model_path: String = file.get_pascal_string()
					
					# Get model position.
					var pos: Vector3 = helper_funcs.get_entity_position(
						file, scale_mesh
					)
					
					# Get model rotation.
					var rot: Vector3 = helper_funcs.get_entity_rotation(
						file
					)
					
					# Get model scale.
					var scale: Vector3 = helper_funcs.get_entity_scale(
						file
					)
					
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
				_:
					push_error(
						"SCP-CB Scene import - Unknown entity"
						+ " detected, probably custom entity ("
						+ ent_name + ")."
					)
					break
	
	var saved_scene = PackedScene.new()
	saved_scene.pack(saved_scene_root)
	return ResourceSaver.save(
		saved_scene, 
		"%s.%s" % [save_path, _get_save_extension()]
	)
