class_name Chain
extends RefCounted
## Chain reactions. Every break, KO, barrel blast, rope cut, bolt snap or trigger that happens within
## `chain.window_s` of the previous one adds a link. The chain's points are paid again at
## (multiplier - 1) when it ends. Tunables: data/balance.json -> "chain".

var count: int = 0
var points: int = 0
var best: int = 0
var best_bonus: int = 0
var total_bonus: int = 0
var chains_paid: int = 0
## Time of the first and last link of the current / best chain (level time, s).
var start_t: float = 0.0
var last_t: float = -100.0
var best_start_t: float = 0.0
var best_end_t: float = 0.0
var best_center: Vector2 = Vector2.ZERO
## Running centre of the current chain's links (world px), for the camera.
var center: Vector2 = Vector2.ZERO
var _milestone: int = 0


func active() -> bool:
	return count > 0


func multiplier(n: int = -1) -> float:
	var c: int = count if n < 0 else n
	if c <= 1:
		return 1.0
	return minf(Data.bf("chain", "max_mult"), 1.0 + Data.bf("chain", "step") * float(c - 1))


## Adds a link. Returns the milestone text reached by this link, or "".
func link(now: float, pos: Vector2, pts: int) -> String:
	if count == 0:
		start_t = now
		center = pos
	else:
		center = center.lerp(pos, 1.0 / float(count + 1))
	count += 1
	points += maxi(0, pts)
	last_t = now
	var text: String = ""
	var ms: Array = Data.balance["chain"]["milestones"]
	for i: int in ms.size():
		if i >= _milestone and count >= int(ms[i][0]):
			_milestone = i + 1
			text = String(ms[i][1])
	return text


## Call every physics frame. Returns the bonus when a chain ends this frame (else -1).
func tick(now: float) -> int:
	if count == 0 or now - last_t < Data.bf("chain", "window_s"):
		return -1
	return finish()


## Ends the current chain now (also called when the level ends). Returns its bonus.
func finish() -> int:
	if count == 0:
		return -1
	var bonus: int = int(round(float(points) * (multiplier() - 1.0)))
	if count >= int(Data.b("chain", "min_links")):
		total_bonus += bonus
		chains_paid += 1
	else:
		bonus = 0
	if count > best:
		best = count
		best_bonus = bonus
		best_start_t = start_t
		best_end_t = last_t
		best_center = center
	count = 0
	points = 0
	_milestone = 0
	return bonus
