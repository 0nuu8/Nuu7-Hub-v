--// SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

--// VARIABLES
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera
while not Camera do
	task.wait()
	Camera = workspace.CurrentCamera
end

if _G.Nuu7Hub and type(_G.Nuu7Hub.Destroy) == "function" then
	pcall(_G.Nuu7Hub.Destroy)
end
local previousGui = PlayerGui:FindFirstChild("Nuu7HubUI")
if previousGui then
	previousGui:Destroy()
end

local Connections = {}
local StatusTweens = {}
local AccentListeners = {}
local Controls = {}
local AvatarViews = {}
local ProfileObjects = {}
local SidebarButtons = {}
local Pages = {}
local Scrolls = {}
local ActiveNotifications = {}
local Orders = setmetatable({}, { __mode = "k" })
local UI = {}

local IsOpen = false
local Destroyed = false
local CurrentPage = nil
local PageToken = 0
local CloseToken = 0
local Compact = nil
local DragOffset = Vector2.zero
local ViewportConn = nil
local ThumbType = Enum.ThumbnailType.HeadShot
local Changed = Instance.new("BindableEvent")

local Navigate, ApplyLayout, ApplyBlur, SetAccent, CreateNotification
local Open, Close, Toggle, Destroy

--// CONFIGURATION
local Config = {
	HubName = "NUU7 HUB",
	LogoImage = "rbxassetid://92548753285325",
	ToggleKey = Enum.KeyCode.RightShift,
	DefaultAccent = "Blue",
	AccentOrder = { "Cyan", "Blue", "Violet", "Magenta", "White" },
	AccentPresets = {
		Cyan = Color3.fromRGB(90, 200, 250),
		Blue = Color3.fromRGB(10, 132, 255),
		Violet = Color3.fromRGB(191, 90, 242),
		Magenta = Color3.fromRGB(255, 64, 170),
		White = Color3.fromRGB(235, 235, 245),
	},
	Icons = {
		NuShoot = "",
		ESP = "",
		Hitbox = "",
		Settings = "",
		Avatar = "",
	},
	ShowUserId = true,
	BlurSize = 10,
	WindowSize = {
		Landscape = Vector2.new(640, 400),
		Portrait = Vector2.new(380, 600),
	},
	Pages = {
		{ Name = "NuShoot", Title = "NuShoot", Subtitle = "Shooting preferences." },
		{ Name = "ESP", Title = "ESP", Subtitle = "Visual overlay preferences." },
		{ Name = "Hitbox", Title = "Hitbox", Subtitle = "Hitbox preferences." },
		{ Name = "Settings", Title = "Settings", Subtitle = "Interface and behavior." },
		{ Name = "Avatar", Title = "Avatar", Subtitle = "Your Roblox profile." },
	},
}

local Settings = {
	NuShoot = { Enabled = false, TeamCheck = true, ShowFov = true, Fov = 120, Smoothness = 35, AimPart = "Head" },
	ESP = { Enabled = false, Boxes = true, Names = true, Distance = false, Health = true, MaxDistance = 500 },
	Hitbox = { Enabled = false, Size = 6, Transparency = 0.6, Part = "HumanoidRootPart" },
	UI = { Accent = Config.DefaultAccent, Scale = 1, Blur = true },
}

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

local Defaults = DeepCopy(Settings)

--// THEME
local Theme = {
	Background = Color3.fromRGB(8, 9, 11),
	Surface = Color3.fromRGB(17, 19, 24),
	SurfaceSecondary = Color3.fromRGB(23, 25, 31),
	Track = Color3.fromRGB(52, 55, 64),
	Text = Color3.fromRGB(245, 245, 247),
	SecondaryText = Color3.fromRGB(161, 161, 170),
	Accent = Config.AccentPresets[Config.DefaultAccent],
	Border = Color3.fromRGB(255, 255, 255),
	BorderAlpha = 0.9,
	BorderHoverAlpha = 0.78,
	Success = Color3.fromRGB(52, 199, 89),
	Danger = Color3.fromRGB(255, 69, 58),
}

local HEADER_H = 56
local SIDE_W = 176
local SIDE_C = 64
local BTN_H = 42
local BTN_GAP = 6

local MOUSE1 = Enum.UserInputType.MouseButton1
local TOUCH = Enum.UserInputType.Touch

--// UTILITY FUNCTIONS
local function Connect(signal, callback)
	local connection = signal:Connect(callback)
	Connections[#Connections + 1] = connection
	return connection
end

local function Order(parent)
	local n = (Orders[parent] or 0) + 1
	Orders[parent] = n
	return n
end

local function Create(className, props, children)
	local instance = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function Corner(parent, radius)
	local value = typeof(radius) == "UDim" and radius or UDim.new(0, radius)
	return Create("UICorner", { CornerRadius = value, Parent = parent })
end

local function Stroke(parent, transparency, thickness, color)
	return Create("UIStroke", {
		Color = color or Theme.Border,
		Transparency = transparency or Theme.BorderAlpha,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

local function Padding(parent, left, top, right, bottom)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top or left),
		PaddingRight = UDim.new(0, right or left),
		PaddingBottom = UDim.new(0, bottom or top or left),
		Parent = parent,
	})
end

