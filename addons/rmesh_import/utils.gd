extends Object
## Utilities for RMesh importing.

# Universal import options.
const OPTION_SCALE_MESH := "mesh/scale_mesh"
const OPTION_INCLUDE_LIGHTMAPS := "lightmaps/include_lightmaps"
const OPTION_LIGHT_MULTIPLIER := "lightmaps/light_multiplier"
const OPTION_LIGHTMAP_PATH := "lightmaps/lightmap_path"
const OPTION_INCLUDE_TEXTURES := "textures/include_textures"
const OPTION_TEXTURE_PATH := "textures/texture_path"
const OPTION_GENERATE_MATERIAL_RESOURCES := (
		"textures/generate_material_resources"
)
const OPTION_INCLUDE_INVISIBLE_COLLISIONS := (
		"collision/include_invisible_collisions"
)

# Import options when importing as PackedScene.
const OPTION_GENERATE_COLLISION_MESH := "collision/generate_collision_mesh"
const OPTION_SPLIT_COLLISION_MESH := "collision/split_collision_mesh"
const OPTION_INCLUDE_ENTITIES := "entities/include_entities"
const OPTION_INCLUDE_LIGHTS := "entities/lights/include_lights"
const OPTION_LIGHT_RANGE_SCALE := "entities/lights/light_range_scale"
const OPTION_INCLUDE_WAYPOINTS := "entities/waypoints/include_waypoints"
const OPTION_INCLUDE_SCREENS := "entities/screens/include_screens"
const OPTION_INCLUDE_MODELS := "entities/models/include_models"
const OPTION_INCLUDE_SOUND_EMITTERS := (
		"entities/sound_emitters/include_sound_emitters"
)
const OPTION_SOUND_RANGE_SCALE := "entities/sound_emitters/sound_range_scale"

# SCP - CB specific PackedScene import options.
const OPTION_INCLUDE_TRIGGER_BOXES := "trigger_boxes/include_trigger_boxes"
const OPTION_INCLUDE_SPOTLIGHTS := "entities/spotlights/include_spotlights"
const OPTION_SPOTLIGHT_RANGE_SCALE := (
		"entities/spotlights/spotlight_range_scale"
)
const OPTION_INCLUDE_PLAYER_STARTS := (
		"entities/player_starts/include_player_starts"
)


## Creates indice-vertice pairs from [param vertices] and [param indices].
static func index_vertices(
		vertices: Array[Vertex], indices: PackedInt32Array, 
) -> Array[Vertex]:
	# The amount of pairs is the same as the highest index indice (+ 1 because 
	# index 0 also counts), since pairs will be stored only for each unique 
	# indice.
	var indexed_size: int = Array(indices).max() + 1
	var indexed: Array[Vertex] = []
	indexed.resize(indexed_size)
	
	# This value is the position from which we will read vertice and other data 
	# from their respective arrays.
	var correct_array_pos: int = 0
	
	for i in indices.size():
		# If an indice already has vertice data associated with it in the pairs,
		# we know we can just skip it.
		if not is_instance_valid(indexed.get(indices.get(i))):
			indexed[indices.get(i)] = vertices.get(correct_array_pos)
			
			correct_array_pos += 1
	
	# Every invisible collision vertice should have only one indice associated 
	# with it.
	if not indexed.size() == vertices.size():
		push_error(
			"Vertice-indice pairs array size doesn't match vertices array size."
			+ " Every indice should have one set of vertices assigned to it"
			+ " (indice-vertice pairs array size: " + str(indexed.size())
			+ ", vertices array size: " + str(vertices.size()) + ")"
		)
		return []
	
	return indexed


static func check_tri_ind_count(
		indices: PackedInt32Array, tri_count: int
) -> bool:
	var ind_size: int = indices.size()
	
	# The triangle indice count must be a multiple of the triangle count.
	# This checks if the result is bigger than 0.
	if (ind_size % tri_count):
		push_error(
				"Triangle indice count is not a multiple of the triangle count"
				+ " (indice count is " + str(ind_size) + ", triangle count is "
				+ str(tri_count) + ", " + str(ind_size)+ " mod " 
				+ str(tri_count) + " = " + str(ind_size % tri_count) + ")."
		)
		return false
	
	return true


static func get_entity_position(file: FileAccess, scale: Vector3) -> Vector3:
	# Each X, Y and Z position is a 4-byte float.
	var pos_x: float = file.get_float()
	var pos_y: float = file.get_float()
	var pos_z: float = file.get_float()
	return Vector3(pos_x, pos_y, -pos_z) * scale


static func get_entity_rotation(file: FileAccess) -> Vector3:
	# Each X, Y and Z rotation is a 4-byte float.
	var rot_x: float = file.get_float()
	var rot_y: float = file.get_float()
	var rot_z: float = file.get_float()
	return Vector3(rot_x, rot_y, -rot_z)


static func get_entity_scale(file: FileAccess) -> Vector3:
	# Each X, Y and Z scale is a 4-byte float.
	var scale_x: float = file.get_float()
	var scale_y: float = file.get_float()
	var scale_z: float = file.get_float()
	return Vector3(scale_x, scale_y, -scale_z)


static func get_rotation_from_angles(angles: String) -> Vector3:
	var angles_split: PackedStringArray = angles.split(" ")
	return Vector3(
			-int(angles_split.get(0)),
			int(angles_split.get(1)),
			int(angles_split.get(2))
	)


static func get_color_from_string(color: String) -> Color:
	var split_color_string: PackedStringArray = color.split(" ")
	return Color8(
			int(split_color_string.get(0)),
			int(split_color_string.get(1)),
			int(split_color_string.get(2))
	)


class Vertex:
	var position := Vector3()
	var texture_uv := Vector2()
	var lightmap_uv := Vector2()


class SurfaceData:
	var texture_path := ""
	var lightmap_path := ""
	var indices := PackedInt32Array()
	var indexed_vertices: Array[Vertex] = []
