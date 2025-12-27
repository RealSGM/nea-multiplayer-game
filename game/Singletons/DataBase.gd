extends Node

const SQLite = preload("res://addons/godot-sqlite/bin/gdsqlite.gdns")
var db 
var db_name = "res://Data/game_database.db"

func _ready():
	db = SQLite.new()
	db.path = db_name
	
func retrieve_all_loadouts():
	# Retrieve every loadout
	db.open_db()
	db.query("SELECT * FROM classes;")
	db.close_db()
	return db.query_result

func retrieve_class_details(chosen_class):
	# Retrieve all details for the chosen class
	db.open_db()
	db.query("SELECT * FROM classes WHERE class_id = '"+ str(chosen_class) + "' ;")
	db.close_db()
	return db.query_result[0]

func retrieve_gun_details(gun_name):
	# Retrieve gun details based on gun details
	db.open_db()
	db.query("SELECT * FROM guns WHERE weapon_id = '" 
	+ str(gun_name) + "' ;")
	db.close_db()

	return db.query_result[0]
	