local function List(parent, padding, direction, horizontal, vertical)
	return Create("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function Label(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return Create("TextLabel", p)
end

local function Readable(color)
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return luminance > 0.62 and Color3.fromRGB(10, 11, 14) or Color3.new(1, 1, 1)
end

local function FirstChar(text)
	if text == "" then
		return "?"
	end
	local nextPos = utf8.offset(text, 2)
	return string.upper(string.sub(text, 1, (nextPos or (#text + 1)) - 1))
end

local function Read(bind, default)
	if bind then
		local value = Settings[bind[1]][bind[2]]
		if value ~= nil then
			return value
		end
	end
	return default
end

local function Store(bind, value)
	if bind then
		Settings[bind[1]][bind[2]] = value
	end
end

local function Commit(bind, value)
	if bind then
		Settings[bind[1]][bind[2]] = value
		Changed:Fire(bind[1], bind[2], value)
	end
end

local function OnAccent(callback)
	AccentListeners[#AccentListeners + 1] = callback
end

local EmptySelection = Create("Frame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(0, 0),
})

--// ANIMATION SYSTEM
local Anim = {
	Fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Exit = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

function Anim.Play(instance, info, props)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function Anim.Set(instance, props, instant)
	if instant then
		for k, v in pairs(props) do
			instance[k] = v
		end
	else
		Anim.Play(instance, Anim.Normal, props)
	end
end

function Anim.Loop(instance, info, props)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	StatusTweens[#StatusTweens + 1] = tween
	return tween
end

local function Interactive(gui, onState)
	local hover, press, focus = false, false, false
	local function push()
		onState(hover, press, focus)
	end
	gui.SelectionImageObject = EmptySelection
	Connect(gui.MouseEnter, function()
		hover = true
		push()
	end)
	Connect(gui.MouseLeave, function()
		hover = false
		press = false
		push()
	end)
	Connect(gui.InputBegan, function(input)
		local t = input.UserInputType
		if t == MOUSE1 or t == TOUCH then
			press = true
			push()
		end
	end)
	Connect(gui.InputEnded, function(input)
		local t = input.UserInputType
		if press and (t == MOUSE1 or t == TOUCH) then
			press = false
			push()
		end
	end)
	Connect(gui.SelectionGained, function()
		focus = true
		push()
	end)
	Connect(gui.SelectionLost, function()
		focus = false
		push()
	end)
end

local function ScaleState(scale, hover, press)
	local target = press and 0.97 or (hover and 1.02 or 1)
	Anim.Play(scale, Anim.Fast, { Scale = target })
end

--// ICONS
local function Bar(holder, parts, x, y, w, h, color, radius)
	local frame = Create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(frame, radius or 1)
	parts[#parts + 1] = { frame, "BackgroundColor3" }
	return frame
end

local function Ring(holder, parts, x, y, w, h, radius, color, thickness)
	local frame = Create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Corner(frame, radius)
	local stroke = Stroke(frame, 0, thickness or 1.6, color)
	parts[#parts + 1] = { stroke, "Color" }
	return frame
end

local Glyphs = {
	NuShoot = function(holder, parts, color)
		Ring(holder, parts, 4, 4, 12, 12, 6, color)
		Bar(holder, parts, 9.2, 0, 1.6, 4, color)
		Bar(holder, parts, 9.2, 16, 1.6, 4, color)
		Bar(holder, parts, 0, 9.2, 4, 1.6, color)
		Bar(holder, parts, 16, 9.2, 4, 1.6, color)
	end,
	ESP = function(holder, parts, color)
		Ring(holder, parts, 3, 3, 14, 14, 4, color)
		Bar(holder, parts, 8.5, 8.5, 3, 3, color, 2)
	end,
	Hitbox = function(holder, parts, color)
		Ring(holder, parts, 2, 6, 11, 11, 3, color)
		Ring(holder, parts, 7, 3, 11, 11, 3, color)
	end,
	Settings = function(holder, parts, color)
		Bar(holder, parts, 1, 4, 18, 1.6, color)
		Bar(holder, parts, 1, 9.2, 18, 1.6, color)
		Bar(holder, parts, 1, 14.4, 18, 1.6, color)
		Bar(holder, parts, 12, 2.6, 4.4, 4.4, color, 3)
		Bar(holder, parts, 4, 7.8, 4.4, 4.4, color, 3)
		Bar(holder, parts, 13, 13, 4.4, 4.4, color, 3)
	end,
	Avatar = function(holder, parts, color)
		Ring(holder, parts, 6, 1, 8, 8, 4, color)
		Ring(holder, parts, 2, 11, 16, 8, 5, color)
	end,
}

local function CreateIcon(parent, key, size, color)
	local holder = Create("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local parts = {}
	local custom = Config.Icons[key]
	if custom and custom ~= "" then
		local image = Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = custom,
			ImageColor3 = color,
			Parent = holder,
		})
		parts[1] = { image, "ImageColor3" }
	elseif Glyphs[key] then
		Glyphs[key](holder, parts, color)
	end
	return {
		Frame = holder,
		SetColor = function(newColor, instant)
			for _, part in ipairs(parts) do
				if instant then
					part[1][part[2]] = newColor
				else
					Anim.Play(part[1], Anim.Fast, { [part[2]] = newColor })
				end
			end
		end,
	}
end

--// UI CREATION
local function CreatePage(cfg)
	local group = Create("CanvasGroup", {
		Name = cfg.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = cfg.Parent,
	})
	local scroll = Create("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.SecondaryText,
		ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = group,
	})
	Padding(scroll, 18, 16, 18, 20)
	List(scroll, 12)
	Label({
		Text = cfg.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = Order(scroll),
		Parent = scroll,
	})
	Label({
		Text = cfg.Subtitle or "",
		TextSize = 12,
		TextColor3 = Theme.SecondaryText,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = Order(scroll),
		Parent = scroll,
	})
	Pages[cfg.Name] = group
	Scrolls[cfg.Name] = scroll
	return scroll
end

local function CreateCard(cfg)
	local card = Create("Frame", {
		Name = cfg.Title or "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
	Corner(card, 14)
	local stroke = Stroke(card)
	Padding(card, 14, 12, 14, 12)
	List(card, 4)
	if cfg.Title then
		Label({
			Text = cfg.Title,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = Order(card),
			Parent = card,
		})
	end
	Interactive(card, function(hover)
		Anim.Play(stroke, Anim.Fast, { Transparency = hover and Theme.BorderHoverAlpha or Theme.BorderAlpha })
	end)
	return card
end

local function CreateSection(cfg)
	return Label({
		Text = cfg.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Theme.SecondaryText,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
end

local function CreateInfoRow(cfg)
	local row = Create("Frame", {
		Name = cfg.Label,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
	Label({
		Text = cfg.Label,
		TextColor3 = Theme.SecondaryText,
		Size = UDim2.new(0.5, 0, 1, 0),
		Parent = row,
	})
	local value = Label({
		Text = cfg.Value,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		Parent = row,
	})
	return value
end

local function CreateButton(cfg)
	local style = cfg.Style or "Secondary"
	local primary = style == "Primary"
	local button = Create("TextButton", {
		Name = cfg.Text or "Button",
		Size = cfg.Size or UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = primary and Theme.Accent or Theme.SurfaceSecondary,
		BackgroundTransparency = primary and 0 or 0.1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
	Corner(button, 10)
	local stroke = Stroke(button, primary and 1 or Theme.BorderAlpha)
	local scale = Create("UIScale", { Parent = button })
	local textColor = primary and Readable(Theme.Accent) or (style == "Danger" and Theme.Danger or Theme.Text)
	local label = Label({
		Text = cfg.Text or "",
		Font = Enum.Font.GothamMedium,
		TextColor3 = textColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	})
	if cfg.Icon and cfg.Icon ~= "" then
		Create("ImageLabel", {
			Size = UDim2.fromOffset(16, 16),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			BackgroundTransparency = 1,
			Image = cfg.Icon,
			ImageColor3 = textColor,
			Parent = button,
		})
	end

	local disabled = false
	Interactive(button, function(hover, press, focus)
		local hot = (hover or focus) and not disabled
		ScaleState(scale, hot, press and not disabled)
		if primary then
			local color = hot and Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.12) or Theme.Accent
			Anim.Play(button, Anim.Fast, { BackgroundColor3 = color })
		else
			Anim.Play(button, Anim.Fast, { BackgroundTransparency = hot and 0 or 0.1 })
			Anim.Play(stroke, Anim.Fast, { Transparency = hot and Theme.BorderHoverAlpha or Theme.BorderAlpha })
		end
	end)

	if primary then
		OnAccent(function(color)
			button.BackgroundColor3 = color
			label.TextColor3 = Readable(color)
		end)
	end
	if cfg.Callback then
		Connect(button.Activated, function()
			if not disabled then
				cfg.Callback()
			end
		end)
	end

	local obj = { Instance = button }
	function obj.SetDisabled(value)
		disabled = value
		button.Interactable = not value
		Anim.Play(label, Anim.Fast, { TextTransparency = value and 0.6 or 0 })
	end
	function obj.SetText(text)
		label.Text = text
	end
	if cfg.Disabled then
		obj.SetDisabled(true)
	end
	return obj
end

local function CreateToggle(cfg)
	local state = Read(cfg.Bind, cfg.Default or false)
	local hasDescription = cfg.Description ~= nil
	local row = Create("TextButton", {
		Name = cfg.Text,
		Size = UDim2.new(1, 0, 0, hasDescription and 46 or 36),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
	local title = Label({
		Text = cfg.Text,
		Position = UDim2.fromOffset(0, hasDescription and 5 or 0),
		Size = UDim2.new(1, -56, 0, hasDescription and 18 or 36),
		Parent = row,
	})
	if hasDescription then
		Label({
			Text = cfg.Description,
			TextSize = 11,
			TextColor3 = Theme.SecondaryText,
			Position = UDim2.fromOffset(0, 23),
			Size = UDim2.new(1, -56, 0, 16),
			Parent = row,
		})
	end
	local track = Create("Frame", {
		Size = UDim2.fromOffset(40, 22),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = state and Theme.Accent or Theme.Track,
		BorderSizePixel = 0,
		Parent = row,
	})
	Corner(track, 11)
	local trackStroke = Stroke(track, 0.85)
	local knob = Create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, state and 21 or 3, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(knob, 8)
	local knobScale = Create("UIScale", { Parent = knob })

	local obj = {}
	local function render(animate)
		local goal = {
			Position = UDim2.new(0, state and 21 or 3, 0.5, 0),
		}
		local trackGoal = { BackgroundColor3 = state and Theme.Accent or Theme.Track }
		if animate then
			Anim.Play(knob, Anim.Normal, goal)
			Anim.Play(track, Anim.Normal, trackGoal)
		else
			knob.Position = goal.Position
			track.BackgroundColor3 = trackGoal.BackgroundColor3
		end
	end

	function obj.Set(value, silent)
		state = value and true or false
		render(true)
		if not silent then
			Commit(cfg.Bind, state)
			if cfg.Callback then
				cfg.Callback(state)
			end
		else
			Store(cfg.Bind, state)
		end
	end
	function obj.Get()
		return state
	end
	function obj.SetDisabled(value)
		row.Interactable = not value
		Anim.Play(row, Anim.Fast, { BackgroundTransparency = 1 })
		Anim.Play(title, Anim.Fast, { TextTransparency = value and 0.6 or 0 })
		Anim.Play(track, Anim.Fast, { BackgroundTransparency = value and 0.5 or 0 })
	end

	Interactive(row, function(hover, press, focus)
		local hot = hover or focus
		Anim.Play(knobScale, Anim.Fast, { Scale = press and 0.9 or (hot and 1.1 or 1) })
		Anim.Play(trackStroke, Anim.Fast, { Transparency = hot and 0.7 or 0.85 })
		Anim.Play(title, Anim.Fast, { TextColor3 = hot and Color3.new(1, 1, 1) or Theme.Text })
	end)
	Connect(row.Activated, function()
		obj.Set(not state)
	end)
	OnAccent(function(color)
		if state then
			track.BackgroundColor3 = color
		end
	end)
	if cfg.Bind then
		Controls[#Controls + 1] = { Bind = cfg.Bind, Set = function(value)
			obj.Set(value)
		end }
	end
	if cfg.Disabled then
		obj.SetDisabled(true)
	end
	return obj
end

local function CreateSlider(cfg)
	local min = cfg.Min or 0
	local max = cfg.Max or 100
	local step = cfg.Step or 1
	local suffix = cfg.Suffix or ""
	local value = Read(cfg.Bind, cfg.Default or min)

	local function snap(v)
		v = math.clamp(v, min, max)
		v = min + math.floor((v - min) / step + 0.5) * step
		return tonumber(string.format("%.4f", math.clamp(v, min, max)))
	end
	value = snap(value)

	local row = Create("Frame", {
		Name = cfg.Text,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
	Label({
		Text = cfg.Text,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, -80, 0, 18),
		Parent = row,
	})
	local valueLabel = Label({
		TextColor3 = Theme.SecondaryText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -80, 0, 4),
		Size = UDim2.new(0, 80, 0, 18),
		Parent = row,
	})
	local track = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.fromOffset(0, 34),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Parent = row,
	})
	Corner(track, 3)
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(fill, 3)
	local knob = Create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	Corner(knob, 8)
	Stroke(knob, 0.7)
	local knobScale = Create("UIScale", { Parent = knob })
	local hit = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = row,
	})

	local function render(animate)
		local alpha = max == min and 0 or (value - min) / (max - min)
		valueLabel.Text = string.format("%g", value) .. suffix
		if animate then
			Anim.Play(fill, Anim.Fast, { Size = UDim2.fromScale(alpha, 1) })
			Anim.Play(knob, Anim.Fast, { Position = UDim2.fromScale(alpha, 0.5) })
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		end
	end
	render(false)

	local obj = {}
	function obj.Set(newValue, silent)
		value = snap(newValue)
		render(true)
		if silent then
			Store(cfg.Bind, value)
		else
			Commit(cfg.Bind, value)
			if cfg.Callback then
				cfg.Callback(value)
			end
		end
	end
	function obj.Get()
		return value
	end

	local scroller = cfg.Parent:FindFirstAncestorWhichIsA("ScrollingFrame")
	local function lockScroll(locked)
		if scroller then
			scroller.ScrollingEnabled = not locked
		end
	end
	local function updateFrom(positionX)
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = math.clamp((positionX - track.AbsolutePosition.X) / width, 0, 1)
		local newValue = snap(min + alpha * (max - min))
		if newValue ~= value then
			value = newValue
			Store(cfg.Bind, value)
			render(false)
		end
	end

	Interactive(hit, function(hover, press, focus)
		Anim.Play(knobScale, Anim.Fast, { Scale = press and 1.25 or ((hover or focus) and 1.1 or 1) })
	end)
	Connect(hit.InputBegan, function(input)
		local inputType = input.UserInputType
		if inputType ~= MOUSE1 and inputType ~= TOUCH then
			return
		end
		lockScroll(true)
		updateFrom(input.Position.X)
		local moveConn, endConn
		local function finish()
			if moveConn then
				moveConn:Disconnect()
			end
			if endConn then
				endConn:Disconnect()
			end
			lockScroll(false)
			Commit(cfg.Bind, value)
			if cfg.Callback then
				cfg.Callback(value)
			end
		end
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed == input or (inputType == MOUSE1 and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				updateFrom(changed.Position.X)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(ended)
			if ended == input or (inputType == MOUSE1 and ended.UserInputType == MOUSE1) then
				finish()
			end
		end)
	end)
	OnAccent(function(color)
		fill.BackgroundColor3 = color
	end)
	if cfg.Bind then
		Controls[#Controls + 1] = { Bind = cfg.Bind, Set = function(v)
			obj.Set(v)
		end }
	end
	return obj
end

local function CreateDropdown(cfg)
	local options = cfg.Options
	local value = Read(cfg.Bind, cfg.Default or options[1])
	local expanded = false
	local listHeight = #options * 32 + 8

	local container = Create("Frame", {
		Name = cfg.Text,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.SurfaceSecondary,
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		LayoutOrder = Order(cfg.Parent),
		Parent = cfg.Parent,
	})
	Corner(container, 10)
	local stroke = Stroke(container)
	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = container,
	})
	Label({
		Text = cfg.Text,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.5, -12, 1, 0),
		Parent = header,
	})
	local valueLabel = Label({
		Text = tostring(value),
		TextColor3 = Theme.SecondaryText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, -34, 1, 0),
		Parent = header,
	})
	local chevron = Label({
		Text = ">",
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.SecondaryText,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 90,
		Parent = header,
	})
	local list = Create("Frame", {
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, listHeight),
		BackgroundTransparency = 1,
		Parent = container,
	})
	Padding(list, 4)
	List(list, 0)

	local optionButtons = {}
	local function refresh()
		for name, button in pairs(optionButtons) do
			button.TextColor3 = name == value and Theme.Accent or Theme.SecondaryText
		end
	end
	local function setExpanded(state)
		expanded = state
		Anim.Play(container, Anim.Normal, { Size = UDim2.new(1, 0, 0, state and (38 + listHeight) or 38) })
		Anim.Play(chevron, Anim.Fast, { Rotation = state and -90 or 90 })
	end

	local obj = {}
	function obj.Set(newValue, silent)
		value = newValue
		valueLabel.Text = tostring(value)
		refresh()
		if silent then
			Store(cfg.Bind, value)
		else
			Commit(cfg.Bind, value)
			if cfg.Callback then
				cfg.Callback(value)
			end
		end
	end
	function obj.Get()
		return value
	end
	function obj.Close()
		setExpanded(false)
	end

	for index, option in ipairs(options) do
		local button = Create("TextButton", {
			Name = tostring(option),
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = Enum.Font.Gotham,
			Text = tostring(option),
			TextSize = 13,
			TextColor3 = Theme.SecondaryText,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
			Parent = list,
		})
		Corner(button, 8)
		Padding(button, 10, 0, 10, 0)
		optionButtons[option] = button
		Interactive(button, function(hover, press, focus)
			Anim.Play(button, Anim.Fast, { BackgroundTransparency = (hover or focus or press) and 0.3 or 1 })
		end)
		Connect(button.Activated, function()
			obj.Set(option)
			setExpanded(false)
		end)
	end
	refresh()

	Interactive(header, function(hover, _, focus)
		local hot = hover or focus
		Anim.Play(stroke, Anim.Fast, { Transparency = hot and Theme.BorderHoverAlpha or Theme.BorderAlpha })
		Anim.Play(valueLabel, Anim.Fast, { TextColor3 = hot and Theme.Text or Theme.SecondaryText })
	end)
	Connect(header.Activated, function()
		setExpanded(not expanded)
	end)
	OnAccent(refresh)
	if cfg.Bind then
		Controls[#Controls + 1] = { Bind = cfg.Bind, Set = function(v)
			obj.Set(v)
		end }
	end
	return obj
end

--// PLAYER PROFILE
local function CreateAvatarImage(parent, size, thumbSize)
	local holder = Create("Frame", {
		Name = "Avatar",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.SurfaceSecondary,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Corner(holder, UDim.new(1, 0))
	Stroke(holder, 0.8)
	local scale = Create("UIScale", { Parent = holder })
	local letter = Label({
		Text = FirstChar(LocalPlayer.DisplayName),
		Font = Enum.Font.GothamBold,
		TextSize = math.floor(size * 0.42),
		TextColor3 = Theme.SecondaryText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	local image = Create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Parent = holder,
	})
	Corner(image, UDim.new(1, 0))
	local view = {
		Holder = holder,
		Image = image,
		Letter = letter,
		Scale = scale,
		ThumbSize = thumbSize,
		Token = 0,
		LoadTween = nil,
	}
	AvatarViews[#AvatarViews + 1] = view
	return view
end

local function LoadAvatar(view)
	view.Token += 1
	local token = view.Token
	if view.LoadTween then
		view.LoadTween:Cancel()
	end
	view.Letter.TextTransparency = 0
	view.Image.ImageTransparency = 1
	view.LoadTween = TweenService:Create(
		view.Holder,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundColor3 = Theme.Track }
	)
	view.LoadTween:Play()

	task.spawn(function()
		local content
		for _ = 1, 5 do
			local ok, result, ready = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				LocalPlayer.UserId,
				ThumbType,
				view.ThumbSize
			)
			if ok then
				content = result
				if ready then
					break
				end
			end
			task.wait(1)
			if Destroyed or view.Token ~= token then
				return
			end
		end
		if Destroyed or view.Token ~= token then
			return
		end
		if view.LoadTween then
			view.LoadTween:Cancel()
			view.LoadTween = nil
		end
		view.Holder.BackgroundColor3 = Theme.SurfaceSecondary
		if content and content ~= "" then
			view.Image.Image = content
			local waited = 0
			while not view.Image.IsLoaded and waited < 3 do
				task.wait(0.1)
				waited += 0.1
			end
			if Destroyed or view.Token ~= token then
				return
			end
			view.Scale.Scale = 0.8
			Anim.Play(view.Scale, Anim.Pop, { Scale = 1 })
			Anim.Play(view.Image, Anim.Normal, { ImageTransparency = 0 })
			Anim.Play(view.Letter, Anim.Normal, { TextTransparency = 1 })
		end
	end)
end

local function RefreshAvatars()
	for _, view in ipairs(AvatarViews) do
		LoadAvatar(view)
	end
end

local function CreatePlayerProfile(cfg)
	local style = cfg.Style or "Compact"
	local obj = {}

	if style == "Compact" then
		local group = Create("CanvasGroup", {
			Name = "PlayerProfile",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.SurfaceSecondary,
			BackgroundTransparency = 0.35,
			GroupTransparency = 1,
			Parent = cfg.Parent,
		})
		Corner(group, 12)
		Stroke(group)
		local body = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 6),
			BackgroundTransparency = 1,
			Parent = group,
		})
		local avatar = CreateAvatarImage(body, 36, Enum.ThumbnailSize.Size150x150)
		avatar.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
		avatar.Holder.Position = UDim2.new(0, 26, 0.5, 0)
		local name = Label({
			Text = LocalPlayer.DisplayName,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 52, 0, 9),
			Size = UDim2.new(1, -58, 0, 16),
			Parent = body,
		})
		local user = Label({
			Text = "@" .. LocalPlayer.Name,
			TextSize = 11,
			TextColor3 = Theme.SecondaryText,
			Position = UDim2.new(0, 52, 0, 26),
			Size = UDim2.new(1, -58, 0, 14),
			Parent = body,
		})
		function obj.SetCompact(isCompact, instant)
			Anim.Set(avatar.Holder, {
				Position = isCompact and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 26, 0.5, 0),
			}, instant)
			name.Visible = not isCompact
			user.Visible = not isCompact
		end
		function obj.Enter()
			Anim.Play(group, Anim.Slow, { GroupTransparency = 0 })
			Anim.Play(body, Anim.Slow, { Position = UDim2.new() })
		end
		function obj.UpdateNames()
			name.Text = LocalPlayer.DisplayName
			user.Text = "@" .. LocalPlayer.Name
			avatar.Letter.Text = FirstChar(LocalPlayer.DisplayName)
		end
		LoadAvatar(avatar)
		obj.Frame = group
	else
		local rows = {}
		if Config.ShowUserId then
			rows[#rows + 1] = { "User ID", tostring(LocalPlayer.UserId) }
		end
		rows[#rows + 1] = { "Account age", tostring(LocalPlayer.AccountAge) .. " days" }
		local group = Create("CanvasGroup", {
			Name = "PlayerProfileCard",
			Size = UDim2.new(1, 0, 0, 181 + 32 * #rows),
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 0.2,
			GroupTransparency = 1,
			LayoutOrder = Order(cfg.Parent),
			Parent = cfg.Parent,
		})
		Corner(group, 14)
		Stroke(group)
		local body = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 8),
			BackgroundTransparency = 1,
			Parent = group,
		})
		Padding(body, 16, 16, 16, 14)
		List(body, 6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
		local avatar = CreateAvatarImage(body, 88, Enum.ThumbnailSize.Size420x420)
		avatar.Holder.LayoutOrder = 1
		local name = Label({
			Text = LocalPlayer.DisplayName,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 2,
			Parent = body,
		})
		local user = Label({
			Text = "@" .. LocalPlayer.Name,
			TextSize = 12,
			TextColor3 = Theme.SecondaryText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 3,
			Parent = body,
		})
		Create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Border,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			LayoutOrder = 4,
			Parent = body,
		})
		for index, data in ipairs(rows) do
			local row = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				LayoutOrder = 4 + index,
				Parent = body,
			})
			Label({
				Text = data[1],
				TextColor3 = Theme.SecondaryText,
				Size = UDim2.new(0.5, 0, 1, 0),
				Parent = row,
			})
			Label({
				Text = data[2],
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
				Parent = row,
			})
		end
		function obj.SetCompact() end
		function obj.Enter()
			Anim.Play(group, Anim.Slow, { GroupTransparency = 0 })
			Anim.Play(body, Anim.Slow, { Position = UDim2.new() })
		end
		function obj.UpdateNames()
			name.Text = LocalPlayer.DisplayName
			user.Text = "@" .. LocalPlayer.Name
			avatar.Letter.Text = FirstChar(LocalPlayer.DisplayName)
		end
		LoadAvatar(avatar)
		obj.Frame = group
	end

	ProfileObjects[#ProfileObjects + 1] = obj
	return obj
end

--// SIDEBAR
local function CreateSidebarButton(cfg)
	local button = Create("TextButton", {
		Name = cfg.Name,
		Size = UDim2.new(1, 0, 0, BTN_H),
		BackgroundColor3 = Theme.SurfaceSecondary,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = cfg.Order,
		Parent = cfg.Parent,
	})
	Corner(button, 10)
	local stroke = Stroke(button, 1)
	local scale = Create("UIScale", { Parent = button })
	local glyph = CreateIcon(button, cfg.Name, 20, Theme.SecondaryText)
	glyph.Frame.Position = UDim2.new(0, 26, 0.5, 0)
	local label = Label({
		Text = cfg.Text,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Theme.SecondaryText,
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -58, 1, 0),
		Parent = button,
	})

	local selected = false
	local isCompact = false
	local state = { hover = false, press = false, focus = false }

	local function iconPosition(hot)
		if isCompact then
			return UDim2.new(0.5, 0, 0.5, 0)
		end
		return UDim2.new(0, hot and 28 or 26, 0.5, 0)
	end

	local function render()
		local hot = state.hover or state.focus
		local highlighted = hot and not selected
		Anim.Play(label, Anim.Fast, { TextColor3 = (selected or hot) and Theme.Text or Theme.SecondaryText })
		glyph.SetColor(selected and Theme.Accent or (hot and Theme.Text or Theme.SecondaryText))
		Anim.Play(button, Anim.Fast, { BackgroundTransparency = highlighted and 0.88 or 1 })
		Anim.Play(stroke, Anim.Fast, { Transparency = highlighted and 0.9 or 1 })
		Anim.Play(glyph.Frame, Anim.Fast, { Position = iconPosition(hot and not state.press) })
		ScaleState(scale, hot, state.press)
	end

	Interactive(button, function(hover, press, focus)
		state.hover, state.press, state.focus = hover, press, focus
		render()
	end)
	Connect(button.Activated, function()
		cfg.Callback()
	end)
	OnAccent(function(color)
		if selected then
			glyph.SetColor(color)
		end
	end)

	local obj = { Button = button }
	function obj.SetSelected(value)
		selected = value
		render()
	end
	function obj.SetCompact(value, instant)
		isCompact = value
		label.Visible = not value
		Anim.Set(glyph.Frame, { Position = iconPosition(false) }, instant)
	end
	return obj
