--!strict
-- Turns the red cells of the model color sheet steel gray for lobby parts, so the lobby reads as a garage.
-- Works on this player's screen only. If EditableImage is unavailable the lobby just stays red.

local AssetService = game:GetService("AssetService")

local SteelLobby = {}

local LIGHT = { 125, 133, 148 }
local DARK = { 74, 83, 102 }
local SIGN_YELLOW = { 255, 205, 60 }

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
		if
			d:IsA("MeshPart")
			and d.Parent
			and d.Parent.Name == "BigSign_CarVsCar"
			and d.Name ~= d.Parent.Name
		then
			d.Color = Color3.fromRGB(SIGN_YELLOW[1], SIGN_YELLOW[2], SIGN_YELLOW[3]) -- its neon strips
		end
		if broken or not d:IsA("MeshPart") or d.TextureID == "" then
			return
		end
		local id = d.TextureID
		if d.Name == "BigSign_CarVsCar" then
			-- Its own copy of the sheet (the other models share one).
			local ok, image = pcall(function()
				local made = AssetService:CreateEditableImageAsync(Content.fromUri(id))
				fillCell(made, 0, 7, LIGHT)
				fillCell(made, 1, 7, DARK)
				-- Every light cell becomes the one yellow; the dark cells stay as the outline.
				local pixels = made:ReadPixelsBuffer(Vector2.zero, made.Size)
				local cell = made.Size.X // 8
				local width = made.Size.X
				for row = 0, 7 do
					for col = 0, 7 do
						local o = ((row * cell + cell // 2) * width + col * cell + cell // 2) * 4
						local sum = buffer.readu8(pixels, o)
							+ buffer.readu8(pixels, o + 1)
							+ buffer.readu8(pixels, o + 2)
						if sum >= 285 then
							fillCell(made, col, row, SIGN_YELLOW)
						end
					end
				end
				return made
			end)
			if ok then
				d.TextureContent = Content.fromObject(image)
				return
			end
		end
		if images[id] == nil then
			-- Needs the EditableImage setting (Experience Settings > Security); without it the lobby stays red.
			local ok, image = pcall(function()
				local made = AssetService:CreateEditableImageAsync(Content.fromUri(id))
				fillCell(made, 0, 7, LIGHT)
				fillCell(made, 1, 7, DARK)
				return made
			end)
			if not ok then
				broken = true
				return
			end
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
