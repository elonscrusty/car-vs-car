--!strict
-- Car VS Car states sheet (spec section 6, "States"): every look a piece can have, side by side,
-- for checking in Studio. Buttons normal / pressed / off / waiting; slots normal / ON / picked /
-- empty / locked; toggles ON and OFF; a side tile with its red dot; tabs; a milestones bar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Ui = script.Parent.Parent
local Base = require(Ui:WaitForChild("Base"))
local Kit = require(Ui:WaitForChild("Kit"))
local Icons = require(Ui:WaitForChild("Icons"))
local Screen = require(Ui:WaitForChild("Screen"))

local States = {}

function States.open(): Screen.Handle
	return Screen.open("states", "full", true, function(g)
		Kit.backdrop(g.back :: ScreenGui, "showroom")
		local c = g.canvas
		-- row 1: buttons
		Kit.button(c, "Normal", 20, 16, 150, 58, "lime", "NORMAL")
		local pressed = Kit.button(c, "Pressed", 190, 16, 150, 58, "lime", "PRESSED")
		local sc = Instance.new("UIScale")
		sc.Scale = 0.9
		sc.Parent = pressed
		local off = Kit.button(c, "Off", 360, 16, 150, 58, "lime", "OFF")
		Kit.enable(off, false)
		local waiting = Kit.button(c, "Wait", 530, 16, 150, 58, "lime", "WAIT")
		Kit.wait(waiting, true)
		-- row 2: slots, toggles, a side tile with a dot
		local y = 120
		Kit.slot(c, "Normal", 26, y, 66, {
			tone = "blue",
			count = "x6",
			car = { kind = "racer", color = Base.color("blue") },
		})
		Kit.slot(c, "On", 112, y, 66, {
			tone = "lime",
			count = "x9",
			badge = "ON",
			car = { kind = "truck", color = Base.color("lime") },
		})
		Kit.slot(c, "Picked", 198, y, 66, {
			tone = "blue",
			count = "x4",
			selected = true,
			car = { kind = "buggy", color = Base.color("pink") },
		})
		local empty = Base.fill(c, "Empty", 284, y, 66, 66, Base.color("lockedFill"), 2)
		Base.corner(empty, UiTheme.CORNER.slot)
		Base.outline(empty, UiTheme.OUTLINE.normal, Base.color("lockedEdge"))
		Base.text(empty, "Plus", 0, 12, 66, 40, "+", { color = Base.color("lockedEdge"), z = 3 })
		local locked = Base.fill(c, "Locked", 370, y, 66, 66, Base.color("lockedFill"), 2)
		Base.corner(locked, UiTheme.CORNER.slot)
		Base.outline(locked, UiTheme.OUTLINE.normal, Base.color("lockedEdge"))
		Icons.make(locked, "lock", 13, 13, 40, { z = 3 })
		Kit.toggle(c, 460, y + 13, true)
		Kit.toggle(c, 552, y + 13, false)
		local side = Kit.side(c, "New", 650, y, "NEW", "gift", 1)
		side.setDot(3)
		-- row 3: tabs and a milestones bar
		Kit.tabs(c, 20, 262, 330, 44, { "SELECTED", "NORMAL", "NORMAL" }, 1)
		Kit.milestones(c, 390, 250, 330, 60, 0.45, {
			{ at = 0.3, label = "10", icon = "coin" },
			{ at = 0.7, label = "20", icon = "gem" },
		})
		return {}
	end)
end

return States
