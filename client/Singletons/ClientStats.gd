extends Node

# Stores value needed to be accessed from different scripts
var ability_instances = []
var game_paused = false
var in_game = false
var is_dead = false
var round_ended = false
var fov = 90
var scope_sensitivity = 1
var mouse_sensitivity = 1
var player_network_id = "ClientPlayer"
var class_details = {}
var options_node 
var player_node
var current_scene = ""
var player_name = ""
var player_guns = {}
var chosen_class = ""
var required_settings = ["vsync","max_fps","fov","mouse_sensitivity","zoom_sensitivity_percentage"]

func reset():
	ability_instances = []
	game_paused = false
	in_game = false
	is_dead = false
	round_ended = false
	fov = 90
	scope_sensitivity = 1
	mouse_sensitivity = 1
	player_network_id = "ClientPlayer"
	class_details = {}
	options_node = null
	player_node = null
	player_name = ""
	player_guns = {}
	chosen_class = ""
