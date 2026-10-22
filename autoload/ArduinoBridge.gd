extends Node

signal connection_changed(connected, message)
signal credit_pressed
signal start_pressed

const BAUD := 9600
const HEARTBEAT_MS := 2500
const TIMEOUT_MS := 7500
const SCAN_MS := 1500
const HANDSHAKE_MS := 4500
const LED_COMMANDS := ["MENU", "BLUE", "RED", "IDLE", "NORMAL", "STRIKE", "SPARE", "MISS", "OFF"]

var credits := 0
var status := "Iniciando USB..."
var connected := false
var device := ""
var _plugin: Object
var _last_scan := 0
var _last_rx := 0
var _last_ping := 0
var _opened_at := 0
var _candidates = PoolStringArray()
var _candidate_index := 0
var _led_state := "MENU"
var _last_led_sent := ""


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	# O jogo usa SO a placa Zero Delay (joystick/teclado): o Android a
	# entrega sem perguntar nada. O USB serial (Arduino dos LEDs) fica
	# desligado: ele fazia o Android pedir permissao de USB.
	_set_status("Somente placa Zero Delay: sem USB serial e sem permissoes")


func _process(_delta: float) -> void:
	if _plugin == null:
		return
	var now = Time.get_ticks_msec()
	if bool(_plugin.call("isOpen")):
		var lines: String = str(_plugin.call("pollLines"))
		for line in lines.split("\n", false):
			_receive(line.strip_edges(), now)
		if connected:
			if now - _last_rx > TIMEOUT_MS:
				_disconnect("Arduino sem resposta; reconectando")
			elif now - _last_ping > HEARTBEAT_MS:
				_send("PING")
				_last_ping = now
		elif now - _opened_at > HANDSHAKE_MS:
			_plugin.call("closePort")
			_try_next()
	elif now - _last_scan > SCAN_MS:
		_scan()


func _scan() -> void:
	_last_scan = Time.get_ticks_msec()
	_candidates = PoolStringArray(str(_plugin.call("listPorts")).split("\n", false))
	_candidate_index = 0
	if _candidates.empty():
		_set_status("Arduino não encontrado: conecte o cabo USB/OTG")
		return
	_try_next()


func _try_next() -> void:
	while _candidate_index < _candidates.size():
		var candidate = _candidates[_candidate_index]
		_candidate_index += 1
		_set_status("Verificando USB %s" % candidate)
		if bool(_plugin.call("openPort", candidate, BAUD)):
			device = candidate
			_opened_at = Time.get_ticks_msec()
			_last_ping = _opened_at
			_send("PING")
			return
		_set_status(str(_plugin.call("getLastError")))
	_last_scan = Time.get_ticks_msec()
	_set_status("Procurando Arduino; confira autorização USB")


func _receive(line: String, now: int) -> void:
	if line == "READY:DRAGON_BOWLING:1" or line == "PONG:DRAGON_BOWLING:1":
		_last_rx = now
		if not connected:
			connected = true
			_set_status("Arduino conectado: %s" % device)
			_send(_led_state)
			_last_led_sent = _led_state
			emit_signal("connection_changed", true, status)
		return
	if not connected:
		return
	match line:
		"START":
			_last_rx = now
			# Os comandos do jogo sao exclusivos da placa Zero Delay.
		"CREDIT":
			_last_rx = now
			# Credito tambem vem exclusivamente de SELECT na Zero Delay.


func _release_start_next_frame() -> void:
	yield(get_tree(), "idle_frame")
	var event := InputEventAction.new()
	event.action = "input_start"
	event.pressed = false
	Input.parse_input_event(event)


func _disconnect(reason: String) -> void:
	connected = false
	device = ""
	_last_led_sent = ""
	_plugin.call("closePort")
	_set_status(reason)
	emit_signal("connection_changed", false, status)
	_last_scan = 0


func _set_status(message: String) -> void:
	status = message


func _send(line: String) -> void:
	if _plugin != null and bool(_plugin.call("isOpen")):
		_plugin.call("writeLine", line)


func send_led(command: String) -> void:
	if not LED_COMMANDS.has(command):
		return
	_led_state = command
	if connected and _last_led_sent != command:
		_send(command)
		_last_led_sent = command


func use_credit() -> bool:
	if credits <= 0:
		return false
	credits -= 1
	return true


func reconnect() -> void:
	if _plugin == null:
		return
	_disconnect("Buscando Arduino novamente...")
	_scan()


func _exit_tree() -> void:
	if _plugin != null:
		_plugin.call("closePort")
