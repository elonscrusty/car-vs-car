--!strict
-- The back of the hall, behind the hero stage. It used to hold work bays, lifts, carts, crates and
-- drums. The back wall is kept free now for the leaderboards (x -41 to 21) and the gumball machine
-- (right corner), and nothing loose stands on the back floor. Only wall furniture stays
-- (LobbyGarage: lockers and a tool cabinet). The module is kept so the lobby build order stays the
-- same; it adds an empty "WorkArea" folder for anything placed here later.

local LobbyWorkArea = {}

function LobbyWorkArea.build(folder: Folder, _origin: Vector3)
	local group = Instance.new("Folder")
	group.Name = "WorkArea"
	group.Parent = folder
end

return LobbyWorkArea
