--!strict
-- Car VS Car screens: opening and closing one screen. Each screen id has one ScreenGui pair
-- (Base.screen); open() clears it, builds it fresh from the data (so every entrance plays) and
-- shows it; close() hides and clears it. Windows blur the world while open; at most one window
-- or popup is open at a time (opening one closes the other).
local Base = require(script.Parent:WaitForChild("Base"))

local Screen = {}

export type Actions = { [string]: (...any) -> () }
export type Handle = {
	id: string,
	gui: Base.Gui,
	close: () -> (),
	set: (...any) -> (),
	api: { [string]: any },
}

local guis: { [string]: Base.Gui } = {}
local openOnes: { [string]: Handle } = {}

local LAYER = {
	hud = Base.ORDER.hud,
	window = Base.ORDER.window,
	full = Base.ORDER.celebrate,
	popup = Base.ORDER.popup,
	loading = Base.ORDER.loading,
}

local function guiFor(id: string, layer: string, full: boolean): Base.Gui
	local g = guis[id]
	if not g then
		g = Base.screen("Ui_" .. id, LAYER[layer] or Base.ORDER.window, full)
		guis[id] = g
	end
	return g
end

local function clear(g: Base.Gui)
	for _, c in g.canvas:GetChildren() do
		c:Destroy()
	end
	if g.back then
		for _, c in g.back:GetChildren() do
			c:Destroy()
		end
	end
end

-- What the action `name` does (a no-op if the caller gave none).
function Screen.act(actions: Actions?, name: string): (...any) -> ()
	local fn = actions and actions[name]
	return fn or function() end
end

-- Open screen `id`: build(canvas, back, data, actions) makes its pieces and returns { set?, api? }.
-- layer: "hud" | "window" | "popup" | "full" | "loading"; full: it has a full-screen back layer.
function Screen.open(
	id: string,
	layer: string,
	full: boolean,
	build: (g: Base.Gui) -> { [string]: any }?
): Handle
	local was = openOnes[id]
	if was then
		was.close()
	end
	-- one window or popup at a time
	if layer == "window" or layer == "popup" then
		for other, h in openOnes do
			local l = h.api.layer
			if other ~= id and (l == "window" or l == "popup") then
				h.close()
			end
		end
	end
	local g = guiFor(id, layer, full)
	clear(g)
	local got: { [string]: any } = build(g) or {}
	Base.show(g, true)
	local blurred = layer == "window" and got.noBlur ~= true
	if blurred then
		Base.blur(true)
	end
	local closed = false
	local handle: Handle
	handle = {
		id = id,
		gui = g,
		close = function()
			if closed then
				return
			end
			closed = true
			if openOnes[id] == handle then
				openOnes[id] = nil
			end
			Base.show(g, false)
			clear(g)
			if blurred then
				Base.blur(false)
			end
		end,
		set = got.set or function() end,
		api = got,
	}
	got.layer = layer
	openOnes[id] = handle
	return handle
end

function Screen.isOpen(id: string): boolean
	return openOnes[id] ~= nil
end

function Screen.closeAll()
	for _, h in openOnes do
		h.close()
	end
end

-- Close every window, popup and big screen, keeping the HUD (the live game's plot screen).
function Screen.closeOver()
	for _, h in openOnes do
		if h.api.layer ~= "hud" then
			h.close()
		end
	end
end

return Screen
