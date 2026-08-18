extends Node

# Universal import options.
const OPTION_SCALE_MESH := "mesh/scale_mesh"
const OPTION_INCLUDE_LIGHTMAPS := "lightmaps/include_lightmaps"
const OPTION_LIGHT_MULTIPLIER := "lightmaps/light_multiplier"
const OPTION_LIGHTMAP_PATH := "lightmaps/lightmap_path"
const OPTION_MATERIAL_PATH := "materials/material_path"
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
