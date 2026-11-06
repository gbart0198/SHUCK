extends Node
## M4 co-op: host-authoritative ENet skeleton (SPEC §16).
## Single player never touches this. Honest status is recorded in DECISIONS.md.

signal peer_list_changed
signal net_error(message: String)

const PORT := 24777
const MAX_PLAYERS := 4

var peer: ENetMultiplayerPeer
var is_host := false
var shift_seed := 0
var players: Dictionary = {}

func host_shift(seed_value: int) -> bool:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		net_error.emit("host_failed")
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	shift_seed = seed_value
	players = {1: "host"}
	multiplayer.peer_connected.connect(func(id: int) -> void:
		players[id] = "crew"
		peer_list_changed.emit())
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		players.erase(id)
		peer_list_changed.emit())
	return true

func join(ip: String) -> bool:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		net_error.emit("join_failed")
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	return true

func leave() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	players.clear()
	peer_list_changed.emit()

func player_count() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return maxi(1, multiplayer.get_peers().size() + 1)

## Oyster transitions are the only authoritative messages (SPEC §16).
@rpc("any_peer", "call_remote", "reliable")
func net_oyster_transition(oyster_id: int, from_state: int, to_state: int, payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	net_oyster_transition.rpc(oyster_id, from_state, to_state, payload)
