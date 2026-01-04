--[[ 
  some stuff from Fondra v3
  not finished yet ui made by @nfpw
]]

local shared = (getgenv and getgenv()) or shared or _G or {}
shared.enviro = {name = "[Enviro]", version = "0.0.1", debug = true, executor = (getexecutorname and getexecutorname()) or "noname", ui_library = {}}
shared.enviro.ui_library = {
	elements = {
		color_pickers = {}, 
		toggles = {}, 
		sliders = {}, 
		buttons = {}, 
		dropdowns = {}, 
		sections = {}, 
		tabs = {}, 
		windows = {}
	},
	connections = {},
	notifications = {},
	objects = {},
	registery = {},
	stats = {},
	assets = {},
	theme = {
		["accent"] = Color3.fromRGB(0, 160, 255),
		["accent_dark"] = Color3.fromRGB(0, 120, 255),

		["background_1"] = Color3.fromRGB(12, 12, 12),
		["background_2"] = Color3.fromRGB(15, 15, 15),
		["background_3"] = Color3.fromRGB(18, 18, 18),

		["border_1"] = Color3.fromRGB(53, 54, 53),
		["border_2"] = Color3.fromRGB(45, 45, 45),
		["border_3"] = Color3.fromRGB(29, 29, 29),

		["selected_tab"] = Color3.fromRGB(15, 15, 15),
		["unselected_tab"] = Color3.fromRGB(10, 10, 10),

		["selected_section"] = Color3.fromRGB(18, 18, 18),
		["unselected_section"] = Color3.fromRGB(20, 20, 20),

		["section_background"] = Color3.fromRGB(15, 15, 15),
		["option_background"] = Color3.fromRGB(20, 20, 20),

		["active_text"] = Color3.fromRGB(255, 255, 255),
		["inactive_text"] = Color3.fromRGB(150, 150, 150),
		["accent_text"] = Color3.fromRGB(80, 180, 255),
		["warning_text"] = Color3.fromRGB(255, 110, 110)
	}
}

local script = shared.enviro
local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local cloneref = cloneref or function(v) return v end
local cache = {game = {}} 

local print = function(...)
	if script.debug then print(script.name, ...); end
end

local warn = function(...)
	if script.debug then warn(script.name, ...); end
end

local error = function(string)
	if script.debug then error(script.name .. " " .. string); end
end

local core = setmetatable({}, {
	__index = function(self, key)
		if not cache[key] then 
			cache[key] = game[key]; print("core cached new key:", key); 
		else 
			print("core using cached key:", key)
		end
		return cache[key]
	end
})

for i, v in ipairs(core.GetChildren(game)) do
	cache.game[v.ClassName.lower(v.ClassName)] = v.ClassName; print("core class cached:", v.ClassName.lower(v.ClassName), "→", v.ClassName)
end

local services = setmetatable({}, {
	__index = function(self, service)
		print("service requesting:", service)
		local normalized = string.gsub(string.lower(service), "[_%-]", "")
		local offsets = cache.game[normalized]
		if not offsets then error("'" .. tostring(service) .. "' is not a valid service name"); end
		print("service resolved to:", offsets)
		local success, svc = pcall(function() return cloneref(game:GetService(offsets)) end)
		if not success or not svc then error("failed to get service '" .. tostring(offsets) .. "'"); end
		rawset(self, service, svc)
		print("service cached:", service, "→", svc.Name)
		return svc
	end
})

local execute = function(func, ...)
	local args = {...}
	local success, result = pcall(function()
		return func(unpack(args))
	end)

	if not success then
		local message = tostring(result)
		local traceback = debug.traceback(message, 2)
		warn("error:", message)
		warn("stack trace:")
		warn(traceback)
		return nil, message, traceback
	else
		print("works in my machine")
		return result
	end
end

local render = function(class, properties)
	local instance = Instance.new(class)
	if properties then
		for property, value in pairs(properties) do
			instance[property] = value
		end
	end
	print("rendered:", class, "instance")
	return instance
end

