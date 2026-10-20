--!strict
local H = require("./harness")
local Tutorial = require("../src/shared/Tutorial")
local Config = require("../src/shared/TutorialConfig")

print("Tutorial")

-- Runs the whole happy path and returns the steps each event finished, in order.
local function happyPath(touch: boolean): { string }
	local t = Tutorial.new(touch)
	local done: { string } = {}
	local function feed(name: string, value: any?)
		local r = t.event(name, value)
		if r.done ~= nil then
			table.insert(done, r.done)
		end
	end
	feed("portal")
	feed("gas", 1)
	feed("steer", 1)
	feed("boxes", 1)
	feed("boxes", 2)
	feed("boxes", 3)
	feed("nearMachine")
	feed("prompt")
	feed("pulled")
	feed("menuClosed")
	feed("pad")
	return done
end

H.test("every step has words for a phone and a PC, short enough for a bubble", function()
	for _, id in Tutorial.Order do
		H.truthy(#Tutorial.text(id, true) > 0, id .. " phone")
		H.truthy(#Tutorial.text(id, false) > 0, id .. " pc")
	end
	for id, entry in Config.text do
		H.truthy(#entry.phone > 0 and #entry.pc > 0, id)
		H.truthy(#entry.phone <= 48 and #entry.pc <= 48, id .. " is too long for a small bubble")
		-- a phone has no keys or mouse, a PC has no finger
		H.eq(string.find(entry.phone, "Press", 1, true), nil, id .. " phone says Press")
		H.eq(string.find(entry.phone, "Click", 1, true), nil, id .. " phone says Click")
		H.eq(string.find(entry.pc, "Tap", 1, true), nil, id .. " pc says Tap")
		H.eq(string.find(entry.pc, "Slide", 1, true), nil, id .. " pc says Slide")
	end
	H.eq(Tutorial.text("nope", true), "")
end)

H.test("the steps run in the order carter picked", function()
	H.eq(
		table.concat(Tutorial.Order, ","),
		"portal,gas,steer,smash,gumballWalk,gumballTap,gumballPull,gumballReveal,play,done"
	)
	for _, id in Tutorial.Order do
		H.truthy(Config.text[id] ~= nil, id)
	end
end)

H.test("the happy path finishes every step, once each, and ends the tutorial", function()
	for _, touch in { true, false } do
		local done = happyPath(touch)
		H.eq(
			table.concat(done, ","),
			"portal,gas,steer,smash,gumballWalk,gumballTap,gumballPull,gumballReveal,play"
		)
	end
	local t = Tutorial.new(true)
	t.event("portal")
	t.event("gas", 1)
	t.event("steer", 1)
	t.event("boxes", 3)
	t.event("nearMachine")
	t.event("prompt")
	t.event("pulled")
	t.event("menuClosed")
	H.eq(t.current(), "play")
	H.eq(t.isFinished(), false)
	local r = t.event("pad")
	H.eq(r.done, "play")
	H.eq(r.now, "done")
	H.eq(r.finished, true)
	H.eq(t.isFinished(), true)
	H.eq(t.wasSkipped(), false)
	H.truthy(t.view() ~= nil and (t.view() :: Tutorial.View).id == "done")
	-- events after the end do nothing
	local late = t.event("skip")
	H.eq(late.finished, true)
	H.eq(late.done, nil)
	H.eq(t.wasSkipped(), false)
end)

H.test("the first bubble has no button: it stands at the top", function()
	local t = Tutorial.new(true)
	H.eq(t.current(), "portal")
	local v = t.view() :: Tutorial.View
	H.eq(v.id, "portal")
	H.eq(v.text, "Walk into the blue portal!")
	H.eq(v.anchor, "top")
	H.eq(v.practice, false)
	H.eq(v.path, nil)
	H.eq((Tutorial.new(false).view() :: Tutorial.View).text, Config.text.portal.pc)
end)

H.test("phone and PC get different gas and steer words and places", function()
	local phone = Tutorial.new(true)
	phone.event("portal")
	local pv = phone.view() :: Tutorial.View
	H.eq(pv.id, "gas")
	H.eq(pv.practice, true)
	H.eq(pv.anchor, Config.names.gas)
	local pc = Tutorial.new(false)
	pc.event("portal")
	local cv = pc.view() :: Tutorial.View
	H.eq(cv.anchor, "keys")
	H.truthy(cv.text ~= pv.text)
	phone.event("gas", 1)
	H.eq((phone.view() :: Tutorial.View).anchor, Config.names.stick)
	pc.event("gas", 1)
	H.eq((pc.view() :: Tutorial.View).anchor, "keys")
end)

H.test("gas and steer need a moment, not a single frame", function()
	local t = Tutorial.new(true)
	t.event("portal")
	local r = t.event("gas", Config.gasSeconds / 3)
	H.eq(r.done, nil)
	H.eq(t.current(), "gas")
	t.event("gas", Config.gasSeconds / 3)
	r = t.event("gas", Config.gasSeconds / 3 + 0.01)
	H.eq(r.done, "gas")
	H.eq(t.current(), "steer")
	-- a wrong value does nothing
	H.eq(t.event("steer", "lots").done, nil)
	H.eq(t.event("steer", Config.steerSeconds / 2).done, nil)
	H.eq(t.event("steer", Config.steerSeconds / 2 + 0.01).done, "steer")
	H.eq(t.current(), "smash")
end)

H.test("smash counts boxes up, never down, and ends the yard at 3", function()
	local t = Tutorial.new(true)
	t.event("portal")
	t.event("gas", 1)
	t.event("steer", 1)
	H.eq(t.boxes(), 0)
	H.eq((t.view() :: Tutorial.View).text, "Smash 3 boxes!  0 / 3")
	t.event("boxes", 1)
	H.eq((t.view() :: Tutorial.View).text, "Smash 3 boxes!  1 / 3")
	H.eq((t.view() :: Tutorial.View).boxes, 1)
	t.event("boxes", 0)
	H.eq(t.boxes(), 1)
	H.eq(t.event("boxes", 2).done, nil)
	H.eq(t.current(), "smash")
	local r = t.event("boxes", 3)
	H.eq(r.done, "smash")
	H.eq(t.current(), "gumballWalk")
	H.eq(Config.boxesNeeded, 3)
end)

H.test("steps ignore events that belong to other steps", function()
	local t = Tutorial.new(true)
	for _, name in { "gas", "steer", "boxes", "nearMachine", "prompt", "pulled", "menuClosed" } do
		local r = t.event(name, 99)
		H.eq(r.done, nil)
		H.eq(t.current(), "portal")
	end
	H.eq(t.event("mystery").done, nil)
	H.eq(t.event("portal").done, "portal")
	H.eq(t.current(), "gas")
	H.eq(t.event("portal").done, nil)
	H.eq(t.current(), "gas")
end)

H.test("walking to the gumball machine: green line, then tap, then pull", function()
	local t = Tutorial.new(true)
	t.event("portal")
	t.event("gas", 1)
	t.event("steer", 1)
	t.event("boxes", 3)
	local v = t.view() :: Tutorial.View
	H.eq(v.id, "gumballWalk")
	H.eq(v.path, "gumball")
	H.eq(v.practice, false)
	H.eq(t.event("nearMachine").done, "gumballWalk")
	v = t.view() :: Tutorial.View
	H.eq(v.id, "gumballTap")
	H.eq(v.text, Config.text.gumballTap.phone)
	-- near the machine, then the claw screen opens
	H.eq(t.event("prompt").done, "gumballTap")
	H.eq(t.current(), "gumballPull")
	-- opening the machine straight from the walk skips the tap step
	local u = Tutorial.new(false)
	u.event("portal")
	u.event("gas", 1)
	u.event("steer", 1)
	u.event("boxes", 3)
	H.eq(u.event("prompt").done, "gumballWalk")
	H.eq(u.current(), "gumballPull")
end)

H.test(
	"the claw bubble stands next to CONFIRM, else next to the pull button, and says FREE",
	function()
		local t = Tutorial.new(true)
		t.event("portal")
		t.event("gas", 1)
		t.event("steer", 1)
		t.event("boxes", 3)
		t.event("prompt")
		local v = t.view() :: Tutorial.View
		H.eq(v.id, "gumballPull")
		local targets = v.targets :: { Tutorial.Target }
		H.eq(#targets, 2)
		H.eq(targets[1].find, Config.names.confirm)
		H.eq(targets[1].text, Config.text.gumballConfirm.phone)
		H.eq(targets[2].find, Config.names.pull)
		H.eq(targets[2].text, Config.text.gumballPullFree.phone)
		t.setFree(false)
		targets = (t.view() :: Tutorial.View).targets :: { Tutorial.Target }
		H.eq(targets[2].text, Config.text.gumballPull.phone)
		t.setFree(true)
		targets = (t.view() :: Tutorial.View).targets :: { Tutorial.Target }
		H.eq(targets[2].text, Config.text.gumballPullFree.phone)
	end
)

H.test("closing the machine without a pull goes back to tapping it", function()
	local t = Tutorial.new(true)
	t.event("portal")
	t.event("gas", 1)
	t.event("steer", 1)
	t.event("boxes", 3)
	t.event("prompt")
	local r = t.event("menuClosed")
	H.eq(r.done, nil)
	H.eq(t.current(), "gumballTap")
	t.event("prompt")
	H.eq(t.current(), "gumballPull")
	t.event("pulled")
	H.eq(t.current(), "gumballReveal")
	local targets = (t.view() :: Tutorial.View).targets :: { Tutorial.Target }
	H.eq(targets[1].find, Config.names.revealDone)
	H.eq(targets[2].find, Config.names.close)
	H.eq(t.event("menuClosed").done, "gumballReveal")
	local v = t.view() :: Tutorial.View
	H.eq(v.id, "play")
	H.eq(v.path, "pad")
	H.eq(v.anchor, Config.names.play)
end)

H.test("skip ends it at every step: no gift, nothing left to show", function()
	for count = 0, 9 do
		local t = Tutorial.new(true)
		local moves: { { string | number } } = {
			{ "portal", 0 },
			{ "gas", 1 },
			{ "steer", 1 },
			{ "boxes", 3 },
			{ "nearMachine", 0 },
			{ "prompt", 0 },
			{ "pulled", 0 },
			{ "menuClosed", 0 },
			{ "x", 0 },
		}
		for i = 1, count do
			local row = moves[i]
			if row ~= nil then
				t.event(row[1] :: string, row[2])
			end
		end
		local r = t.event("skip")
		H.eq(r.finished, true, "step " .. tostring(count))
		H.eq(r.now, nil)
		H.eq(r.done, nil)
		H.eq(t.isFinished(), true)
		H.eq(t.wasSkipped(), true)
		H.eq(t.current(), nil)
		H.eq(t.view(), nil)
	end
end)

H.test(
	"stepping on a pad early ends the tutorial as skipped; on the last step it finishes",
	function()
		local early = Tutorial.new(true)
		early.event("portal")
		local r = early.event("pad")
		H.eq(r.finished, true)
		H.eq(early.wasSkipped(), true)
		H.eq(early.view(), nil)
		local fromStart = Tutorial.new(false)
		fromStart.event("pad")
		H.eq(fromStart.wasSkipped(), true)
		local late = Tutorial.new(true)
		for _, name in
			{ "portal", "gas", "steer", "boxes", "nearMachine", "prompt", "pulled", "menuClosed" }
		do
			late.event(name, 5)
		end
		H.eq(late.current(), "play")
		late.event("pad")
		H.eq(late.wasSkipped(), false)
		H.eq(late.isFinished(), true)
	end
)

H.test("if the yard cannot be built the player goes on to the gumball machine", function()
	local steps: { { string | number } } = {
		{ "portal", 0 },
		{ "gas", 1 },
		{ "steer", 1 },
	}
	for count = 0, #steps do
		local t = Tutorial.new(true)
		for i = 1, count do
			t.event(steps[i][1] :: string, steps[i][2])
		end
		local r = t.event("practiceFailed")
		H.eq(t.current(), "gumballWalk", "after " .. tostring(count))
		H.eq(r.done, nil)
		H.eq(r.finished, false)
		H.eq((t.view() :: Tutorial.View).path, "gumball")
	end
	-- not once the walk to the machine has started
	local t = Tutorial.new(true)
	t.event("practiceFailed")
	t.event("nearMachine")
	t.event("practiceFailed")
	H.eq(t.current(), "gumballTap")
end)

H.test("only a new player gets the tutorial", function()
	H.truthy(Tutorial.isNew({}))
	H.truthy(Tutorial.isNew(nil))
	H.truthy(Tutorial.isNew({ "claw", "aim" }))
	H.eq(Tutorial.isNew({ "tutorial" }), false)
	H.eq(Tutorial.isNew({ "pad" }), false)
	H.eq(Tutorial.isNew({ "claw", "pad", "aim" }), false)
	H.truthy(Tutorial.isNew("junk"))
end)

H.test("the numbers are sane", function()
	H.eq(Config.giftCoins, 30)
	H.truthy(Config.giftCoins < 120, "the gift stays well under one pull (120 coins)")
	H.truthy(Config.boxesNeeded >= 1)
	H.truthy(Config.practiceMaxSeconds > Config.minGiftSeconds)
	H.truthy(Config.portal.enterRadius <= Config.portal.radius)
	H.truthy(Config.gumballNearStuds < 40, "the machine's prompt works from 40 studs")
	H.truthy(Config.celebrateSeconds > 0.5 and Config.celebrateSeconds < 2)
	H.eq(Tutorial.text("done", true), "Great job! You got 30 coins!")
	H.eq(Tutorial.text("done", true, { coins = 5 }), "Great job! You got 5 coins!")
	H.eq(Tutorial.text("smash", false, { n = 2 }), "Smash 3 boxes!  2 / 3")
end)
