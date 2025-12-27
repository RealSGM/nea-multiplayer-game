extends Node

var magic_shield = preload("res://Assets/Other/MagicShield.tscn")
var shield_spawn

func prepare_class():
	# Create new shield spawn location node
	shield_spawn = Spatial.new()
	shield_spawn.translation.z = -1
	shield_spawn.set_name("ShieldSpawn")
	get_parent().camera.add_child(shield_spawn,true)
	
func activate_ability():
	# Activates the shield
	if shield_spawn.get_children().size() == 0:
		var shield_instance = magic_shield.instance()
		var data_dict = {}
		
		data_dict["visuals_name"] = "activate_magic_shield"
		data_dict["weapon_name"] = shield_instance.get_name()
		GameServer.send_visuals(data_dict)
		
		shield_instance.get_node("ShieldBody/CollisionShape").set_disabled(true)
		shield_instance.get_node("ShieldTimer").connect("timeout",self,"remove_shield",[shield_instance])
		
		shield_spawn.add_child(shield_instance,true)
		ClientStats.ability_instances.append(shield_instance)

func check_event():
	pass
	
func remove_shield(shield):
	shield.hide()

func reset_ability():
	for child in shield_spawn.get_children():
		child.hide()
