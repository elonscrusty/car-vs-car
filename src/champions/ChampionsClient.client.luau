-- UI only. Existing game code owns accounts, matchmaking, driving and outcomes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local namespace = ReplicatedStorage:WaitForChild("CVC_Champions", 30)
if not namespace then
	warn("Champions UI: install the Shared modules and bridge events first.")
	return
end
local shared = namespace:WaitForChild("Shared")
local T = require(shared.Theme)
local State = require(shared.State)
local Config = require(shared.Config)
local Catalog = require(shared.Catalog)
local Race = require(shared.Race)
local Utility = require(shared.Utility)
local preview = false -- the preview simulator is not shipped; the game adapter feeds real data
local Preview = nil
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("CVC_Champions") then
	warn("Champions UI already mounted; duplicate client ignored.")
	return
end
local function event(name)
	local object = namespace:WaitForChild(name, 10)
	assert(object and object:IsA("BindableEvent"), "Champions UI bridge missing: " .. name)
	return object
end
local actions, stateEvent, openEvent, notifyEvent =
	event("Actions"), event("State"), event("Open"), event("Notify")
local gui = Instance.new("ScreenGui")
gui.Name = "CVC_Champions"
gui.ResetOnSpawn = false
gui.DisplayOrder = 35
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui:SetAttribute("PreviewMode", preview)
gui:SetAttribute("PreviewToolsVisible", preview)
gui.Parent = playerGui
local viewport = Instance.new("Frame")
viewport.Name = "Viewport"
viewport.BackgroundTransparency = 1
viewport.AnchorPoint = Vector2.new(0.5, 0.5)
viewport.Position = UDim2.fromScale(0.5, 0.5)
viewport.Size = UDim2.fromScale(1, 1)
viewport.Parent = gui
local stage = Instance.new("Frame")
stage.Name = "Stage"
stage.BackgroundTransparency = 1
stage.Size = UDim2.fromScale(1, 1)
stage.Parent = viewport
-- The dark dim covers the WHOLE screen, top bar included, so it has its own full-screen gui.
local dimGui = Instance.new("ScreenGui")
dimGui.Name = "CVC_ChampionsDim"
dimGui.ResetOnSpawn = false
dimGui.DisplayOrder = 34
dimGui.ScreenInsets = Enum.ScreenInsets.None
dimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dimGui.Parent = playerGui
-- Loading cover: the game name and what the game is, until the player's data is in.
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "CVC_ChampionsLoading"
loadingGui.ResetOnSpawn = false
loadingGui.DisplayOrder = 100
loadingGui.IgnoreGuiInset = true
loadingGui.ScreenInsets = Enum.ScreenInsets.None
loadingGui.Parent = playerGui
local loadingCover = Instance.new("Frame")
loadingCover.Size = UDim2.fromScale(1, 1)
loadingCover.BackgroundColor3 = T.C.ink
loadingCover.BorderSizePixel = 0
loadingCover.Parent = loadingGui
local loadingBox = Instance.new("Frame")
loadingBox.AnchorPoint = Vector2.new(0.5, 0.5)
loadingBox.Position = UDim2.fromScale(0.5, 0.5)
loadingBox.Size = UDim2.fromOffset(760, 260)
loadingBox.BackgroundTransparency = 1
loadingBox.Parent = loadingCover
local loadingFit = Instance.new("UIScale")
loadingFit.Parent = loadingBox
T.text(loadingBox, "Title", "CAR VS CAR", 0, 0, 760, 120, 100, T.C.gold, "Center")
T.text(
	loadingBox,
	"Objective",
	"PICK A CAR. IT FIGHTS BY ITSELF. WIN 2 OF 3 ROUNDS!",
	0,
	130,
	760,
	70,
	34,
	T.C.white,
	"Center"
)
T.text(loadingBox, "Status", "LOADING...", 0, 210, 760, 40, 26, T.C.cyan, "Center")
local loadingDone = false
local function hideLoading()
	if loadingDone then
		return
	end
	loadingDone = true
	loadingGui:Destroy()
