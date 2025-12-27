extends Control

onready var options = $BG/FG/Options
onready var  main_body = $BG/FG/CC
onready var hide_button = $BG/FG/HideButton
onready var loading_screen = $BG/FG/LoadingScreen
onready var label = $BG/FG/LoadingScreen/VBC/Label
onready var loadout_selection = load("res://Scenes/Player/UI/LoadoutSelection.tscn")

var queue_string = ""

func _ready():
	ClientStats.current_scene = "Lobby"
	options.hide()
	hide_button.hide()
	var res = OS.get_screen_size()
	options.rect_size = Vector2(res.x-40,res.y-40)

func _on_JoinButton_pressed():
	GameServer.join_matchmaking_queue()
	main_body.hide()
	loading_screen.show()
	label.get_node("Timer").start()
	
func _on_QuitButton_pressed():
	get_tree().quit()

func _on_OptionsButton_pressed():
	main_body.hide()
	options.show()
	hide_button.show()
	
func _on_HideButton_pressed():
	main_body.show()
	options.hide()
	hide_button.hide()
	
func match_found():
	GameServer.load_world()
	queue_free()

func _on_ExitQueue_pressed():
	main_body.show()
	loading_screen.hide()
	label.get_node("Timer").stop()
	GameServer.leave_matchmaking_queue()

func _on_Timer_timeout():
	if queue_string == "...":
		queue_string = ""
	else:
		queue_string += "."
	label.set_text("In Queue" + queue_string)

func _on_ChangeLoadoutButton_pressed():
	queue_free()
	get_node("/root/MainScene").add_child(loadout_selection.instance(),true)