end

local function CreateSidebar(parent)
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDE_W, 1, 0),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Border,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	local nav = Create("Frame", {
		Name = "Nav",
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		Parent = sidebar,
	})
	Padding(nav, 10, 12, 10, 0)

	local pill = Create("Frame", {
		Name = "Selection",
		Size = UDim2.new(1, 0, 0, BTN_H),
		BackgroundColor3 = Theme.SurfaceSecondary,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Parent = nav,
	})
	Corner(pill, 10)
	Stroke(pill, 0.88)
	local accentBar = Create("Frame", {
		Size = UDim2.fromOffset(3, 18),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = pill,
	})
	Corner(accentBar, 2)
	OnAccent(function(color)
		accentBar.BackgroundColor3 = color
	end)

	local navList = Create("Frame", {
		Name = "NavList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = nav,
	})
	List(navList, BTN_GAP)

	for index, page in ipairs(Config.Pages) do
		SidebarButtons[page.Name] = CreateSidebarButton({
			Parent = navList,
			Name = page.Name,
			Text = page.Name,
			Order = index,
			Callback = function()
				Navigate(page.Name)
			end,
		})
	end

	local profileHolder = Create("Frame", {
		Name = "ProfileHolder",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 52),
		BackgroundTransparency = 1,
		Parent = sidebar,
	})

	UI.Sidebar = sidebar
	UI.Pill = pill
	UI.Profile = CreatePlayerProfile({ Parent = profileHolder, Style = "Compact" })
	return sidebar
