extends Node
## Procedural one-shots. No external assets (SPEC instruction 5).

const RATE := 22050
var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build()

func play(id: String, volume_db := -6.0, pitch := 1.0) -> void:
	if not _cache.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[id]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func _build() -> void:
	_cache["tick"] = _tone([880.0], 0.04, 0.25, "sine")
	_cache["tock"] = _tone([1500.0, 2300.0], 0.10, 0.5, "sine", 22.0)
	_cache["click"] = _tone([520.0], 0.035, 0.3, "square")
	_cache["crack"] = _noise(0.14, 0.55, 1400.0)
	_cache["plink"] = _tone([1150.0, 1750.0, 2600.0], 0.30, 0.4, "sine", 16.0)
	_cache["thud"] = _tone([110.0, 70.0], 0.28, 0.7, "sine", 9.0)
	_cache["stamp"] = _tone([200.0, 140.0], 0.12, 0.45, "square", 30.0)
	_cache["gull"] = _noise(0.40, 0.4, 900.0)
	_cache["beep"] = _tone([760.0, 760.0], 0.18, 0.35, "square", 4.0)
	_cache["coin"] = _tone([1320.0, 1760.0], 0.22, 0.35, "triangle", 14.0)
	_cache["money"] = _tone([900.0, 1350.0, 1800.0], 0.26, 0.35, "triangle", 12.0)
	_cache["fail"] = _tone([180.0, 120.0], 0.45, 0.4, "saw", 6.0)
	_cache["splash"] = _noise(0.25, 0.4, 2200.0)
	_cache["drill"] = _noise(0.30, 0.25, 3000.0)
	_cache["door"] = _tone([90.0], 0.5, 0.3, "sine", 8.0)

func _envelope(i: int, n: int, decay: float) -> float:
	var t := float(i) / float(RATE)
	return exp(-t * decay) * minf(1.0, float(i) / 200.0)

func _tone(freqs: Array, dur: float, amp: float, wave: String, decay := 10.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		for k in freqs.size():
			var f: float = freqs[k] * (1.0 + 0.002 * k)
			match wave:
				"square":
					v += 0.5 * (1.0 if sin(TAU * f * t) >= 0.0 else -1.0)
				"triangle":
					v += 0.6 * (2.0 / PI) * asin(sin(TAU * f * t))
				"saw":
					v += 0.4 * (2.0 * (t * f - floor(t * f + 0.5)))
				_:
					v += sin(TAU * f * t)
		v /= float(freqs.size())
		var s := int(clampf(v * amp * _envelope(i, n, decay), -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _noise(dur: float, amp: float, filter_hz: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	var prev := 0.0
	var a := clampf(filter_hz / float(RATE) * TAU, 0.02, 1.0)
	for i in n:
		var raw := rng.randf_range(-1.0, 1.0)
		prev += (raw - prev) * a
		var v := prev * amp * _envelope(i, n, 7.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
