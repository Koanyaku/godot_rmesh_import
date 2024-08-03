@tool
extends EditorPlugin

var cbre_ex_import_plugin: EditorImportPlugin
var scpcb_import_plugin: EditorImportPlugin

func _enter_tree():
	cbre_ex_import_plugin = preload("res://addons/rmesh_import/cbre_ex_rmesh_import.gd").new()
	scpcb_import_plugin = preload("res://addons/rmesh_import/scpcb_rmesh_import.gd").new()
	add_import_plugin(cbre_ex_import_plugin)
	add_import_plugin(scpcb_import_plugin)

func _exit_tree():
	remove_import_plugin(cbre_ex_import_plugin)
	remove_import_plugin(scpcb_import_plugin)
	cbre_ex_import_plugin = null
	scpcb_import_plugin = null
