# https://github.com/AnalogFeelings/cbre-ex/blob/main/Source/CBRE.Editor/Compiling/RMeshExport.cs
@tool
extends EditorImportPlugin

enum PRESETS { DEFAULT }


# Fix crash when importing multiple files.
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
					"name": "collision/generate_collision_mesh",
					"default_value": false,
				},
				{
					"name": "collision/include_invisible_collisions",
					"default_value": true,
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
					"name": "entities/include_entities",
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
					"name": "entities/waypoints/include_waypoints",
					"default_value": true,
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
					"name": "entities/models/include_models",
					"default_value": true,
				},
				{
					"name": "entities/screens/include_screens",
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
	
	# Get the header.
	var header: String = read_b3d_string(file)
	if not header == "RoomMesh":
		return ERR_FILE_UNRECOGNIZED
	
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
		var lm_flag: int = file.get_8()
		var lm_name: String = ""
		# If the lightmap flag is 0, a lightmap isn't 
		# generated for this texture.
		if lm_flag == 1:
			lm_name = read_b3d_string(file)
		
		# If the texture flag is 3, the texture is 
		# without a lightmap.
		var tex_flag = file.get_8()
		var tex_name: String = read_b3d_string(file)
		if not tex_dict.has(tex_name):
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
			# In CBRE-EX, X and Y are horizontal positions, 
			# while Z is vertical. This means that a vertex 
			# location is technically X Z Y. This is how they
			# are stored in the file, however, in Godot, X and Z
			# are horizontal, while Y is vertical.
			
			# CBRE-EX 'X' position
			var pos_x: float = vertex_data.decode_float(0)
			# CBRE-EX 'Z' position
			var pos_y: float = vertex_data.decode_float(4)
			# CBRE-EX 'Y' position
			var pos_z: float = vertex_data.decode_float(8)
			
			# In CBRE-EX, the positive 'Y' axis 
			# (Godot's positive Z axis) is in the opposite direction
			# to Godot's positive Z axis, so we have to flip it here.
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
			return FAILED
		
		Array(tex_dict.get(tex_name)).append(
			{
				"indices": tri_indices,
				"pairs": vert_ind_pairs
			}
		)
	
	var has_invis_coll: bool = file.get_32() as bool
	var include_invis_coll: bool = options.get(
		"collision/include_invisible_collisions"
	) as bool
	var generate_coll: bool = options.get(
		"collision/generate_collision_mesh"
	) as bool
	
	# Handle invisible collisions. We mostly have to repeat 
	# the same processes as with the normal face data.
	var invis_coll_arr: Array[Dictionary] = []
	
	if has_invis_coll and generate_coll and include_invis_coll:
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
			
			# CBRE-EX 'X' position
			var pos_x: float = invis_coll_vertex_data.decode_float(0)
			# CBRE-EX 'Z' position 
			var pos_y: float = invis_coll_vertex_data.decode_float(4)
			# CBRE-EX 'Y' position
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
		
		# The triangle indice count must be a multiple
		# of the triangle count.
		if invis_coll_tri_indices.size() % invis_coll_tri_count:
			return FAILED
		
		# For each invisible collision indice, give it it's
		# corresponding vertex.
		var invis_coll_vert_ind_pairs: Dictionary = {}
		var pos_in_invis_coll_ind_arr: int = -1
		for i in invis_coll_tri_indices.size():
			pos_in_invis_coll_ind_arr += 1
			# If an indice already has vertex data associated
			# with it, we know we can just skip it.
			if not invis_coll_vert_ind_pairs.has(
				invis_coll_tri_indices[i]
			):
				invis_coll_vert_ind_pairs[
					invis_coll_tri_indices[i]
				] = invis_coll_vertices[pos_in_invis_coll_ind_arr]
			else:
				pos_in_invis_coll_ind_arr -= 1
		
		# Every invisible collision vertex should have only
		# one indice associated with it.
		if not (
			invis_coll_vert_ind_pairs.size()
			== invis_coll_vertices.size()
		):
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
					# Fix up material path so it works.
					var n_mat_path: String = mat_path
					if not n_mat_path.right(1) == "/":
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
	
	# Add the mesh to the scene as a MeshInstance3D.
	var arr_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	arr_mesh_instance.name = saved_scene_root_name
	arr_mesh_instance.mesh = arr_mesh
	saved_scene_root.add_child(arr_mesh_instance)
	arr_mesh_instance.owner = saved_scene_root
	
	# Generating the collision mesh.
	if generate_coll:
		if bool(options.get("collision/split_collision_mesh")):
			# If we want to create a separate collision shape for
			# each surface, we have to iterate through each
			# surface of the entire ArrayMesh, get the arrays of
			# the given surface, generate a new ArrayMesh from
			# those arrays and then generate a trimesh collision
			# from the new ArrayMesh.
			for i in arr_mesh.get_surface_count():
				var surf_arrays: Array = (
					arr_mesh.surface_get_arrays(i)
				)
				
				var new_arr_mesh: ArrayMesh = ArrayMesh.new()
				new_arr_mesh.add_surface_from_arrays(
					Mesh.PRIMITIVE_TRIANGLES, surf_arrays
				)
				
				var coll_body: StaticBody3D = StaticBody3D.new()
				var coll_body_name: String = (
					arr_mesh.surface_get_name(i).get_file()
				)
				if not coll_body_name.ends_with("_collision"):
					coll_body_name += "_collision"
				coll_body.name = coll_body_name
				arr_mesh_instance.add_child(coll_body)
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
			coll_body.name = saved_scene_root_name + "_collision"
			arr_mesh_instance.add_child(coll_body)
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
				for j in i.get("indices") as Array[int]:
					invis_st.add_vertex(pairs.get(j))
			invis_st.generate_normals()
			var invis_arr_mesh: ArrayMesh = invis_st.commit()
			
			var coll_body: StaticBody3D = StaticBody3D.new()
			coll_body.name = "invisible_collision"
			arr_mesh_instance.add_child(coll_body)
			coll_body.owner = saved_scene_root
			
			var coll_shape: CollisionShape3D = CollisionShape3D.new()
			coll_shape.name = "CollisionShape3D"
			
			var coll_polygon: ConcavePolygonShape3D = (
				invis_arr_mesh.create_trimesh_shape()
			)
			coll_shape.shape = coll_polygon
			
			coll_body.add_child(coll_shape)
			coll_shape.owner = saved_scene_root
	
	# If the RMesh has invisible collisions but we choose to
	# ignore them, we still have to move forward in the file
	# so that we don't read the wrong data for the entities.
	if invis_coll_arr.is_empty():
		var invis_coll_vert_count: int = file.get_32()
		for i in invis_coll_vert_count * 3:
			file.get_32()
		var invis_coll_tri_count: int = file.get_32()
		for i in invis_coll_tri_count * 3:
			file.get_32()
	
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
		
		var ent_count: int = file.get_32()
		for i in ent_count as int:
			var ent_name: String = read_b3d_string(file)
			match(ent_name):
				"light":
					# NOTICE: CBRE-EX doesn't distinguish
					# between normal lights and spotlights when
					# exporting. All imported lights will always
					# be OmniLight3Ds, never SpotLight3D. Also, 
					# lighting will always look different with
					# imported lights than how it looks in CBRE-EX.
					# The lights receive their color, range and
					# intensity (energy) values, but you will have
					# to tweak them more if you want to get them to look
					# the same (or almost the same) as in CBRE-EX.
					
					# Get light position. Each X, Y and Z
					# position is a 4-byte float.
					# CBRE-EX 'X' position
					var pos_x: float = file.get_float()
					# CBRE-EX 'Z' position
					var pos_y: float = file.get_float()
					# CBRE-EX 'Y' position
					var pos_z: float = file.get_float()
					var pos: Vector3 = Vector3(
						pos_x, pos_y, -pos_z
					) * scale_mesh
					
					# Get light range. 4-byte float.
					var range: float = (
						file.get_float()
						* light_range_scale
					)
					
					# Get light color string.
					var color_string = read_b3d_string(file)
					var split_color_string: PackedStringArray = (
						color_string.split(" ")
					)
					var actual_color = Color8(
						int(split_color_string[0]),
						int(split_color_string[1]),
						int(split_color_string[2])
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
				"waypoint":
					# Get waypoint position. Each X, Y and Z
					# position is a 4-byte float.
					# CBRE-EX 'X' position
					var pos_x: float = file.get_float()
					# CBRE-EX 'Z' position
					var pos_y: float = file.get_float()
					# CBRE-EX 'Y' position
					var pos_z: float = file.get_float()
					var pos: Vector3 = Vector3(
						pos_x, pos_y, -pos_z
					) * scale_mesh
					
					if include_waypoints:
						if not waypoints_folder_node:
							waypoints_folder_node = Node3D.new()
							waypoints_folder_node.name = "waypoints"
							saved_scene_root.add_child(
								waypoints_folder_node
							)
							waypoints_folder_node.owner = saved_scene_root
						
						var waypoint_node: Node3D = Node3D.new()
						waypoint_node.name = "waypoint"
						waypoint_node.position = pos
						waypoints_folder_node.add_child(
							waypoint_node, true
						)
						waypoint_node.owner = saved_scene_root
				"soundemitter":
					# Get sound emitter position. Each X, Y and Z
					# position is a 4-byte float.
					# CBRE-EX 'X' position
					var pos_x: float = file.get_float()
					# CBRE-EX 'Z' position
					var pos_y: float = file.get_float()
					# CBRE-EX 'Y' position
					var pos_z: float = file.get_float()
					var pos: Vector3 = Vector3(
						pos_x, pos_y, -pos_z
					) * scale_mesh
					
					# Get ambience index. 4-byte int.
					var amb_ind: int = file.get_32()
					
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
				"model":
					# Get model file path.
					var model_path: String = read_b3d_string(file)
					
					# Get model position. Each X, Y and Z
					# position is a 4-byte float.
					# CBRE-EX 'X' position
					var pos_x: float = file.get_float()
					# CBRE-EX 'Z' position
					var pos_y: float = file.get_float()
					# CBRE-EX 'Y' position
					var pos_z: float = file.get_float()
					var pos: Vector3 = Vector3(
						pos_x, pos_y, -pos_z
					) * scale_mesh
					
					# Get model rotation. Each X, Y and Z
					# rotation is a 4-byte float.
					# CBRE-EX 'X' rotation
					var rot_x: float = file.get_float()
					# CBRE-EX 'Z' rotation
					var rot_y: float = file.get_float()
					# CBRE-EX 'Y' rotation
					var rot_z: float = file.get_float()
					var rot: Vector3 = Vector3(
						rot_x, rot_y, -rot_z
					)
					
					# Get model scale. Each X, Y and Z scale
					# is a 4-byte float.
					# CBRE-EX 'X' scale
					var scale_x: float = file.get_float()
					# CBRE-EX 'Z' scale
					var scale_y: float = file.get_float()
					# CBRE-EX 'Y' scale
					var scale_z: float = file.get_float()
					var scale: Vector3 = Vector3(
						scale_x, scale_y, -scale_z
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
				"screen":
					# Get screen position. Each X, Y and Z
					# position is a 4-byte float.
					# CBRE-EX 'X' position
					var pos_x: float = file.get_float()
					# CBRE-EX 'Z' position
					var pos_y: float = file.get_float()
					# CBRE-EX 'Y' position
					var pos_z: float = file.get_float()
					var pos: Vector3 = Vector3(
						pos_x, pos_y, -pos_z
					) * scale_mesh
					
					# Get screen image file path.
					var img_path: String = read_b3d_string(file)
					
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
					printerr(
						"Unknown entity detected,"
						+ " probably custom entity."
					)
					break
	
	var saved_scene = PackedScene.new()
	saved_scene.pack(saved_scene_root)
	return ResourceSaver.save(
		saved_scene, 
		"%s.%s" % [save_path, _get_save_extension()]
	)


func read_b3d_string(file: FileAccess) -> String:
	var len: int = file.get_32()
	var string: String = (
		file.get_buffer(len).get_string_from_utf8()
	)
	return string
