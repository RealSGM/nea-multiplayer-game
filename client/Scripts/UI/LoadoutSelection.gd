extends Control

onready var loadout_button = preload("res://Scenes/Player/UI/LoadoutButton.tscn")
onready var client_lobby = preload("res://Scenes/Player/UI/ClientLobby.tscn")
onready var stats_label = preload("res://Scenes/Player/UI/StatsLabel.tscn")
var select_buttons = []
var delete_buttons = []
var invs
var remaining_loadouts = 3
var awaiting_deletion

func _ready():
	get_node("/root/GameServer").get_player_invs()
	$ConfirmSection.hide()

func receive_inv(inv_list,class_details):
	invs = inv_list
	for inv in range(3):
		var ld_path = $BG/FG/CC/GC
		var select_button = loadout_button.instance()
		select_buttons.append(select_button)		
		select_button.set_name("Select" + str(inv))
		select_button.connect("pressed",self,"select_loadout",[select_button.get_name()])
		
		ld_path.get_node("VB"+str(inv)).add_child(select_button,true)
		
		var delete_button = loadout_button.instance()	
		delete_buttons.append(delete_button)
		delete_button.set_text("Delete Loadout")
		delete_button.set_name("Delete" + str(inv))
		delete_button.connect("pressed",self,"confirm_select",[delete_button.get_name()])
		delete_button.set_tooltip("Click me to delete this loadout")
		ld_path.get_node("VB"+str(inv)).add_child(delete_button,true)
		if str(inv_list[inv]) == "{}":
			select_buttons[inv].text = "Empty"
			delete_buttons[inv].disabled = true
		else:
			remaining_loadouts -= 1
			select_buttons[inv].text = inv_list[inv]["chosen_class"]
			instance_stats(inv,ld_path,inv_list[inv])
		var message = ""
		for key in class_details[inv].keys():
			message =  message + str(key) + ": " + str(class_details[inv][key]) + "\n"
		select_button.set_tooltip(message)
	
func instance_stats(count,path,dict):
	var curr_ld_path = path.get_node("VB" + str(count))
	for stat in dict:
		if stat != "player_id" and stat != "inventory_id": 
			var stat_instance = stats_label.instance()
			var message = stat + ": " + str(dict[stat])		
			stat_instance.name = stat
			stat_instance.text = message
			curr_ld_path.add_child(stat_instance,true)

func existing_inventory(loadout_id):
	ClientStats.chosen_class = invs[loadout_id]["chosen_class"]
	GameServer.send_client_stats(invs[loadout_id])
	while str(ClientStats.class_details) ==  "{}":
		yield(get_tree().create_timer(0.1),"timeout")
	queue_free()
	get_parent().add_child(client_lobby.instance(),true)
	
func create_inventory():
	var loadout_picker = load("res://Scenes/Player/UI/LoadoutPicker.tscn").instance()
	get_parent().add_child(loadout_picker,true)
	queue_free()
	
func select_loadout(loadout_id):
	for loadout in select_buttons:
		loadout.disabled = true
	for delete in delete_buttons:
		delete.disabled = true
	loadout_id = int(loadout_id)
	if select_buttons[loadout_id].text != "Empty":
		existing_inventory(loadout_id)
	else:
		create_inventory()		
	
func delete_loadout(index):
	index = int(index)
	var inv_id = invs[index]["inventory_id"]
	GameServer.send_deletion_requestion(inv_id)
	invs[index] = {}
	get_node("BG/FG/CC/GC/VB" + str(index) + "/Select" + 
	str(index)).set_tooltip("")
	
	var ld_path = $BG/FG/CC/GC.get_node("VB" + str(index))
	ld_path.get_node("Select" + str(index)).text = "Empty"
	ld_path.get_node("Delete" + str(index)).disabled = true
	for i in ld_path.get_children():
		if i.get_class() == "Label":
			i.queue_free()
	
func _on_ExitButton_pressed():
	get_tree().quit()

func confirm_select(index):
	$ConfirmSection.show()
	$BG/FG/CC.hide()
	awaiting_deletion = index

func _on_NoBtn_pressed():
	$ConfirmSection.hide()
	$BG/FG/CC.show()

func _on_YesBtn_button_down():
	delete_loadout(awaiting_deletion)
	$ConfirmSection.hide()
	$BG/FG/CC.show()
