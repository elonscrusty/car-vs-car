--!strict
local H = require("./harness")
local Sim = require("./botsim")
local GameConfig = require("../src/shared/GameConfig")

print("BotSim (200 seeded duels each)")

local N = 200

local function summary(label: string, results: { Sim.Result })
	local firsts: { number } = {}
	local never, ring, accidents, secs = 0, 0, 0, 0
	local worst = 0
	for _, r in results do
		if r.firstContact == math.huge then
			never += 1
		else
			table.insert(firsts, r.firstContact)
			worst = math.max(worst, r.firstContact)
		end
		if r.ringOut then
			ring += 1
		end
		if r.accident then
			accidents += 1
		end
		secs += r.seconds
	end
	print(
		string.format(
			"       %-22s first contact median %.2fs worst %.1fs | no contact %d | ring-outs %d | accidental %d (%.1f%%) | avg length %.0fs",
			label,
			Sim.median(firsts),
			worst,
			never,
			ring,
			accidents,
			accidents / #results * 100,
			secs / #results
		)
	)
	return Sim.median(firsts), never, accidents / #results, worst
end

local function winShare(results: { Sim.Result }, side: number): number
	local wins, decided = 0, 0
	for _, r in results do
		if r.winner ~= 0 then
			decided += 1
			if r.winner == side then
				wins += 1
			end
		end
	end
	return wins / math.max(decided, 1)
end

for _, lvl in { "easy", "medium", "hard" } do
	H.test(`{lvl} vs {lvl}: contact fast, never idle, rarely out by accident`, function()
		local rs = Sim.batch(N, 11, { lvl, lvl })
		local median, never, accident = summary(lvl .. " v " .. lvl, rs)
		H.truthy(median < GameConfig.Pacing.targetSeconds, `median first contact {median}`)
		H.eq(never, 0, "matches with zero contact")
		H.truthy(accident < 0.05, `accident rate {accident}`)
	end)
end

H.test("sloppy launches (stress): still touch fast and stay in the bowl", function()
	local rs = Sim.batch(N, 23, { "medium", "medium" }, nil, true)
	local median, never, accident, worst = summary("medium bad launch", rs)
	H.truthy(median < GameConfig.Pacing.targetSeconds, `median {median}`)
	H.eq(never, 0)
	H.truthy(worst < 30, `worst first contact {worst}`)
	H.truthy(accident < 0.05, `accident rate {accident}`)
end)

H.test(
	"levels are clearly different: hard > medium > easy, easy loses to a decent human",
	function()
		local mVe = Sim.batch(N, 31, { "medium", "easy" })
		local hVm = Sim.batch(N, 32, { "hard", "medium" })
		local hVe = Sim.batch(N, 33, { "hard", "easy" })
		local human = Sim.batch(N, 34, { "easy", "easy" }, { false, true })
		local humanVm = Sim.batch(N, 35, { "medium", "medium" }, { false, true })
		local a, b, c = winShare(mVe, 1), winShare(hVm, 1), winShare(hVe, 1)
		local easyVsHuman, mediumVsHuman = winShare(human, 1), winShare(humanVm, 1)
		print(
			string.format(
				"       win share: medium>easy %.0f%% | hard>medium %.0f%% | hard>easy %.0f%% | easy>human %.0f%% | medium>human %.0f%%",
				a * 100,
				b * 100,
				c * 100,
				easyVsHuman * 100,
				mediumVsHuman * 100
			)
		)
		H.truthy(a > 0.6, `medium vs easy {a}`)
		H.truthy(b > 0.55, `hard vs medium {b}`)
		H.truthy(c > 0.7, `hard vs easy {c}`)
		H.truthy(easyVsHuman < 0.3, `easy vs human {easyVsHuman}`)
		H.truthy(mediumVsHuman < 0.5, `medium vs human {mediumVsHuman}`)
	end
)

H.test("bots use boost and ability in real duels", function()
	local rs = Sim.batch(60, 41, { "hard", "hard" })
	local boosts, specials = 0, 0
	for _, r in rs do
		boosts += r.boosts
		specials += r.specials
	end
	print(`       hard v hard, 60 duels: {boosts} boosts, {specials} abilities`)
	H.truthy(boosts > 30, "boosts")
	H.truthy(specials > 60, "abilities")
end)
