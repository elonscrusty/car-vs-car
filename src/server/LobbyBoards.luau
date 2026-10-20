--!strict
-- The two standing leaderboard frames of the Car Battle Lobby (weekly drivers left, all-time wins
-- right): a dark navy panel in a chunky blue / orange frame on two posts. Look only.
--
-- The panels are Parts named "Board_weekly" and "Board_wins", size w x h x 0.6, bottom edge 4
-- studs above the plaza. Another module puts SurfaceGuis (title, top 5) on them. The face that
-- looks toward the ring is Enum.NormalId.Back (the +Z side of a part drawn facing +Z, turned by
-- the layout yaw). The panel's front is free of decoration; the frame only stands round its edge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)

local LobbyBoards = {}

export type Result = { weekly: Part, wins: Part }

local rgb, part = MapParts.rgb, MapParts.part
local C = LobbyLayout.colors

local BOTTOM = 4 -- panel bottom edge above the plaza
local BORDER = 1.4

local function frame(
	grp: Folder,
	origin: Vector3,
	key: string,
	cfg: { x: number, z: number, w: number, h: number, yawDeg: number }
): Part
	local base = CFrame.new(origin + Vector3.new(cfg.x, 0, cfg.z))
		* CFrame.Angles(0, math.rad(cfg.yawDeg), 0)
	local function at(u: number, y: number, depth: number): CFrame
		return base * CFrame.new(u, y, depth)
	end
	local w, h = cfg.w, cfg.h
	local midY = BOTTOM + h / 2
	local topY = BOTTOM + h
	local panel =
		part(grp, "Board_" .. key, Vector3.new(w, h, 0.6), at(0, midY, 0), rgb(C.panel), false)
	local blue, orange = rgb(C.blue), rgb(C.orange)
	-- the two posts run from the ground to just above the panel
	for _, s in { -1, 1 } do
		local px = s * (w / 2 + BORDER / 2)
		part(
			grp,
			"BoardPost",
			Vector3.new(BORDER + 0.4, topY + BORDER - 0.6, 1.6),
			at(px, (topY + BORDER - 0.6) / 2, 0),
			blue,
			false
		)
		part(
			grp,
			"BoardFoot",
			Vector3.new(BORDER + 2, 0.8, 2),
			at(px, 0.4, 0),
			rgb(C.metalDark),
			false,
			nil,
			Enum.Material.Metal
		)
		part(
			grp,
			"BoardPostCap",
			Vector3.new(BORDER + 0.9, 0.8, 1.9),
			at(px, topY + BORDER - 0.2, 0),
			orange,
			false
		)
	end
	-- top and bottom bars of the frame (a touch deeper than the panel, never over its face)
	part(
		grp,
		"BoardBarTop",
		Vector3.new(w, BORDER, 1.2),
		at(0, topY + BORDER / 2, 0),
		orange,
		false
	)
	part(
		grp,
		"BoardBarBottom",
		Vector3.new(w, BORDER, 1.2),
		at(0, BOTTOM - BORDER / 2, 0),
		orange,
		false
	)
	-- header strip above the frame, with a steady glow line under it and chunky studs
	local headY = topY + BORDER + 1.3
	part(grp, "BoardHeader", Vector3.new(w + 4, 2.6, 1.8), at(0, headY, 0), blue, false)
	local glow = part(
		grp,
		"BoardHeaderGlow",
		Vector3.new(w + 2, 0.4, 0.4),
		at(0, topY + BORDER + 0.2, 1),
		rgb(C.light),
		false,
		nil,
		Enum.Material.Neon
	)
	glow.CastShadow = false
	for i = 1, 5 do
		part(
			grp,
			"BoardStud",
			Vector3.new(1.2, 1.2, 0.4),
			at((i - 3) * (w / 5), headY, 1),
			if i % 2 == 0 then orange else rgb(C.marking),
			false
		)
	end
	return panel
end

function LobbyBoards.build(folder: Folder, origin: Vector3): Result
	local grp = MapParts.group(folder, "Boards")
	return {
		weekly = frame(grp, origin, "weekly", LobbyLayout.boards.weekly),
		wins = frame(grp, origin, "wins", LobbyLayout.boards.wins),
	}
end

return LobbyBoards
