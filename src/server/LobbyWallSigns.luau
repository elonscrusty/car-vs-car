--!strict
-- The big painted signs on the tire wall (PLAY HERE, GUMBALL, SHOP), all looking at the PLAY ring.
-- Navy board, chunky orange or blue trim, one FredokaOne word in orange with a blue outline, and
-- a fat arrow on the side signs pointing toward the back. Positions come from
-- LobbyLayout.wallSigns. The board stands just outside the tire line on two posts, its bottom
-- above the tires and wall lights. Look only: nothing here collides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(script.Parent.MapParts)

local LobbyWallSigns = {}

local rgb, part, group = MapParts.rgb, MapParts.part, MapParts.group
local C = LobbyLayout.colors

local BOARD_T = 0.6 -- board thickness
local OUT = 2.0 -- board middle, studs outside the tire line (clear of the wall lights)
local POST_OUT = 2.6 -- the posts stand behind the board
local TRIM = 0.8

local function label(panel: Part, face: Enum.NormalId, str: string, top: number, height: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = panel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(0.92, height)
	l.Position = UDim2.fromScale(0.04, top)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = str
	l.TextColor3 = rgb(C.orange)
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = rgb(C.blue)
	l.Parent = gui
end

-- A fat arrow lying on the plaza face of the board: shaft plus two head bars. `cf` is the board
-- middle; local +x is the viewer's right, local +z points at the plaza.
local function arrow(grp: Instance, cf: CFrame, s: number, w: number, y: number, color: Color3)
	local len = w * 0.5
	local z = BOARD_T / 2 + 0.1
	local tip = s * len / 2
	part(
		grp,
		"ArrowShaft",
		Vector3.new(len - 0.6, 0.7, 0.2),
		cf * CFrame.new(-s * 0.3, y, z),
		color,
		false
	)
	local head, ang = 2.2, math.rad(40)
	for _, sy in { -1, 1 } do
		part(
			grp,
			"ArrowHead",
			Vector3.new(head, 0.7, 0.2),
			cf
				* CFrame.new(
					tip - s * math.cos(ang) * head / 2,
					y + sy * math.sin(ang) * head / 2,
					z
				)
				* CFrame.Angles(0, 0, -s * sy * ang),
			color,
			false
		)
	end
end

local function sign(folder: Instance, origin: Vector3, d: LobbyLayout.WallSign)
	local grp = group(folder, "WallSign")
	local w, h = d.w, d.h
	local bottom = LobbyLayout.wallSignBottom
	local midY = bottom + h / 2
	-- the wall line, then step outside the plaza (local -z is away from the ring)
	local base = CFrame.new(origin + Vector3.new(d.x, 0, d.z))
		* CFrame.Angles(0, math.rad(d.yawDeg), 0)
	local cf = base * CFrame.new(0, midY, -OUT)
	local navy = rgb(C.panel)
	local trim = if d.frame == "blue" then rgb(C.blue) else rgb(C.orange)

	local board = part(grp, "WallSignBoard", Vector3.new(w, h, BOARD_T), cf, navy, false)
	board.Material = Enum.Material.SmoothPlastic
	board.Reflectance = 0
	-- chunky trim round the edge, a little thicker than the board
	part(
		grp,
		"TrimTop",
		Vector3.new(w + TRIM, TRIM, BOARD_T + 0.4),
		cf * CFrame.new(0, h / 2, 0),
		trim,
		false
	)
	part(
		grp,
		"TrimBottom",
		Vector3.new(w + TRIM, TRIM, BOARD_T + 0.4),
		cf * CFrame.new(0, -h / 2, 0),
		trim,
		false
	)
	for _, s in { -1, 1 } do
		part(
			grp,
			"TrimSide",
			Vector3.new(TRIM, h + TRIM, BOARD_T + 0.4),
			cf * CFrame.new(s * w / 2, 0, 0),
			trim,
			false
		)
		-- two posts from the ground up behind the board
		local postH = bottom + h - 1
		part(
			grp,
			"SignPost",
			Vector3.new(0.8, postH, 0.8),
			base * CFrame.new(s * (w / 2 - 1.5), postH / 2, -POST_OUT),
			rgb(C.metalDark),
			false,
			nil,
			Enum.Material.Metal
		)
	end

	-- the plaza face (+z, Back) gets the word and the arrow; the outside face only the word
	local arrowDir = d.arrow
	if arrowDir ~= 0 then
		label(board, Enum.NormalId.Back, d.text, 0.06, 0.58)
		arrow(grp, cf, arrowDir, w, -h * 0.3, rgb(C.marking))
	else
		label(board, Enum.NormalId.Back, d.text, 0.1, 0.8)
	end
	label(board, Enum.NormalId.Front, d.text, 0.1, 0.8)
end

function LobbyWallSigns.build(folder: Folder, origin: Vector3)
	local grp = group(folder, "WallSigns")
	for _, d in LobbyLayout.wallSigns do
		sign(grp, origin, d)
	end
end

return LobbyWallSigns
