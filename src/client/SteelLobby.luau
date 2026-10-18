--!strict
-- Turns the red cells of the model color sheet steel gray for lobby parts, so the lobby reads as a garage.
-- Works on this player's screen only. If EditableImage is unavailable the lobby just stays red.

local AssetService = game:GetService("AssetService")

local SteelLobby = {}

local LIGHT = { 125, 133, 148 }
local DARK = { 74, 83, 102 }

local function fillCell(image: EditableImage, col: number, row: number, rgb: { number })
	local cell = image.Size.X // 8
	local buf = buffer.create(cell * cell * 4)
	for i = 0, cell * cell - 1 do
		buffer.writeu8(buf, i * 4, rgb[1])
		buffer.writeu8(buf, i * 4 + 1, rgb[2])
		buffer.writeu8(buf, i * 4 + 2, rgb[3])
		buffer.writeu8(buf, i * 4 + 3, 255)
	end
	image:WritePixelsBuffer(Vector2.new(col * cell, row * cell), Vector2.new(cell, cell), buf)
end

function SteelLobby.start()
	local lobby = workspace:WaitForChild("Lobby", 30)
	if not lobby then
		return
	end
	local images: { [string]: EditableImage? } = {}
	local broken = false

	local function paint(d: Instance)
		if broken or not d:IsA("MeshPart") or d.TextureID == "" then
			return
		end
		local id = d.TextureID
		if images[id] == nil then
			local ok, image = pcall(function()
				return AssetService:CreateEditableImageAsync(Content.fromUri(id))
			end)
			if not ok then
				broken = true
				return
			end
			fillCell(image, 0, 7, LIGHT)
			fillCell(image, 1, 7, DARK)
			images[id] = image
		end
		local image = images[id]
		if image then
			d.TextureContent = Content.fromObject(image)
		end
	end

	for _, d in lobby:GetDescendants() do
		task.spawn(paint, d)
	end
	lobby.DescendantAdded:Connect(paint)
end

return SteelLobby