end

--// HEADER
local function EnableDrag(handle)
	Connect(handle.InputBegan, function(input)
		local inputType = input.UserInputType
		if inputType ~= MOUSE1 and inputType ~= TOUCH then
			return
		end
		local startPoint = Vector2.new(input.Position.X, input.Position.Y)
		local startOffset = DragOffset
		local moveConn, endConn
		local function stop()
			if moveConn then
				moveConn:Disconnect()
			end
			if endConn then
				endConn:Disconnect()
			end
		end
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed == input or (inputType == MOUSE1 and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				local delta = Vector2.new(changed.Position.X, changed.Position.Y) - startPoint
				local viewport = Camera.ViewportSize
				local size = UI.PixelSize
				local maxX = math.max((viewport.X - size.X) / 2, 0)
				local maxY = math.max((viewport.Y - size.Y) / 2, 0)
				local target = startOffset + delta
				DragOffset = Vector2.new(math.clamp(target.X, -maxX, maxX), math.clamp(target.Y, -maxY, maxY))
				UI.Root.Position = UDim2.new(0.5, DragOffset.X, 0.5, DragOffset.Y)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(ended)
			if ended == input or (inputType == MOUSE1 and ended.UserInputType == MOUSE1) then
				stop()
			end
		end)
	end)