end
task.delay(12, hideLoading) -- never trap the player behind it
local function fitLoading()
	local size = loadingGui.AbsoluteSize
	loadingFit.Scale = math.clamp(math.min(size.X / 800, size.Y / 300), 0.4, 1.2)
end
loadingGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitLoading)
fitLoading()
local menuBackdrop = Instance.new("Frame")
menuBackdrop.Name = "MenuBackdrop"
menuBackdrop.Size = UDim2.fromScale(1, 1)
menuBackdrop.BackgroundColor3 = T.C.ink
menuBackdrop.BackgroundTransparency = 0.15
menuBackdrop.BorderSizePixel = 0
menuBackdrop.Active = false
menuBackdrop.Parent = dimGui
-- The lobby and fight HUD use the top row next to Roblox's own buttons, so they only keep out of
-- the device notch, not the Roblox top bar.
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "CVC_ChampionsHud"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 35
hudGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.Parent = playerGui
local hudStage = Instance.new("Frame")
hudStage.Name = "HudStage"
hudStage.BackgroundTransparency = 1
hudStage.Size = UDim2.fromScale(1, 1)
hudStage.Parent = hudGui
local menuHost = Instance.new("Frame")
menuHost.Name = "MenuCanvas"
menuHost.BackgroundTransparency = 1
menuHost.Size = UDim2.fromOffset(1200, 675)
menuHost.AnchorPoint = Vector2.new(0.5, 0.5)
menuHost.Position = UDim2.fromScale(0.5, 0.5)
menuHost.Parent = stage
local scale = Instance.new("UIScale")
scale.Parent = menuHost
local toast = T.panel(viewport, "Notice", 0, 0, 420, 56, T.C.cyan)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -62)
toast.ZIndex = 100
local toastText = T.text(toast, "Message", "", 10, 4, 400, 48, 21, T.C.white, "Center")
toastText.TextWrapped = true
toastText.ZIndex = 101
toast.Visible = false
local queueBadge = T.panel(viewport, "QueueBadge", 0, 0, 300, 44, T.C.blue)
queueBadge.AnchorPoint = Vector2.new(0.5, 0)
queueBadge.Position = UDim2.new(0.5, 0, 0, 8)
queueBadge.ZIndex = 100
local queueBadgeText = T.text(queueBadge, "Status", "", 8, 2, 284, 40, 22, T.C.white, "Center")
queueBadgeText.ZIndex = 101
queueBadge.Visible = false
local state = preview and Preview.initial() or State.normalize(nil)
local selection = state.selection or state.equipped or Config.Vehicles[1].Id
local filter = "ALL"
local screen = preview and (script:GetAttribute("PreviewStartScreen") or "CARS") or "LOBBY"
local previousScreen = "LOBBY"
local confirmation
local activeIntent
local view
local pendingToken = 0
local toastToken = 0
local alive = true
local connections = {}
local render, navigate, request, acceptState
local allowed = {
	LOBBY = true,
	CARS = true,
	PICKER = true,
	SHOP = true,
	CLAW = true,
	MODES = true,
	GIFT = true,
	CONFIRM = true,
	REVEAL = true,
	SETTINGS = true,
	MATCH = true,
	RESULTS = true,
}
local scenes = { "SOCCER", "TAG", "RACE", "DUEL", "GOAL", "SUDDEN", "SPECTATOR", "RESULTS" }
local sceneIndex = 0
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
local function message(value)
	toastToken += 1
	local token = toastToken
	if value == nil or value == "" then
		toast.Visible = false -- an empty notice clears the old one (e.g. a stale BUSY after a good pull)
		return
	end
	toastText.Text = tostring(value)
	toast.Visible = true
	task.delay(4, function()
		if alive and token == toastToken then
			toast.Visible = false
		end
	end)
end
local savedTouchGui, oldTouchEnabled
local function touchFocus(open)
	local touch = playerGui:FindFirstChild("TouchGui")
	if open then
		if touch and touch:IsA("ScreenGui") then
			if savedTouchGui ~= touch then
				savedTouchGui = touch
				oldTouchEnabled = touch.Enabled
			end
			touch.Enabled = false
		end
	elseif savedTouchGui then
		if savedTouchGui.Parent then
			savedTouchGui.Enabled = oldTouchEnabled
		end
		savedTouchGui = nil
		oldTouchEnabled = nil
	end
	namespace:SetAttribute("MenuOpen", open)
