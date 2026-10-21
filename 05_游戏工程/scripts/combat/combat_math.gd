class_name CombatMath
extends RefCounted
## Pure combat timing math so the parry can be unit-tested headlessly.

const PERFECT_WINDOW := 0.08
const ACTIVE_WINDOW := 0.20
const RECOVERY_WINDOW := 0.20
const COOLDOWN := 0.40
const FAIL_INTEGRITY := 15.0
const FAIL_SYNC := 10.0
const SUCCESS_SYNC := 6.0
const PERFECT_SYNC := 6.0
const PERFECT_SYNC_FREEZE := 2.0
const PERFECT_SWITCH_TIME := 0.6
const PERFECT_SEAM_TIME := 1.5
const PERFECT_DAMAGE_MULT := 1.5


static func classify_parry(elapsed: float) -> String:
	if elapsed < 0.0:
		return "none"
	if elapsed <= PERFECT_WINDOW:
		return "perfect"
	if elapsed <= ACTIVE_WINDOW:
		return "normal"
	return "none"


static func is_active(elapsed: float) -> bool:
	return elapsed >= 0.0 and elapsed <= ACTIVE_WINDOW


static func parry_cooldown_after(perfect: bool) -> float:
	return 0.0 if perfect else COOLDOWN


static func damage_multiplier(seam_exposed: bool) -> float:
	return PERFECT_DAMAGE_MULT if seam_exposed else 1.0
