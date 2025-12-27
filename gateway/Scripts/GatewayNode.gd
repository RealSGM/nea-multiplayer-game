extends Node

onready var container = $ColorRect/ScrollContainer/VBoxContainer
onready var message = preload("res://Scenes/Message.tscn")
export var console_enabled = true

func send_message_to_console(new_message):
	# Console display
	if console_enabled:
		var new_message_label = message.instance()
		new_message_label.set_text(new_message + "\n")
		container.add_child(new_message_label,true)
