@tool
extends EditorPlugin

const _SCP_CB_SCENE_IMPORT_PLUGIN = preload(
		"res://addons/rmesh_import/scp_cb/scene.gd"
)
const _SCP_CB_MESH_IMPORT_PLUGIN = preload(
		"res://addons/rmesh_import/scp_cb/mesh.gd"
)
const _CBRE_EX_SCENE_IMPORT_PLUGIN = preload(
		"res://addons/rmesh_import/cbre_ex/scene.gd"
)
const _CBRE_EX_MESH_IMPORT_PLUGIN = preload(
		"res://addons/rmesh_import/cbre_ex/mesh.gd"
)

var _scp_cb_scene_import_plugin: EditorImportPlugin = null
var _scp_cb_mesh_import_plugin: EditorImportPlugin = null
var _cbre_ex_scene_import_plugin: EditorImportPlugin = null
var _cbre_ex_mesh_import_plugin: EditorImportPlugin = null


func _enter_tree():
	#_scp_cb_scene_import_plugin = _SCP_CB_SCENE_IMPORT_PLUGIN.new()
	#add_import_plugin(_scp_cb_scene_import_plugin)
	#
	#_scp_cb_mesh_import_plugin = _SCP_CB_MESH_IMPORT_PLUGIN.new()
	#add_import_plugin(_scp_cb_mesh_import_plugin)
	
	_cbre_ex_scene_import_plugin = _CBRE_EX_SCENE_IMPORT_PLUGIN.new()
	add_import_plugin(_cbre_ex_scene_import_plugin)
	
	#_cbre_ex_mesh_import_plugin = _CBRE_EX_MESH_IMPORT_PLUGIN.new()
	#add_import_plugin(_cbre_ex_mesh_import_plugin)
	


func _exit_tree():
	#remove_import_plugin(_scp_cb_scene_import_plugin)
	#_scp_cb_scene_import_plugin = null
	#
	#remove_import_plugin(_scp_cb_mesh_import_plugin)
	#_scp_cb_mesh_import_plugin = null
	
	remove_import_plugin(_cbre_ex_scene_import_plugin)
	_cbre_ex_scene_import_plugin = null
	
	#remove_import_plugin(_cbre_ex_mesh_import_plugin)
	#_cbre_ex_mesh_import_plugin = null
