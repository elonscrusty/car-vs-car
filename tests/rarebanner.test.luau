--!nocheck
-- The small message at the top of everyone's screen when someone pulls a rare car from the gumball
-- machine (carter's L51), and the client pieces that carry it (LobbyClient).
local H = require("./harness")
local Mock = require("./robloxmock")
local eq, near, truthy = H.eq, H.near, H.truthy

print("Rare pull banner")

local function setup()
	local world = Mock.new("./src", { fakeClock = true })
	world.quiet = true
	local player = world.newLocalPlayer("Dana", 7)
	local env: any = { world = world, player = player, gui = player.PlayerGui }
	function env.pill()
		local gui = env.gui:FindFirstChild("CVC_RareBanner")
		return if gui then gui:FindFirstChild("Pill") else nil
	end
	function env.text(): string
		return env.pill():FindFirstChild("Text").Text
	end
	return env
end

H.test(
	"a rare pull slides a message under the top bar, keeps it a few seconds and takes it away",
	function()
		local e = setup()
		local banner = e.world.requireClient("RareBanner").new()
		local pill = e.pill()
		truthy(pill, "the banner exists")
		eq(pill.Visible, false, "hidden until there is something to say")
		banner.show("Sam pulled a Hot Rod from the gumball machine!", { 255, 201, 35 })
		eq(pill.Visible, true)
		eq(e.text(), "Sam pulled a Hot Rod from the gumball machine!")
		eq(pill.Position.Y.Offset, 66, "under the top bar")
		-- the rim wears the car's rarity colour
		near(pill:FindFirstChild("UIStroke").Color.R, 255 / 255, 0.001)
		near(pill:FindFirstChild("UIStroke").Color.G, 201 / 255, 0.001)
		e.world.step(4.9)
		eq(pill.Visible, true, "still there")
		e.world.step(0.2)
		truthy(pill.Position.Y.Offset < 0, "sliding away")
		e.world.step(0.5)
		eq(pill.Visible, false, "gone")
	end
)

H.test("messages wait their turn, and a flood does not make a long line", function()
	local e = setup()
	local banner = e.world.requireClient("RareBanner").new()
	for i = 1, 8 do
		banner.show("message " .. i, { 255, 255, 255 })
	end
	local seen = { e.text() }
	local last = e.text()
	for _ = 1, 400 do
		e.world.step(0.1)
		local shown = if e.pill().Visible then e.text() else nil
		if shown ~= nil and shown ~= last then
			table.insert(seen, shown)
		end
		last = shown
	end
	-- the first one plays at once, then at most 3 more wait: 4 in all, in order
	eq(table.concat(seen, ","), "message 1,message 2,message 3,message 4")
	eq(e.pill().Visible, false)
	-- and it works again afterwards
	banner.show("later", { 255, 255, 255 })
	eq(e.pill().Visible, true)
	eq(e.text(), "later")
end)

H.test(
	"the lobby's client shows what the server announces, in the car's colour, and ignores junk",
	function()
		local e = setup()
		local LobbyClient = e.world.requireClient("LobbyClient")
		LobbyClient.start()
		local remotes = e.world.require("shared/Remotes").get()
		local cars = e.world.require("shared/LobbyCars")
		local battle = e.world.require("shared/BattleConfig")
		-- a car worth telling everyone about (Epic or better) from the catalog
		local legend
		for _, id in battle.Order do
			if cars.isRarePull(id) then
				legend = id
				break
			end
		end
		truthy(legend, "the catalog has an Epic or better car")
		remotes.LobbyUpdate.OnClientEvent:Fire({
			kind = "announce",
			text = "Kim pulled a big one!",
			carId = legend,
		})
		eq(e.pill().Visible, true)
		eq(e.text(), "Kim pulled a big one!")
		local rgb = cars.rarityColor(legend)
		near(e.pill():FindFirstChild("UIStroke").Color.R, rgb[1] / 255, 0.001)
		-- junk messages change nothing
		e.world.step(6)
		e.world.step(0.5)
		remotes.LobbyUpdate.OnClientEvent:Fire(nil)
		remotes.LobbyUpdate.OnClientEvent:Fire("text")
		remotes.LobbyUpdate.OnClientEvent:Fire({ kind = "announce" })
		remotes.LobbyUpdate.OnClientEvent:Fire({ kind = "announce", text = 5 })
		eq(e.pill().Visible, false)
		-- no car id: the gold rim
		remotes.LobbyUpdate.OnClientEvent:Fire({
			kind = "announce",
			text = "Someone pulled something!",
		})
		eq(e.pill().Visible, true)
		near(e.pill():FindFirstChild("UIStroke").Color.G, 205 / 255, 0.001)
	end
)

H.test(
	"the lobby's client runs its small jobs without error (fade, reminder, slow-phone cuts)",
	function()
		local e = setup()
		local LobbyClient = e.world.requireClient("LobbyClient")
		LobbyClient.start()
		local remotes = e.world.require("shared/Remotes").get()
		remotes.BattleUpdate.OnClientEvent:Fire({ kind = "prep" })
		remotes.BattleUpdate.OnClientEvent:Fire({ kind = "end" })
		remotes.BattleUpdate.OnClientEvent:Fire(nil)
		e.world.step(301) -- the like reminder (a chat line, never a pop-up)
		e.world.step(10)
		truthy(e.gui:FindFirstChild("LobbyFade"))
	end
)
