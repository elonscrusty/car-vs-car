--!strict
-- Pure combat rules: hit zone, combo chain, HP thresholds and the final damage formula.

local Damage = {}

export type Zone = "front" | "side" | "back"

export type ZoneCfg = {
	frontCos: number,
	backCos: number,
	frontMult: number,
	sideMult: number,
	backMult: number,
}

export type ComboState = { count: number, lastAt: number }

-- cosAngle = dot(victim look vector, unit direction from victim to attacker).
function Damage.zone(cosAngle: number, cfg: ZoneCfg): Zone
	if cosAngle >= cfg.frontCos then
		return "front"
	elseif cosAngle <= cfg.backCos then
		return "back"
	end
	return "side"
end

function Damage.zoneMult(zone: Zone, cfg: ZoneCfg): number
	if zone == "front" then
		return cfg.frontMult
	elseif zone == "back" then
		return cfg.backMult
	end
	return cfg.sideMult
end

-- Flat (XZ) cosine between a look vector and the direction to the attacker.
function Damage.cosFlat(lookX: number, lookZ: number, toX: number, toZ: number): number
	local ll = math.sqrt(lookX * lookX + lookZ * lookZ)
	local tl = math.sqrt(toX * toX + toZ * toZ)
	if ll < 1e-6 or tl < 1e-6 then
		return 1
	end
	return (lookX * toX + lookZ * toZ) / (ll * tl)
end

function Damage.newCombo(): ComboState
	return { count = 0, lastAt = -math.huge }
end

-- Registers a hit at `now` and returns the chain length (1 = no combo). Mutates `state`.
function Damage.comboHit(state: ComboState, now: number, window: number): number
	if now - state.lastAt <= window then
		state.count += 1
	else
		state.count = 1
	end
	state.lastAt = now
	return state.count
end

function Damage.comboMult(count: number, mults: { number }): number
	if count < 1 then
		return 1
	end
	return mults[math.min(count, #mults)] or 1
end

-- Which of `thresholds` (HP fractions) were crossed going from oldHp to newHp.
-- Returns the indexes (into thresholds), in order.
function Damage.crossed(
	oldHp: number,
	newHp: number,
	maxHp: number,
	thresholds: { number }
): { number }
	local out = {}
	if maxHp <= 0 then
		return out
	end
	local o, n = oldHp / maxHp, newHp / maxHp
	for i, t in thresholds do
		if o > t and n <= t then
			table.insert(out, i)
		end
	end
	return out
end

-- Final damage = base x zone x combo x buff x special.
function Damage.final(
	base: number,
	zoneMult: number,
	comboMult: number,
	buffMult: number,
	specialMult: number
): number
	return base * zoneMult * comboMult * buffMult * specialMult
end

-- Short feedback text for the client, or nil for a plain front hit.
function Damage.tag(zone: Zone, comboCount: number): string?
	local z = if zone == "back" then "BACK HIT!" elseif zone == "side" then "SIDE HIT!" else nil
	if comboCount >= 2 then
		local c = `COMBO x{comboCount}`
		return if z then `{z} {c}` else c
	end
	return z
end

return Damage
