--!strict
-- The SHOP of the Car Battle Lobby (blue shell): counter with the "StorePrompt" (the client opens
-- the shop from it by that name), shelves with coin stacks and paint cans, and three display
-- platforms for the rare gumball cars. Look only (no collision, no query, no touch).
--
-- `carSpots` are the world CFrames of the platform tops, in LobbyLayout.shopCars order; the
-- CFrame's LookVector points out of the garage mouth (cars face the plaza).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local LobbyCustomize = require(script.Parent.LobbyCustomize)
local LobbyGarageShell = require(script.Parent.LobbyGarageShell)
local MapParts = require(script.Parent.MapParts)

local LobbyShop = {}

export type Result = { carSpots: { CFrame }, group: Folder }

local rgb, part, can = MapParts.rgb, MapParts.part, MapParts.can
local C = LobbyLayout.colors

local FLOOR = 0.4
local PLATFORM_R = 5.2

function LobbyShop.build(folder: Folder, origin: Vector3): Result
	local b = LobbyLayout.shop
	local shell = LobbyGarageShell.build(folder, origin, b, "blue", "Shop")
	local grp, at = shell.group, shell.at
	local d = shell.depth
	local backV = -d / 2 + 1.6
	local metalDark = rgb(C.metalDark)

	LobbyCustomize.roofSign(shell, "SHOP", rgb(C.blue), rgb(C.orange))

	-- the counter: body (holds the prompt), white top, orange stripe, till and a coin pile
	local K = LobbyLayout.counter
	local counter = part(
		grp,
		"ShopCounter",
		Vector3.new(K.w, 3.4, K.d),
		at(K.u, FLOOR + 1.7, K.v),
		rgb(C.orange),
		false
	)
	part(
		grp,
		"CounterTop",
		Vector3.new(K.w + 0.8, 0.6, K.d + 0.8),
		at(K.u, FLOOR + 3.7, K.v),
		rgb(C.marking),
		false
	)
	part(
		grp,
		"CounterStripe",
		Vector3.new(K.w - 0.4, 0.5, 0.2),
		at(K.u, FLOOR + 1.9, K.v + K.d / 2 + 0.05),
		rgb(C.blue),
		false
	)
	part(
		grp,
		"Till",
		Vector3.new(3.4, 1.6, 2.4),
		at(K.u + 6, FLOOR + 4.8, K.v),
		metalDark,
		false,
		nil,
		Enum.Material.Metal
	)
	part(
		grp,
		"TillScreen",
		Vector3.new(2.6, 1, 0.3),
		at(K.u + 6, FLOOR + 5.9, K.v + 0.4),
		rgb(C.blue),
		false,
		nil,
		Enum.Material.Neon
	)
	for i = 1, 4 do
		can(
			grp,
			"CounterCoins",
			2,
			0.35 * i,
			at(K.u - 6 + (i - 1) * 2.4, FLOOR + 4, K.v + 0.3).Position,
			rgb(C.gold),
			false
		)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StorePrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 40
	prompt.HoldDuration = 0
	prompt.Enabled = true
	prompt.Parent = counter

	-- shelves on the back wall (two units): coin stacks and paint cans on three planks
	local shelfV = backV + 1.2
	local canColors = { C.orange, C.blue, C.marking, C.leaf, C.flowers[2] }
	for _, side in { -1, 1 } do
		local cu = side * 11.5
		for _, e in { -7, 7 } do
			part(
				grp,
				"ShelfUpright",
				Vector3.new(0.8, 12, 2.2),
				at(cu + e, FLOOR + 6, shelfV),
				metalDark,
				false
			)
		end
		for tier = 1, 3 do
			local py = FLOOR + 2.6 + (tier - 1) * 3.6
			part(
				grp,
				"ShelfPlank",
				Vector3.new(15, 0.5, 2.4),
				at(cu, py, shelfV),
				rgb(C.wood),
				false,
				nil,
				Enum.Material.Wood
			)
			for i = 1, 5 do
				local px = cu - 6 + (i - 1) * 3
				if (i + tier) % 2 == 0 then
					-- a coin stack: gold disc column with a darker band
					local hh = 0.5 + ((i * tier) % 3) * 0.6
					can(
						grp,
						"CoinStack",
						2.2,
						hh + 1,
						at(px, py + 0.25, shelfV).Position,
						rgb(C.gold),
						false
					)
					can(
						grp,
						"CoinBand",
						2.3,
						0.25,
						at(px, py + 0.25 + (hh + 1) / 2, shelfV).Position,
						rgb(C.wood),
						false
					)
				else
					can(
						grp,
						"PaintCan",
						1.7,
						2,
						at(px, py + 0.25, shelfV).Position,
						rgb(canColors[(i + tier) % #canColors + 1]),
						false
					)
				end
			end
		end
	end
	-- a big coin sack on each side of the counter
	for _, side in { -1, 1 } do
		part(
			grp,
			"CoinSack",
			Vector3.new(3.2, 3.4, 3.2),
			at(side * 15, FLOOR + 1.7, K.v),
			rgb(C.wood),
			false
		)
		can(grp, "SackCoin", 2.4, 0.4, at(side * 15, FLOOR + 3.4, K.v).Position, rgb(C.gold), false)
	end

	-- three display platforms with a glow rim; cars sit on top and face the mouth
	local spots: { CFrame } = {}
	for i, s in LobbyLayout.shopCars do
		local pos = at(s.u, FLOOR, s.v).Position
		local rim = can(
			grp,
			"PlatformRim",
			PLATFORM_R * 2 + 1.2,
			0.3,
			pos,
			rgb(C.blue),
			false,
			nil,
			Enum.Material.Neon
		)
		rim.CastShadow = false
		can(
			grp,
			"Platform" .. i,
			PLATFORM_R * 2,
			0.8,
			pos + Vector3.new(0, 0.3, 0),
			metalDark,
			false,
			nil,
			Enum.Material.Metal
		)
		can(
			grp,
			"PlatformTop",
			PLATFORM_R * 2 - 1.6,
			0.2,
			pos + Vector3.new(0, 1.1, 0),
			rgb(C.asphalt),
			false
		)
		table.insert(spots, at(s.u, FLOOR + 1.3, s.v) * CFrame.Angles(0, math.pi, 0))
	end

	return { carSpots = spots, group = grp }
end

return LobbyShop
