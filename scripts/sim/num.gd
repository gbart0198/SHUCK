extends RefCounted
class_name Num
## Big-number formatting: 999 → 1.00K → 1.00M → ... the simulator way.

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

static func short(v: float) -> String:
	if is_nan(v) or is_inf(v):
		return "∞"
	var neg := v < 0.0
	v = absf(v)
	if v < 1000.0:
		var s := str(int(floor(v))) if v >= 100.0 or is_equal_approx(v, floor(v)) else "%.1f" % v
		return ("-" if neg else "") + s
	var idx := 0
	while v >= 1000.0 and idx < SUFFIXES.size() - 1:
		v /= 1000.0
		idx += 1
	var body := ""
	if v >= 100.0:
		body = "%d" % int(floor(v))
	elif v >= 10.0:
		body = "%.1f" % (floor(v * 10.0) / 10.0)
	else:
		body = "%.2f" % (floor(v * 100.0) / 100.0)
	return ("-" if neg else "") + body + SUFFIXES[idx]

static func cash(v: float) -> String:
	return "$" + short(v)

static func rate(v: float) -> String:
	return short(v) + "/s"

static func duration(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s