end

local function CreateHeader(parent)
	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_H),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Padding(header, 16, 0, 12, 0)

	local left = Create("Frame", {
		Name = "Brand",
		Size = UDim2.new(0.6, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	})
	List(left, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local logo = Create("ImageLabel", {
		Name = "Logo",
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.SurfaceSecondary,
		BorderSizePixel = 0,
		Image = Config.LogoImage,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		Parent = left,
	})
	Corner(logo, 8)
	Stroke(logo, 0.85)
	Label({
		Name = "HubName",
		Text = Config.HubName,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = left,
	})

	local right = Create("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	})
	List(right, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	local pill = Create("Frame", {
		Name = "Status",
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.SurfaceSecondary,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = right,
	})
	Corner(pill, 12)
	Stroke(pill, 0.88)
	Padding(pill, 10, 0, 10, 0)
	List(pill, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local dotHolder = Create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = pill,
	})
	local ring = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Success,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = dotHolder,
	})
	Corner(ring, UDim.new(1, 0))
	local dot = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Success,
		BorderSizePixel = 0,
		Parent = dotHolder,
	})
	Corner(dot, UDim.new(1, 0))
	Anim.Loop(ring, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, 0.2), {
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
	})
	Label({
		Text = "ONLINE",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Theme.SecondaryText,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = pill,
	})

	local close = Create("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.SurfaceSecondary,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "×",
		TextSize = 20,
		TextColor3 = Theme.SecondaryText,
		LayoutOrder = 2,
		Parent = right,
	})
	Corner(close, UDim.new(1, 0))
	local closeScale = Create("UIScale", { Parent = close })
	Interactive(close, function(hover, press, focus)
		local hot = hover or focus
		ScaleState(closeScale, hot, press)
		Anim.Play(close, Anim.Fast, { BackgroundTransparency = hot and 0.2 or 1, TextColor3 = hot and Theme.Text or Theme.SecondaryText })
	end)
	Connect(close.Activated, function()
		Close()
	end)

	EnableDrag(header)
	UI.Header = header
	return header