execute(function() -- ui assets
	local theme = shared.enviro.ui_library.theme
	shared.enviro.ui_library.assets = {
		screen = execute(function()
			local screen = render("ScreenGui", {
				Name = "ENVIRO",
				ResetOnSpawn = false,
				ZIndexBehavior = Enum.ZIndexBehavior.Global,
				ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
				IgnoreGuiInset = true,
				DisplayOrder = 100067,
			})

			local menu_gui = render("ScreenGui", {
				Name = "MENUS",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				Parent = screen,
				ZIndexBehavior = Enum.ZIndexBehavior.Global,
				DisplayOrder = 100067 + 1,
			})

			local components_gui = render("ScreenGui", {
				Name = "COMPONENTS",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				Parent = screen,
				ZIndexBehavior = Enum.ZIndexBehavior.Global,
				DisplayOrder = 100067 + 2,
			})

			local notifications_gui = render("ScreenGui", {
				Name = "NOTIFICATIONS",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				Parent = screen,
				ZIndexBehavior = Enum.ZIndexBehavior.Global,
				DisplayOrder = 100067 + 3,
			})
			return screen
		end),

		window = execute(function()
			local window = render("Frame", {
				Name = "WINDOW",
				BackgroundColor3 = theme["accent"],
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, 600, 0, 420),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BorderSizePixel = 0,
			})

			local frame_1 = render("Frame", {
				Name = "FRAME_1",
				Parent = window,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["border_1"],
				BorderSizePixel = 0,
			})

			local frame_2 = render("Frame", {
				Name = "FRAME_2",
				Parent = frame_1,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["border_3"],
				BorderSizePixel = 0,
			})

			local frame_3 = render("Frame", {
				Name = "FRAME_3",
				Parent = frame_2,
				Size = UDim2.new(1, -6, 1, -6),
				Position = UDim2.new(0, 3, 0, 3),
				BackgroundColor3 = theme["border_1"],
				BorderSizePixel = 0,
			})

			local frame_4 = render("Frame", {
				Name = "FRAME_4",
				Parent = frame_3,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["background_1"],
				BorderSizePixel = 0,
			})

			local drag_handle = render("Frame", {
				Name = "DRAG_HANDLE",
				Parent = frame_4,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				ZIndex = 10,
			})

			local title = render("TextLabel", {
				Name = "TITLE",
				Parent = drag_handle,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "t e l e g r a m",
				TextColor3 = theme["accent_text"],
				Font = Enum.Font.Code,
				TextSize = 16,
			})

			local subtitle = render("TextLabel", {
				Name = "SUB_TITLE",
				Parent = frame_4,
				Position = UDim2.new(0, 0, 0, 22),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Best Regards Tele-Gram Management Team",
				TextColor3 = theme["active_text"],
				Font = Enum.Font.SourceSans,
				TextSize = 12,
			})

			local sub_grad = render("UIGradient", {
				Name = "SUB_GRAD",
				Parent = subtitle,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, theme["accent_dark"]),
					ColorSequenceKeypoint.new(0.5, theme["active_text"]),
					ColorSequenceKeypoint.new(1, theme["accent_dark"])
				}),
			})

			local resize_handle = render("TextButton", {
				Name = "RESIZE_HANDLE",
				Parent = frame_4,
				Size = UDim2.new(0, 15, 0, 15),
				Position = UDim2.new(1, -15, 1, -15),
				BackgroundTransparency = 1,
				Text = "◢",
				TextColor3 = theme["accent_text"],
				TextSize = 14,
				Font = Enum.Font.Code,
				ZIndex = 5,
			})

			local tab_holder = render("Frame", {
				Name = "TAB_HOLDER",
				Parent = frame_4,
				Position = UDim2.new(0, 10, 0, 48),
				Size = UDim2.new(1, -20, 0, 28),
				BackgroundTransparency = 1,
				ZIndex = 5,
			})

			local ui_list_tabs = render("UIListLayout", {
				Name = "UI_LIST_TABS",
				Parent = tab_holder,
				FillDirection = Enum.FillDirection.Horizontal,
			})

			local content = render("Frame", {
				Name = "CONTENT",
				Parent = frame_4,
				Position = UDim2.new(0, 10, 0, 75),
				Size = UDim2.new(1, -20, 1, -85),
				BackgroundColor3 = theme["background_2"] or Color3.fromRGB(15, 15, 15),
				BorderColor3 = theme["border_1"] or Color3.fromRGB(53, 54, 53),
				BorderSizePixel = 1,
			})
			return window
		end),

		tab_content_holder = execute(function()
			local tab_content = render("ScrollingFrame", {
				Name = "TAB_CONTENT",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				ScrollBarImageColor3 = theme["accent"],
				Visible = false,
				CanvasSize = UDim2.new(0, 0, 0, 0),
			})

			local left_side = render("Frame", {
				Name = "LEFT_SIDE",
				Parent = tab_content,
				Size = UDim2.new(0.5, -12, 1, 0),
				Position = UDim2.new(0, 8, 0, 8),
				BackgroundTransparency = 1,
			})

			local left_layout = render("UIListLayout", {
				Name = "LIST_LAYOUT",
				Parent = left_side,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})

			local right_side = render("Frame", {
				Name = "RIGHT_SIDE",
				Parent = tab_content,
				Size = UDim2.new(0.5, -12, 1, 0),
				Position = UDim2.new(0.5, 4, 0, 8),
				BackgroundTransparency = 1,
			})

			local right_layout = render("UIListLayout", {
				Name = "LIST_LAYOUT",
				Parent = right_side,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})

			return tab_content
		end),

		tab = execute(function()
			local tab = render("Frame", {
				Name = "TAB",
				Size = UDim2.new(0, 93, 1, 0),
				BackgroundColor3 = theme["selected_tab"] or theme["unselected_tab"],
				BorderColor3 = theme["border_1"],
				BorderSizePixel = 1,
			})

			local txt = render("TextLabel", {
				Name = "TAB_TEXT",
				Text = "LABEL",
				Parent = tab,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = theme["accent_text"] or theme["inactive_text"],
				Font = Enum.Font.SourceSans,
				TextSize = 14,
			})

			local line = render("Frame", {
				Name = "TAB_LINE",
				Parent = tab,
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = theme["accent"],
				BorderSizePixel = 0,
			})

			local cover = render("Frame", {
				Name = "TAB_COVER",
				Parent = tab,
				Size = UDim2.new(1, -2, 0, 2),
				Position = UDim2.new(0, 1, 1, -1),
				BackgroundColor3 = theme["selected_tab"],
				BorderSizePixel = 0,
				ZIndex = 10,
				Visible = false
			})
			return tab
		end),

		section = execute(function()
			local section_group = render("Frame", {
				Name = "SECTION_GROUP",
				Size = UDim2.new(0.5, -12, 0, 150),
				BackgroundTransparency = 1,
			})

			local header_box = render("TextButton", {
				Name = "HEADER_BOX",
				Parent = section_group,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = theme["selected_section"] or Color3.fromRGB(18, 18, 18),
				BorderColor3 = theme["border_2"] or Color3.fromRGB(45, 45, 45),
				Text = "",
				AutoButtonColor = false,
			})

			local title_label = render("TextLabel", {
				Name = "TITLE_LABEL",
				Parent = header_box,
				Size = UDim2.new(1, -30, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = "Section",
				TextColor3 = theme["active_text"] or Color3.fromRGB(200, 200, 200),
				Font = Enum.Font.Code,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local arrow = render("TextLabel", {
				Name = "ARROW",
				Parent = header_box,
				Size = UDim2.new(0, 20, 1, 0),
				Position = UDim2.new(1, -25, 0, 0),
				BackgroundTransparency = 1,
				Text = "v",
				TextColor3 = theme["active_text"] or Color3.fromRGB(200, 200, 200),
				Font = Enum.Font.Code,
				TextSize = 14,
			})

			local main_box = render("Frame", {
				Name = "MAIN_BOX",
				Parent = section_group,
				Size = UDim2.new(1, 0, 1, -22),
				Position = UDim2.new(0, 0, 0, 22),
				BackgroundColor3 = theme["section_background"] or Color3.fromRGB(15, 15, 15),
				BorderColor3 = theme["border_2"] or Color3.fromRGB(45, 45, 45),
				ClipsDescendants = true,
			})

			local padding = render("UIPadding", {
				Name = "PADDING",
				Parent = main_box,
				PaddingLeft = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
			})

			local ui_list = render("UIListLayout", {
				Name = "UI_LIST",
				Parent = main_box,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			return section_group
		end),

		label = execute(function()
			local label = render("TextLabel", {
				Name = "LABEL",
				Size = UDim2.new(1, -20, 0, 13),
				BackgroundTransparency = 1,
				Text = "LABEL",
				TextColor3 = theme["active_text"],
				Font = Enum.Font.Code,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			})
			return label
		end),

		button = execute(function()
			local button_holder = render("Frame", {
				Name = "BUTTON_HOLDER",
				Size = UDim2.new(1, -10, 0, 20),
				BackgroundTransparency = 1,
			})

			local btn = render("TextButton", {
				Name = "BUTTON",
				Parent = button_holder,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = theme["option_background"],
				BorderColor3 = theme["border_2"],
				BorderSizePixel = 1,
				Text = "Button",
				TextColor3 = theme["inactive_text"],
				Font = Enum.Font.Code,
				TextSize = 12,
				AutoButtonColor = false,
			})
			return button_holder
		end),

		slider = execute(function()
			local slider_holder = render("Frame", {
				Name = "SLIDER_HOLDER",
				Size = UDim2.new(1, -10, 0, 26),
				BackgroundTransparency = 1,
			})

			local title = render("TextLabel", {
				Name = "TITLE",
				Parent = slider_holder,
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = "Slider",
				TextColor3 = theme["inactive_text"],
				Font = Enum.Font.Code,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local value_box = render("TextBox", {
				Name = "VALUE_BOX",
				Parent = slider_holder,
				Size = UDim2.new(0, 40, 0, 14),
				Position = UDim2.new(1, -40, 0, 0),
				BackgroundTransparency = 1,
				Text = "0",
				TextColor3 = theme["accent_text"],
				Font = Enum.Font.Code,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
				ClearTextOnFocus = false,
			})

			local slider_back = render("Frame", {
				Name = "SLIDER_BACK",
				Parent = slider_holder,
				Size = UDim2.new(1, 0, 0, 8),
				Position = UDim2.new(0, 0, 0, 18),
				BackgroundColor3 = theme["border_3"],
				BorderSizePixel = 1,
				BorderColor3 = theme["border_2"],
			})

			local slider_fill = render("Frame", {
				Name = "SLIDER_FILL",
				Parent = slider_back,
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundColor3 = theme["accent"],
				BorderSizePixel = 0,
			})
			return slider_holder
		end),

		watermark = execute(function()
			local watermark = render("Frame", {
				Name = "WATERMARK",
				BackgroundColor3 = theme["accent"],
				Size = UDim2.new(0, 220, 0, 26),
				Position = UDim2.new(0, 10, 0, 10),
				BorderSizePixel = 0,
			})

			local frame_1 = render("Frame", {
				Name = "FRAME_1",
				Parent = watermark,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["border_1"],
				BorderSizePixel = 0,
			})

			local frame_2 = render("Frame", {
				Name = "FRAME_2",
				Parent = frame_1,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["border_3"],
				BorderSizePixel = 0,
			})

			local frame_3 = render("Frame", {
				Name = "FRAME_3",
				Parent = frame_2,
				Size = UDim2.new(1, -6, 1, -6),
				Position = UDim2.new(0, 3, 0, 3),
				BackgroundColor3 = theme["border_1"],
				BorderSizePixel = 0,
			})

			local frame_4 = render("Frame", {
				Name = "FRAME_4",
				Parent = frame_3,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["background_1"],
				BorderSizePixel = 0,
			})

			local top_line = render("Frame", {
				Name = "TOP_LINE",
				Parent = frame_4,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = theme["accent"],
				BorderSizePixel = 0,
			})

			local text_label = render("TextLabel", {
				Name = "TEXT_LABEL",
				Parent = frame_4,
				Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				BackgroundTransparency = 1,
				Text = "enviro | telegram | " .. os.date("%X"),
				TextColor3 = theme["accent_text"],
				Font = Enum.Font.Code,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			return watermark
		end),

		notification = execute(function()
			local notification = render("Frame", {
				Name = "NOTIFICATION",
				Size = UDim2.new(0, 180, 0, 26), 
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BorderSizePixel = 1,
				BorderColor3 = Color3.fromRGB(50, 50, 50),
			})

			local text_label = render("TextLabel", {
				Name = "TEXT_LABEL",
				Parent = notification,
				Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				BackgroundTransparency = 1,
				Text = "Speed set to: true",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.Code,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local accent_line = render("Frame", {
				Name = "ACCENT",
				Parent = notification,
				Size = UDim2.new(0, 2, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = theme["accent"],
				BorderSizePixel = 0,
				Visible = true
			})
			return notification
		end),

		keybind_list = execute(function()
			local keybind_main = render("Frame", {
				Name = "KEYBIND_LIST",
				BackgroundColor3 = theme["accent"],
				Size = UDim2.new(0, 180, 0, 30),
				Position = UDim2.new(0, 10, 0, 45),
				BorderSizePixel = 0,
			})

			local f1 = render("Frame", { Name = "F1", Parent = keybind_main, Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1), BackgroundColor3 = theme["border_1"], BorderSizePixel = 0 })
			local f2 = render("Frame", { Name = "F2", Parent = f1, Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1), BackgroundColor3 = theme["border_3"], BorderSizePixel = 0 })
			local f3 = render("Frame", { Name = "F3", Parent = f2, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.new(0, 3, 0, 3), BackgroundColor3 = theme["border_1"], BorderSizePixel = 0 })

			local content_bg = render("Frame", {
				Name = "CONTENT_BG",
				Parent = f3,
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundColor3 = theme["background_1"],
				BorderSizePixel = 0,
			})

			local header = render("TextLabel", {
				Name = "HEADER",
				Parent = content_bg,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "keybinds",
				TextColor3 = theme["accent_text"],
				Font = Enum.Font.Code,
				TextSize = 13,
			})

			local line = render("Frame", {
				Name = "LINE",
				Parent = content_bg,
				Size = UDim2.new(1, -10, 0, 1),
				Position = UDim2.new(0, 5, 0, 20),
				BackgroundColor3 = theme["accent"],
				BorderSizePixel = 0,
			})

			local list_holder = render("Frame", {
				Name = "LIST_HOLDER",
				Parent = content_bg,
				Position = UDim2.new(0, 5, 0, 25),
				Size = UDim2.new(1, -10, 1, -30),
				BackgroundTransparency = 1,
			})

			local layout = render("UIListLayout", {
				Parent = list_holder,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2)
			})
			return keybind_main
		end),

		keybind_item = execute(function()
			local item = render("Frame", {
				Name = "ITEM",
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
			})

			local feature_label = render("TextLabel", {
				Name = "FEATURE",
				Parent = item,
				Size = UDim2.new(0.7, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "Flight",
				TextColor3 = Color3.fromRGB(200, 200, 200),
				Font = Enum.Font.SourceSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local key_label = render("TextLabel", {
				Name = "KEY",
				Parent = item,
				Size = UDim2.new(0.3, 0, 1, 0),
				Position = UDim2.new(0.7, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "[V]",
				TextColor3 = theme["accent_text"],
				Font = Enum.Font.Code,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			return item
		end),
	}
end)

execute(function()
	local theme = shared.enviro.ui_library.theme
	local tween_service = services.tween_service
	local user_input = services.user_input_service

	local function get_input_position(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			return input.Position
		else
			return user_input:GetMouseLocation()
		end
	end

	local function make_draggable(frame, drag_target)
		if not drag_target then
			warn("where is 2nd argument??"); return
		end

		drag_target = drag_target or frame

		local drag_frame = render("Frame", {
			Name = "DRAG_OVERLAY",
			Parent = frame.Parent,
			Size = frame.Size,
			Position = frame.Position,
			AnchorPoint = frame.AnchorPoint,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1000,
		})

		local drag_stroke = render("UIStroke", {
			Parent = drag_frame,
			Color = theme["accent"],
			Thickness = 2,
			Transparency = 1,
		})

		local dragging = false
		local drag_input, drag_start, start_pos

		local function update_drag(input)
			local current_pos = get_input_position(input)
			local delta = current_pos - drag_start

			local viewport_size = services.workspace.CurrentCamera.ViewportSize
			local frame_size = drag_frame.AbsoluteSize
			local anchor = drag_frame.AnchorPoint

			local min_x = frame_size.X * anchor.X
			local min_y = frame_size.Y * anchor.Y
			local max_x = viewport_size.X - frame_size.X * (1 - anchor.X)
			local max_y = viewport_size.Y - frame_size.Y * (1 - anchor.Y)

			local target_x = math.clamp(start_pos.X + delta.X, min_x, max_x)
			local target_y = math.clamp(start_pos.Y + delta.Y, min_y, max_y)

			drag_frame.Position = UDim2.new(0, target_x, 0, target_y)
		end

		drag_target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				drag_start = get_input_position(input)

				start_pos = Vector2.new(
					frame.AbsolutePosition.X + frame.AbsoluteSize.X * frame.AnchorPoint.X, 
					frame.AbsolutePosition.Y + frame.AbsoluteSize.Y * frame.AnchorPoint.Y
				)

				drag_frame.Position = frame.Position
				drag_frame.AnchorPoint = frame.AnchorPoint
				drag_frame.Size = frame.Size

				tween_service:Create(drag_frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.5}):Play()
				tween_service:Create(drag_stroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Transparency = 0}):Play()

				local drag_connection; drag_connection = user_input.InputChanged:Connect(function(input_changed)
					if input_changed.UserInputType == Enum.UserInputType.MouseMovement or input_changed.UserInputType == Enum.UserInputType.Touch then
						if dragging then
							update_drag(input_changed)
						end
					end
				end)

				local end_connection; end_connection = user_input.InputEnded:Connect(function(input_ended)
					if input_ended.UserInputType == Enum.UserInputType.MouseButton1 or input_ended.UserInputType == Enum.UserInputType.Touch then
						if dragging then
							dragging = false
							drag_connection:Disconnect()
							end_connection:Disconnect()

							tween_service:Create(drag_frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
							tween_service:Create(drag_stroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Transparency = 1}):Play()

							frame.Position = drag_frame.Position
						end
					end
				end)
			end
		end)

		return drag_frame
	end

	local function make_resizable(frame, resize_handle)
		if not resize_handle then
			warn("where is 2nd argument??"); return
		end

		local resizing = false
		local resize_start, start_size

		local min_width = 400
		local min_height = 300

		local function update_resize(input)
			local current_pos = get_input_position(input)
			local delta = current_pos - resize_start

			local new_width = math.max(start_size.X + delta.X, min_width)
			local new_height = math.max(start_size.Y + delta.Y, min_height)

			frame.Size = UDim2.new(0, new_width, 0, new_height)
		end

		resize_handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resize_start = get_input_position(input)
				start_size = Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)

				tween_service:Create(resize_handle, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
					TextColor3 = theme["accent"]
				}):Play()

				local resize_connection; resize_connection = user_input.InputChanged:Connect(function(input_changed)
					if input_changed.UserInputType == Enum.UserInputType.MouseMovement or input_changed.UserInputType == Enum.UserInputType.Touch then
						if resizing then
							update_resize(input_changed)
						end
					end
				end)

				local end_connection; end_connection = user_input.InputEnded:Connect(function(input_ended)
					if input_ended.UserInputType == Enum.UserInputType.MouseButton1 or input_ended.UserInputType == Enum.UserInputType.Touch then
						if resizing then
							resizing = false
							resize_connection:Disconnect()
							end_connection:Disconnect()
							tween_service:Create(resize_handle, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
								TextColor3 = theme["accent_text"]
							}):Play()
						end
					end
				end)
			end
		end)

		resize_handle.MouseEnter:Connect(function()
			if not resizing then
				tween_service:Create(resize_handle, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
					TextColor3 = Color3.fromRGB(255, 255, 255)
				}):Play()
			end
		end)

		resize_handle.MouseLeave:Connect(function()
			if not resizing then
				tween_service:Create(resize_handle, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
					TextColor3 = theme["accent_text"]
				}):Play()
			end
		end)
	end

	shared.enviro.ui_library.make_resizable = make_resizable
	shared.enviro.ui_library.make_draggable = make_draggable
end)

execute(function() -- ui library creation
	local library = {}
	library.__index = library

	local assets = shared.enviro.ui_library.assets
	local theme = shared.enviro.ui_library.theme

	local make_draggable = shared.enviro.ui_library.make_draggable
	local make_resizable = shared.enviro.ui_library.make_resizable

	local ts = services.tween_service

	function library.create_window(config, parent)
		if config == nil then
			config = {
				window_name = "Developer Mode",
				sub_title = "Best Regards Development Team",
				color = Color3.fromRGB(255, 128, 64),
				keybind = Enum.KeyCode.RightShift,
			}
		else
			config.keybind = config.keybind or Enum.KeyCode.RightShift
			config.window_name = config.window_name or "Developer Mode"
			config.sub_title = config.sub_title or "Best Regards Development Team"
			config.color = config.color or Color3.fromRGB(255, 128, 64)
		end

		if config.color then
			shared.enviro.ui_library.theme["accent"] = config.color
			local r = math.clamp(config.color.R - 0.15, 0, 1)
			local g = math.clamp(config.color.G - 0.15, 0, 1)
			local b = math.clamp(config.color.B - 0.15, 0, 1)
			shared.enviro.ui_library.theme["accent_dark"] = Color3.new(r, g, b)
			local r2 = math.clamp(config.color.R + 0.2, 0, 1)
			local g2 = math.clamp(config.color.G + 0.2, 0, 1)
			local b2 = math.clamp(config.color.B + 0.2, 0, 1)
			shared.enviro.ui_library.theme["accent_text"] = Color3.new(r2, g2, b2)
			print("theme colors updated - accent:", config.color)
		end

		print("creating window with config:", config.window_name)

		local window_clone = assets.window:Clone()
		if not window_clone then
			error("failed to clone window asset")
			return nil
		end

		local window = {
			window = window_clone,
			drag_frame = nil,
			config = config,
		}

		local target_parent = parent or services.players.LocalPlayer.PlayerGui
		window.window.Parent = target_parent
		print("window parented to:", target_parent.Name)

		local main_frame = window.window:FindFirstChild("FRAME_1")
		main_frame = main_frame:FindFirstChild("FRAME_2")
		main_frame = main_frame:FindFirstChild("FRAME_3")
		main_frame = main_frame:FindFirstChild("FRAME_4")
		if not main_frame then
			error("FRAME_4 not found"); return nil
		end

		local drag_handle = main_frame:FindFirstChild("DRAG_HANDLE")
		local resize_handle = main_frame:FindFirstChild("RESIZE_HANDLE")

		local title = drag_handle and drag_handle:FindFirstChild("TITLE")
		if title then
			title.Text = config.window_name
			title.TextColor3 = theme["accent_text"]
			print("title set to:", config.window_name)
		else
			warn("TITLE element not found")
		end

		local subtitle = main_frame:FindFirstChild("SUB_TITLE")
		if subtitle then
			subtitle.Text = config.sub_title
			print("subtitle set to:", config.sub_title)
		else
			warn("SUB_TITLE element not found")
		end

		window.window.BackgroundColor3 = theme["accent"]
		if resize_handle then
			resize_handle.TextColor3 = theme["accent_text"]
		end

		if drag_handle and make_draggable then
			window.drag_frame = make_draggable(window.window, drag_handle)
			print("window made draggable via handle")
		else
			warn("could not make window draggable - drag_handle:", drag_handle ~= nil, "make_draggable:", make_draggable ~= nil)
		end

		if resize_handle and make_resizable then
			make_resizable(window.window, resize_handle)
			print("window made resizable via handle")
			window.window:GetPropertyChangedSignal("Size"):Connect(function()
				window.update_tab_sizes()
			end)
		else
			warn("could not make window resizable - resize_handle:", resize_handle ~= nil, "make_resizable:", make_resizable ~= nil)
		end

		local visible = true
		local toggle_connection = services.user_input_service.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == config.keybind then
				visible = not visible
				window.window.Visible = visible
				print("window toggled:", visible and "visible" or "hidden", "- Keybind:", config.keybind.Name)
			end
		end)
		window.toggle_connection = toggle_connection
		window.tabs = {}
		window.current_tab = nil

		local function update_tab_sizes()
			local tab_holder = main_frame:FindFirstChild("TAB_HOLDER")
			if not tab_holder then return end

			local horizontal_padding = 10
			local vertical_padding = 0

			tab_holder.Size = UDim2.new(1, -(horizontal_padding * 2), 0, 28)
			tab_holder.Position = UDim2.new(0, horizontal_padding, 0, 48)

			local tab_buttons = {}
			for _, child in pairs(tab_holder:GetChildren()) do
				if child:IsA("Frame") and child.Name:match("^TAB_") then
					table.insert(tab_buttons, child)
				end
			end

			local tab_count = #tab_buttons
			if tab_count > 0 then
				local available_width = tab_holder.AbsoluteSize.X
				local button_width = math.floor(available_width / tab_count)
				local remainder = available_width - (button_width * tab_count)

				for i, tab_button in ipairs(tab_buttons) do
					local extra = (i <= remainder) and 1 or 0
					local final_width = button_width + extra
					local pos_x = 0
					for j = 1, i - 1 do
						local prev_extra = (j <= remainder) and 1 or 0
						pos_x = pos_x + button_width + prev_extra
					end

					tab_button.Size = UDim2.new(0, final_width, 1, 0)
					tab_button.Position = UDim2.new(0, pos_x, 0, 0)
				end
			end
		end
		window.update_tab_sizes = update_tab_sizes

		function window:add_tab(tab_config)
			tab_config = tab_config or {}
			tab_config.name = tab_config.name or "new tab"

			print("creating tab:", tab_config.name)

			local tab_frame = assets.tab:Clone()
			if not tab_frame then
				warn("failed to clone tab asset"); return nil
			end

			local tab_holder = main_frame:FindFirstChild("TAB_HOLDER")
			local content_area = main_frame:FindFirstChild("CONTENT")

			if not tab_holder or not content_area then
				warn("tab holder or content area not found"); return nil
			end

			local tab_content = assets.tab_content_holder:Clone()
			tab_content.Name = "TAB_CONTENT_" .. tab_config.name
			tab_content.Parent = content_area

			local left_side = tab_content:FindFirstChild("LEFT_SIDE")
			local right_side = tab_content:FindFirstChild("RIGHT_SIDE")
			local left_layout = left_side:FindFirstChild("LIST_LAYOUT")
			local right_layout = right_side:FindFirstChild("LIST_LAYOUT")

			tab_frame.Name = "TAB_" .. tab_config.name
			tab_frame.Parent = tab_holder
			local tab_text = tab_frame:FindFirstChild("TAB_TEXT")
			local tab_line = tab_frame:FindFirstChild("TAB_LINE")
			local tab_cover = tab_frame:FindFirstChild("TAB_COVER")

			if tab_text then
				tab_text.Text = tab_config.name
			end

			tab_frame.BackgroundColor3 = theme["unselected_tab"]
			if tab_text then
				tab_text.TextColor3 = theme["inactive_text"]
			end
			if tab_line then
				tab_line.BackgroundColor3 = theme["accent"]
				tab_line.BackgroundTransparency = 1
			end
			if tab_cover then
				tab_cover.Visible = false
			end

			local tab = {
				frame = tab_frame,
				content = tab_content,
				name = tab_config.name,
				text = tab_text,
				line = tab_line,
				cover = tab_cover,
				sections = {},
				left_side = left_side,
				right_side = right_side,
				left_layout = left_layout,
				right_layout = right_layout,
			}

			local function update_canvas()
				local left_height = left_layout.AbsoluteContentSize.Y
				local right_height = right_layout.AbsoluteContentSize.Y
				local max_height = math.max(left_height, right_height)
				tab_content.CanvasSize = UDim2.new(0, 0, 0, max_height + 15)
			end

			left_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update_canvas)
			right_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update_canvas)

			function tab:add_section(section_config)
				section_config = section_config or {}
				section_config.name = section_config.name or "section"
				section_config.side = section_config.side or "left"
				section_config.size = section_config.size or 150
				print("creating section:", section_config.name, "on", section_config.side, "side", "with size:", section_config.size)

				local section_frame = assets.section:Clone()
				if not section_frame then
					warn("failed to clone section asset!"); return nil
				end

				section_frame.Name = "SECTION_GROUP_" .. section_config.name
				section_frame.Size = UDim2.new(1, 0, 0, section_config.size)

				local parent_side = (section_config.side == "right") and tab.right_side or tab.left_side
				section_frame.Parent = parent_side

				local header = section_frame:FindFirstChild("HEADER_BOX")
				local title = header and header:FindFirstChild("TITLE_LABEL")
				local arrow = header and header:FindFirstChild("ARROW")
				local main_box = section_frame:FindFirstChild("MAIN_BOX")

				if title then
					title.Text = section_config.name
				end

				local section = {
					frame = section_frame,
					header = header,
					title = title,
					arrow = arrow,
					main_box = main_box,
					name = section_config.name,
					side = section_config.side,
					size = section_config.size,
					expanded = true,
					elements = {},
				}

				local function update_section_size()
					local total_height = 0
					for _, element in pairs(section.elements) do
						if element.frame and element.frame.Visible then
							total_height = total_height + element.frame.Size.Y.Offset
						end
					end

					local element_count = #section.elements
					if element_count > 0 then
						total_height = total_height + (element_count * 5)
					end

					local new_size = math.max(total_height + 22 + 10, section_config.size)
					section_frame.Size = UDim2.new(1, 0, 0, new_size)
					if section.expanded then
						main_box.Size = UDim2.new(1, 0, 1, -22)
					end
				end

				if header then
					header.MouseButton1Click:Connect(function()
						section.expanded = not section.expanded
						if section.expanded then
							ts:Create(main_box, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
								Size = UDim2.new(1, 0, 1, -22)
							}):Play()
							ts:Create(section_frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
								Size = UDim2.new(1, 0, 0, section_config.size)
							}):Play()
						else
							ts:Create(main_box, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
								Size = UDim2.new(1, 0, 0, 0)
							}):Play()
							ts:Create(section_frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
								Size = UDim2.new(1, 0, 0, 22)
							}):Play()
						end
						if arrow then
							local target_rotation = section.expanded and 0 or -90
							ts:Create(arrow, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
								Rotation = target_rotation
							}):Play()
						end
					end)
				end

				function section:add_label(label_config)
					label_config = label_config or {}
					label_config.text = label_config.text or "Label"
					label_config.side = label_config.side or "left"
					label_config.text_wrap = label_config.text_wrap or false

					local label_frame = assets.label:Clone()
					if not label_frame then
						warn("failed to clone label asset!"); return nil
					end

					label_frame.Name = "LABEL_HOLDER_" .. label_config.text
					label_frame.Text = label_config.text
					label_frame.TextWrapped = label_config.text_wrap
					label_frame.Size = UDim2.new(1, -20, 0, label_config.text_wrap and 32 or 20)

					if label_config.side == "right" then
						label_frame.TextXAlignment = Enum.TextXAlignment.Right
					elseif label_config.side == "center" then
						label_frame.TextXAlignment = Enum.TextXAlignment.Center
					else
						label_frame.TextXAlignment = Enum.TextXAlignment.Left
					end

					if label_config.color then
						label_frame.TextColor3 = label_config.color
					end

					label_frame.Parent = section.main_box
					label_frame.LayoutOrder = #section.elements + 1

					local label_obj = {
						frame = label_frame,
						text = label_config.text,
						type = "label"
					}

					table.insert(section.elements, label_obj)
					update_section_size()

					return {
						set_text = function(_, new_text)
							label_frame.Text = new_text
							label_obj.text = new_text
							update_section_size()
						end,
						set_color = function(_, new_color)
							label_frame.TextColor3 = new_color
						end,
						set_visible = function(_, visible)
							label_frame.Visible = visible
							update_section_size()
						end,
						get_text = function()
							return label_frame.Text
						end,
						get_color = function()
							return label_frame.TextColor3
						end,
						get_visible = function()
							return label_frame.Visible
						end,
						destroy = function()
							label_frame:Destroy()
							for i, element in ipairs(section.elements) do
								if element == label_obj then
									table.remove(section.elements, i)
									break
								end
							end
							update_section_size()
						end
					}
				end

				function section:add_button(button_config)
					button_config = button_config or {}
					button_config.name = button_config.name or "Button"
					button_config.callback = button_config.callback or function() end
					button_config.flag = button_config.flag or false 

					local holder = assets.button:Clone()
					holder.Name = "BUTTON_HOLDER_" .. button_config.name

					local btn = holder:FindFirstChild("BUTTON")
					btn.Text = button_config.name
					holder.Parent = section.main_box

					local button_data = { flag = button_config.flag }

					btn.MouseEnter:Connect(function()
						ts:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
							TextColor3 = theme["active_text"],
							BorderColor3 = theme["accent"] 
						}):Play()
					end)

					btn.MouseLeave:Connect(function()
						ts:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
							TextColor3 = theme["inactive_text"],
							BorderColor3 = theme["border_2"]
						}):Play()
					end)

					btn.MouseButton1Down:Connect(function()
						ts:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
							BackgroundColor3 = theme["option_background"]:Lerp(theme["accent"], 0.5),
							BorderColor3 = theme["accent"]
						}):Play()
					end)

					btn.MouseButton1Up:Connect(function()
						ts:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
							BackgroundColor3 = theme["option_background"],
							BorderColor3 = theme["accent"]
						}):Play()

						button_data.flag = not button_data.flag
						button_config.callback(button_data.flag)
					end)

					local button_obj = { frame = holder, type = "button" }
					table.insert(section.elements, button_obj)
					update_section_size()

					return {
						set_text = function(_, t) 
							btn.Text = t 
						end,
						set_flag = function(_, v) 
							button_data.flag = v 
						end,
						set_visible = function(_, visible)
							holder.Visible = visible
							update_section_size()
						end,
						get_text = function()
							return btn.Text
						end,
						get_visible = function()
							return holder.Visible
						end,
						get_flag = function() 
							return button_data.flag 
						end,
						destroy = function()
							holder:Destroy()
							for i, element in ipairs(section.elements) do
								if element == button_obj then
									table.remove(section.elements, i)
									break
								end
							end
							update_section_size()
						end
					}
				end

				function section:add_slider(slider_config)
					slider_config = slider_config or {}
					slider_config.name = slider_config.name or "Slider"
					slider_config.min = slider_config.min or 0
					slider_config.max = slider_config.max or 100
					slider_config.default = slider_config.default or slider_config.min
					slider_config.flag = slider_config.flag or nil
					local callback = slider_config.callback or slider_config.on_changed or function() end

					local holder = assets.slider:Clone()
					holder.Name = "SLIDER_HOLDER_" .. (slider_config.flag or slider_config.name)
					holder.Parent = section.main_box

					local title = holder:FindFirstChild("TITLE")
					local value_box = holder:FindFirstChild("VALUE_BOX")
					local slider_back = holder:FindFirstChild("SLIDER_BACK")
					local slider_fill = slider_back:FindFirstChild("SLIDER_FILL")

					title.Text = slider_config.name

					local slider_data = {
						value = slider_config.default
					}

					local function update_slider(val, from_input)
						val = math.clamp(val, slider_config.min, slider_config.max)
						slider_data.value = val

						local percent = (val - slider_config.min) / (slider_config.max - slider_config.min)

						ts:Create(slider_fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
							Size = UDim2.new(percent, 0, 1, 0)
						}):Play()

						if not from_input then
							value_box.Text = tostring(math.floor(val * 10) / 10)
						end

						callback(val)
					end

					local dragging = false
					slider_back.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							dragging = true
							ts:Create(title, TweenInfo.new(0.2), {TextColor3 = theme["active_text"]}):Play()
						end
					end)

					services.user_input_service.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
							dragging = false
							ts:Create(title, TweenInfo.new(0.2), {TextColor3 = theme["inactive_text"]}):Play()
						end
					end)

					services.user_input_service.InputChanged:Connect(function(input)
						if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
							local pos = math.clamp((input.Position.X - slider_back.AbsolutePosition.X) / slider_back.AbsoluteSize.X, 0, 1)
							local val = slider_config.min + (pos * (slider_config.max - slider_config.min))
							update_slider(val)
						end
					end)

					value_box.FocusLost:Connect(function()
						local num = tonumber(value_box.Text)
						update_slider(num or slider_data.value)
					end)

					update_slider(slider_config.default)

					local slider_obj = { frame = holder, type = "slider" }
					table.insert(section.elements, slider_obj)
					update_section_size()

					return {
						set_value = function(_, v) update_slider(v) end,
						set_visible = function(_, visible)
							holder.Visible = visible
							update_section_size()
						end,
						get_value = function() 
							return slider_data.value 
						end,
						get_visible = function()
							return holder.Visible
						end,
						destroy = function()
							holder:Destroy()
							for i, element in ipairs(section.elements) do
								if element == slider_obj then
									table.remove(section.elements, i)
									break
								end
							end
							update_section_size()
						end
					}
				end

				table.insert(tab.sections, section)

				print("section created:", section_config.name)
				return section
			end

			tab_frame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					window:select_tab(tab)
				end
			end)

			tab_frame.MouseEnter:Connect(function()
				if window.current_tab ~= tab then
					ts:Create(tab_frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
						BackgroundColor3 = Color3.new(
							theme["unselected_tab"].R + 0.05,
							theme["unselected_tab"].G + 0.05,
							theme["unselected_tab"].B + 0.05
						)
					}):Play()
					if tab_text then
						ts:Create(tab_text, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
							TextColor3 = theme["active_text"]
						}):Play()
					end
				end
			end)

			tab_frame.MouseLeave:Connect(function()
				if window.current_tab ~= tab then
					ts:Create(tab_frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
						BackgroundColor3 = theme["unselected_tab"]
					}):Play()
					if tab_text then
						ts:Create(tab_text, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
							TextColor3 = theme["inactive_text"]
						}):Play()
					end
				end
			end)

			table.insert(window.tabs, tab)

			window.update_tab_sizes()

			if #window.tabs == 1 then
				task.wait()
				window:select_tab(tab)
			end

			print("tab created:", tab_config.name)
			return tab
		end

		function window:select_tab(tab)
			if not tab then return end

			print("selecting tab:", tab.name)

			for _, t in ipairs(window.tabs) do
				ts:Create(t.frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = theme["unselected_tab"]
				}):Play()
				if t.text then
					ts:Create(t.text, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextColor3 = theme["inactive_text"]
					}):Play()
				end
				if t.line then
					ts:Create(t.line, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 1
					}):Play()
				end
				if t.cover then
					t.cover.Visible = false
				end
				if t.content then
					t.content.Visible = false
				end
			end
			ts:Create(tab.frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = theme["selected_tab"]
			}):Play()
			if tab.text then
				ts:Create(tab.text, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = theme["accent_text"]
				}):Play()
			end
			if tab.line then
				tab.line.BackgroundColor3 = theme["accent"]
				ts:Create(tab.line, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0
				}):Play()
			end
			if tab.cover then
				tab.cover.Visible = true
			end
			if tab.content then
				tab.content.Visible = true
			end
			window.current_tab = tab
		end

		function window:get_tab(name)
			for _, tab in ipairs(window.tabs) do
				if tab.name == name then
					return tab
				end
			end
			return nil
		end

		print("window creation complete")
		return window
	end

	shared.enviro.ui_library.library = library
	return library