end
local function matchRoute(snapshot)
	local match = snapshot.match
	if
		snapshot.result
		or (match and (match.result or match.phase == "RESULTS" or match.phase == "ENDED"))
	then
		return "RESULTS"
	end
	if match then
		return "MATCH"
	end
	return "LOBBY"
end
local function close()
	confirmation = nil
	navigate(matchRoute(state))
end
local function cycle()
	if not preview then
		return
	end
	sceneIndex = sceneIndex % #scenes + 1
	local snapshot, route = Preview.scenario(scenes[sceneIndex], T.monoTime())
	acceptState(snapshot)
	screen = route or matchRoute(state)
	render()
end
local toolbar
if preview then
	toolbar = T.frame(gui, "PreviewTools", 0, 0, 0, 52, T.C.navy, 0)
	toolbar.AnchorPoint = Vector2.new(0, 1)
	toolbar.Position = UDim2.fromScale(0, 1)
	toolbar.Size = UDim2.new(1, 0, 0, 52)
	T.text(toolbar, "PreviewLabel", "UI PREVIEW ONLY", 12, 3, 188, 46, 21, T.C.gold)
	T.button(toolbar, "CycleMatch", "CYCLE MATCH [F6]", 210, 3, 210, 46, cycle, T.C.blue)
	T.button(toolbar, "OpenPicker", "CAR PICKER", 432, 3, 156, 46, function()
		navigate("PICKER")
	end, T.C.navy)
	T.button(toolbar, "ResetData", "RESET DATA", 600, 3, 156, 46, function()
		acceptState(Preview.initial())
		navigate("CARS")
	end, T.C.red)
end
local function layout()
	local test = preview and gui:GetAttribute("PreviewViewport") or nil
	local tools = toolbar and gui:GetAttribute("PreviewToolsVisible") == true
	if toolbar then
		toolbar.Visible = tools
	end
	if typeof(test) == "Vector2" then
		viewport.Size = UDim2.fromOffset(math.max(320, test.X), math.max(220, test.Y))
		viewport.Position = UDim2.new(0.5, 0, 0.5, tools and -26 or 0)
	else
		viewport.Size = UDim2.new(1, 0, 1, tools and -52 or 0)
		viewport.Position = UDim2.new(0.5, 0, 0.5, tools and -26 or 0)
	end
	local size = stage.AbsoluteSize
	scale.Scale = math.max(0.1, math.min(size.X / 1200, size.Y / 675))
	local override = gui:GetAttribute("ScaleOverride") -- Studio testing: pretend to be a small phone
	if type(override) == "number" and override > 0 then
		scale.Scale = override
	end
	toast.Size = UDim2.fromOffset(math.min(420, math.max(240, size.X - 28)), 56)
	toastText.Size = UDim2.new(1, -20, 1, -8)
end
local function presented()
	local value = table.clone(state)
	value.selection = selection
	value.filter = filter
	value.confirm = confirmation
	value.previousScreen = previousScreen
	return value