end

--// WINDOW
local function CreateWindow()
	local gui = Create("ScreenGui", {
		Name = "Nuu7HubUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
	})
	gui.Parent = PlayerGui

	local root = Create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 400),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	local rootScale = Create("UIScale", { Parent = root })
	local aspect = Create("UIAspectRatioConstraint", {
		AspectRatio = 1.6,
		DominantAxis = Enum.DominantAxis.Width,
		Parent = root,
	})

	local shadows = {}
	local shadowBase = { 0.82, 0.9, 0.95 }
	for i = 1, 3 do
		local frame = Create("Frame", {
			Name = "Shadow" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 6),
			Size = UDim2.new(1, i * 16, 1, i * 16),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = shadowBase[i],
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = root,
		})
		Corner(frame, 18 + i * 8)
		shadows[i] = { Frame = frame, Base = shadowBase[i] }
	end

	local window = Create("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.04,
		GroupTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	Corner(window, 18)
	Stroke(window, 0.88)
	local windowScale = Create("UIScale", { Parent = window })

	UI.Gui = gui
	UI.Root = root
	UI.RootScale = rootScale
	UI.Aspect = aspect
	UI.Shadows = shadows
	UI.Window = window
	UI.WindowScale = windowScale
	UI.PixelSize = Vector2.new(640, 400)

	CreateHeader(window)
	Create("Frame", {
		Name = "HeaderDivider",
		Position = UDim2.fromOffset(0, HEADER_H - 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Border,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = window,
	})

	local body = Create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H),
		BackgroundTransparency = 1,
		Parent = window,
	})
	UI.Body = body
	CreateSidebar(body)

	UI.Content = Create("Frame", {
		Name = "Content",
		Position = UDim2.new(0, SIDE_W, 0, 0),
		Size = UDim2.new(1, -SIDE_W, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})
	return window
end

local function CreateLauncher()
	local launcher = Create("TextButton", {
		Name = "Launcher",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = UI.Gui,
	})
	Corner(launcher, UDim.new(1, 0))
	local stroke = Stroke(launcher, 0.8)
	local scale = Create("UIScale", { Parent = launcher })
	Padding(launcher, 9)
	local logo = Create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Config.LogoImage,
		ScaleType = Enum.ScaleType.Fit,
		Parent = launcher,
	})
	Corner(logo, UDim.new(1, 0))
	Interactive(launcher, function(hover, press, focus)
		local hot = hover or focus
		ScaleState(scale, hot, press)
		Anim.Play(stroke, Anim.Fast, { Transparency = hot and 0.6 or 0.8 })
	end)
	Connect(launcher.Activated, function()
		Open()
	end)
	UI.Launcher = launcher
end

local function CreateNotificationHolder()
	local holder = Create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.new(0, 280, 1, -28),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = UI.Gui,
	})
	List(holder, 8)
	UI.Notifications = holder
end