end)

--[[example usage
execute(function()
	print("eaeaea...")

	local lib = shared.enviro.ui_library.library
	if not lib then 
		warn("library not initialized")
		return
	end
	print("library found:", lib)

	if not shared.enviro.ui_library.assets then
		warn("assets not initialized")
		return
	end
	print("assets found")

	if not shared.enviro.ui_library.assets.screen then
		warn("screen asset not found")
		return
	end
	print("screen asset found")

	if not shared.enviro.ui_library.assets.window then
		warn("window asset not found")
		return
	end
	print("window asset found")

	local screen = shared.enviro.ui_library.assets.screen:Clone()
	screen.Parent = services.players.LocalPlayer.PlayerGui
	print("screen created to PlayerGui")

	local menus_gui = screen:FindFirstChild("MENUS")
	if not menus_gui then
		warn("MENUS ScreenGui not found in screen")
		return
	end
	print("MENUS ScreenGui found")

	local main_window = lib.create_window({
		window_name = "Telegram Hub",
		sub_title = "Welcome to the best hub!",
		color = Color3.fromRGB(0, 160, 255),
		keybind = Enum.KeyCode.RightShift
	}, menus_gui)

	if main_window then
		print("example window created successfully")
		print("press RightShift to toggle window visibility")

		local tab1 = main_window:add_tab({name = "Combat"})
		local tab2 = main_window:add_tab({name = "Movement"})
		local tab3 = main_window:add_tab({name = "Visuals"})
		local tab4 = main_window:add_tab({name = "Settings"})

		print("example tabs created")

		if tab1 then
			local aimbot_section = tab1:add_section({name = "Aimbot", side = "left", size = 200})
			local target_section = tab1:add_section({name = "Target Settings", side = "left", size = 180})
			local settings_section = tab1:add_section({name = "Aimbot Settings", side = "right", size = 250})

			if aimbot_section then
				aimbot_section:add_slider({
					name = "Speed Multiplier",
					min = 16,
					max = 250,
					default = 16,
					callback = function(value)
						print("speed val:", value)
					end
				})

				aimbot_section:add_label({
					text = "Welcome to the menu!",
					side = "left",
					color = Color3.fromRGB(0, 200, 255)
				})

				aimbot_section:add_button({
					name = "Reset Settings",
					callback = function()
						print("yoo")
					end
				})
			end

			if settings_section then

			end
		end

		if tab2 then
			local speed_section = tab2:add_section({name = "Speed", side = "left", size = 150})
			local flight_section = tab2:add_section({name = "Flight", side = "right", size = 150})

			if speed_section then

			end

			if flight_section then

			end
		end

		print("example sections created")
	else
		warn("failed to create example window")
	end
end)]]
