--!strict
-- One popup at a time (car shop, LOOKS, RIVALS), each with two ways out: its big X, or a tap
-- anywhere outside it (a dim cover behind the panel). Opening one shuts the one before, so they
-- never stack. Each popup script says when its popup opens and shuts with Popup.shown.
local Popup = {}

local closers: { [string]: () -> () } = {}
local covers: { [string]: GuiButton } = {}
local openName: string? = nil

-- the dim cover for a popup: put it in the popup's ScreenGui (under the panel), and say how to
-- shut the popup
function Popup.add(name: string, holder: Instance, close: () -> ())
	local cover = Instance.new("TextButton")
	cover.Name = "TapOutside"
	cover.Text = ""
	cover.AutoButtonColor = false
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 0.55
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.Position = UDim2.fromScale(0, 0)
	cover.ZIndex = 0 -- under the panel (ZIndex 1)
	cover.Visible = false
	cover:SetAttribute("NoTap", true) -- no squish or tick for the cover (Tap.client)
	cover.Parent = holder
	cover.Activated:Connect(close)
	closers[name] = close
	covers[name] = cover
end

-- the popup just opened (on) or shut (off)
function Popup.shown(name: string, on: boolean)
	local cover = covers[name]
	if cover then
		cover.Visible = on
	end
	if on then
		local was = openName
		openName = name
		if was and was ~= name then
			local shut = closers[was]
			if shut then
				shut()
			end
		end
	elseif openName == name then
		openName = nil
	end
end

-- a popup is up (the daily gift waits for it)
function Popup.isOpen(): boolean
	return openName ~= nil
end

return Popup