CreateNotification = function(cfg)
	if Destroyed or not UI.Notifications then
		return
	end
	local kinds = {
		Info = Theme.Accent,
		Success = Theme.Success,
		Danger = Theme.Danger,
	}
	local holder = UI.Notifications
	local wrapper = Create("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		LayoutOrder = Order(holder),
		Parent = holder,
	})
	local card = Create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(0, 40, 0, 0),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.05,
		GroupTransparency = 1,
		Parent = wrapper,
	})
	Corner(card, 14)
	Stroke(card, 0.85)
	local bar = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(3, 26),
		BackgroundColor3 = kinds[cfg.Type or "Info"] or Theme.Accent,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(bar, 2)
	Label({
		Text = cfg.Title or "",
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(26, 11),
		Size = UDim2.new(1, -40, 0, 18),
		Parent = card,
	})
	Label({
		Text = cfg.Text or "",
		TextSize = 12,
		TextColor3 = Theme.SecondaryText,
		Position = UDim2.fromOffset(26, 31),
		Size = UDim2.new(1, -40, 0, 18),
		Parent = card,
	})
	local button = Create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = card,
	})

	local entry = { Wrapper = wrapper, Dismissed = false }
	local function dismiss()
		if entry.Dismissed or Destroyed then
			return
		end
		entry.Dismissed = true
		Anim.Play(card, Anim.Exit, { GroupTransparency = 1, Position = UDim2.new(0, 40, 0, 0) })
		task.delay(0.2, function()
			wrapper:Destroy()
		end)
		for index, item in ipairs(ActiveNotifications) do
			if item == entry then
				table.remove(ActiveNotifications, index)
				break
			end
		end
	end
	Connect(button.Activated, dismiss)

	ActiveNotifications[#ActiveNotifications + 1] = entry
	if #ActiveNotifications > 4 then
		local oldest = ActiveNotifications[1]
		if oldest.Dismiss then
			oldest.Dismiss()
		end
	end
	entry.Dismiss = dismiss

	Anim.Play(card, Anim.Normal, { GroupTransparency = 0, Position = UDim2.new() })
	task.delay(cfg.Duration or 3.5, dismiss)
end

--// PAGES
local function BuildPages()
	local function newPage(name)
		local info
		for _, page in ipairs(Config.Pages) do
			if page.Name == name then
				info = page
			end
		end
		return CreatePage({ Parent = UI.Content, Name = name, Title = info.Title, Subtitle = info.Subtitle })
	end

	-- NuShoot
	local nushoot = newPage("NuShoot")
	local shooting = CreateCard({ Parent = nushoot, Title = "Shooting" })
	CreateToggle({ Parent = shooting, Text = "Enabled", Bind = { "NuShoot", "Enabled" } })
	CreateToggle({
		Parent = shooting,
		Text = "Team check",
		Description = "Ignore players on your team.",
		Bind = { "NuShoot", "TeamCheck" },
	})
	CreateToggle({ Parent = shooting, Text = "Show FOV circle", Bind = { "NuShoot", "ShowFov" } })
	local tuning = CreateCard({ Parent = nushoot, Title = "Tuning" })
	CreateSlider({
		Parent = tuning,
		Text = "Field of view",
		Min = 30,
		Max = 300,
		Step = 5,
		Suffix = "°",
		Bind = { "NuShoot", "Fov" },
	})
	CreateSlider({
		Parent = tuning,
		Text = "Smoothness",
		Min = 0,
		Max = 100,
		Step = 1,
		Suffix = "%",
		Bind = { "NuShoot", "Smoothness" },
	})
	CreateDropdown({
		Parent = tuning,
		Text = "Target part",
		Options = { "Head", "Torso", "Nearest" },
		Bind = { "NuShoot", "AimPart" },
	})

	-- ESP
	local esp = newPage("ESP")
	local display = CreateCard({ Parent = esp, Title = "Display" })
	CreateToggle({ Parent = display, Text = "Enabled", Bind = { "ESP", "Enabled" } })
	CreateToggle({ Parent = display, Text = "Boxes", Bind = { "ESP", "Boxes" } })
	CreateToggle({ Parent = display, Text = "Names", Bind = { "ESP", "Names" } })
	CreateToggle({ Parent = display, Text = "Distance", Bind = { "ESP", "Distance" } })
	CreateToggle({ Parent = display, Text = "Health", Bind = { "ESP", "Health" } })
	local range = CreateCard({ Parent = esp, Title = "Range" })
	CreateSlider({
		Parent = range,
		Text = "Max distance",
		Min = 50,
		Max = 2000,
		Step = 50,
		Suffix = " studs",
		Bind = { "ESP", "MaxDistance" },
	})

	-- Hitbox
	local hitbox = newPage("Hitbox")
	local hitboxCard = CreateCard({ Parent = hitbox, Title = "Hitbox" })
	CreateToggle({ Parent = hitboxCard, Text = "Enabled", Bind = { "Hitbox", "Enabled" } })
	CreateSlider({
		Parent = hitboxCard,
		Text = "Size",
		Min = 2,
		Max = 25,
		Step = 1,
		Bind = { "Hitbox", "Size" },
	})
	CreateSlider({
		Parent = hitboxCard,
		Text = "Transparency",
		Min = 0,
		Max = 1,
		Step = 0.05,
		Bind = { "Hitbox", "Transparency" },
	})
	CreateDropdown({
		Parent = hitboxCard,
		Text = "Part",
		Options = { "Head", "HumanoidRootPart" },
		Bind = { "Hitbox", "Part" },
	})

	-- Settings
	local settings = newPage("Settings")
	local appearance = CreateCard({ Parent = settings, Title = "Appearance" })
	CreateDropdown({
		Parent = appearance,
		Text = "Accent",
		Options = Config.AccentOrder,
		Bind = { "UI", "Accent" },
		Callback = function(name)
			SetAccent(name)
		end,
	})
	CreateSlider({
		Parent = appearance,
		Text = "Interface scale",
		Min = 0.8,
		Max = 1.2,
		Step = 0.05,
		Bind = { "UI", "Scale" },
		Callback = function()
			ApplyLayout()
		end,
	})
	CreateToggle({
		Parent = appearance,
		Text = "Background blur",
		Description = "Soft blur behind the window.",
		Bind = { "UI", "Blur" },
		Callback = function()
			ApplyBlur()
		end,
	})
	local behavior = CreateCard({ Parent = settings, Title = "Behavior" })
	CreateInfoRow({ Parent = behavior, Label = "Toggle key", Value = Config.ToggleKey.Name })
	CreateButton({
		Parent = behavior,
		Text = "Test notification",
		Callback = function()
			CreateNotification({ Title = Config.HubName, Text = "Notifications are working.", Type = "Success" })
		end,
	})
	CreateButton({
		Parent = behavior,
		Text = "Reset settings",
		Callback = function()
			for _, control in ipairs(Controls) do
				control.Set(Defaults[control.Bind[1]][control.Bind[2]])
			end
			CreateNotification({ Title = "Settings", Text = "Default values restored." })
		end,
	})
	local hub = CreateCard({ Parent = settings, Title = "Hub" })
	CreateButton({
		Parent = hub,
		Text = "Unload hub",
		Style = "Danger",
		Callback = function()
			Destroy()
		end,
	})

	-- Avatar
	local avatar = newPage("Avatar")
	CreatePlayerProfile({ Parent = avatar, Style = "Card" })
	local thumbnails = CreateCard({ Parent = avatar, Title = "Thumbnail" })
	local thumbTypes = {
		Headshot = Enum.ThumbnailType.HeadShot,
		Bust = Enum.ThumbnailType.AvatarBust,
		["Full body"] = Enum.ThumbnailType.AvatarThumbnail,
	}
	CreateDropdown({
		Parent = thumbnails,
		Text = "Style",
		Options = { "Headshot", "Bust", "Full body" },
		Default = "Headshot",
		Callback = function(name)
			ThumbType = thumbTypes[name]
			RefreshAvatars()
		end,
	})
	CreateButton({
		Parent = thumbnails,
		Text = "Reload avatar",
		Callback = function()
			RefreshAvatars()
		end,
	})
end

--// NAVIGATION
local PageIndex = {}
for index, page in ipairs(Config.Pages) do
	PageIndex[page.Name] = index
end

Navigate = function(name, instant)
	if name == CurrentPage and not instant then
		return
	end
	local previous = CurrentPage
	CurrentPage = name
	PageToken += 1
	local token = PageToken

	for pageName, button in pairs(SidebarButtons) do
		button.SetSelected(pageName == name)
	end
	local target = UDim2.fromOffset(0, (PageIndex[name] - 1) * (BTN_H + BTN_GAP))
	Anim.Set(UI.Pill, { Position = target }, instant)

	for pageName, group in pairs(Pages) do
		if pageName ~= name and pageName ~= previous then
			group.Visible = false
		end
	end

	local incoming = Pages[name]
	incoming.Visible = true
	Scrolls[name].CanvasPosition = Vector2.zero

	if instant then
		incoming.GroupTransparency = 0
		incoming.Position = UDim2.new()
		return
	end

	local outgoing = previous and Pages[previous]
	if outgoing then
		Anim.Play(outgoing, Anim.Exit, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -8) })
		task.delay(0.2, function()
			if CurrentPage ~= previous then
				outgoing.Visible = false
			end
		end)
	end
	incoming.GroupTransparency = 1
	incoming.Position = UDim2.fromOffset(0, 8)
	task.delay(0.1, function()
		if Destroyed or token ~= PageToken then
			return
		end
		Anim.Play(incoming, Anim.Normal, { GroupTransparency = 0, Position = UDim2.new() })
	end)
