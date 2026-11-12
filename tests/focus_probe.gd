extends Node
## Test helper: opens the pause menu from inside a propagated focus-out notification, which is the
## exact situation that used to freeze the game (add_child fails while the tree is notifying).

var main: Node

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and main != null:
		main.open_pause()
