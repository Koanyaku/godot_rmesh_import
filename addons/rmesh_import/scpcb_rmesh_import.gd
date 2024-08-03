@tool
extends EditorImportPlugin

enum PRESETS { DEFAULT }

func _get_importer_name() -> String:
	return "scpcb.rmesh"

func _get_visible_name() -> String:
	return "SCP – CB RMesh"

func _get_recognized_extensions() -> PackedStringArray:
	return ["rmesh"]

func _get_save_extension() -> String:
	return "rmesh"

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
			return [{
				"name": "Some option",
				"default_value": true
			}]
		_:
			return []

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	return OK
