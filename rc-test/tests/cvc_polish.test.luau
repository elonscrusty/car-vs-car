--!strict
-- Car VS Car fixes from the Studio final pass that live in client scripts (no Roblox in Lune: these
-- read the source for the rule each fix keeps).
local fs = require("@lune/fs")
local H = require("./harness")
local test, truthy = H.test, H.truthy

print("Car VS Car polish")

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

test(
	"MY GARAGE updates in place on coins and training; it rebuilds only when its cars move",
	function()
		local src = fs.readFile("src/client/CvcGarage.client.luau")
		-- (a rebuild on every coin tick lost a BETTER tap, Studio final-14)
		truthy(has(src, "if now == built then"), "render compares the shape first")
		truthy(has(src, "table.insert(updates, update)"), "station cards update in place")
		local _, renders = string.gsub(src, "\n\tclear%(%)", "")
		truthy(renders == 0, "no clear() straight in render")
	end
)

test("a bar at its car's top is drawn full and gold (MAX! looks maxed)", function()
	local src = fs.readFile("src/client/CvcUi.luau")
	truthy(has(src, "local f = if full then 1 else v / scale"), "full width at the top")
	truthy(has(src, "if full then MAX_GOLD"), "gold at the top")
end)

test("dark words on a yellow button have no light outline (the tabs looked smeared)", function()
	local src = fs.readFile("src/client/CvcGarage.client.luau")
	truthy(
		has(src, "b.TextStrokeTransparency = if on then 1 else 0.2"),
		"inkText drops the outline"
	)
	truthy(not has(src, "TextColor3 = if view =="), "the tabs go through inkText")
end)

test("the crate's big car name waits for the ribbon to step aside", function()
	local src = fs.readFile("src/client/CvcCrate.client.luau")
	truthy(has(src, "ribbon.Visible = false"), "the ribbon hides while the name is up")
end)

test("Car VS Car's NEXT chip points at crates, never the car shop", function()
	local src = fs.readFile("src/client/Stars.client.luau")
	truthy(has(src, "info = cvcGoal(info)"), "the goal goes through cvcGoal")
	truthy(has(src, '"GET A CRATE!"'), "GET A CRATE! when you have the coins")
end)

test("the crate's odds leave off a kind that can't come out (no LEGEND 0%)", function()
	local src = fs.readFile("src/client/CvcCrate.client.luau")
	truthy(has(src, "if info and pct > 0 then"), "0% rows are skipped")
end)

test("each podium car fits its block as it spins, clear of the next car", function()
	local src = fs.readFile("src/client/Podium.luau")
	truthy(has(src, "copy:ScaleTo(copy:GetScale() * CAR_FIT / across)"), "scaled corner to corner")
	-- (the numbers: square block tops 8.5 wide, cars 92% of that corner to corner, 10.5 apart)
	local fit, apart = 8.5 * 0.92, 10.5
	truthy(fit <= 8.5, "a spinning car stays on its block")
	truthy(fit < apart, "two spinning cars never touch")
end)

test("the how-to tip hides the JOBS chip only when it can't keep clear of it", function()
	local how = fs.readFile("src/client/CvcHowTo.client.luau")
	local stars = fs.readFile("src/client/Stars.client.luau")
	truthy(has(how, "hideJobs(spotJ == nil)"), "the tip tries to keep clear first")
	truthy(has(stars, 'GetAttribute("TipHidesJobs") ~= true'), "Stars steps the chip away")
end)

test("the driving pieces step away while the race result card shows", function()
	local main = fs.readFile("src/client/Main.client.luau")
	local race = fs.readFile("src/client/CvcRace.client.luau")
	local server = fs.readFile("src/client/ServerRace.client.luau")
	local lobby = fs.readFile("src/client/Lobby.luau")
	truthy(
		has(main, "gui.Enabled = not walking and not (resultCard ~= nil and resultCard.Visible)"),
		"Hud / Controls (RCControls)"
	)
	truthy(
		has(race, 'boost.Visible = player:GetAttribute("Racing") == true and not resultUp()'),
		"BOOST"
	)
	truthy(has(server, "and not card.Visible -- (the result card has the screen"), "JOIN")
	truthy(has(lobby, 'cardShown("ServerRace", "Result")'), "WALK")
end)

