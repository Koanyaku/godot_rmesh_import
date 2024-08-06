@tool
extends EditorPlugin

var scpcb_scene_import_plugin: EditorImportPlugin
var scpcb_mesh_import_plugin: EditorImportPlugin
var cbre_ex_scene_import_plugin: EditorImportPlugin
var cbre_ex_mesh_import_plugin: EditorImportPlugin

func _enter_tree():
	scpcb_scene_import_plugin = preload("res://addons/rmesh_import/scpcb_scene.gd").new()
	add_import_plugin(scpcb_scene_import_plugin)
	
	scpcb_mesh_import_plugin = preload("res://addons/rmesh_import/scpcb_mesh.gd").new()
	add_import_plugin(scpcb_mesh_import_plugin)
	
	cbre_ex_scene_import_plugin = preload("res://addons/rmesh_import/cbre_ex_scene.gd").new()
	add_import_plugin(cbre_ex_scene_import_plugin)
	
	cbre_ex_mesh_import_plugin = preload("res://addons/rmesh_import/cbre_ex_mesh.gd").new()
	add_import_plugin(cbre_ex_mesh_import_plugin)

func _exit_tree():
	remove_import_plugin(scpcb_scene_import_plugin)
	scpcb_scene_import_plugin = null
	
	remove_import_plugin(scpcb_mesh_import_plugin)
	scpcb_mesh_import_plugin = null
	
	remove_import_plugin(cbre_ex_scene_import_plugin)
	cbre_ex_scene_import_plugin = null
	
	remove_import_plugin(cbre_ex_mesh_import_plugin)
	cbre_ex_mesh_import_plugin = null
