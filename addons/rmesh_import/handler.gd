@tool
extends EditorPlugin

var scp_cb_scene_import_plugin: EditorImportPlugin
var scp_cb_mesh_import_plugin: EditorImportPlugin
var cbre_ex_scene_import_plugin: EditorImportPlugin
var cbre_ex_mesh_import_plugin: EditorImportPlugin

func _enter_tree():
	scp_cb_scene_import_plugin = preload("res://addons/rmesh_import/scp_cb_scene.gd").new()
	add_import_plugin(scp_cb_scene_import_plugin)
	
	scp_cb_mesh_import_plugin = preload("res://addons/rmesh_import/scp_cb_mesh.gd").new()
	add_import_plugin(scp_cb_mesh_import_plugin)
	
	cbre_ex_scene_import_plugin = preload("res://addons/rmesh_import/cbre_ex_scene.gd").new()
	add_import_plugin(cbre_ex_scene_import_plugin)
	
	cbre_ex_mesh_import_plugin = preload("res://addons/rmesh_import/cbre_ex_mesh.gd").new()
	add_import_plugin(cbre_ex_mesh_import_plugin)

func _exit_tree():
	remove_import_plugin(scp_cb_scene_import_plugin)
	scp_cb_scene_import_plugin = null
	
	remove_import_plugin(scp_cb_mesh_import_plugin)
	scp_cb_mesh_import_plugin = null
	
	remove_import_plugin(cbre_ex_scene_import_plugin)
	cbre_ex_scene_import_plugin = null
	
	remove_import_plugin(cbre_ex_mesh_import_plugin)
	cbre_ex_mesh_import_plugin = null
