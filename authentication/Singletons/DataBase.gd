extends Node

const SQLite = preload("res://addons/godot-sqlite/bin/gdsqlite.gdns")
var db 
var db_name = "res://Data/player_database.db"

func _ready():
	db = SQLite.new()
	db.path = db_name
	
func register_user(username,hashed_password,salt):
	# Add new field with provided account detail arguments
	db.open_db()
	var dict = {}
	dict["username"] = username
	dict["hashed_password"] = hashed_password
	dict["salt"] = salt
	db.insert_row("player_details",dict)
	db.close_db()
	
func retrieve_user_details(username):
	# Retrieve player details based off username query
	db.open_db()
	db.query("SELECT * FROM player_details WHERE username = '" + username +  "';")
	db.close_db()
	return db.query_result

func retrieve_player_inventory(id):
	# Retrieve a player inventory based on ID
	db.open_db()
	db.query("SELECT * FROM inventory WHERE player_id = " + str(id) + ";")
	db.close_db()
	return db.query_result

func get_player_id(username,opened):
	# Get player ID based on username, opened bool value is used to check which if DB is still opened
	if opened:
		db.query("SELECT id FROM player_details WHERE username = '" + username +"';")
	else:
		db.open_db()	
		db.query("SELECT id FROM player_details WHERE username = '" + username +"';")
	db.close_db()	
	return db.query_result[0]["id"]	

func add_inventory(peer_id,inv):
	db.open_db()
	db.insert_row("inventory",inv)
	var new_inv_id = db.last_insert_rowid
	GameServers.send_inv_id(peer_id,new_inv_id)
	db.close_db()
	
func update_inventory(inv,inv_id):
	# Update the required inventory 
	db.open_db()
	db.update_rows("inventory","inventory_id = '" + str(inv_id) + "';",inv)
	db.close_db()
	
func delete_inv(inv_id):
	# Delete inventory based on inventory ID
	db.open_db()
	db.delete_rows("inventory","inventory_id = '" + str(inv_id) + "';")
	db.close_db()
	
func retrieve_player_stats(player_id):
	# Retrieve the player stats based on player ID
	db.open_db()
	db.query("SELECT * FROM inventory WHERE player_id = " + str(player_id) + ";")
	db.close_db()
	return db.query_result
	
func update_username(new_name,old_name):
	# Update a player's username
	db.open_db()
	db.query("SELECT * FROM player_details WHERE username = '" + str(old_name) + "';")
	var new_details = db.query_result[0]
	new_details["username"] = new_name
	db.update_rows("player_details","username = '" + old_name + "';",new_details)
	db.close_db()

func verify_pw(pw,db_id):
	# Verify password by retrieving salt and hashed password
	db.open_db()
	db.query("SELECT salt,hashed_password FROM player_details WHERE id = '" + str(db_id) + "';")
	db.close_db()
	
	var salt = db.query_result[0]["salt"]
	var db_hashed_password = db.query_result[0]["hashed_password"]
	var hashed_password = get_node("/root/AuthenticationServer").generate_hashed_password(pw,salt)
	
	if db_hashed_password == hashed_password:
		return true
	return false
	
func update_pw(pw,db_id):
	db.open_db()
	db.query("SELECT * FROM player_details WHERE id = '" + str(db_id) + "';")
	var details = db.query_result[0]	
	var salt = details["salt"]
	var hashed_password = get_node("/root/AuthenticationServer").generate_hashed_password(pw,salt)
	details["hashed_password"] = hashed_password
	db.update_rows("player_details","id = '" + str(db_id) + "';",details)
	db.close_db()
