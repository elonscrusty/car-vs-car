--!strict
-- The win screen's coins + LEVEL UP! (carter 10-29, try A). Coins fly from the winner's step into
-- the coins number, one ding each; when the level bar fills a big LEVEL UP! slams down with a burst
-- of stars. A fixed pool of frames, numbers from shared/WinReward. Nothing moves with reduced motion
-- (the number is just shown).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WinReward = require(Shared:WaitForChild("WinReward"))
local Base = require(script.Parent:WaitForChild("Base"))
local Anim = require(script.Parent:WaitForChild("Anim"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Reward = {}

export type Fx = { coin: (i: number) -> (), levelUp: () -> () }

local GOLD = "ffd93b"
local STAR_COLORS = { "ffd93b", "55ea2c", "ffe46a" }

-- the middle of `obj` as 0..1 of `layer`
local function centre(layer: GuiObject, obj: GuiObject): (number, number)
	local lp, ls = layer.AbsolutePosition, layer.AbsoluteSize
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return (p.X + s.X / 2 - lp.X) / math.max(ls.X, 1), (p.Y + s.Y / 2 - lp.Y) / math.max(ls.Y, 1)
end

-- Coins fly from the middle of `from` into `to` (the coin icon); `pulse` (the icon with the number)
-- bumps as each lands and `amount` counts up to +total. fx.coin(i) plays the ding.
function Reward.coins(
	layer: GuiObject,
	from: GuiObject,
	to: GuiObject,
	pulse: GuiObject,
	amount: TextLabel,
	total: number,
	fx: Fx?
)
	if Base.reduced() or total <= 0 then
		Base.setText(amount, `+{total}`)
		return
	end
	Base.setText(amount, "+0")
	local pool: { Frame } = {}
	for i = 1, WinReward.COINS do
		local f = Base.fill(layer, "Coin", 0, 0, 24, 24, Kit.hex(GOLD), 3)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Visible = false
		Base.corner(f)
		Kit.face(f, { "fff7b0", "ffd93b", "ffaa00" })
		Base.outline(f, 2)
		pool[i] = f
	end
	local t0 = Anim.now()
	local sx, sy = 0, 0
	local tx, ty = 0, 0
	local done: { boolean } = {}
	local lastLand = -1
	local started = false
	Anim.tick(layer, function(now)
		local t = now - t0
		if t < WinReward.FIRST_AT then
			return
		end
		if not started then
			started = true
			-- (the screen has laid itself out by now)
			sx, sy = centre(layer, from)
			tx, ty = centre(layer, to)
			sy -= 0.08
		end
		for k, f in pool do
			local u = (t - WinReward.leaves(k)) / WinReward.FLIGHT
			if u >= 1 then
				f.Visible = false
				if not done[k] then
					done[k] = true
					lastLand = t
					Base.setText(amount, `+{WinReward.shown(k, total)}`)
					if fx then
						fx.coin(k)
					end
				end
				continue
			end
			if u < 0 then
				continue
			end
			f.Visible = true
			local x, y, size =
				WinReward.fly(k, u, sx * Base.W, sy * Base.H, tx * Base.W, ty * Base.H)
			f.Position = UDim2.fromScale(x / Base.W, y / Base.H)
			local w = WinReward.spin(k, t - WinReward.leaves(k))
			f.Size = UDim2.fromScale(24 * size * w / Base.W, 24 * size / Base.H)
		end
		-- (the number and its coin bump a little as each coin lands)
		local p = if lastLand >= 0 then WinReward.pulse(t - lastLand) else 0
		Anim.scaler(pulse).Scale = 1 + 0.3 * p
	end)
end

-- A big LEVEL UP! over the screen: spinning rays, the title slamming in, "YOU ARE NOW LEVEL n", a
-- white flash and a burst of stars; it shrinks away after WinReward.BANNER_HOLD s.
function Reward.levelUp(layer: GuiObject, level: number, fx: Fx?)
	if fx then
		fx.levelUp()
	end
	local box = Base.box(layer, "LevelUp", 0, 0, Base.W, Base.H, 6)
	-- (shrinks to its middle)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	local rays = Kit.rays(box, 422, 112, 520, "go", 0.7)
	rays.ZIndex = 2
	local title = Kit.title(box, 122, 48, 600, 92, "LEVEL UP!", "gold")
	local sub = Base.text(box, "Now", 122, 144, 600, 36, `YOU ARE NOW LEVEL {level}`, {
		stroke = 4,
		drop = 2,
		z = 9,
	})
	if Base.reduced() then
		task.delay(WinReward.BANNER_HOLD, function()
			box:Destroy()
		end)
		return
	end
	Anim.slam(title)
	Anim.pop(sub, 0.4, 0.2, 0.25)
	-- the flash: white, gone in a blink
	local flash = Base.fill(box, "Flash", 0, 0, Base.W, Base.H, Base.WHITE, 1)
	flash.BackgroundTransparency = 0.3
	Anim.to(flash, 0.22, { BackgroundTransparency = 1 })
	-- the stars
	local stars: { Frame } = {}
	for i = 1, WinReward.STARS do
		local f =
			Base.fill(box, "Star", 0, 0, 14, 14, Kit.hex(STAR_COLORS[(i % #STAR_COLORS) + 1]), 8)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Visible = false
		Base.outline(f, 1.5)
		stars[i] = f
	end
	local t0 = Anim.now()
	Anim.tick(box, function(now)
		local age = now - t0
		for i, f in stars do
			local x, y = WinReward.star(i, age, 422, 110)
			if x and y then
				f.Visible = true
				f.Position = UDim2.fromScale(x / Base.W, y / Base.H)
				-- (a diamond, turning as it flies)
				f.Rotation = 45 + age * 300 * (if i % 2 == 0 then 1 else -1)
			elseif f.Visible then
				f.Visible = false
			end
		end
	end)
	task.delay(WinReward.BANNER_HOLD, function()
		if not box.Parent then
			return
		end
		Anim.to(
			Anim.scaler(box),
			0.3,
			{ Scale = 0.6 },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		task.delay(0.3, function()
			box:Destroy()
		end)
	end)
end

return Reward
