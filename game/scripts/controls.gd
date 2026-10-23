extends Node
## Controles por defecto. El juego solo lee estos nombres de acción, nunca teclas
## ni botones directos, así teclado, control y pantalla táctil funcionan igual.

signal device_changed(device: Device)

enum Device { KEYBOARD, GAMEPAD, TOUCH }

const DEVICE_NAMES := ["Teclado", "Control", "Táctil"]

const BINDINGS := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"move_up": {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_down": {"keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"jump": {"keys": [KEY_SPACE, KEY_K], "buttons": [JOY_BUTTON_A]},
	"attack": {"keys": [KEY_J, KEY_X], "buttons": [JOY_BUTTON_X]},
	"dodge": {"keys": [KEY_SHIFT, KEY_L], "buttons": [JOY_BUTTON_B]},
	"soul": {"keys": [KEY_U, KEY_C], "buttons": [JOY_BUTTON_Y]},
	"tilt": {"keys": [KEY_I, KEY_V], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"pause": {"keys": [KEY_ESCAPE, KEY_ENTER], "buttons": [JOY_BUTTON_START]},
}

var device := Device.KEYBOARD


func _ready() -> void:
	for action: String in BINDINGS:
		var spec: Dictionary = BINDINGS[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		for key: Key in spec.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button: JoyButton in spec.get("buttons", []):
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
		if spec.has("axis"):
			var ev := InputEventJoypadMotion.new()
			ev.axis = spec["axis"][0]
			ev.axis_value = spec["axis"][1]
			InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	var detected := device
	if event is InputEventKey:
		detected = Device.KEYBOARD
	elif event is InputEventJoypadButton:
		detected = Device.GAMEPAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		detected = Device.GAMEPAD
	elif event is InputEventScreenTouch:
		detected = Device.TOUCH
	if detected != device:
		device = detected
		device_changed.emit(device)


func device_name() -> String:
	return DEVICE_NAMES[device]
