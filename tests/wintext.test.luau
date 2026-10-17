--!strict
local Harness = require("./harness")
local LobbyConfig = require("../src/shared/LobbyConfig")
local WinText = require("../src/shared/WinText")

local test, eq = Harness.test, Harness.eq

print("WinText")

test("headline and subtitle follow the rewards config", function()
	eq(WinText.headline(true), "YOU WIN!")
	eq(WinText.headline(false), "YOU LOSE")
	eq(WinText.subtitle(true, LobbyConfig.Rewards), `+{LobbyConfig.Rewards.winCoins} coins`)
	eq(WinText.subtitle(false, LobbyConfig.Rewards), `+{LobbyConfig.Rewards.loseCoins} coins`)
	eq(WinText.coinsFor(true, { winCoins = 7, loseCoins = 2 }), 7)
end)

test("coin particles are deterministic and bounded", function()
	local a = WinText.coinParticles(42, 24)
	local b = WinText.coinParticles(42, 24)
	eq(#a, 24)
	for i = 1, #a do
		eq(a[i].startX, b[i].startX)
		eq(a[i].peakY, b[i].peakY)
		eq(a[i].endX, b[i].endX)
	end
	eq(#WinText.coinParticles(1, 999), WinText.MaxCoins)
	eq(#WinText.coinParticles(1, -3), 0)
end)

test("coin positions stay on screen", function()
	for seed = 1, 20 do
		for _, c in WinText.coinParticles(seed, 30) do
			eq(c.startX >= 0 and c.startX <= 1, true)
			eq(c.peakX >= 0 and c.peakX <= 1, true)
			eq(c.endX >= 0 and c.endX <= 1, true)
			eq(c.peakY > 0 and c.peakY < 0.7, true)
			eq(c.delay >= 0 and c.delay <= 0.5, true)
		end
	end
end)
