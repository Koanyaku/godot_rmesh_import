# https://github.com/AnalogFeelings/cbre-ex/blob/main/Source/CBRE.Editor/Compiling/RMeshExport.cs
@tool
extends EditorImportPlugin

enum PRESETS { DEFAULT }

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
					"name": "mesh/include_invisible_collisions",
					"default_value": true,
				},
				{
					"name": "collision/generate_collision_mesh",
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
	var file: FileAccess = FileAccess.open(source_file, FileAccess.READ)
	if !file:
		return FileAccess.get_open_error()
	
	# Get the header.
	var header: String = read_b3d_string(file) as String
	if header != "RoomMesh":
		return ERR_FILE_UNRECOGNIZED
	
	var scale_mesh: Vector3 = options.get("mesh/scale_mesh") as Vector3
	
	var saved_scene_root: Node3D = Node3D.new()
	var saved_scene_root_name: String = source_file.get_file().trim_suffix(".rmesh").rstrip(".") as String
	saved_scene_root.name = saved_scene_root_name
	
	# Get the texture count.
	var tex_count: int = file.get_32() as int
	
	# We accumulate all the data for all the textures in this texture dictionary.
	# Each texture will store an array of dictionaries, where each dictionary will store
	# a specific set of indices, where each indice stores an array of values for that indice.
	var tex_dict: Dictionary = {} as Dictionary
	
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
		if !tex_dict.has(tex_name):
			tex_dict[tex_name] = []
		
		# Get the vertex count.
		var vertex_count: int = file.get_32() as int
		
		# Initialize arrays for texture and lightmap UVs.
		# NOTE: Lightmap UVs are not used.
		var tex_uvs: Array
		var lm_uvs: Array
		
		# Get the vertices.
		var vertices: PackedVector3Array = PackedVector3Array() as PackedVector3Array
		for j in vertex_count:
			# The data for each vertex takes up 31 bytes.
			var vertex_data: PackedByteArray = file.get_buffer(31) as PackedByteArray
			
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
			vertices.append(Vector3(pos_x, pos_y, -pos_z) * scale_mesh)
			
			# Get the texture and lightmap UVs.
			var texU = vertex_data.decode_float(12)
			var texV = vertex_data.decode_float(16)
			var lmU = vertex_data.decode_float(20)
			var lmV = vertex_data.decode_float(24)
			tex_uvs.append(Vector2(texU, texV))
			lm_uvs.append(Vector2(lmU, lmV))
			
			# The data for each vertex ends with three 'RGB' bytes. Usually, they
			# are just three FF bytes. We don't really care about these.
		
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
				vert_ind_pairs[tri_indices[j]] = [
					vertices[pos_in_ind_arr],
					tex_uvs[pos_in_ind_arr],
					lm_uvs[pos_in_ind_arr]
				]
			else:
				pos_in_ind_arr -= 1
		
		# Every vertex should have only one indice associated with it.
		if vert_ind_pairs.size() != vertices.size():
			return FAILED
		
		Array(tex_dict.get(tex_name)).append({
			"indices": tri_indices,
			"pairs": vert_ind_pairs
		})
	
	var has_invis_coll: bool = file.get_32() as bool
	var include_invis_coll: bool = options.get("mesh/include_invisible_collisions") as bool
	
	# Handle invisible collisions. We mostly have to repeat the same processes
	# as with the normal face data.
	if has_invis_coll and include_invis_coll:
		tex_dict["invisible_collision"] = []
		
		var invis_coll_vert_count: int = file.get_32() as int
		
		# Get the invisible collision vertices.
		var invis_coll_vertices: PackedVector3Array = PackedVector3Array() as PackedVector3Array
		for i in invis_coll_vert_count:
			# The actual data for each invisible collision vertex takes up 12 bytes.
			# Only the X, Y and Z positions get saved with invisible collision vertices.
			# Other than that, we do mostly the same things as with normal face vertices.
			var invis_coll_vertex_data: PackedByteArray = file.get_buffer(12) as PackedByteArray
			
			var pos_x: float = invis_coll_vertex_data.decode_float(0) # CBRE-EX 'X' position
			var pos_y: float = invis_coll_vertex_data.decode_float(4) # CBRE-EX 'Z' position
			var pos_z: float = invis_coll_vertex_data.decode_float(8) # CBRE-EX 'Y' position
			invis_coll_vertices.append(Vector3(pos_x, pos_y, -pos_z) * scale_mesh)
			
			# The data for each invisible collision vertex doesn't end with any extra bytes.
		
		# Get the invisible collision triangle count.
		var invis_coll_tri_count: int = file.get_32() as int
		
		# Get the invisible collision triangle indices.
		var invis_coll_tri_indices: PackedInt32Array = PackedInt32Array() as PackedInt32Array
		for i in invis_coll_tri_count * 3:
			# Each indice is stored as 4 bytes.
			invis_coll_tri_indices.append(file.get_32() as int)
		
		# The triangle indice count must be a multiple of the triangle count.
		if invis_coll_tri_indices.size() % invis_coll_tri_count:
			return FAILED
		
		# For each invisible collision indice, give it it's corresponding vertex.
		var invis_coll_vert_ind_pairs: Dictionary = {} as Dictionary
		var pos_in_invis_coll_ind_arr: int = -1 as int
		for i in invis_coll_tri_indices.size() as int:
			pos_in_invis_coll_ind_arr += 1
			# If an indice already has vertex data associated with it, 
			# we know we can just skip it.
			if !invis_coll_vert_ind_pairs.has(invis_coll_tri_indices[i]):
				invis_coll_vert_ind_pairs[invis_coll_tri_indices[i]] = [
					invis_coll_vertices[pos_in_invis_coll_ind_arr]
				]
			else:
				pos_in_invis_coll_ind_arr -= 1
		
		# Every invisible collision vertex should have only one indice associated with it.
		if invis_coll_vert_ind_pairs.size() != invis_coll_vertices.size():
			return FAILED
		
		Array(tex_dict.get("invisible_collision")).append({
			"indices": invis_coll_tri_indices,
			"pairs": invis_coll_vert_ind_pairs
		})
	
	# Initialize the ArrayMesh and SurfaceTool.
	var arr_mesh: ArrayMesh = ArrayMesh.new() as ArrayMesh
	var st: SurfaceTool = SurfaceTool.new() as SurfaceTool
	
	var mat_path: String = options.get("materials/material_path") as String
	var current_material_checked: bool = false as bool
	var current_loaded_material: Material = null
	
	# For each texture in the texture dictionary.
	for i in tex_dict.keys() as Array[Dictionary]:
		var tex_name: String = tex_dict.find_key(tex_dict.get(i)) as String
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# For each dictionary stored with the texture.
		for j in Array(tex_dict.get(i)) as Array[Dictionary]:
			# For each indice in the indices array.
			var pairs: Dictionary = j.get("pairs") as Dictionary
			for k in j.get("indices") as Array[int]:
				# Set the texture UV.
				# Invisible collisions don't have UVs or materials.
				if tex_name != "invisible_collision":
					st.set_uv(Vector2(Array(pairs.get(k))[1]))
					# Set the material.
					if mat_path != "" and !current_material_checked and !current_loaded_material:
						var n_mat_path: String = mat_path
						# Fix up material path so it works.
						if n_mat_path.right(1) != "/":
							n_mat_path += "/"
						n_mat_path += tex_name.trim_suffix(tex_name.get_extension()) + "tres"
						# If we don't have a material loaded, we can check if it exists
						# and load it. Then we say the material was checked. We only
						# need to check it once to know if it exists or not.
						if ResourceLoader.exists(n_mat_path, "Material"):
							current_loaded_material = load(n_mat_path)
						current_material_checked = true
					# We then check if we have a material loaded after that process.
					if current_loaded_material:
						st.set_material(current_loaded_material)
				st.add_vertex(Vector3(Array(pairs.get(k))[0]))
		st.generate_normals()
		st.commit(arr_mesh)
		st.clear()
		arr_mesh.surface_set_name(arr_mesh.get_surface_count() - 1, tex_name.trim_suffix(tex_name.get_extension()).rstrip("."))
		current_loaded_material = null
		current_material_checked = false
	
	# Add the mesh to the scene as a MeshInstance3D.
	var arr_mesh_instance: MeshInstance3D = MeshInstance3D.new() as MeshInstance3D
	arr_mesh_instance.name = saved_scene_root_name
	arr_mesh_instance.mesh = arr_mesh
	saved_scene_root.add_child(arr_mesh_instance)
	arr_mesh_instance.owner = saved_scene_root
	
	# Generating the collision mesh.
	if bool(options.get("collision/generate_collision_mesh")):
		if bool(options.get("collision/split_collision_mesh")):
			# If we want to create a separate collision shape for each surface,
			# we have to iterate through each surface of the entire ArrayMesh,
			# get the arrays of the given surface, generate a new ArrayMesh from
			# those arrays and then generate a trimesh collision from the new ArrayMesh.
			for i in arr_mesh.get_surface_count():
				var surf_arrays: Array = arr_mesh.surface_get_arrays(i) as Array
				
				var new_arr_mesh: ArrayMesh = ArrayMesh.new() as ArrayMesh
				new_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arrays)
				
				var coll_body: StaticBody3D = StaticBody3D.new()
				var coll_body_name: String = arr_mesh.surface_get_name(i).get_file() as String
				if !coll_body_name.ends_with("_collision"):
					coll_body_name += "_collision"
				coll_body.name = coll_body_name
				arr_mesh_instance.add_child(coll_body)
				coll_body.owner = saved_scene_root
				
				var coll_shape: CollisionShape3D = CollisionShape3D.new()
				coll_shape.name = "CollisionShape3D"
				
				var coll_polygon: ConcavePolygonShape3D = new_arr_mesh.create_trimesh_shape() as ConcavePolygonShape3D
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
			
			var coll_polygon: ConcavePolygonShape3D = arr_mesh.create_trimesh_shape() as ConcavePolygonShape3D
			coll_shape.shape = coll_polygon
			
			coll_body.add_child(coll_shape)
			coll_shape.owner = saved_scene_root
	
	# If the RMesh has invisible collisions but we choose to ignore them,
	# we still have to move forward in the file so that we don't read the
	# wrong data for the entities.
	if has_invis_coll and !include_invis_coll:
		var invis_coll_vert_count: int = file.get_32() as int
		for i in invis_coll_vert_count * 3:
			file.get_32()
		var invis_coll_tri_count: int = file.get_32() as int
		for i in invis_coll_tri_count * 3:
			file.get_32()
	
	var include_lights: bool = options.get("entities/lights/include_lights") as bool
	var include_waypoints: bool = options.get("entities/waypoints/include_waypoints") as bool
	var include_sound_emitters: bool = options.get("entities/sound_emitters/include_sound_emitters") as bool
	var include_models: bool = options.get("entities/models/include_models") as bool
	var include_screens: bool = options.get("entities/screens/include_screens") as bool
	
	if bool(options.get("entities/include_entities")) and (
		include_lights or include_waypoints or include_sound_emitters
		or include_models or include_screens
	):
		var lights_folder_node: Node = null
		var waypoints_folder_node: Node = null
		var sound_emitters_folder_node: Node = null
		var models_folder_node: Node = null
		var screens_folder_node: Node = null
		
		var light_range_scale: float = options.get("entities/lights/light_range_scale") as float
		var sound_range_scale: float = options.get("entities/sound_emitters/sound_range_scale") as float
		
		var ent_count: int = file.get_32() as int
		for i in ent_count as int:
			var ent_name: String = read_b3d_string(file) as String
			match(ent_name):
				"light":
					# NOTICE: CBRE-EX doesn't distinguish between normal lights and
					# spotlights when exporting. All imported lights will always
					# be OmniLight3Ds, never SpotLight3D. Also, lighting will always
					# look different with imported lights than how it looks in CBRE-EX.
					# The lights receive their color, range and intensity (energy) values,
					# but you will have to tweak them more if you want to get them to look
					# the same (or almost the same) as in CBRE-EX.
					
					# Get light position. Each X, Y and Z position is a 4-byte float.
					var pos_x: float = file.get_float() as float # CBRE-EX 'X' position
					var pos_y: float = file.get_float() as float # CBRE-EX 'Z' position
					var pos_z: float = file.get_float() as float # CBRE-EX 'Y' position
					var pos: Vector3 = Vector3(pos_x, pos_y, -pos_z) * scale_mesh as Vector3
					
					# Get light range. 4-byte float.
					var range: float = file.get_float() * float() as float
					
					# Get light color string.
					var color_string = read_b3d_string(file) as String
					var split_color_string: PackedStringArray = color_string.split(" ") as PackedStringArray
					var actual_color = Color8(int(split_color_string[0]), int(split_color_string[1]), int(split_color_string[2]))
					
					# Get light intensity. 4-byte float.
					var intensity: float = file.get_float() as float
					
					if include_lights:
						if !lights_folder_node:
							lights_folder_node = Node.new() as Node
							lights_folder_node.name = "lights"
							saved_scene_root.add_child(lights_folder_node)
							lights_folder_node.owner = saved_scene_root
						
						var light_node: OmniLight3D = OmniLight3D.new()
						light_node.name = "light"
						light_node.position = pos
						light_node.omni_range = range
						light_node.light_color = actual_color
						light_node.light_energy = intensity
						lights_folder_node.add_child(light_node, true)
						light_node.owner = saved_scene_root
				"waypoint":
					# Get waypoint position. Each X, Y and Z position is a 4-byte float.
					var pos_x: float = file.get_float() as float # CBRE-EX 'X' position
					var pos_y: float = file.get_float() as float # CBRE-EX 'Z' position
					var pos_z: float = file.get_float() as float # CBRE-EX 'Y' position
					var pos: Vector3 = Vector3(pos_x, pos_y, -pos_z) * scale_mesh as Vector3
					
					if include_waypoints:
						if !waypoints_folder_node:
							waypoints_folder_node = Node.new() as Node
							waypoints_folder_node.name = "waypoints"
							saved_scene_root.add_child(waypoints_folder_node)
							waypoints_folder_node.owner = saved_scene_root
						
						var waypoint_node: Node3D = Node3D.new() as Node3D
						waypoint_node.name = "waypoint"
						waypoint_node.position = pos
						waypoints_folder_node.add_child(waypoint_node, true)
						waypoint_node.owner = saved_scene_root
				"soundemitter":
					# Get sound emitter position. Each X, Y and Z position is a 4-byte float.
					var pos_x: float = file.get_float() as float # CBRE-EX 'X' position
					var pos_y: float = file.get_float() as float # CBRE-EX 'Z' position
					var pos_z: float = file.get_float() as float # CBRE-EX 'Y' position
					var pos: Vector3 = Vector3(pos_x, pos_y, -pos_z) * scale_mesh as Vector3
					
					# Get ambience index. 4-byte int.
					var amb_ind: int = file.get_32() as int
					
					# Get soundemitter range. 4-byte float.
					var range: float = file.get_float() as float
					
					if include_sound_emitters:
						if !sound_emitters_folder_node:
							sound_emitters_folder_node = Node.new() as Node
							sound_emitters_folder_node.name = "sound_emitters"
							saved_scene_root.add_child(sound_emitters_folder_node)
							sound_emitters_folder_node.owner = saved_scene_root
						
						var emitter_node: AudioStreamPlayer3D = AudioStreamPlayer3D.new() as AudioStreamPlayer3D
						emitter_node.name = "soundemitter"
						emitter_node.position = pos
						emitter_node.max_distance = range * sound_range_scale
						sound_emitters_folder_node.add_child(emitter_node, true)
						emitter_node.owner = saved_scene_root
				"model":
					# Get model file path.
					var model_path: String = read_b3d_string(file) as String
					
					# Get model position. Each X, Y and Z position is a 4-byte float.
					var pos_x: float = file.get_float() as float # CBRE-EX 'X' position
					var pos_y: float = file.get_float() as float # CBRE-EX 'Z' position
					var pos_z: float = file.get_float() as float # CBRE-EX 'Y' position
					var pos: Vector3 = Vector3(pos_x, pos_y, -pos_z) * scale_mesh as Vector3
					
					# Get model rotation. Each X, Y and Z rotation is a 4-byte float.
					var rot_x: float = file.get_float() as float # CBRE-EX 'X' rotation
					var rot_y: float = file.get_float() as float # CBRE-EX 'Z' rotation
					var rot_z: float = file.get_float() as float # CBRE-EX 'Y' rotation
					var rot: Vector3 = Vector3(rot_x, rot_y, -rot_z) as Vector3
					
					# Get model scale. Each X, Y and Z scale is a 4-byte float.
					var scale_x: float = file.get_float() as float # CBRE-EX 'X' scale
					var scale_y: float = file.get_float() as float # CBRE-EX 'Z' scale
					var scale_z: float = file.get_float() as float # CBRE-EX 'Y' scale
					var scale: Vector3 = Vector3(scale_x, scale_y, -scale_z) as Vector3
					
					if include_models:
						if !models_folder_node:
							models_folder_node = Node.new() as Node
							models_folder_node.name = "models"
							saved_scene_root.add_child(models_folder_node)
							models_folder_node.owner = saved_scene_root
						
						var model_node: Node3D = Node3D.new() as Node3D
						model_node.name = "model"
						model_node.position = pos
						model_node.rotation_degrees = rot
						model_node.scale = scale
						models_folder_node.add_child(model_node, true)
						model_node.owner = saved_scene_root
				"screen":
					# Get screen position. Each X, Y and Z position is a 4-byte float.
					var pos_x: float = file.get_float() as float # CBRE-EX 'X' position
					var pos_y: float = file.get_float() as float # CBRE-EX 'Z' position
					var pos_z: float = file.get_float() as float # CBRE-EX 'Y' position
					var pos: Vector3 = Vector3(pos_x, pos_y, -pos_z) * scale_mesh as Vector3
					
					# Get screen image file path.
					var img_path: String = read_b3d_string(file) as String
					
					if include_screens:
						if !screens_folder_node:
							screens_folder_node = Node.new() as Node
							screens_folder_node.name = "screens"
							saved_scene_root.add_child(screens_folder_node)
							screens_folder_node.owner = saved_scene_root
						
						var screen_node: Node3D = Node3D.new() as Node3D
						screen_node.name = "screen"
						screen_node.position = pos
						screens_folder_node.add_child(screen_node, true)
						screen_node.owner = saved_scene_root
				_:
					pass
					#print("Unknown entity detected, probably custom entity.")
	
	var saved_scene = PackedScene.new()
	saved_scene.pack(saved_scene_root)
	return ResourceSaver.save(saved_scene, "%s.%s" % [save_path, _get_save_extension()])

func read_b3d_string(file: FileAccess) -> String:
	var len: int = file.get_32() as int
	var string: String = file.get_buffer(len).get_string_from_utf8()
	return string
