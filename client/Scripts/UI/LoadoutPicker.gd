extends Control

onready var loadout_button = preload("res://Scenes/Player/UI/LoadoutButton.tscn")
onready var client_lobby = preload("res://Scenes/Player/UI/ClientLobby.tscn")

var ld_buttons = []
var all_loadouts = []

func _ready():
	GameServer.request_all_loadouts()

func loadout_instancing(list):
	for index in range(list.size()):
		all_loadouts.append(list[index]["class_id"])
		var ld_bt_instance = loadout_button.instance()
		ld_buttons.append(ld_bt_instance)
		ld_bt_instance.text = all_loadouts[index]
		ld_bt_instance.name = str(index)
		ld_bt_instance.rect_min_size = Vector2(120,60)
		ld_bt_instance.rect_size = Vector2(120,60)
		var message = ""
		for key in list[index].keys():
			message =  message + str(key) + ": " + str(list[index][key]) + "\n"
		ld_bt_instance.set_tooltip(message)
		ld_bt_instance.connect("pressed",self,"loadout_selected",[ld_bt_instance.get_name()])
		$BG/FG/CC/HBC.add_child(ld_bt_instance,true)		

func loadout_selected(loadout_index):
	for ld in ld_buttons:
		ld.disabled = true
	var chosen_class = all_loadouts[int(loadout_index)]
	ClientStats.chosen_class = chosen_class
	# Send chosen class to game server and authentication server
	GameServer.create_new_inventory(chosen_class)
	while str(ClientStats.class_details) == "{}":
		yield(get_tree().create_timer(0.1),"timeout")
	queue_free()
	get_parent().add_child(client_lobby.instance(),true)

func _on_ExitButton_pressed():
	get_tree().quit()