end
render = function()
	if not alive then
		return
	end
	layout()
	if view then
		view:Destroy()
		view = nil
	end
	local value = presented()
	T.configure(value)
	local menu = screen ~= "LOBBY" and screen ~= "MATCH"
	menuHost.Visible = menu
	menuBackdrop.Visible = menu
	hudStage.Visible = not menu
	touchFocus(menu)
	local ctx = {
		preview = preview,
		pending = value.pending ~= nil,
		navigate = function(...)
			navigate(...)
		end,
		close = close,
		toast = message,
		select = function(id)
			if Config.ById[id] then
				selection = id
				render()
			end
		end,
		filter = function(newFilter)
			filter = newFilter
			render()
		end,
		request = function(...)
			request(...)
		end,
		confirm = function(action, payload, title, body)
			confirmation = {
				action = action,
				payload = payload or {},
				title = title,
				body = body,
				returnScreen = screen,
			}
			navigate("CONFIRM")
		end,
	}
	local target = menu and menuHost or hudStage
	local renderer = if screen == "LOBBY"
			or screen == "MATCH"
			or screen == "RESULTS"
		then Race
		elseif
			screen == "CARS"
			or screen == "PICKER"
			or screen == "SHOP"
			or screen == "CLAW"
		then Catalog
		else Utility
	local ok, result = pcall(renderer.render, target, screen, value, ctx)
	if ok then
		view = result
	else
		warn("Champions UI render: " .. tostring(result))
		message("This screen could not open. See Studio Output.")
		for _, child in target:GetChildren() do
			if child:IsA("Frame") and child ~= menuHost and child ~= toast then
				child:Destroy()
			end
		end
	end
	-- A fight is queued but a menu covers the lobby: keep the countdown visible on top.
	local queued = state.queue
	local covered = screen ~= "LOBBY" and screen ~= "MATCH" and screen ~= "RESULTS"
	queueBadge.Visible = queued ~= nil and covered
	if queued ~= nil then
		queueBadgeText.Text = tostring(queued.status or "FIGHT STARTING")
	end
	gui:SetAttribute("ActiveScreen", screen)
	gui:SetAttribute("Ready", state.ready)
	gui:SetAttribute("Coins", state.coins)
	gui:SetAttribute("Equipped", state.equipped)
	gui:SetAttribute("Mode", state.mode)
end
navigate = function(destination, payload)
	if type(destination) ~= "string" then
		return
	end
	destination = string.upper(destination)
	if not allowed[destination] then
		return
	end
	if payload and type(payload) == "table" and Config.ById[payload.selection] then
		selection = payload.selection
	end
	if screen ~= destination then
		previousScreen = screen
	end
	if (destination == "CARS" or destination == "SHOP") and destination ~= screen then
		filter = "ALL"
	end
	screen = destination
	render()