end

--// LAYOUT
local function SetCompact(value, instant)
	if Compact == value and not instant then
		return
	end
	Compact = value
	local width = value and SIDE_C or SIDE_W
	Anim.Set(UI.Sidebar, { Size = UDim2.new(0, width, 1, 0) }, instant)
	Anim.Set(UI.Content, {
		Position = UDim2.new(0, width, 0, 0),
		Size = UDim2.new(1, -width, 1, 0),
	}, instant)
	for _, button in pairs(SidebarButtons) do
		button.SetCompact(value, instant)
	end
	UI.Profile.SetCompact(value, instant)
end

ApplyLayout = function(instant)
	if Destroyed or not UI.Root then
		return
	end
	local viewport = Camera.ViewportSize
	local portrait = viewport.Y > viewport.X * 1.05
	local base = portrait and Config.WindowSize.Portrait or Config.WindowSize.Landscape
	local fit = math.min(viewport.X * 0.94 / base.X, viewport.Y * 0.92 / base.Y)
	local limit = math.min(viewport.X * 0.98 / base.X, viewport.Y * 0.98 / base.Y)
	local scale = math.clamp(fit, 0.5, 1.25) * Settings.UI.Scale
	scale = math.min(scale, limit)

	UI.Root.Size = UDim2.fromOffset(base.X, base.Y)
	UI.Aspect.AspectRatio = base.X / base.Y
	UI.RootScale.Scale = scale
	UI.PixelSize = Vector2.new(base.X * scale, base.Y * scale)

	local maxX = math.max((viewport.X - UI.PixelSize.X) / 2, 0)
	local maxY = math.max((viewport.Y - UI.PixelSize.Y) / 2, 0)
	DragOffset = Vector2.new(math.clamp(DragOffset.X, -maxX, maxX), math.clamp(DragOffset.Y, -maxY, maxY))
	UI.Root.Position = UDim2.new(0.5, DragOffset.X, 0.5, DragOffset.Y)

	SetCompact(portrait or UI.PixelSize.X < 520, instant == true)
end

ApplyBlur = function()
	if not UI.Blur then
		return
	end
	local active = IsOpen and Settings.UI.Blur
	Anim.Play(UI.Blur, Anim.Normal, { Size = active and Config.BlurSize or 0 })
end

SetAccent = function(name)
	local color = Config.AccentPresets[name]
	if not color then
		return
	end
	Theme.Accent = color
	for _, listener in ipairs(AccentListeners) do
		listener(color)
	end
end

--// WINDOW STATE
Open = function()
	if IsOpen or Destroyed then
		return
	end
	IsOpen = true
	CloseToken += 1
	UI.Root.Visible = true
	UI.Launcher.Visible = false
	UI.WindowScale.Scale = 0.96
	UI.Window.GroupTransparency = 1
	UI.Window.Position = UDim2.new(0.5, 0, 0.5, 10)
	for _, shadow in ipairs(UI.Shadows) do
		shadow.Frame.BackgroundTransparency = 1
		Anim.Play(shadow.Frame, Anim.Slow, { BackgroundTransparency = shadow.Base })
	end
	Anim.Play(UI.WindowScale, Anim.Slow, { Scale = 1 })
	Anim.Play(UI.Window, Anim.Slow, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) })
	for _, tween in ipairs(StatusTweens) do
		tween:Play()
	end
	ApplyBlur()
end

Close = function()
	if not IsOpen or Destroyed then
		return
	end
	IsOpen = false
	CloseToken += 1
	local token = CloseToken
	Anim.Play(UI.WindowScale, Anim.Exit, { Scale = 0.96 })
	Anim.Play(UI.Window, Anim.Exit, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 8) })
	for _, shadow in ipairs(UI.Shadows) do
		Anim.Play(shadow.Frame, Anim.Exit, { BackgroundTransparency = 1 })
	end
	ApplyBlur()
	task.delay(0.2, function()
		if Destroyed or IsOpen or token ~= CloseToken then
			return
		end
		UI.Root.Visible = false
		UI.Launcher.Visible = true
		for _, tween in ipairs(StatusTweens) do
			tween:Pause()
		end
	end)
end

Toggle = function()
	if IsOpen then
		Close()
	else
		Open()
	end
end

Destroy = function()
	if Destroyed then
		return
	end
	Destroyed = true
	for _, connection in ipairs(Connections) do
		connection:Disconnect()
	end
	if ViewportConn then
		ViewportConn:Disconnect()
	end
	for _, tween in ipairs(StatusTweens) do
		tween:Cancel()
	end
	for _, view in ipairs(AvatarViews) do
		if view.LoadTween then
			view.LoadTween:Cancel()
		end
	end
	if UI.Blur then
		UI.Blur:Destroy()
	end
	if UI.Gui then
		UI.Gui:Destroy()
	end
	Changed:Destroy()
	if _G.Nuu7Hub and _G.Nuu7Hub.Destroy == Destroy then
		_G.Nuu7Hub = nil
	end
end

--// EVENT CONNECTIONS
local function BindCamera()
	if ViewportConn then
		ViewportConn:Disconnect()
		ViewportConn = nil
	end
	local current = workspace.CurrentCamera
	if current then
		Camera = current
		ViewportConn = current:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			ApplyLayout()
		end)
	end
	ApplyLayout()
end

local function ConnectEvents()
	Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), BindCamera)
	Connect(UserInputService.InputBegan, function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Config.ToggleKey then
			Toggle()
		end
	end)
	Connect(LocalPlayer:GetPropertyChangedSignal("DisplayName"), function()
		for _, profile in ipairs(ProfileObjects) do
			profile.UpdateNames()
		end
	end)
end

--// INITIALIZATION
CreateWindow()
BuildPages()
CreateLauncher()
CreateNotificationHolder()

UI.Blur = Create("BlurEffect", { Name = "Nuu7HubBlur", Size = 0 })
UI.Blur.Parent = Lighting

BindCamera()
ApplyLayout(true)
Navigate(Config.Pages[1].Name, true)
ConnectEvents()
Open()

task.delay(0.2, function()
	if Destroyed then
		return
	end
	for _, profile in ipairs(ProfileObjects) do
		profile.Enter()
	end
	CreateNotification({
		Title = "Welcome",
		Text = LocalPlayer.DisplayName,
		Duration = 3,
	})
end)

_G.Nuu7Settings = Settings
_G.Nuu7Hub = {
	Settings = Settings,
	Changed = Changed.Event,
	Open = Open,
	Close = Close,
	Toggle = Toggle,
	Notify = CreateNotification,
	SetAccent = SetAccent,
	Destroy = Destroy,
}
