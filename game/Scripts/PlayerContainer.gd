extends Node
var player_name = ""
var player_id = 0
var inventory_id = 0
var player_guns = []
var player_inventory 

func _ready():
	reset_inv()

func reset_inv():
	# Reset all inventory values, used for when deleting a loadout
	player_inventory = {	
		"inventory_id":0,
		"player_id":0,
		"level":0,
		"balance":0,
		"chosen_class":"Null",
		"player_kills":0,
		"bullets_fired":0,
		"distance_travelled":0.0,
		"abilities_used":0,
		"experience":0,
		"deaths":0
		}