end
local function same(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end
acceptState = function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	local prior = state
	state = State.normalize(snapshot)
	if state.ready then
		hideLoading()
	end
	if same(prior, state) then
		return -- nothing changed: keep the screen as it is so buttons do not flicker
	end
	if
		(not prior.ready and state.ready)
		or (type(snapshot.selection) == "string" and Config.ById[snapshot.selection])
	then
		selection = state.selection or state.equipped or Config.Vehicles[1].Id
	elseif not Config.ById[selection] then
		selection = state.equipped or Config.Vehicles[1].Id
	end
	local destination = State.route(prior, state, screen, activeIntent)
	if
		state.reveal
		and (
			not prior.reveal
			or state.reveal.vehicleId ~= prior.reveal.vehicleId
			or prior.pending == "PullClaw"
		)
	then
		screen = "REVEAL"
	elseif destination then
		screen = destination
	end
	if not state.pending then
		pendingToken += 1
		activeIntent = nil
	end
	render()
end
request = function(action, payload)
	local sanitized, why = State.validateAction(state, action, payload, T.monoTime())
	if not sanitized then
		message(why)
		return
	end
	if preview then
		local nextState, note = Preview.apply(state, action, sanitized, T.monoTime())
		acceptState(nextState)
		if action == "PullClaw" then
			navigate("REVEAL")
		elseif action == "SetMode" or action == "ChooseCar" or action == "LeaveMatch" then
			navigate(matchRoute(state))
		elseif screen == "CONFIRM" then
			navigate(confirmation and confirmation.returnScreen or "SHOP")
		end
		if note then
			message(note)
		end
		return
	end
	pendingToken += 1
	local token = pendingToken
	activeIntent = {
		action = action,
		payload = sanitized,
		returnScreen = confirmation and confirmation.returnScreen or screen,
	}
	state.pending = action
	render()
	actions:Fire(action, sanitized, token)
	task.delay(12, function()
		if alive and token == pendingToken and state.pending == action then
			state.pending = nil
			activeIntent = nil
			render()
			message("No confirmation yet. Your game handles this action; try again when connected.")
		end
	end)
end
connect(stateEvent.Event, function(snapshot)
	acceptState(snapshot)
end)
connect(openEvent.Event, function(destination, payload)
	navigate(destination, payload)
end)
connect(notifyEvent.Event, function(value, ok)
	if ok == false then
		pendingToken += 1
		state.pending = nil
		activeIntent = nil
		if screen == "CONFIRM" then
			-- The purchase failed: back to where it started, the toast says why.
			screen = confirmation and confirmation.returnScreen or "SHOP"
			confirmation = nil
		end
		render()
	end
	message(value)
end)
local resizePending = false
connect(stage:GetPropertyChangedSignal("AbsoluteSize"), function()
	if resizePending then
		return
	end
	resizePending = true
	task.defer(function()
		resizePending = false
		if alive then
			render()
		end
	end)
end)
connect(gui:GetAttributeChangedSignal("PreviewViewport"), function()
	layout()
	render()
end)
connect(gui:GetAttributeChangedSignal("PreviewToolsVisible"), function()
	layout()
	render()
end)
local resetHeld = 0
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if preview and input.KeyCode == Enum.KeyCode.F6 then
		cycle()
	elseif input.KeyCode == Enum.KeyCode.G then
		navigate(screen == "CARS" and matchRoute(state) or "CARS")
	elseif input.KeyCode == Enum.KeyCode.ButtonB then
		if screen == "CONFIRM" then
			navigate(confirmation and confirmation.returnScreen or matchRoute(state))
		else
			close()
		end
	elseif screen == "MATCH" then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			request("Boost")
		elseif input.KeyCode == Enum.KeyCode.E then
			request("Ability")
		elseif input.KeyCode == Enum.KeyCode.R and state.match and state.match.stuck then
			resetHeld += 1
			local hold = resetHeld
			task.delay(0.8, function()
				if
					alive
					and hold == resetHeld
					and UserInputService:IsKeyDown(Enum.KeyCode.R)
					and screen == "MATCH"
				then
					request("ResetCar")
				end
			end)
		end
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.KeyCode == Enum.KeyCode.R then
		resetHeld += 1
	end
end)
connect(GuiService.MenuOpened, function()
	if screen ~= "MATCH" then
		close()
	end
end)
local tick = 0
connect(RunService.Heartbeat, function(dt)
	tick += dt
	if tick < 0.1 or not view then
		return
	end
	tick = 0
	local now = T.monoTime()
	for _, object in view:GetDescendants() do
		local hide = object:GetAttribute("HideAt")
		if hide and object:IsA("GuiObject") then
			object.Visible = now < hide
		end
		local daily = object:GetAttribute("DailyNextAt")
		local endsAt = object:GetAttribute("EndsAt")
		if object:IsA("TextLabel") and (daily or endsAt) then
			local seconds = math.max(0, math.ceil((daily or endsAt) - now))
			local clock = if seconds >= 3600
				then string.format(
					"%d:%02d:%02d",
					math.floor(seconds / 3600),
					math.floor(seconds / 60) % 60,
					seconds % 60
				)
				else string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
			object.Text = daily
					and (seconds == 0 and "GIFT CHECK AVAILABLE" or "NEXT GIFT IN " .. clock)
				or clock
		elseif object:IsA("TextButton") and endsAt then
			local left = math.max(0, endsAt - now)
			local duration = object:GetAttribute("Duration") or 1
			local number = object:FindFirstChild("CooldownNumber")
			if number then
				number.Text = left > 0 and tostring(math.ceil(left)) .. "s" or ""
			end
			local icon = object:FindFirstChild("Icon")
			if icon then
				icon.Visible = left == 0
			end
			local arc = object:FindFirstChild("CooldownArc")
			if arc then
				for _, segment in arc:GetChildren() do
					if segment:IsA("Frame") then
						segment.Visible = left == 0
							or (segment:GetAttribute("Segment") or 0)
								< 12 * math.clamp(left / math.max(0.01, duration), 0, 1)
					end
				end
			end
			T.disable(object, left > 0 or state.pending ~= nil or not state.ready)
		end
	end
end)
gui.Destroying:Connect(function()
	alive = false
	namespace:SetAttribute("UIReady", false)
	touchFocus(false)
	for _, connection in connections do
		connection:Disconnect()
	end
end)
render()
T.preload()
namespace:SetAttribute("UIReady", true)
if preview then
	message("UI PREVIEW • sample data only • F6 cycles match screens")
end