test(
	"every button the how-to tip looks for is in the screen it names (JOBS is in StarsHud)",
	function()
		-- (it looked in "Stars" for the JOBS chip, never found it, and the arrow sat on JOBS 2/3 and
		-- on the open jobs list, Studio final-47 and final-50)
		local how = fs.readFile("src/client/CvcHowTo.client.luau")
		local files: { string } = {}
		for _, f in fs.readDir("src/client") do
			local path = `src/client/{f}`
			if fs.isFile(path) then
				table.insert(files, fs.readFile(path))
			end
		end
		local looks = 0
		local function check(g: string, n: string)
			looks += 1
			local found = false
			for _, src in files do
				local v = string.match(src, `([%w_]+)%.Name = "{n}"`)
				if v and has(src, `Name = "{g}"`) then
					-- up its .Parent lines: when they go further, the screen they reach is the one named
					local names: { string } = {}
					for _ = 1, 8 do
						local name = string.match(src, `\n%s*{v}%.Name = "([%w_]+)"`)
						if name then
							table.insert(names, name)
						end
						local up = string.match(src, `\n%s*{v}%.Parent = ([%w_]+)\n`)
						if not up then
							break
						end
						v = up
					end
					found = found or #names <= 1 or table.find(names, g) ~= nil
				end
			end
			truthy(found, `no screen {g} with {n}`)
		end
		for g, n in string.gmatch(how, 'find%("([%w_]+)", "([%w_]+)"%)') do
			check(g, n)
		end
		for g, n in string.gmatch(how, '{ "([%w_]+)", "([%w_]+)" }') do
			check(g, n)
		end
		truthy(looks >= 8, `found the looks ({looks})`)
		truthy(has(how, 'find("StarsHud", "DailyJobs")'), "JOBS in StarsHud")
		-- the open list: the tip waits while it's open
		local stars = fs.readFile("src/client/Stars.client.luau")
		truthy(has(stars, 'jobs:SetAttribute("Open", not folded)'), "Stars says when it's open")
		truthy(has(how, 'jobs:GetAttribute("Open") == true then'), "the tip waits")
	end
)

test("short words (+50 COINS: JOB DONE!) wait for the after-race cards", function()
	local stars = fs.readFile("src/client/Stars.client.luau")
	truthy(has(stars, 'CvcLayout.waitTurn(gui.Parent :: Instance, "Toast", 30)'), "Toast waits")
	truthy(has(stars, 'toast.Name = "Toast"'), "the name it waits under")
end)

test(
	"a race with no coins and no cup still says something on its card (no empty GOOD TRY!)",
	function()
		local src = fs.readFile("src/client/CvcRace.client.luau")
		truthy(has(src, "got.Text = NO_PRIZE_WORDS"), "the card's second line")
		truthy(has(src, 'local NO_PRIZE_WORDS = "'), "the words")
	end
)

test(
	"buy buttons say what they do and that it's coins (no bare 81 MORE); crates show name and price",
	function()
		local garage = fs.readFile("src/client/CvcGarage.client.luau")
		local crate = fs.readFile("src/client/CvcCrate.client.luau")
		for name, src in { garage = garage, crate = crate } do
			truthy(not has(src, "{short} MORE`"), `{name}: a bare N MORE`)
		end
		truthy(has(garage, "BETTER!\\n{cost} COINS"), "BETTER says coins")
		truthy(has(garage, "NEW STATION: {cost} COINS"), "NEW STATION says coins")
		truthy(has(crate, "NEED {short} MORE COINS"), "the crate says coins")
		truthy(has(crate, "`{kind.label}  {cost} COINS`"), "the crate's name and price")
	end
)

test("NOT SAVING sits past Roblox's top left buttons; the coin +N stays on the screen", function()
	local stars = fs.readFile("src/client/Stars.client.luau")
	truthy(has(stars, "noSave.Position = UDim2.fromOffset(NO_SAVE_X, 18)"), "NOT SAVING moved")
	truthy(has(stars, "local NO_SAVE_X = 180"), "past the three buttons")
	-- (+5 went off the top: AbsolutePosition starts under the top bar, Studio polish-8)
	truthy(
		has(stars, "coinChip.AbsolutePosition - topOrigin.AbsolutePosition"),
		"coins fly in StarsTop's offsets"
	)
	truthy(
		has(stars, "plus.Position = UDim2.fromOffset(start.X, start.Y - 56)"),
		"+N where the coins start"
	)
end)

test("the how-to tip waits while the daily gift card is up", function()
	local how = fs.readFile("src/client/CvcHowTo.client.luau")
	truthy(has(how, 'if shown(find("StarsTop", "DailyGift")) then'), "one at a time")
end)

test(
	"the pick screen's bars are out of a bit past the best starter, and say what each car is best at",
	function()
		local cvc = fs.readFile("src/client/Cvc.client.luau")
		local ui = fs.readFile("src/client/CvcUi.luau")
		-- (out of 100, 26 and 18 looked the same, Studio polish-6)
		truthy(
			has(cvc, "most = math.max(most, (CvcState.bar(CvcState.fresh(id), b)))"),
			"one number, not the top too"
		)
		truthy(has(cvc, "{ barMost = most, best = true }"), "the pick cards")
		truthy(has(ui, "local f = if full then 1 else v / scale"), "bars use the scale")
		truthy(has(ui, "`BEST AT {CvcUi.BAR_WORDS[CvcUi.bestBar(car)]}!`"), "BEST AT SPEED!")
	end
)

test(
	"the garage shows the next stations locked, and the crate screen says what's inside",
	function()
		-- (one station card, or a crate and its odds, left big empty blue areas, Studio polish-12)
		local garage = fs.readFile("src/client/CvcGarage.client.luau")
		truthy(has(garage, "lockedShown = lockedCards()"), "locked cards after the stations")
		truthy(has(garage, "(#CvcState.stations + lockedShown) * (CARD_W + 12)"), "they scroll too")
		local crate = fs.readFile("src/client/CvcCrate.client.luau")
		truthy(has(crate, 'local NEW_CAR_WORDS = "A NEW CAR FOR YOUR GARAGE!"'), "the crate's line")
	end
)
