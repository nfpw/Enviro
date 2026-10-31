--[[
	- Logs RemoteEvent:FireServer, RemoteFunction:InvokeServer and UnreliableRemoteEvent:FireServer (namecall and, if you want,
	  direct calls like Remote.FireServer(Remote, ...)). Optional: BindableEvent:Fire / BindableFunction:Invoke and incoming
	  OnClientEvent.
	- Actors: scripts inside Actors run in their own Lua VM, so a normal hook never sees their remotes. With "Spy on actors" the
	  spy injects a small hook into every actor (getactors + run_on_actor, or getactorthreads + run_on_thread) that sends the
	  calls back through a comm channel. New actors are picked up while "Watch for new actors" is on.
	- Click a call for its generated code (copy it, or run it again), the remote's path, the calling script and the actor.
	  Block stops the game from firing that remote, Ignore hides it.
	- Settings (saved to LarpSpy/settings.json): what is hooked, actors, max logs, merging repeats, ignored names,
	  code style, accent colour and the toggle key.

	Running the script again replaces the old window (the hooks stay installed once and are reused).
]]

local Env = (getgenv and getgenv())

if Env.LarpSpy and Env.LarpSpy.Destroy then
	pcall(Env.LarpSpy.Destroy)
end

local CloneRef = cloneref or function(Object) return Object end

local Players = CloneRef(game:GetService("Players"))
local UserInputService = CloneRef(game:GetService("UserInputService"))
local RunService = CloneRef(game:GetService("RunService"))
local HttpService = CloneRef(game:GetService("HttpService"))
local TweenService = CloneRef(game:GetService("TweenService"))
local CoreGui = CloneRef(game:GetService("CoreGui"))

local Folder = "LarpSpy"
local FontUrl = "https://raw.githubusercontent.com/nfpw/Enviro/main/ui_library/assets/Monaco.ttf"
local IconBase = "https://raw.githubusercontent.com/nfpw/Enviro/main/ui_library/assets/spy_icons/" -- put the png files from spy_icons/ here (one per call kind)

local X = { } -- executor functions
local UI = { } -- interface objects

X.GetNamecallMethod = getnamecallmethod
X.HookMetamethod = hookmetamethod
X.HookFunction = hookfunction or replaceclosure
X.NewCClosure = newcclosure or function(Function) return Function end
X.CheckCaller = checkcaller or function() return false end
X.GetCallingScript = getcallingscript or function() return nil end
X.SetClipboard = setclipboard or toclipboard or set_clipboard
X.GetHui = gethui or get_hidden_gui
X.FireSignal = firesignal or fire_signal
X.ReplicateSignal = replicatesignal or replicate_signal

X.GetBytecode = getscriptbytecode or get_script_bytecode or dumpstring
X.Request = (syn and syn.request) or (http and http.request) or http_request or request
X.GetActors = getactors or (syn and syn.getactors)
X.RunOnActor = run_on_actor or (syn and syn.run_on_actor)
X.GetActorThreads = getactorthreads
X.RunOnThread = run_on_thread
X.CreateCommChannel = create_comm_channel or (syn and syn.create_comm_channel)

local RGB = Color3.fromRGB

-- settings

local Settings = {
	Events = true, -- RemoteEvent:FireServer
	Functions = true, -- RemoteFunction:InvokeServer
	Unreliable = true, -- UnreliableRemoteEvent:FireServer
	Bindables = false, -- BindableEvent:Fire / BindableFunction:Invoke
	Incoming = false, -- OnClientEvent (server -> you)
	Direct = true, -- Remote.FireServer(Remote, ...) as well as Remote:FireServer(...)
	Executor = false, -- calls made by executor scripts (this one's Run button included)
	Actors = true,
	WatchActors = true,
	MaxLogs = 300,
	Stack = "remote", -- "remote": one row per remote with a xN counter, "same args": only identical calls stack, "off"
	StackToTop = false,
	HistoryLimit = 50, -- past calls kept per stacked row -- a stacked row moves back to the top when it's called again
	IgnoreNames = "", -- comma separated, Lua patterns
	OnlyNames = "", -- comma separated, Lua patterns: when set, only matching remotes are logged
	AutoCopy = false, -- copy the generated code when a call is selected
	EscapeUnicode = true, -- strings: non-ASCII characters as \u{XXXX} (the Monaco font has no glyphs for them, so they showed up wrong)
	PauseKey = "None", -- key that pauses / resumes logging
	ExportFormat = "code", -- "code" (runnable calls) or "summary" (one line per call)
	Require = false, -- require(ModuleScript) calls from game scripts
	Kicks = true, -- LocalPlayer:Kick
	BlockKicks = false,
	Teleports = true, -- TeleportService:Teleport / TeleportToPlaceInstance / TeleportToSpawnByName
	BlockTeleports = false,
	FireSignals = true, -- firesignal(...) calls from executor scripts
	ReplicateSignals = true, -- replicatesignal(...) calls from executor scripts
	CodeStyle = "table", -- "table" ([1] = ...), "array" ({a, b}), "inline" (in the call), "variables" (local arg1 = ...)
	PathStyle = "GetService", -- "GetService" (.Name, FindFirstChild for odd names), "dot" (.Name / ["odd name"]), "WaitForChild", "FindFirstChild"
	RemoteVariable = false, -- local remote = <path> first
	Wrap = "none", -- "none", "loop" (for i = 1, LoopCount), "while" (while task.wait), "spawn" (task.spawn), "pcall"
	LoopCount = 10,
	LoopDelay = 0,
	Unpack = "unpack", -- "unpack" or "table.unpack"
	CallerComment = true,
	Accent = "Blue",
	ToggleKey = "RightControl",
}

local function EnsureFolder()
	if isfolder and makefolder and not isfolder(Folder) then
		pcall(makefolder, Folder)
	end
end

do
	local Ok, Saved = pcall(function()
		return HttpService:JSONDecode(readfile(Folder .. "/settings.json"))
	end)

	if Ok and type(Saved) == "table" then
		for Key, Value in Saved do
			if Settings[Key] ~= nil and type(Settings[Key]) == type(Value) then
				Settings[Key] = Value
			end
		end
	end
end

local function SaveSettings()
	if writefile then
		EnsureFolder()
		pcall(writefile, Folder .. "/settings.json", HttpService:JSONEncode(Settings))
	end
end

UI.AccentPresets = {
	{"Blue", RGB(120, 200, 255)},
	{"Pink", RGB(255, 120, 190)},
	{"Green", RGB(120, 230, 150)},
	{"Orange", RGB(255, 170, 90)},
	{"Purple", RGB(180, 140, 255)},
	{"Red", RGB(255, 100, 100)},
}

local function PresetColor(Name)
	for _, Preset in UI.AccentPresets do
		if Preset[1] == Name then
			return Preset[2]
		end
	end

	return UI.AccentPresets[1][2]
end

-- the Larp "Preset" theme
local T = {
	Background = RGB(13, 14, 18),
	Border = RGB(7, 8, 10),
	Inline = RGB(18, 20, 25),
	Hover = RGB(40, 44, 54),
	Page = RGB(23, 25, 31),
	Outline = RGB(45, 49, 60),
	Element = RGB(29, 32, 39),
	Text = RGB(232, 234, 240),
	Dim = RGB(151, 153, 160),
	Accent = PresetColor(Settings.Accent),
	Bad = RGB(235, 90, 90),
}

local Hex = {Dim = "#979aa0", Accent = "#" .. T.Accent:ToHex()}

-- what each kind of call looks like in the list
local Kinds = {
	event = {Tag = "fire", Color = nil}, -- accent
	unreliable = {Tag = "unrel", Color = RGB(120, 220, 200)},
	["function"] = {Tag = "invoke", Color = RGB(200, 140, 255)},
	bindable = {Tag = "bind", Color = RGB(180, 180, 190)},
	incoming = {Tag = "in", Color = RGB(130, 220, 120)},
	require = {Tag = "req", Color = RGB(255, 190, 90)},
	kick = {Tag = "kick", Color = RGB(235, 90, 90)},
	teleport = {Tag = "tp", Color = RGB(240, 220, 100)},
	firesignal = {Tag = "fsig", Color = RGB(255, 150, 220)},
	replicatesignal = {Tag = "rsig", Color = RGB(150, 170, 255)},
}

local function KindColor(Kind)
	return Kinds[Kind] and Kinds[Kind].Color or T.Accent
end

-- hooks: installed once per session and reused when the script runs again (Shared.Capture is swapped)

local Methods = {
	FireServer = true, fireServer = true, InvokeServer = true, invokeServer = true, Fire = true, Invoke = true,
	Kick = true, kick = true, Teleport = true, TeleportToPlaceInstance = true, TeleportToSpawnByName = true,
}

local TeleportMethods = {Teleport = true, TeleportToPlaceInstance = true, TeleportToSpawnByName = true}

local function KindOf(Class, Method, Object)
	if Method == "FireServer" or Method == "fireServer" then
		if Class == "RemoteEvent" then
			return Settings.Events and "event"
		elseif Class == "UnreliableRemoteEvent" then
			return Settings.Unreliable and "unreliable"
		end
	elseif Method == "InvokeServer" or Method == "invokeServer" then
		return Class == "RemoteFunction" and Settings.Functions and "function"
	elseif Method == "Fire" then
		return Class == "BindableEvent" and Settings.Bindables and "bindable"
	elseif Method == "Invoke" then
		return Class == "BindableFunction" and Settings.Bindables and "bindable"
	elseif Method == "Kick" or Method == "kick" then
		return Class == "Player" and Object == Players.LocalPlayer and Settings.Kicks and "kick"
	elseif TeleportMethods[Method] then
		return Class == "TeleportService" and Settings.Teleports and "teleport"
	elseif Method == "require" then
		return Class == "ModuleScript" and Settings.Require and "require"
	end

	return nil
end

local Shared = Env.__LarpSpyShared
local HookStatus = "hooked"

if not Shared then
	Shared = {Capture = function() return false end, Installed = { }}
	Env.__LarpSpyShared = Shared
elseif not Shared.Installed then
	-- hooks from an older version of this script: they stay, only the new ones get added (kick / teleport by namecall need a rejoin)
	Shared.Installed = {Namecall = true, Legacy = true, FireServer = true, UnreliableFireServer = true, InvokeServer = true, Fire = true, Invoke = true}
end

Shared.Methods = Methods

local function Capture(...)
	local Ok, Block = pcall(Shared.Capture, ...)

	return Ok and Block == true
end

if not Shared.Installed.Namecall then
	if X.GetNamecallMethod and (X.HookMetamethod or getrawmetatable) then
		local OldNamecall

		local Hook = X.NewCClosure(function(self, ...)
			local Method = X.GetNamecallMethod()

			if Shared.Methods[Method] and Capture(self, Method, false, ...) then
				return nil
			end

			return OldNamecall(self, ...)
		end)

		if X.HookMetamethod then
			OldNamecall = X.HookMetamethod(game, "__namecall", Hook)
		else
			local Meta = getrawmetatable(game)

			OldNamecall = Meta.__namecall

			if setreadonly then
				setreadonly(Meta, false)
			end

			Meta.__namecall = Hook

			if setreadonly then
				setreadonly(Meta, true)
			end
		end

		Shared.Installed.Namecall = true
	else
		HookStatus = "no hookmetamethod"
	end
end

-- direct calls (Remote.FireServer(Remote, ...), Player.Kick(Player), ...): the C functions themselves
local function HookDirect(Key, Getter, Method)
	if not X.HookFunction or Shared.Installed[Key] then
		return
	end

	pcall(function()
		local Original = Getter()
		local Old

		Old = X.HookFunction(Original, X.NewCClosure(function(self, ...)
			if Capture(self, Method, true, ...) then
				return nil
			end

			return Old(self, ...)
		end))

		Shared.Installed[Key] = true
	end)
end

local function Probe(Class, Method)
	return function()
		local Object = Instance.new(Class)
		local Function = Object[Method]

		Object:Destroy()

		return Function
	end
end

HookDirect("FireServer", Probe("RemoteEvent", "FireServer"), "FireServer")
HookDirect("UnreliableFireServer", Probe("UnreliableRemoteEvent", "FireServer"), "FireServer")
HookDirect("InvokeServer", Probe("RemoteFunction", "InvokeServer"), "InvokeServer")
HookDirect("Fire", Probe("BindableEvent", "Fire"), "Fire")
HookDirect("Invoke", Probe("BindableFunction", "Invoke"), "Invoke")
HookDirect("Kick", function() return Players.LocalPlayer.Kick end, "Kick")

for Method in TeleportMethods do
	HookDirect(Method, function() return game:GetService("TeleportService")[Method] end, Method)
end

-- require: hooked only once it's turned on (a module that yields while loading goes through this hook)
local function InstallRequire()
	if Shared.Installed.Require or not X.HookFunction or not getrenv then
		return Shared.Installed.Require == true
	end

	local Ok = pcall(function()
		local Real = getrenv().require
		local Old

		Old = X.HookFunction(Real, X.NewCClosure(function(Module, ...)
			local Results = table.pack(Old(Module, ...))

			pcall(Shared.CaptureRequire, Module, Results)

			return table.unpack(Results, 1, Results.n)
		end))
	end)

	Shared.Installed.Require = Ok

	return Ok
end

if Settings.Require then
	InstallRequire()
end

-- firesignal / replicatesignal: executor functions, so only other executor scripts call them
local function HookSignalFunction(Name, Function)
	if not X.HookFunction or type(Function) ~= "function" or Shared.Installed[Name] then
		return
	end

	pcall(function()
		local Old

		Old = X.HookFunction(Function, X.NewCClosure(function(Signal, ...)
			local Ok, Block = pcall(Shared.CaptureSignal, Name, Signal, ...)

			if Ok and Block then
				return nil
			end

			return Old(Signal, ...)
		end))

		Shared.Installed[Name] = true
	end)
end

HookSignalFunction("firesignal", X.FireSignal)
HookSignalFunction("replicatesignal", X.ReplicateSignal)

-- state

local Active = true
local Paused = false
local Logs = { } -- newest first
local DetailsDirty = false
local Stacks = { } -- [Remote] = {[Method|Kind|Actor] = Log}: the row new calls of that remote stack onto
local Queue = { }
local Blocked = { } -- [Remote] = true
local Ignored = { } -- [Remote] = true
local SelfIgnore = { } -- our own channel
local IgnorePatterns = { }
local Channel = nil

local function ParseIgnore()
	IgnorePatterns = { }

	for Piece in Settings.IgnoreNames:gmatch("[^,]+") do
		Piece = Piece:match("^%s*(.-)%s*$")

		if Piece ~= "" then
			table.insert(IgnorePatterns, Piece)
		end
	end
end

local OnlyPatterns = { }

local function ParseOnly()
	OnlyPatterns = { }

	for Piece in Settings.OnlyNames:gmatch("[^,]+") do
		Piece = Piece:match("^%s*(.-)%s*$")

		if Piece ~= "" then
			table.insert(OnlyPatterns, Piece)
		end
	end
end

ParseIgnore()
ParseOnly()

local function NameIgnored(Name)
	if #OnlyPatterns > 0 then
		local Allowed = false

		for _, Pattern in OnlyPatterns do
			local Ok, Found = pcall(string.find, Name, Pattern)

			if Ok and Found then
				Allowed = true
				break
			end
		end

		if not Allowed then
			return true
		end
	end

	for _, Pattern in IgnorePatterns do
		local Ok, Found = pcall(string.find, Name, Pattern)

		if Ok and Found then
			return true
		end
	end

	return false
end

-- copies tables right away (the game may change them after firing), keeps everything else as it is
local function DeepCopy(Value, Seen)
	if type(Value) ~= "table" then
		return Value
	end

	Seen = Seen or { }

	if Seen[Value] then
		return Seen[Value]
	end

	local Copy = { }

	Seen[Value] = Copy

	for Key, Inner in next, Value do
		Copy[DeepCopy(Key, Seen)] = DeepCopy(Inner, Seen)
	end

	return Copy
end

local function Push(Remote, Method, Kind, Script, Actor, Count, ...)
	local Args = {...}

	for Index = 1, Count do
		Args[Index] = DeepCopy(Args[Index])
	end

	table.insert(Queue, {
		Remote = Remote,
		Method = Method,
		Kind = Kind,
		Script = Script,
		Actor = Actor,
		Args = Args,
		Count = Count,
		Calls = 1,
		Time = os.date("%H:%M:%S"),
	})
end

Shared.Capture = function(self, Method, Direct, ...)
	-- a require hook from an older version of this script
	if Method == "require" then
		Shared.CaptureRequire(self, nil)

		return false
	end

	if not Active or typeof(self) ~= "Instance" or SelfIgnore[self] then
		return false
	end

	local Kind = KindOf(self.ClassName, Method, self)

	if not Kind then
		return false
	end

	if Direct and not Settings.Direct then
		return false
	end

	local FromExecutor = X.CheckCaller()

	if FromExecutor and not Settings.Executor then
		return false
	end

	if not Paused and not Ignored[self] and not NameIgnored(self.Name) then
		Push(self, Method, Kind, X.GetCallingScript(), nil, select("#", ...), ...)
	end

	local Block = Blocked[self] == true

	if Kind == "kick" then
		Block = Settings.BlockKicks

		if Block then
			task.defer(function() Shared.Notify("blocked a kick") end)
		end
	elseif Kind == "teleport" then
		Block = Settings.BlockTeleports

		if Block then
			task.defer(function() Shared.Notify("blocked a teleport") end)
		end
	elseif Kind == "require" then
		Block = false
	end

	return Block and not FromExecutor
end

Shared.Notify = function() end

-- require(module): the module (or asset id) is the argument, what it returned is kept
Shared.CaptureRequire = function(Module, Results)
	if not Active or Paused or not Settings.Require then
		return
	end

	if X.CheckCaller() and not Settings.Executor then
		return
	end

	local IsInstance = typeof(Module) == "Instance"
	local Name = IsInstance and Module.Name or ("asset " .. tostring(Module))

	if Ignored[Module] or NameIgnored(Name) then
		return
	end

	Push(Module, "require", "require", X.GetCallingScript(), nil, 1, Module)

	Queue[#Queue].Result = Results
end

-- firesignal / replicatesignal: the signal can't be stored as the "remote" (a new object every time it's indexed),
-- so its name is the key and the owner instance is looked up when the call is opened
local Replaying = false

Shared.CaptureSignal = function(Name, Signal, ...)
	if not Active or Paused or Replaying then
		return false
	end

	if (Name == "firesignal" and not Settings.FireSignals) or (Name == "replicatesignal" and not Settings.ReplicateSignals) then
		return false
	end

	if typeof(Signal) ~= "RBXScriptSignal" then
		return false
	end

	local Key = tostring(Signal)
	local Event = Key:match("^Signal (.+)$") or Key

	if Ignored[Key] or NameIgnored(Event) then
		return Blocked[Key] == true
	end

	Push(Key, Name, Name, X.GetCallingScript(), nil, select("#", ...), ...)

	local Log = Queue[#Queue]

	Log.Signal = Signal
	Log.EventName = Event

	return Blocked[Key] == true
end

-- ui helpers

local Connections = { }

local function Connect(Signal, Callback)
	local Connection = Signal:Connect(Callback)

	table.insert(Connections, Connection)

	return Connection
end

local function HttpGet(Url)
	local Ok, Body = pcall(function()
		return game:HttpGet(Url)
	end)

	if Ok and type(Body) == "string" and #Body > 0 then
		return Body
	end

	return nil
end

local FontFace, FontSize, Pixel = (function()
	local Ok, Face = pcall(function()
		assert(writefile and isfile and getcustomasset)

		EnsureFolder()

		local Ttf = Folder .. "/Monaco.ttf"
		local Json = Folder .. "/Monaco.json"

		if not isfile(Ttf) then
			writefile(Ttf, assert(HttpGet(FontUrl)))
		end

		writefile(Json, HttpService:JSONEncode({name = "Monaco", faces = {{name = "Regular", weight = 400, style = "Regular", assetId = getcustomasset(Ttf)}}}))

		return Font.new(getcustomasset(Json))
	end)

	if Ok and Face then
		return Face, 9, true
	end

	return Font.fromEnum(Enum.Font.RobotoMono), 12, false
end)()

-- one small png per call kind (spy_icons/ on github), downloaded once into LarpSpy/icons and tinted with the kind's colour
local KindIcons = { }

do
	pcall(function()
		assert(writefile and isfile and getcustomasset)

		EnsureFolder()

		if makefolder and isfolder and not isfolder(Folder .. "/icons") then
			makefolder(Folder .. "/icons")
		end

		for _, Name in {"event", "unreliable", "function", "bindable", "incoming", "require", "kick", "teleport", "firesignal", "replicatesignal"} do
			local Path = Folder .. "/icons/" .. Name .. ".png"

			if not isfile(Path) then
				local Ok, Data = pcall(HttpGet, IconBase .. Name .. ".png")

				if Ok and type(Data) == "string" and #Data > 50 and Data:sub(2, 4) == "PNG" then
					writefile(Path, Data)
				end
			end

			if isfile(Path) then
				KindIcons[Name] = getcustomasset(Path)
			end
		end
	end)
end

local Accented = { } -- {Object, Property} that follow the accent colour

local function Accent(Object, Property)
	table.insert(Accented, {Object, Property})
	Object[Property] = T.Accent

	return Object
end

local function New(Class, Props)
	local Object = Instance.new(Class)

	for Key, Value in Props do
		if Key ~= "Parent" then
			Object[Key] = Value
		end
	end

	Object.Parent = Props.Parent

	return Object
end

local function Stroke(Parent, Color)
	return New("UIStroke", {Parent = Parent, Color = Color or T.Outline, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter})
end

local function Text(Parent, Props, Class)
	local Base = {
		Parent = Parent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FontFace,
		TextSize = FontSize,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}

	if Class == "TextButton" then
		Base.AutoButtonColor = false
	end

	for Key, Value in Props do
		Base[Key] = Value
	end

	local Label = New(Class or "TextLabel", Base)

	if Pixel then
		New("UIStroke", {Parent = Label, Color = RGB(0, 0, 0), Transparency = 0.6, Thickness = 1, LineJoinMode = Enum.LineJoinMode.Miter})
	end

	return Label
end

local function Tween(Object, Goal, Time)
	local Playing = TweenService:Create(Object, TweenInfo.new(Time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), Goal)

	Playing:Play()

	return Playing
end

local function Esc(String)
	return (tostring(String):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function Glow(Parent, Height, Top)
	local Frame = Accent(New("Frame", {Parent = Parent, Size = UDim2.new(1, 0, 0, Height), BorderSizePixel = 0}), "BackgroundColor3")

	New("UIGradient", {Parent = Frame, Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, Top), NumberSequenceKeypoint.new(0.193, 0.869), NumberSequenceKeypoint.new(0.504, 0.969), NumberSequenceKeypoint.new(1, 1)})})

	return Frame
end

-- a Larp section: inline background, border, accent line and glow on top, title
local function Panel(Parent, Title)
	local Frame = New("Frame", {Parent = Parent, BackgroundColor3 = T.Inline, BorderSizePixel = 2, BorderColor3 = T.Outline, ClipsDescendants = true})

	Stroke(Frame, T.Border)
	Accent(New("Frame", {Parent = Frame, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 2}), "BackgroundColor3")
	Glow(Frame, 15, 0)

	local Head = Text(Frame, {Name = "Title", Position = UDim2.new(0, 7, 0, 5), Size = UDim2.new(1, -14, 0, 12), Text = Title})

	return Frame, Head
end

local function Input(Parent, Props, Placeholder)
	local Holder = New("Frame", {Parent = Parent, BackgroundColor3 = T.Element, BorderSizePixel = 0})

	for Key, Value in Props do
		Holder[Key] = Value
	end

	local HolderStroke = Stroke(Holder, T.Outline)
	local Box = Text(Holder, {Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -12, 1, 0), PlaceholderText = Placeholder or "", PlaceholderColor3 = T.Dim, ClearTextOnFocus = false}, "TextBox")

	Connect(Box.Focused, function() Tween(HolderStroke, {Color = T.Accent}) end)
	Connect(Box.FocusLost, function() Tween(HolderStroke, {Color = T.Outline}) end)

	return Box, Holder
end

local function Button(Parent, Label, Props, Callback)
	local Object = Text(Parent, {BackgroundTransparency = 0, BackgroundColor3 = T.Element, Text = Label, TextXAlignment = Enum.TextXAlignment.Center}, "TextButton")

	for Key, Value in Props do
		Object[Key] = Value
	end

	Stroke(Object, T.Outline)

	if Object.AutomaticSize == Enum.AutomaticSize.X then
		New("UIPadding", {Parent = Object, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
	end

	Connect(Object.MouseEnter, function() Tween(Object, {BackgroundColor3 = T.Hover}) end)
	Connect(Object.MouseLeave, function() Tween(Object, {BackgroundColor3 = T.Element}) end)

	if Callback then
		Connect(Object.MouseButton1Click, Callback)
	end

	return Object
end

local function HorizontalList(Parent, Padding)
	return New("UIListLayout", {Parent = Parent, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Padding or 5), SortOrder = Enum.SortOrder.LayoutOrder})
end

-- window

local Gui = New("ScreenGui", {Name = HttpService:GenerateGUID(false), ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999998})

if syn and syn.protect_gui then
	pcall(syn.protect_gui, Gui)
end

if not (X.GetHui and pcall(function() Gui.Parent = X.GetHui() end) and Gui.Parent) then
	if not pcall(function() Gui.Parent = CoreGui end) then
		Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

local Main = New("Frame", {
	Parent = Gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 760, 0, 480),
	BackgroundColor3 = T.Background,
	BorderSizePixel = 2,
	BorderColor3 = T.Outline,
})

Stroke(Main, T.Border)
Accent(New("Frame", {Parent = Main, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 2}), "BackgroundColor3")
Glow(Main, 20, 0.55)

UI.TitleBar = New("Frame", {Parent = Main, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Active = true})
UI.TitleText = Text(UI.TitleBar, {Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0, 130, 1, 0), RichText = true})

local function DrawTitle()
	UI.TitleText.Text = '<font color="' .. Hex.Accent .. '">Larp</font> remote spy'
end

DrawTitle()

local Tabs = New("Frame", {Parent = UI.TitleBar, Position = UDim2.new(0, 140, 0, 4), Size = UDim2.new(0, 200, 0, 16), BackgroundTransparency = 1})

HorizontalList(Tabs, 4)

local Status = Text(UI.TitleBar, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 0), Size = UDim2.new(0, 280, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Dim, Text = HookStatus})

local function SetStatus(Message)
	Status.Text = Message
end

Shared.Notify = SetStatus

local Inner = New("Frame", {Parent = Main, Position = UDim2.new(0, 6, 0, 24), Size = UDim2.new(1, -12, 1, -30), BackgroundColor3 = T.Page, BorderSizePixel = 2, BorderColor3 = T.Border})

Stroke(Inner, T.Outline)

local Destroy -- at the bottom

UI.CloseButton = Text(UI.TitleBar, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 18, 0, 18), Text = "x", TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.Dim}, "TextButton")
UI.MinimizeButton = Text(UI.TitleBar, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -26, 0.5, 0), Size = UDim2.new(0, 18, 0, 18), Text = "-", TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.Dim}, "TextButton")

for _, Object in {UI.CloseButton, UI.MinimizeButton} do
	Connect(Object.MouseEnter, function() Tween(Object, {TextColor3 = T.Accent}) end)
	Connect(Object.MouseLeave, function() Tween(Object, {TextColor3 = T.Dim}) end)
end

local Minimized = false
local FullSize = Main.Size

Connect(UI.MinimizeButton.MouseButton1Click, function()
	Minimized = not Minimized
	Inner.Visible = not Minimized

	if Minimized then
		FullSize = Main.Size
		Main.Size = UDim2.new(0, FullSize.X.Offset, 0, 24)
	else
		Main.Size = FullSize
	end
end)

Connect(UI.CloseButton.MouseButton1Click, function()
	Destroy()
end)

do
	local Dragging, DragStart, StartPosition
	local Resizing, ResizeStart, StartSize

	Connect(UI.TitleBar.InputBegan, function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 or InputObject.UserInputType == Enum.UserInputType.Touch then
			Dragging, DragStart, StartPosition = true, InputObject.Position, Main.Position
		end
	end)

	local Resizer = New("TextButton", {Parent = Main, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0, 12, 0, 12), BackgroundTransparency = 1, Text = "", ZIndex = 10})

	New("Frame", {Parent = Resizer, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Size = UDim2.new(0, 6, 0, 1), BackgroundColor3 = T.Dim, BorderSizePixel = 0})
	New("Frame", {Parent = Resizer, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Size = UDim2.new(0, 1, 0, 6), BackgroundColor3 = T.Dim, BorderSizePixel = 0})

	Connect(Resizer.InputBegan, function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 and not Minimized then
			Resizing, ResizeStart, StartSize = true, InputObject.Position, Main.AbsoluteSize
		end
	end)

	Connect(UserInputService.InputChanged, function(InputObject)
		if InputObject.UserInputType ~= Enum.UserInputType.MouseMovement and InputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if Dragging then
			local Delta = InputObject.Position - DragStart

			Main.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
		elseif Resizing then
			local Delta = InputObject.Position - ResizeStart

			Main.Size = UDim2.new(0, math.max(600, StartSize.X + Delta.X), 0, math.max(340, StartSize.Y + Delta.Y))
		end
	end)

	Connect(UserInputService.InputEnded, function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 or InputObject.UserInputType == Enum.UserInputType.Touch then
			Dragging, Resizing = false, false
		end
	end)

	-- keep the top left corner in place when the size changes (AnchorPoint is the middle)
	local LastSize = Main.AbsoluteSize

	Connect(Main:GetPropertyChangedSignal("AbsoluteSize"), function()
		local Grow = Main.AbsoluteSize - LastSize

		LastSize = Main.AbsoluteSize
		Main.Position = Main.Position + UDim2.new(0, Grow.X / 2, 0, Grow.Y / 2)
	end)
end

-- context menu
local Menu = New("ScrollingFrame", {
	Parent = Gui,
	Visible = false,
	BackgroundColor3 = T.Inline,
	BorderSizePixel = 2,
	BorderColor3 = T.Outline,
	ScrollBarThickness = 2,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 50,
})

Accent(Menu, "ScrollBarImageColor3")
Stroke(Menu, T.Border)
New("UIListLayout", {Parent = Menu, SortOrder = Enum.SortOrder.LayoutOrder})

local function CloseMenu()
	Menu.Visible = false
end

local function OpenMenu(Options, Width)
	for _, Child in Menu:GetChildren() do
		if Child:IsA("GuiObject") then
			Child:Destroy()
		end
	end

	for Index, Option in Options do
		local Row = Text(Menu, {LayoutOrder = Index, Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = T.Hover, Text = "  " .. Option[1], TextColor3 = Option[3] or T.Text, ZIndex = 51}, "TextButton")

		Connect(Row.MouseEnter, function() Row.BackgroundTransparency = 0.4 end)
		Connect(Row.MouseLeave, function() Row.BackgroundTransparency = 1 end)
		Connect(Row.MouseButton1Click, function()
			CloseMenu()
			task.spawn(Option[2])
		end)
	end

	Width = Width or 150

	local Mouse = UserInputService:GetMouseLocation()
	local Height = math.min(#Options * 18 + 2, 260)
	local Screen = Gui.AbsoluteSize

	Menu.Size = UDim2.new(0, Width, 0, Height)
	Menu.Position = UDim2.new(0, math.min(Mouse.X, Screen.X - Width - 4), 0, math.min(Mouse.Y, Screen.Y - Height - 4))
	Menu.Visible = true
end

local function Over(Object)
	local Mouse = UserInputService:GetMouseLocation()
	local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize

	return Mouse.X >= Position.X and Mouse.X <= Position.X + Size.X and Mouse.Y >= Position.Y and Mouse.Y <= Position.Y + Size.Y
end

Connect(UserInputService.InputBegan, function(InputObject)
	if Menu.Visible and (InputObject.UserInputType == Enum.UserInputType.MouseButton1 or InputObject.UserInputType == Enum.UserInputType.MouseButton2) and not Over(Menu) then
		CloseMenu()
	end
end)

local function Copy(String)
	if X.SetClipboard then
		X.SetClipboard(String)
		SetStatus("copied to clipboard")
	else
		SetStatus("no setclipboard in this executor")
	end
end

-- code generation

local function NameOf(Object)
	local Ok, Name = pcall(function() return Object.Name end)

	return Ok and tostring(Name) or "?"
end

local function ClassOf(Object)
	local Ok, Class = pcall(function() return Object.ClassName end)

	return Ok and Class or "?"
end

local QuoteMap = {["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ['"'] = '\\"', ["\\"] = "\\\\"}

local function Quote(String)
	String = tostring(String)

	-- valid UTF-8: walk it character by character. invalid bytes (random binary, broken text) get escaped one by one
	if utf8.len(String) then
		return '"' .. String:gsub(utf8.charpattern, function(Character)
			local Code = utf8.codepoint(Character)

			if Code > 127 then
				return Settings.EscapeUnicode and string.format("\\u{%X}", Code) or Character
			elseif QuoteMap[Character] then
				return QuoteMap[Character]
			elseif Code < 32 or Code == 127 then
				return string.format("\\%03d", Code)
			end

			return Character
		end) .. '"'
	end

	return '"' .. String:gsub('[%c"\\\128-\255]', function(Character)
		return QuoteMap[Character] or string.format("\\%03d", Character:byte())
	end) .. '"'
end

local function Number(Value)
	if Value ~= Value then
		return "0/0"
	elseif Value == math.huge then
		return "math.huge"
	elseif Value == -math.huge then
		return "-math.huge"
	end

	return tostring(Value)
end

-- Context = {NeedsNil = bool}: nil instances use a getnil helper put above the code
local function PathOf(Object, Context)
	if Object == game then
		return "game"
	end

	local Chain = { }
	local Current = Object

	while Current and Current ~= game do
		table.insert(Chain, 1, Current)

		local Ok, Parent = pcall(function() return Current.Parent end)

		Current = Ok and Parent or nil
	end

	local Style = Settings.PathStyle

	local function Index(Child)
		local Name = NameOf(Child)

		if Style == "WaitForChild" then
			return ":WaitForChild(" .. Quote(Name) .. ")"
		elseif Style == "FindFirstChild" then
			return ":FindFirstChild(" .. Quote(Name) .. ")"
		elseif Name:match("^[%a_][%w_]*$") then
			return "." .. Name
		elseif Style == "dot" then
			return "[" .. Quote(Name) .. "]"
		end

		return ":FindFirstChild(" .. Quote(Name) .. ")"
	end

	local Path, Start = nil, 2

	if Current == game then
		local First = Chain[1]
		local IsService = pcall(function() assert(game:FindService(First.ClassName) == First) end)

		if First == workspace then
			Path = "workspace"
		elseif IsService then
			Path = 'game:GetService("' .. First.ClassName .. '")'
		else
			Path = "game" .. Index(First)
		end

		if First == Players and Chain[2] == Players.LocalPlayer then
			Path ..= ".LocalPlayer"
			Start = 3
		end
	else
		if Context then
			Context.NeedsNil = true
		end

		Path = "getnil(" .. Quote(NameOf(Chain[1])) .. ", " .. Quote(ClassOf(Chain[1])) .. ")"
	end

	for Position = Start, #Chain do
		Path ..= Index(Chain[Position])
	end

	return Path
end

local Serialize

local function SerializeTable(Value, Depth, Seen, Context)
	if Seen[Value] then
		return "{} --[[ cycle ]]"
	end

	if Depth > 25 then
		return "{} --[[ too deep ]]"
	end

	Seen[Value] = true

	local Indent = string.rep("    ", Depth + 1)
	local Lines = { }
	local Length = #Value
	local Count = 0

	for Index = 1, Length do
		Count += 1

		if Count > 1000 then
			table.insert(Lines, Indent .. "-- ...")
			break
		end

		table.insert(Lines, Indent .. Serialize(Value[Index], Depth + 1, Seen, Context) .. ",")
	end

	local Keys = { }

	for Key in next, Value do
		if not (type(Key) == "number" and Key >= 1 and Key <= Length and Key % 1 == 0) then
			table.insert(Keys, Key)
		end
	end

	table.sort(Keys, function(A, B)
		if type(A) == type(B) and (type(A) == "number" or type(A) == "string") then
			return A < B
		end

		return type(A) < type(B)
	end)

	for _, Key in Keys do
		Count += 1

		if Count > 1000 then
			table.insert(Lines, Indent .. "-- ...")
			break
		end

		local KeyText

		if type(Key) == "string" and Key:match("^[%a_][%w_]*$") then
			KeyText = Key
		else
			KeyText = "[" .. Serialize(Key, Depth + 1, Seen, Context) .. "]"
		end

		table.insert(Lines, Indent .. KeyText .. " = " .. Serialize(Value[Key], Depth + 1, Seen, Context) .. ",")
	end

	Seen[Value] = nil

	if #Lines == 0 then
		return "{}"
	end

	return "{\n" .. table.concat(Lines, "\n") .. "\n" .. string.rep("    ", Depth) .. "}"
end

local function List(Values)
	local Out = { }

	for _, Value in Values do
		table.insert(Out, Number(Value))
	end

	return table.concat(Out, ", ")
end

Serialize = function(Value, Depth, Seen, Context)
	Depth = Depth or 0
	Seen = Seen or { }

	local Type = typeof(Value)

	if Type == "nil" then
		return "nil"
	elseif Type == "boolean" then
		return tostring(Value)
	elseif Type == "number" then
		return Number(Value)
	elseif Type == "string" then
		return Quote(Value)
	elseif Type == "table" then
		return SerializeTable(Value, Depth, Seen, Context)
	elseif Type == "Instance" then
		return PathOf(Value, Context)
	elseif Type == "Vector3" then
		return "Vector3.new(" .. List({Value.X, Value.Y, Value.Z}) .. ")"
	elseif Type == "Vector2" then
		return "Vector2.new(" .. List({Value.X, Value.Y}) .. ")"
	elseif Type == "Vector3int16" then
		return "Vector3int16.new(" .. List({Value.X, Value.Y, Value.Z}) .. ")"
	elseif Type == "Vector2int16" then
		return "Vector2int16.new(" .. List({Value.X, Value.Y}) .. ")"
	elseif Type == "CFrame" then
		return "CFrame.new(" .. List({Value:GetComponents()}) .. ")"
	elseif Type == "Color3" then
		return "Color3.new(" .. List({Value.R, Value.G, Value.B}) .. ")"
	elseif Type == "BrickColor" then
		return "BrickColor.new(" .. Quote(Value.Name) .. ")"
	elseif Type == "UDim2" then
		return "UDim2.new(" .. List({Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset}) .. ")"
	elseif Type == "UDim" then
		return "UDim.new(" .. List({Value.Scale, Value.Offset}) .. ")"
	elseif Type == "EnumItem" then
		return tostring(Value)
	elseif Type == "Enum" then
		return "Enum." .. tostring(Value)
	elseif Type == "NumberRange" then
		return "NumberRange.new(" .. List({Value.Min, Value.Max}) .. ")"
	elseif Type == "Rect" then
		return "Rect.new(" .. List({Value.Min.X, Value.Min.Y, Value.Max.X, Value.Max.Y}) .. ")"
	elseif Type == "Ray" then
		return "Ray.new(" .. Serialize(Value.Origin) .. ", " .. Serialize(Value.Direction) .. ")"
	elseif Type == "NumberSequence" then
		local Points = { }

		for _, Point in Value.Keypoints do
			table.insert(Points, "NumberSequenceKeypoint.new(" .. List({Point.Time, Point.Value, Point.Envelope}) .. ")")
		end

		return "NumberSequence.new({" .. table.concat(Points, ", ") .. "})"
	elseif Type == "ColorSequence" then
		local Points = { }

		for _, Point in Value.Keypoints do
			table.insert(Points, "ColorSequenceKeypoint.new(" .. Number(Point.Time) .. ", " .. Serialize(Point.Value) .. ")")
		end

		return "ColorSequence.new({" .. table.concat(Points, ", ") .. "})"
	elseif Type == "buffer" then
		return "buffer.fromstring(" .. Quote(buffer.tostring(Value)) .. ")"
	elseif Type == "DateTime" then
		return "DateTime.fromUnixTimestampMillis(" .. Value.UnixTimestampMillis .. ")"
	elseif Type == "TweenInfo" then
		return "TweenInfo.new(" .. List({Value.Time}) .. ", " .. tostring(Value.EasingStyle) .. ", " .. tostring(Value.EasingDirection) .. ", " .. List({Value.RepeatCount}) .. ", " .. tostring(Value.Reverses) .. ", " .. List({Value.DelayTime}) .. ")"
	elseif Type == "Font" then
		return "Font.new(" .. Quote(Value.Family) .. ", " .. tostring(Value.Weight) .. ", " .. tostring(Value.Style) .. ")"
	elseif Type == "PhysicalProperties" then
		return "PhysicalProperties.new(" .. List({Value.Density, Value.Friction, Value.Elasticity, Value.FrictionWeight, Value.ElasticityWeight}) .. ")"
	end

	if Type == "function" then
		local Ok, Name = pcall(debug.info, Value, "n")

		return "function() end --[[ " .. ((Ok and Name and Name ~= "") and Name or "function") .. " ]]"
	end

	return "nil --[[ " .. Type .. ": " .. tostring(Value):gsub("%]%]", "] ]") .. " ]]"
end

UI.GetNilHelper = [[local function getnil(name, class)
    for _, v in getnilinstances() do
        if v.Name == name and v.ClassName == class then
            return v
        end
    end
end

]]

-- name / class / path of what a log is about: a remote, a module (or asset id), or a signal
local function DisplayName(Log)
	if Log.Signal then
		return Log.Owner and (NameOf(Log.Owner) .. "." .. Log.EventName) or Log.EventName
	end

	if typeof(Log.Remote) ~= "Instance" then
		return "asset " .. tostring(Log.Remote)
	end

	return NameOf(Log.Remote)
end

local function DisplayClass(Log)
	if Log.Signal then
		return Log.Owner and (ClassOf(Log.Owner) .. " signal") or "signal"
	end

	if typeof(Log.Remote) ~= "Instance" then
		return "asset id"
	end

	return ClassOf(Log.Remote)
end

local function DisplayPath(Log, Context)
	if Log.Signal then
		if Log.Owner then
			return PathOf(Log.Owner, Context) .. "." .. Log.EventName
		end

		return "signal --[[ " .. tostring(Log.Remote) .. ": owner not found ]]"
	end

	if typeof(Log.Remote) ~= "Instance" then
		return tostring(Log.Remote)
	end

	return PathOf(Log.Remote, Context)
end

local function Indent(Code)
	return "    " .. (Code:gsub("\n", "\n    "))
end

local function Generate(Log)
	local Context = {NeedsNil = false}
	local Setup = { }
	local Target = DisplayPath(Log, Context)
	local Unpack = Settings.Unpack
	local Count = Log.Count
	local Kind = Log.Kind

	if Settings.RemoteVariable and Kind ~= "require" then
		local Variable = (Kind == "kick" and "player") or (Kind == "teleport" and "teleportService") or (Kind == "bindable" and "bindable") or (Log.Signal and "signal") or "remote"

		table.insert(Setup, "local " .. Variable .. " = " .. Target)
		Target = Variable
	end

	-- the arguments, in the chosen style
	local ArgText = ""

	if Count > 0 and Kind ~= "require" then
		local Style = Settings.CodeStyle

		if Style == "inline" then
			local Parts = { }

			for Index = 1, Count do
				table.insert(Parts, Serialize(Log.Args[Index], 0, nil, Context))
			end

			ArgText = table.concat(Parts, ", ")
		elseif Style == "variables" then
			local Names = { }

			for Index = 1, Count do
				table.insert(Setup, "local arg" .. Index .. " = " .. Serialize(Log.Args[Index], 0, nil, Context))
				table.insert(Names, "arg" .. Index)
			end

			ArgText = table.concat(Names, ", ")
		else
			local Holes = false
			local Lines = {"local args = {"}

			for Index = 1, Count do
				local Value = Log.Args[Index]

				if Value == nil then
					Holes = true
				end

				if Style == "array" then
					table.insert(Lines, "    " .. Serialize(Value, 1, nil, Context) .. ",")
				elseif Value ~= nil then
					table.insert(Lines, "    [" .. Index .. "] = " .. Serialize(Value, 1, nil, Context) .. ",")
				end
			end

			table.insert(Lines, "}")

			if #Setup > 0 then
				table.insert(Setup, "")
			end

			table.insert(Setup, table.concat(Lines, "\n"))

			ArgText = Holes and (Unpack .. "(args, 1, " .. Count .. ")") or (Unpack .. "(args)")
		end
	end

	-- the call itself
	local Call

	if Kind == "incoming" then
		Call = "firesignal(" .. Target .. ".OnClientEvent" .. (ArgText ~= "" and (", " .. ArgText) or "") .. ")"
	elseif Kind == "require" then
		Call = "require(" .. Target .. ")"
	elseif Log.Signal then
		Call = Kind .. "(" .. Target .. (ArgText ~= "" and (", " .. ArgText) or "") .. ")"
	else
		Call = Target .. ":" .. (Log.Method:gsub("^%l", string.upper)) .. "(" .. ArgText .. ")"
	end

	local Returns = Kind == "function" or Kind == "require" or (Kind == "bindable" and Log.Method == "Invoke")
	local Wrap = Settings.Wrap
	local Delay = tonumber(Settings.LoopDelay) or 0
	local Body

	if Wrap == "loop" then
		local Inner = Call

		if Delay > 0 then
			Inner ..= "\ntask.wait(" .. Number(Delay) .. ")"
		end

		Body = "for i = 1, " .. math.max(1, math.floor(tonumber(Settings.LoopCount) or 1)) .. " do\n" .. Indent(Inner) .. "\nend"
	elseif Wrap == "while" then
		Body = "while task.wait(" .. (Delay > 0 and Number(Delay) or "") .. ") do\n" .. Indent(Call) .. "\nend"
	elseif Wrap == "spawn" then
		Body = "task.spawn(function()\n" .. Indent(Call) .. "\nend)"
	elseif Wrap == "pcall" then
		Body = "local ok, result = pcall(function()\n" .. Indent((Returns and "return " or "") .. Call) .. "\nend)\n\nprint(ok, result)"
	elseif Kind == "require" then
		Body = "local module = " .. Call .. "\n\nprint(module)"
	elseif Returns then
		Body = "local result = " .. Call .. "\n\nprint(result)"
	else
		Body = Call
	end

	local Header = {"-- generated by Larp remote spy"}

	if Settings.CallerComment then
		if Log.Script then
			local Ok, Path = pcall(PathOf, Log.Script)

			table.insert(Header, "-- caller: " .. (Ok and Path or NameOf(Log.Script)))
		end

		if Log.Actor then
			table.insert(Header, "-- actor: " .. Log.Actor)
		end
	end

	if Kind == "incoming" then
		table.insert(Header, "-- incoming (server -> client): replays the event on your client")
	elseif Kind == "kick" then
		table.insert(Header, "-- a kick the game tried on you")
	elseif Log.Signal then
		table.insert(Header, "-- " .. Kind .. " call from an executor script" .. (Log.Owner and "" or " (signal owner not found, set it yourself)"))
	end

	local SetupText = #Setup > 0 and (table.concat(Setup, "\n") .. "\n\n") or ""
	local Returned = ""

	-- what the module gave back (kept from the call itself)
	if Kind == "require" and Log.Result then
		local Parts = { }

		for Index = 1, Log.Result.n or #Log.Result do
			table.insert(Parts, Serialize(Log.Result[Index]))
		end

		Returned = "\n\n-- returned:\n-- " .. (table.concat(Parts, ", "):gsub("\n", "\n-- "))
	end

	return table.concat(Header, "\n") .. "\n\n" .. (Context.NeedsNil and UI.GetNilHelper or "") .. SetupText .. Body .. Returned
end

-- signature of a call for merging repeats (cheap: top level values only)
local function Unstack(Log)
	local Per = Stacks[Log.Remote]

	if Per then
		for Key, Value in Per do
			if Value == Log then
				Per[Key] = nil
			end
		end

		if next(Per) == nil then
			Stacks[Log.Remote] = nil
		end
	end
end

local function Signature(Log)
	local Parts = {tostring(Log.Remote), Log.Method, Log.Kind, tostring(Log.Actor), Log.Count}

	for Index = 1, Log.Count do
		local Value = Log.Args[Index]

		if type(Value) == "table" then
			local Count = 0

			table.insert(Parts, "{")

			for Key, Inner in next, Value do
				Count += 1

				if Count > 20 then
					break
				end

				table.insert(Parts, tostring(Key) .. "=" .. tostring(Inner))
			end

			table.insert(Parts, "}")
		else
			table.insert(Parts, typeof(Value) .. ":" .. tostring(Value))
		end
	end

	return table.concat(Parts, "|")
end

-- logs view

UI.LogsView = New("Frame", {Parent = Inner, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1})
UI.SettingsView = New("Frame", {Parent = Inner, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false})

local Split = 0.42
UI.CallsPanel = Panel(UI.LogsView, "calls")
UI.DetailsPanel = Panel(UI.LogsView, "details")
UI.Splitter = New("TextButton", {Parent = UI.LogsView, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.new(0, 6, 1, -12), ZIndex = 5})

local function Layout()
	UI.CallsPanel.Position = UDim2.new(0, 6, 0, 6)
	UI.CallsPanel.Size = UDim2.new(Split, -10, 1, -12)
	UI.DetailsPanel.Position = UDim2.new(Split, 4, 0, 6)
	UI.DetailsPanel.Size = UDim2.new(1 - Split, -10, 1, -12)
	UI.Splitter.Position = UDim2.new(Split, -4, 0, 6)
end

Layout()

do
	local Splitting = false

	Connect(UI.Splitter.InputBegan, function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			Splitting = true
		end
	end)

	Connect(UserInputService.InputEnded, function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			Splitting = false
		end
	end)

	Connect(UserInputService.InputChanged, function(InputObject)
		if Splitting and InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			Split = math.clamp((InputObject.Position.X - Inner.AbsolutePosition.X) / math.max(1, Inner.AbsoluteSize.X), 0.25, 0.7)
			Layout()
		end
	end)
end

UI.FilterBox = Input(UI.CallsPanel, {Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(1, -110, 0, 18)}, "filter name, method, caller...")
UI.CallButtons = New("Frame", {Parent = UI.CallsPanel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 24), Size = UDim2.new(0, 96, 0, 18), BackgroundTransparency = 1})

HorizontalList(UI.CallButtons, 4).HorizontalAlignment = Enum.HorizontalAlignment.Right

local Selected = nil
local Render, ShowDetails, Rebuild, FindOwner -- below

UI.PauseButton = Button(UI.CallButtons, "pause", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X}, function()
	Paused = not Paused
	UI.PauseButton.Text = Paused and "resume" or "pause"
	UI.PauseButton.TextColor3 = Paused and T.Accent or T.Text
	SetStatus(Paused and "paused" or "logging")
end)

Button(UI.CallButtons, "clear", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1}, function()
	Logs = { }
	Stacks = { }
	Selected = nil
	Rebuild()
	ShowDetails(nil)
end)

local Tree = New("ScrollingFrame", {
	Parent = UI.CallsPanel,
	Position = UDim2.new(0, 8, 0, 48),
	Size = UDim2.new(1, -16, 1, -56),
	BackgroundColor3 = T.Background,
	BorderSizePixel = 0,
	ScrollBarThickness = 2,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollingDirection = Enum.ScrollingDirection.Y,
})

Accent(Tree, "ScrollBarImageColor3")
Stroke(Tree, T.Outline)

local RowHeight = 18
local Flat = { }
local Pool = { }
local RowLog = { }
local Filter = ""

local function Matches(Log)
	if Filter == "" then
		return true
	end

	local Haystack = (DisplayName(Log) .. " " .. Log.Method .. " " .. Log.Kind .. " " .. (Log.Script and NameOf(Log.Script) or "") .. " " .. (Log.Actor or "")):lower()

	return Haystack:find(Filter, 1, true) ~= nil
end

Rebuild = function()
	Flat = { }

	for _, Log in Logs do
		if Matches(Log) then
			table.insert(Flat, Log)
		end
	end

	Tree.CanvasSize = UDim2.new(0, 0, 0, #Flat * RowHeight + 4)
	Render()
end

local LogMenu -- below

local function GetRow(Index)
	if Pool[Index] then
		return Pool[Index]
	end

	local Row = New("TextButton", {Parent = Tree, Size = UDim2.new(1, -6, 0, RowHeight), BackgroundColor3 = T.Hover, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = ""})

	New("Frame", {Parent = Row, Name = "Bar", Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0})
	New("ImageLabel", {Parent = Row, Name = "Icon", BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0.5, -6), Size = UDim2.new(0, 12, 0, 12), ScaleType = Enum.ScaleType.Fit, Visible = false})
	Text(Row, {Name = "Label", Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -122, 1, 0), RichText = true})
	Accent(Text(Row, {Name = "Count", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 0), Size = UDim2.new(0, 50, 1, 0), TextXAlignment = Enum.TextXAlignment.Right}), "TextColor3")
	Text(Row, {Name = "Time", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.new(0, 60, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Dim})

	Connect(Row.MouseEnter, function()
		Row:SetAttribute("Hovered", true)

		if RowLog[Row] ~= Selected then
			Row.BackgroundTransparency = 0.5
		end
	end)

	Connect(Row.MouseLeave, function()
		Row:SetAttribute("Hovered", false)

		if RowLog[Row] ~= Selected then
			Row.BackgroundTransparency = 1
		end
	end)

	Connect(Row.MouseButton1Click, function()
		if RowLog[Row] then
			ShowDetails(RowLog[Row])
		end
	end)

	Connect(Row.MouseButton2Click, function()
		if RowLog[Row] then
			ShowDetails(RowLog[Row])
			LogMenu(RowLog[Row])
		end
	end)

	Pool[Index] = Row

	return Row
end

Render = function()
	local Height = Tree.AbsoluteWindowSize.Y
	local First = math.max(1, math.floor(Tree.CanvasPosition.Y / RowHeight) + 1)
	local Count = math.ceil(Height / RowHeight) + 1

	for Index = 1, math.max(Count, #Pool) do
		local Log = Index <= Count and Flat[First + Index - 1]

		if not Log then
			if Pool[Index] then
				Pool[Index].Visible = false
				RowLog[Pool[Index]] = nil
			end

			continue
		end

		local Row = GetRow(Index)
		local Kind = Kinds[Log.Kind]
		local Color = "#" .. KindColor(Log.Kind):ToHex()
		local Extra = ""

		Row.Count.Text = Log.Calls > 1 and ("x" .. Log.Calls) or ""

		if Log.Actor then
			Extra ..= " [" .. Esc(Log.Actor) .. "]"
		end

		if Blocked[Log.Remote] then
			Extra ..= " blocked"
		end

		RowLog[Row] = Log
		Row.Visible = true
		Row.Position = UDim2.new(0, 0, 0, (First + Index - 2) * RowHeight)
		Row.Bar.BackgroundColor3 = KindColor(Log.Kind)
		local Icon = KindIcons[Log.Kind]

		Row.Icon.Visible = Icon ~= nil
		Row.Icon.Image = Icon or ""
		Row.Icon.ImageColor3 = KindColor(Log.Kind)
		Row.Label.Position = UDim2.new(0, Icon and 24 or 8, 0, 0)
		Row.Label.Size = UDim2.new(1, Icon and -138 or -122, 1, 0)
		Row.Label.Text = (Icon and "" or ('<font color="' .. Color .. '">' .. Kind.Tag .. "</font>  ")) .. Esc(DisplayName(Log)) .. ' <font color="' .. Hex.Dim .. '">' .. Extra .. "</font>"
		Row.Time.Text = Log.Time

		local IsSelected = Log == Selected

		Row.BackgroundColor3 = IsSelected and T.Element or T.Hover
		Row.BackgroundTransparency = IsSelected and 0 or (Row:GetAttribute("Hovered") and 0.5 or 1)
	end
end

Connect(Tree:GetPropertyChangedSignal("CanvasPosition"), function() Render() end)
Connect(Tree:GetPropertyChangedSignal("AbsoluteWindowSize"), function() Render() end)

do
	local Pending = 0

	Connect(UI.FilterBox:GetPropertyChangedSignal("Text"), function()
		Pending += 1

		local Mine = Pending

		task.delay(0.2, function()
			if Mine == Pending then
				Filter = UI.FilterBox.Text:lower()
				Rebuild()
			end
		end)
	end)
end

-- details

UI.InfoName = Text(UI.DetailsPanel, {Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -16, 0, 12), RichText = true, Text = '<font color="' .. Hex.Dim .. '">select a call</font>'})
UI.InfoPath = Text(UI.DetailsPanel, {Position = UDim2.new(0, 8, 0, 35), Size = UDim2.new(1, -16, 0, 12), TextColor3 = T.Dim})
UI.InfoMeta = Text(UI.DetailsPanel, {Position = UDim2.new(0, 8, 0, 48), Size = UDim2.new(1, -16, 0, 12), TextColor3 = T.Dim})

local Actions = New("Frame", {Parent = UI.DetailsPanel, Position = UDim2.new(0, 8, 0, 64), Size = UDim2.new(1, -16, 0, 18), BackgroundTransparency = 1})

HorizontalList(Actions, 4)

-- the calling script (copy its path / decompile it) and the history of a stacked row
UI.CallerRow = New("Frame", {Parent = UI.DetailsPanel, Position = UDim2.new(0, 8, 0, 86), Size = UDim2.new(1, -16, 0, 18), BackgroundTransparency = 1, Visible = false})
UI.HistoryRow = New("Frame", {Parent = UI.DetailsPanel, Position = UDim2.new(0, 8, 0, 108), Size = UDim2.new(1, -16, 0, 18), BackgroundTransparency = 1, Visible = false})

HorizontalList(UI.CallerRow, 4)
HorizontalList(UI.HistoryRow, 4)

UI.CodeScroll = New("ScrollingFrame", {
	Parent = UI.DetailsPanel,
	Position = UDim2.new(0, 8, 0, 88),
	Size = UDim2.new(1, -16, 1, -96),
	BackgroundColor3 = T.Background,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.XY,
	ScrollingDirection = Enum.ScrollingDirection.XY,
})

Accent(UI.CodeScroll, "ScrollBarImageColor3")
Stroke(UI.CodeScroll, T.Outline)

UI.CodeBody = New("Frame", {Parent = UI.CodeScroll, Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1})

New("UIListLayout", {Parent = UI.CodeBody, SortOrder = Enum.SortOrder.LayoutOrder})
New("UIPadding", {Parent = UI.CodeBody, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12)})

local CurrentCode = ""

local function FillCode(Body, Source)
	for _, Child in Body:GetChildren() do
		if Child:IsA("GuiObject") then
			Child:Destroy()
		end
	end

	local Lines = Source:split("\n")
	local NumberWidth = #tostring(#Lines) * (Pixel and 6 or 8) + 10

	for Start = 1, #Lines, 120 do
		local Numbers, Code = { }, { }

		for Line = Start, math.min(Start + 119, #Lines) do
			table.insert(Numbers, tostring(Line))
			table.insert(Code, Lines[Line])
		end

		local Row = New("Frame", {Parent = Body, LayoutOrder = Start, Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1})

		Text(Row, {Size = UDim2.new(0, NumberWidth - 10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None, TextColor3 = T.Dim, Text = table.concat(Numbers, "\n")})
		Text(Row, {Position = UDim2.new(0, NumberWidth, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None, Text = table.concat(Code, "\n")})
	end
end

local function ShowCode(Source)
	CurrentCode = Source
	FillCode(UI.CodeBody, Source)
end

-- the call a row shows: its newest one, or the one picked from its history
local function Viewed(Log)
	local History = Log.History
	local Record = History and History[Log.ViewIndex or #History]

	if not Record then
		return Log
	end

	return {
		Remote = Log.Remote, Method = Log.Method, Kind = Log.Kind, Actor = Log.Actor, Calls = Log.Calls,
		Args = Record.Args, Count = Record.Count, Script = Record.Script, Time = Record.Time, Number = Record.Number,
		Result = Record.Result, Signal = Record.Signal or Log.Signal, EventName = Log.EventName, Owner = Log.Owner,
	}
end

-- decompiling the calling script: the executor's decompile, else its bytecode goes to the Konstant decompiler
UI.KonstantUrl = "http://api.plusgiant5.com/konstant/decompile"
UI.SourceCache = setmetatable({ }, {__mode = "k"})

local function Decompile(Script)
	local Native = (getgenv and getgenv().decompile) or decompile or (syn and syn.decompile)
	local Problem = nil

	if type(Native) == "function" then
		local Ok, Source = pcall(Native, Script)

		if Ok and type(Source) == "string" and #Source > 0 and not Source:find("^%-%- ?[Ff]ailed") then
			return true, Source
		end

		Problem = Ok and tostring(Source) or ("decompile error: " .. tostring(Source))
	end

	if X.GetBytecode and X.Request then
		local OkBytecode, Bytecode = pcall(X.GetBytecode, Script)

		if not OkBytecode or type(Bytecode) ~= "string" or #Bytecode == 0 then
			return false, "no bytecode for this script (not loaded on your client?)"
		end

		local Ok, Response = pcall(X.Request, {Url = UI.KonstantUrl, Method = "POST", Headers = {["Content-Type"] = "text/plain"}, Body = Bytecode})

		if Ok and Response and (Response.StatusCode == nil or Response.StatusCode == 200) and type(Response.Body) == "string" and #Response.Body > 0 then
			return true, Response.Body
		end

		return false, "online decompiler failed" .. (Ok and Response and Response.StatusCode and (" (" .. tostring(Response.StatusCode) .. ")") or "")
	end

	return false, Problem or "this executor has no decompile (and no getscriptbytecode + request for the online one)"
end

-- source viewer over the logs view
local Viewer = Panel(UI.LogsView, "source")

Viewer.Visible = false
Viewer.Active = true
Viewer.ZIndex = 10
Viewer.Position = UDim2.new(0, 6, 0, 6)
Viewer.Size = UDim2.new(1, -12, 1, -12)
Viewer.Title.Size = UDim2.new(1, -200, 0, 12)

UI.ViewerBar = New("Frame", {Parent = Viewer, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 3), Size = UDim2.new(0, 180, 0, 16), BackgroundTransparency = 1})

HorizontalList(UI.ViewerBar, 4).HorizontalAlignment = Enum.HorizontalAlignment.Right

UI.ViewerScroll = New("ScrollingFrame", {
	Parent = Viewer,
	Position = UDim2.new(0, 8, 0, 24),
	Size = UDim2.new(1, -16, 1, -32),
	BackgroundColor3 = T.Background,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.XY,
	ScrollingDirection = Enum.ScrollingDirection.XY,
})

Accent(UI.ViewerScroll, "ScrollBarImageColor3")
Stroke(UI.ViewerScroll, T.Outline)

UI.ViewerBody = New("Frame", {Parent = UI.ViewerScroll, Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1})

New("UIListLayout", {Parent = UI.ViewerBody, SortOrder = Enum.SortOrder.LayoutOrder})
New("UIPadding", {Parent = UI.ViewerBody, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12)})

UI.ViewerText = ""

Button(UI.ViewerBar, "copy", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X}, function() Copy(UI.ViewerText) end)
Button(UI.ViewerBar, "close", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1}, function() Viewer.Visible = false end)

local function ShowSource(Title, Source)
	UI.ViewerText = Source
	Viewer.Title.Text = Title
	Viewer.Visible = true
	UI.ViewerScroll.CanvasPosition = Vector2.new(0, 0)
	FillCode(UI.ViewerBody, Source)
end

local function DecompileCaller(Script)
	if not Script then
		SetStatus("no calling script for this call")

		return
	end

	local Ok, Path = pcall(PathOf, Script)

	Path = Ok and Path or NameOf(Script)

	if UI.SourceCache[Script] then
		ShowSource("source  " .. NameOf(Script), UI.SourceCache[Script])

		return
	end

	ShowSource("source  " .. NameOf(Script) .. "  (decompiling...)", "-- decompiling " .. Path .. "...")
	SetStatus("decompiling " .. NameOf(Script) .. "...")

	task.spawn(function()
		local Success, Result = Decompile(Script)

		if Success then
			Result = Result:gsub("\r\n", "\n"):gsub("\t", "    ")
			UI.SourceCache[Script] = Result
			SetStatus("decompiled " .. NameOf(Script))
			ShowSource("source  " .. NameOf(Script), "-- " .. Path .. "\n\n" .. Result)
		else
			SetStatus(Result)
			ShowSource("source  " .. NameOf(Script) .. "  (failed)", "-- couldn't decompile " .. Path .. "\n-- " .. Result)
		end
	end)
end

local ActionButtons = { }

local function ActionButton(Name, Label, Order, Callback)
	ActionButtons[Name] = Button(Actions, Label, {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = Order}, function()
		if Selected then
			Callback(Selected)
		end
	end)
end

local SyncActors -- below

local function Replay(Log)
	task.spawn(function()
		local Remote = Log.Remote
		local Args = Log.Args
		local Ok, Result

		if Log.Signal then
			local Function = Log.Kind == "replicatesignal" and X.ReplicateSignal or X.FireSignal

			if not Function then
				SetStatus("no " .. Log.Kind .. " in this executor")

				return
			end

			Replaying = true
			Ok, Result = pcall(Function, Log.Signal, table.unpack(Args, 1, Log.Count))
			Replaying = false

			SetStatus(Ok and ("ran " .. Log.Kind .. " " .. Log.EventName) or ("run failed: " .. tostring(Result)))

			return
		elseif Log.Kind == "kick" then
			SetStatus("not running a kick on yourself")

			return
		elseif Log.Kind == "require" then
			Ok, Result = pcall(function() return table.pack(require(Remote)) end)

			if Ok then
				Log.Result = Result
				ShowCode(Generate(Log))
			end
		elseif Log.Kind == "incoming" then
			if not X.FireSignal then
				SetStatus("no firesignal in this executor")

				return
			end

			Replaying = true
			Ok, Result = pcall(X.FireSignal, Remote.OnClientEvent, table.unpack(Args, 1, Log.Count))
			Replaying = false
		elseif Log.Kind == "function" or Log.Method == "Invoke" then
			SetStatus("invoking " .. NameOf(Remote) .. "...")
			Ok, Result = pcall(function()
				return table.pack(Remote[Log.Method:gsub("^%l", string.upper)](Remote, table.unpack(Args, 1, Log.Count)))
			end)

			if Ok then
				local Parts = { }

				for Index = 1, Result.n do
					table.insert(Parts, Serialize(Result[Index]))
				end

				ShowCode(Generate(Log) .. "\n\n-- returned:\n-- " .. (table.concat(Parts, ", "):gsub("\n", "\n-- ")))
			end
		else
			Ok, Result = pcall(function()
				Remote[Log.Method:gsub("^%l", string.upper)](Remote, table.unpack(Args, 1, Log.Count))
			end)
		end

		SetStatus(Ok and ("ran " .. DisplayName(Log)) or ("run failed: " .. tostring(Result)))
	end)
end

local function SetBlocked(Remote, Bool)
	Blocked[Remote] = Bool or nil

	if Channel then
		pcall(function() Channel:Fire("block", Remote, Bool) end)
	end

	Render()

	if Selected then
		ShowDetails(Selected)
	end
end

local function SetIgnored(Remote, Bool)
	Ignored[Remote] = Bool or nil

	if Channel then
		pcall(function() Channel:Fire("ignore", Remote, Bool) end)
	end

	if Bool then
		local Kept = { }

		for _, Log in Logs do
			if Log.Remote ~= Remote then
				table.insert(Kept, Log)
			end
		end

		Logs = Kept
		Stacks[Remote] = nil

		if Selected and Selected.Remote == Remote then
			ShowDetails(nil)
		end
	end

	Rebuild()
end

ActionButton("Copy", "copy code", 0, function() Copy(CurrentCode) end)
ActionButton("Path", "copy path", 1, function(Log) Copy(DisplayPath(Log)) end)
ActionButton("Run", "run", 2, function(Log) Replay(Viewed(Log)) end)
ActionButton("Block", "block", 3, function(Log) SetBlocked(Log.Remote, not Blocked[Log.Remote]) end)
ActionButton("Ignore", "ignore", 4, function(Log) SetIgnored(Log.Remote, true) end)
ActionButton("CopyAll", "copy all", 5, function(Log)
	local Parts = { }

	for _, Record in Log.History or {Log} do
		local Ok, Code = pcall(Generate, {
			Remote = Log.Remote, Method = Log.Method, Kind = Log.Kind, Actor = Log.Actor, Calls = Log.Calls,
			Signal = Record.Signal or Log.Signal, EventName = Log.EventName, Owner = Log.Owner,
			Args = Record.Args, Count = Record.Count, Script = Record.Script, Time = Record.Time, Result = Record.Result,
		})

		if Ok then
			table.insert(Parts, Code)
		end
	end

	Copy(table.concat(Parts, "\n\n"))
end)

UI.ExportLogs = function()
	if not writefile then
		SetStatus("no writefile in this executor")

		return
	end

	EnsureFolder()

	local Out = { }

	for Index = #Logs, 1, -1 do
		local Log = Logs[Index]

		if Settings.ExportFormat == "summary" then
			table.insert(Out, string.format("[%s] %s %s %s (%d args) x%d", Log.Time, Kinds[Log.Kind].Tag, DisplayName(Log), Log.Method, Log.Count, Log.Calls))
		else
			local Ok, Code = pcall(Generate, Viewed(Log))

			table.insert(Out, "-- [" .. Log.Time .. "] " .. DisplayName(Log) .. "\n" .. (Ok and Code or "-- couldn't generate"))
		end
	end

	local Name = Folder .. "/export_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
	local Ok, Error = pcall(writefile, Name, table.concat(Out, "\n\n"))

	SetStatus(Ok and ("exported " .. #Logs .. " logs to " .. Name) or ("export failed: " .. tostring(Error)))
end

UI.CallerLabel = Text(UI.CallerRow, {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = T.Dim, Text = "caller", LayoutOrder = 0})

Button(UI.CallerRow, "decompile caller", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1}, function()
	if Selected then
		DecompileCaller(Viewed(Selected).Script)
	end
end)

Button(UI.CallerRow, "copy caller path", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2}, function()
	local Script = Selected and Viewed(Selected).Script

	if Script then
		Copy(PathOf(Script))
	end
end)

-- history of a stacked row: older / newer / newest / pick from a list
local function ViewCall(Index)
	if not Selected or not Selected.History then
		return
	end

	local Count = #Selected.History

	Index = math.clamp(Index, 1, Count)
	Selected.ViewIndex = Index < Count and Index or nil
	ShowDetails(Selected)
end

local function CurrentIndex()
	return Selected and (Selected.ViewIndex or #Selected.History) or 1
end

Button(UI.HistoryRow, "<", {Size = UDim2.new(0, 20, 1, 0), LayoutOrder = 0}, function() ViewCall(CurrentIndex() - 1) end)
Button(UI.HistoryRow, ">", {Size = UDim2.new(0, 20, 1, 0), LayoutOrder = 1}, function() ViewCall(CurrentIndex() + 1) end)
Button(UI.HistoryRow, "latest", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2}, function() ViewCall(math.huge) end)
Button(UI.HistoryRow, "history", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3}, function()
	if not Selected or not Selected.History then
		return
	end

	local Options = { }
	local Current = CurrentIndex()

	for Index = #Selected.History, 1, -1 do
		local Record = Selected.History[Index]
		local Caller = Record.Script and ("  " .. NameOf(Record.Script)) or ""

		table.insert(Options, {"#" .. Record.Number .. "  " .. Record.Time .. "  " .. Record.Count .. " args" .. Caller, function() ViewCall(Index) end, Index == Current and T.Accent or nil})
	end

	OpenMenu(Options, 220)
end)

UI.HistoryLabel = Text(UI.HistoryRow, {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = T.Dim, LayoutOrder = 4})

LogMenu = function(Log)
	OpenMenu({
		{"Copy code", function() Copy(Generate(Viewed(Log))) end},
		{"Copy remote path", function() Copy(DisplayPath(Log)) end},
		{"Run again", function() Replay(Viewed(Log)) end},
		{"Decompile caller", function() DecompileCaller(Viewed(Log).Script) end},
		{Blocked[Log.Remote] and "Unblock remote" or "Block remote", function() SetBlocked(Log.Remote, not Blocked[Log.Remote]) end, T.Bad},
		{"Ignore remote", function() SetIgnored(Log.Remote, true) end},
		{"Remove this log", function()
			local Position = table.find(Logs, Log)

			if Position then
				table.remove(Logs, Position)
			end

			Unstack(Log)

			if Selected == Log then
				ShowDetails(nil)
			end

			Rebuild()
		end},
	}, 160)
end

-- the instance a signal belongs to: every instance's event of that name is compared with it
FindOwner = function(Log)
	Log.OwnerSearched = true

	task.spawn(function()
		local Signal, Event = Log.Signal, Log.EventName
		local Scanned = 0

		local function Check(List)
			for _, Object in List do
				local Ok, Same = pcall(function()
					return Object[Event] == Signal
				end)

				if Ok and Same then
					return Object
				end

				Scanned += 1

				if Scanned % 4000 == 0 then
					task.wait()
				end
			end

			return nil
		end

		local Ok, All = pcall(game.GetDescendants, game)
		local Found = Check(Ok and All or { })

		if not Found and getnilinstances then
			local OkNil, Nils = pcall(getnilinstances)

			Found = Check(OkNil and Nils or { })
		end

		Log.Owner = Found

		if Found and Selected == Log then
			ShowDetails(Log, true)
			Render()
		end
	end)
end

ShowDetails = function(Log, KeepScroll)
	Selected = Log

	for _, Object in ActionButtons do
		Object.Visible = Log ~= nil
	end

	if not Log then
		UI.InfoName.Text = '<font color="' .. Hex.Dim .. '">select a call</font>'
		UI.InfoPath.Text = ""
		UI.InfoMeta.Text = ""
		UI.CallerRow.Visible = false
		UI.HistoryRow.Visible = false
		ShowCode("")
		Render()

		return
	end

	local Color = "#" .. KindColor(Log.Kind):ToHex()

	UI.InfoName.Text = Esc(DisplayName(Log)) .. ' <font color="' .. Hex.Dim .. '">' .. Esc(DisplayClass(Log)) .. '</font>  <font color="' .. Color .. '">' .. Kinds[Log.Kind].Tag .. "</font>"
	local OkPath, Path = pcall(DisplayPath, Log)

	UI.InfoPath.Text = OkPath and Path or ""

	if Log.Signal and not Log.OwnerSearched then
		FindOwner(Log)
	end

	local Call = Viewed(Log)
	local Meta = {Log.Method, Call.Count .. " args", Call.Time}

	if Log.Calls > 1 then
		table.insert(Meta, "x" .. Log.Calls)
	end

	if Log.Actor then
		table.insert(Meta, "actor " .. Log.Actor)
	end

	UI.InfoMeta.Text = table.concat(Meta, "  ·  ")

	-- rows under the actions: caller, then history; the code goes under whatever is shown
	local Y = 86

	UI.CallerRow.Visible = Call.Script ~= nil

	if Call.Script then
		UI.CallerLabel.Text = "caller " .. NameOf(Call.Script)
		UI.CallerRow.Position = UDim2.new(0, 8, 0, Y)
		Y += 22
	end

	local History = Log.History or { }

	UI.HistoryRow.Visible = #History > 1

	if #History > 1 then
		local Index = Log.ViewIndex or #History

		UI.HistoryLabel.Text = "call #" .. (Call.Number or Log.Calls) .. " of " .. Log.Calls .. "  (" .. Index .. "/" .. #History .. " kept)" .. (Log.ViewIndex and "" or "  latest")
		UI.HistoryRow.Position = UDim2.new(0, 8, 0, Y)
		Y += 22
	end

	UI.CodeScroll.Position = UDim2.new(0, 8, 0, Y + 2)
	UI.CodeScroll.Size = UDim2.new(1, -16, 1, -(Y + 10))

	ActionButtons.Block.Text = Blocked[Log.Remote] and "unblock" or "block"
	ActionButtons.Block.TextColor3 = Blocked[Log.Remote] and T.Bad or T.Text
	ActionButtons.Run.Text = (Log.Kind == "incoming" and "fire locally") or (Log.Kind == "require" and "require & dump") or "run"
	ActionButtons.Run.Visible = Log.Kind ~= "kick"

	local Ok, Code = pcall(Generate, Call)

	ShowCode(Ok and Code or ("-- couldn't generate code: " .. tostring(Code)))

	if Ok and Settings.AutoCopy and not KeepScroll and X.SetClipboard then
		pcall(X.SetClipboard, Code)
		SetStatus("auto copied code")
	end

	if not KeepScroll then
		UI.CodeScroll.CanvasPosition = Vector2.new(0, 0)
	end

	Render()
end

ShowDetails(nil)

-- incoming events

UI.IncomingConnections = { }

local function WatchIncoming(Remote)
	if UI.IncomingConnections[Remote] or SelfIgnore[Remote] then
		return
	end

	local Kind = Remote.ClassName

	if Kind ~= "RemoteEvent" and Kind ~= "UnreliableRemoteEvent" then
		return
	end

	UI.IncomingConnections[Remote] = Remote.OnClientEvent:Connect(function(...)
		if Active and not Paused and Settings.Incoming and not Ignored[Remote] and not NameIgnored(Remote.Name) then
			Push(Remote, "OnClientEvent", "incoming", nil, nil, select("#", ...), ...)
		end
	end)
end


local function SetIncoming(Bool)
	if Bool then
		local Ok, All = pcall(game.GetDescendants, game)

		for _, Object in Ok and All or { } do
			pcall(WatchIncoming, Object)
		end

		UI.IncomingAdded = UI.IncomingAdded or game.DescendantAdded:Connect(function(Object)
			pcall(WatchIncoming, Object)
		end)
	else
		for Remote, Connection in UI.IncomingConnections do
			Connection:Disconnect()
			UI.IncomingConnections[Remote] = nil
		end

		if UI.IncomingAdded then
			UI.IncomingAdded:Disconnect()
			UI.IncomingAdded = nil
		end
	end
end

-- actors: a hook per actor VM that sends the calls back through a comm channel

local ActorSource = [==[
local Channel = %CHANNEL%

if not Channel then
	return
end

local G = (getgenv and getgenv()) or _G
local Settings = game:GetService("HttpService"):JSONDecode(%SETTINGS%)
local Label = %LABEL%
local State = G.__LarpSpyActor

local function Listen(Target)
	Target.Event:Connect(function(Kind, A, B)
		if State.Channel ~= Target then
			return
		end

		if Kind == "settings" then
			State.Settings = A
		elseif Kind == "block" then
			State.Blocked[A] = B or nil
		elseif Kind == "ignore" then
			State.Ignored[A] = B or nil
		elseif Kind == "stop" then
			State.Active = false
		end
	end)
end

if State then
	State.Channel, State.Settings, State.Label, State.Active = Channel, Settings, Label, true
	State.Blocked, State.Ignored = { }, { }
	Listen(Channel)

	return
end

State = {Channel = Channel, Settings = Settings, Label = Label, Active = true, Blocked = { }, Ignored = { }}
G.__LarpSpyActor = State
Listen(Channel)

local Methods = {FireServer = true, fireServer = true, InvokeServer = true, invokeServer = true, Fire = true, Invoke = true}

local function Wanted(Class, Method)
	local S = State.Settings

	if Method == "FireServer" or Method == "fireServer" then
		return (Class == "RemoteEvent" and S.Events) or (Class == "UnreliableRemoteEvent" and S.Unreliable)
	elseif Method == "InvokeServer" or Method == "invokeServer" then
		return Class == "RemoteFunction" and S.Functions
	elseif Method == "Fire" then
		return Class == "BindableEvent" and S.Bindables
	elseif Method == "Invoke" then
		return Class == "BindableFunction" and S.Bindables
	end
end

local function Capture(self, Method, ...)
	if not State.Active or typeof(self) ~= "Instance" or self == State.Channel then
		return false
	end

	if not Wanted(self.ClassName, Method) then
		return false
	end

	local FromExecutor = checkcaller and checkcaller()

	if FromExecutor and not State.Settings.Executor then
		return false
	end

	if not State.Ignored[self] then
		local Caller = getcallingscript and getcallingscript() or nil

		if not pcall(State.Channel.Fire, State.Channel, "call", self, Method, Caller, State.Label, select("#", ...), ...) then
			pcall(State.Channel.Fire, State.Channel, "call", self, Method, Caller, State.Label, 1, "<arguments couldn't be sent from the actor>")
		end
	end

	return State.Blocked[self] == true and not FromExecutor
end

local Close = newcclosure or function(f) return f end
local Old

Old = hookmetamethod(game, "__namecall", Close(function(self, ...)
	local Method = getnamecallmethod()

	if Methods[Method] then
		local Ok, Block = pcall(Capture, self, Method, ...)

		if Ok and Block then
			return nil
		end
	end

	return Old(self, ...)
end))
]==]

UI.ChannelExpression = nil
local Injected = { } -- [actor or thread] = true
UI.InjectedCount = 0
UI.ActorStatus = "off"

local function ActorSettings()
	return {Events = Settings.Events, Functions = Settings.Functions, Unreliable = Settings.Unreliable, Bindables = Settings.Bindables, Executor = Settings.Executor}
end

local function SetupChannel()
	if Channel then
		return true
	end

	if X.CreateCommChannel then
		local Ok, Id, Event = pcall(X.CreateCommChannel)

		if Ok and Event then
			Channel = Event
			UI.ChannelExpression = "(get_comm_channel or (syn and syn.get_comm_channel))(" .. (type(Id) == "number" and tostring(Id) or string.format("%q", tostring(Id))) .. ")"
		end
	end

	if not Channel then
		-- a BindableEvent both VMs can find by its name works the same way
		local Name = HttpService:GenerateGUID(false)
		local Event = Instance.new("BindableEvent")

		Event.Name = Name

		if not pcall(function() Event.Parent = CoreGui end) then
			Event.Parent = Gui
		end

		Channel = Event
		UI.ChannelExpression = ('(game:GetService("CoreGui"):FindFirstChild(%q) or (gethui and gethui():FindFirstChild(%q, true)))'):format(Name, Name)
	end

	SelfIgnore[Channel] = true

	Connect(Channel.Event, function(Kind, Remote, Method, Script, Label, Count, ...)
		if Kind ~= "call" or not Active or Paused or typeof(Remote) ~= "Instance" then
			return
		end

		if Ignored[Remote] or NameIgnored(NameOf(Remote)) then
			return
		end

		local Kind2 = KindOf(ClassOf(Remote), Method)

		if Kind2 then
			Push(Remote, Method, Kind2, Script, Label, Count or select("#", ...), ...)
		end
	end)

	return true
end

local function ActorTargets()
	local Targets = { }

	if X.GetActors and X.RunOnActor then
		local Ok, List = pcall(X.GetActors)

		for Index, Actor in Ok and List or { } do
			table.insert(Targets, {Key = Actor, Label = typeof(Actor) == "Instance" and NameOf(Actor) or ("actor " .. Index), Run = function(Source) X.RunOnActor(Actor, Source) end})
		end
	elseif X.GetActorThreads and X.RunOnThread then
		local Ok, List = pcall(X.GetActorThreads)

		for Index, Thread in Ok and List or { } do
			table.insert(Targets, {Key = Thread, Label = "actor thread " .. Index, Run = function(Source) X.RunOnThread(Thread, Source) end})
		end
	end

	return Targets
end

local function UpdateActorInfo()
	if UI.ActorInfo then
		UI.ActorInfo.Text = UI.ActorStatus
	end
end

local function InjectActors(Force)
	if not Settings.Actors then
		UI.ActorStatus = "off"
		UpdateActorInfo()

		return
	end

	if not ((X.GetActors and X.RunOnActor) or (X.GetActorThreads and X.RunOnThread)) then
		UI.ActorStatus = "not supported (needs getactors + run_on_actor)"
		UpdateActorInfo()

		return
	end

	SetupChannel()

	local Json = HttpService:JSONEncode(ActorSettings())
	local Failed = 0

	for _, Target in ActorTargets() do
		if Force or not Injected[Target.Key] then
			local Source = ActorSource
				:gsub("%%CHANNEL%%", function() return UI.ChannelExpression end)
				:gsub("%%SETTINGS%%", function() return string.format("%q", Json) end)
				:gsub("%%LABEL%%", function() return string.format("%q", Target.Label) end)

			if pcall(Target.Run, Source) then
				if not Injected[Target.Key] then
					UI.InjectedCount += 1
				end

				Injected[Target.Key] = true
			else
				Failed += 1
			end
		end
	end

	UI.ActorStatus = UI.InjectedCount .. " actor" .. (UI.InjectedCount == 1 and "" or "s") .. " hooked" .. (Failed > 0 and (", " .. Failed .. " failed") or "")
	UpdateActorInfo()
end

SyncActors = function()
	if Channel then
		pcall(function() Channel:Fire("settings", ActorSettings()) end)
	end
end

-- settings view

UI.SettingsScroll = New("ScrollingFrame", {
	Parent = UI.SettingsView,
	Position = UDim2.new(0, 6, 0, 6),
	Size = UDim2.new(1, -12, 1, -12),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 2,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})

Accent(UI.SettingsScroll, "ScrollBarImageColor3")

local Columns = { }

for Index = 1, 2 do
	local Column = New("Frame", {Parent = UI.SettingsScroll, Position = UDim2.new((Index - 1) * 0.5, Index == 1 and 0 or 4, 0, 0), Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})

	New("UIListLayout", {Parent = Column, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})

	Columns[Index] = Column
end

local SectionOrder = 0

local function Section(Side, Title)
	SectionOrder += 1

	local Frame = New("Frame", {Parent = Columns[Side], LayoutOrder = SectionOrder, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Inline, BorderSizePixel = 2, BorderColor3 = T.Outline})

	Stroke(Frame, T.Border)
	Accent(New("Frame", {Parent = Frame, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 2}), "BackgroundColor3")
	Glow(Frame, 15, 0)
	Text(Frame, {Position = UDim2.new(0, 7, 0, 5), Size = UDim2.new(1, -14, 0, 12), Text = Title})

	local Content = New("Frame", {Parent = Frame, Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})

	New("UIListLayout", {Parent = Content, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
	New("UIPadding", {Parent = Frame, PaddingBottom = UDim.new(0, 8)})

	return Content
end

local function Changed(Key)
	SaveSettings()

	if Key == "Events" or Key == "Functions" or Key == "Unreliable" or Key == "Bindables" or Key == "Executor" then
		SyncActors()
	end
end

local function Check(Content, Label, Key, OnChange)
	local Row = New("TextButton", {Parent = Content, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "", AutoButtonColor = false})
	local Box = New("Frame", {Parent = Row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = T.Element, BorderSizePixel = 0})

	Stroke(Box, T.Outline)

	local Fill = Accent(New("Frame", {Parent = Box, Position = UDim2.new(0, 2, 0, 2), Size = UDim2.new(1, -4, 1, -4), BorderSizePixel = 0}), "BackgroundColor3")
	local Name = Text(Row, {Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -16, 1, 0), Text = Label})

	local function Draw()
		Fill.Visible = Settings[Key] == true
		Name.TextColor3 = Settings[Key] and T.Text or T.Dim
	end

	Draw()

	Connect(Row.MouseButton1Click, function()
		Settings[Key] = not Settings[Key]
		Draw()
		Changed(Key)

		if OnChange then
			OnChange(Settings[Key])
		end
	end)
end

local function Choice(Content, Label, Key, Options, OnChange)
	local Row = New("Frame", {Parent = Content, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1})

	Text(Row, {Size = UDim2.new(0.5, 0, 1, 0), Text = Label})

	local Picker

	Picker = Button(Row, tostring(Settings[Key]), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0)}, function()
		local Index = table.find(Options, Settings[Key]) or 0

		Settings[Key] = Options[Index % #Options + 1]
		Picker.Text = tostring(Settings[Key])
		Changed(Key)

		if OnChange then
			OnChange(Settings[Key])
		end
	end)
end

local function Field(Content, Label, Key, Placeholder, Parse, OnChange)
	local Row = New("Frame", {Parent = Content, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1})

	Text(Row, {Size = UDim2.new(0.5, 0, 1, 0), Text = Label})

	local Box = Input(Row, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0)}, Placeholder)

	Box.Text = tostring(Settings[Key])

	Connect(Box.FocusLost, function()
		local Value = Box.Text

		if Parse then
			Value = Parse(Box.Text)
		end

		if Value == nil then
			Box.Text = tostring(Settings[Key])

			return
		end

		Settings[Key] = Value
		Box.Text = tostring(Value)
		Changed(Key)

		if OnChange then
			OnChange(Value)
		end
	end)
end

local function Action(Content, Label, Callback)
	Button(Content, Label, {Size = UDim2.new(1, 0, 0, 18)}, Callback)
end

local function Info(Content, String)
	return Text(Content, {Size = UDim2.new(1, 0, 0, 12), TextColor3 = T.Dim, Text = String, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, TextTruncate = Enum.TextTruncate.None})
end

local SetAccent -- below

do
	local Hooks = Section(1, "hooks")

	Check(Hooks, "RemoteEvent:FireServer", "Events")
	Check(Hooks, "RemoteFunction:InvokeServer", "Functions")
	Check(Hooks, "UnreliableRemoteEvent:FireServer", "Unreliable")
	Check(Hooks, "Bindable Fire / Invoke", "Bindables")
	Check(Hooks, "Incoming OnClientEvent", "Incoming", SetIncoming)
	Check(Hooks, "Direct calls (Remote.FireServer(Remote))", "Direct")
	Check(Hooks, "Calls from executor scripts", "Executor")

	local Extra = Section(1, "other spies")

	Check(Extra, "require (ModuleScripts)", "Require", function(Bool)
		if Bool and not InstallRequire() then
			SetStatus("couldn't hook require (needs hookfunction + getrenv)")
		end
	end)

	Check(Extra, "LocalPlayer:Kick", "Kicks")
	Check(Extra, "Block kicks", "BlockKicks")
	Check(Extra, "Teleports (TeleportService)", "Teleports")
	Check(Extra, "Block teleports", "BlockTeleports")
	Check(Extra, "firesignal (executor scripts)", "FireSignals")
	Check(Extra, "replicatesignal (executor scripts)", "ReplicateSignals")

	if not X.HookFunction or not (X.FireSignal or X.ReplicateSignal) then
		Info(Extra, "firesignal / replicatesignal spying needs hookfunction and those functions")
	end
	Info(Extra, Shared.Installed.Legacy and "an older version hooked this session: rejoin for kick / teleport spying by namecall" or "kicks and teleports also show here when blocked")
	Info(Hooks, "hook: " .. HookStatus .. (X.HookFunction and ", direct calls hooked" or ", no hookfunction"))

	local Actors = Section(1, "actors")

	Check(Actors, "Spy on actors", "Actors", function(Bool)
		if Bool then
			InjectActors(false)
		else
			UI.ActorStatus = "off (actors already hooked keep logging until you rejoin)"

			if Channel then
				pcall(function() Channel:Fire("stop") end)
			end

			Injected = { }
			UI.InjectedCount = 0
			UpdateActorInfo()
		end
	end)

	Check(Actors, "Watch for new actors", "WatchActors")
	Action(Actors, "hook actors now", function() InjectActors(true) end)

	UI.ActorInfo = Info(Actors, UI.ActorStatus)

	Info(Actors, "Scripts in Actors run in their own VM; this hooks each one and sends its calls back here.")

	local Logging = Section(2, "logging")

	Field(Logging, "Max logs", "MaxLogs", "300", function(String)
		local Value = tonumber(String)

		return Value and math.clamp(math.floor(Value), 10, 5000) or nil
	end)

	Choice(Logging, "Stack calls", "Stack", {"remote", "same args", "off"}, function() Stacks = { } end)
	Check(Logging, "Move stacked calls to top", "StackToTop")
	Field(Logging, "History per row", "HistoryLimit", "50", function(String)
		local Value = tonumber(String)

		return Value and math.clamp(math.floor(Value), 1, 1000) or nil
	end)
	Info(Logging, "remote: one row per remote (xN), showing its latest call. same args: only identical calls in a row stack.")
	Field(Logging, "Ignore names", "IgnoreNames", "ping, ^Mouse", nil, ParseIgnore)
	Info(Logging, "Comma separated Lua patterns, matched against the remote name.")
	Field(Logging, "Only log names", "OnlyNames", "Damage, ^Shop", nil, ParseOnly)
	Info(Logging, "Whitelist: when filled, only remotes matching these patterns are logged.")
	Choice(Logging, "Export format", "ExportFormat", {"code", "summary"})
	Action(Logging, "export logs to file", function() UI.ExportLogs() end)
	Check(Logging, "Auto copy code on select", "AutoCopy")
	Action(Logging, "unblock all remotes", function()
		for Remote in Blocked do
			SetBlocked(Remote, false)
		end

		SetStatus("unblocked all")
	end)

	Action(Logging, "unignore all remotes", function()
		for Remote in Ignored do
			SetIgnored(Remote, false)
		end

		SetStatus("unignored all")
	end)

	local Code = Section(2, "code")

	local function Redraw()
		if Selected then
			ShowDetails(Selected, true)
		end
	end

	Choice(Code, "Args style", "CodeStyle", {"table", "array", "inline", "variables"}, Redraw)
	Choice(Code, "Paths", "PathStyle", {"GetService", "dot", "WaitForChild", "FindFirstChild"}, Redraw)
	Check(Code, "Remote in a variable", "RemoteVariable", Redraw)
	Check(Code, "Escape non-ASCII text (\\u{...})", "EscapeUnicode")
	Choice(Code, "Wrap call", "Wrap", {"none", "loop", "while", "spawn", "pcall"}, Redraw)
	Field(Code, "Loop count", "LoopCount", "10", function(String)
		local Value = tonumber(String)

		return Value and math.clamp(math.floor(Value), 1, 100000) or nil
	end, Redraw)
	Field(Code, "Loop delay (s)", "LoopDelay", "0", function(String)
		local Value = tonumber(String)

		return Value and math.max(0, Value) or nil
	end, Redraw)
	Choice(Code, "Unpack", "Unpack", {"unpack", "table.unpack"}, function() if Selected then ShowDetails(Selected) end end)
	Check(Code, "Caller / actor comment", "CallerComment", Redraw)

	local Interface = Section(2, "interface")
	local AccentNames = { }

	for _, Preset in UI.AccentPresets do
		table.insert(AccentNames, Preset[1])
	end

	Choice(Interface, "Accent", "Accent", AccentNames, function(Name) SetAccent(PresetColor(Name)) end)
	Field(Interface, "Pause key", "PauseKey", "None", function(String)
		if String == "None" then
			return String
		end

		local Ok, Key = pcall(function() return Enum.KeyCode[String] end)

		return Ok and Key and String or nil
	end)
	Field(Interface, "Toggle key", "ToggleKey", "RightControl", function(String)
		local Ok, Key = pcall(function() return Enum.KeyCode[String] end)

		return Ok and Key and String or nil
	end)
end

SetAccent = function(Color)
	T.Accent = Color
	Hex.Accent = "#" .. Color:ToHex()

	for _, Pair in Accented do
		pcall(function() Pair[1][Pair[2]] = Color end)
	end

	DrawTitle()
	Render()

	if Selected then
		ShowDetails(Selected)
	end
end

-- tabs

UI.TabButtons = { }

local function ShowTab(Name)
	UI.LogsView.Visible = Name == "logs"
	UI.SettingsView.Visible = Name == "settings"

	for TabName, Object in UI.TabButtons do
		Object.TextColor3 = TabName == Name and T.Accent or T.Dim
	end
end

for Index, Name in {"logs", "settings"} do
	local Object = Text(Tabs, {LayoutOrder = Index, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = Name, TextColor3 = T.Dim}, "TextButton")

	New("UIPadding", {Parent = Object, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)})

	Connect(Object.MouseButton1Click, function() ShowTab(Name) end)

	UI.TabButtons[Name] = Object
end

ShowTab("logs")

-- queue -> list, actor watching

do
	local LastActors = 0
	local LastDetails = 0

	Connect(RunService.Heartbeat, function()
		if #Queue > 0 then
			local Batch = Queue

			Queue = { }

			for _, Log in Batch do
				local Target = nil

				if Settings.Stack == "remote" then
					local Key = Log.Method .. "|" .. Log.Kind .. "|" .. tostring(Log.Actor)
					local Per = Stacks[Log.Remote]

					Target = Per and Per[Key]

					if not Target then
						Per = Per or { }
						Per[Key] = Log
						Stacks[Log.Remote] = Per
					end
				elseif Settings.Stack == "same args" then
					local Top = Logs[1]

					if Top and Top.Remote == Log.Remote and Top.Method == Log.Method and Top.Actor == Log.Actor then
						Log.Signature = Signature(Log)
						Top.Signature = Top.Signature or Signature(Top)

						if Top.Signature == Log.Signature then
							Target = Top
						end
					end
				end

				if Target then
					-- the row keeps its place (or goes back to the top) and shows the newest call
					Target.Calls += 1
					Target.Time = Log.Time
					Target.Args = Log.Args
					Target.Count = Log.Count
					Target.Script = Log.Script or Target.Script
					Target.Signature = Log.Signature

					local History = Target.History

					table.insert(History, {Args = Log.Args, Count = Log.Count, Script = Log.Script, Time = Log.Time, Number = Target.Calls, Result = Log.Result, Signal = Log.Signal})

					Target.Result = Log.Result or Target.Result
					Target.Signal = Log.Signal or Target.Signal

					while #History > math.max(1, Settings.HistoryLimit) do
						table.remove(History, 1)

						-- keep looking at the same call while older ones drop off
						if Target.ViewIndex then
							Target.ViewIndex = math.max(1, Target.ViewIndex - 1)
						end
					end

					if Settings.StackToTop and Logs[1] ~= Target then
						local Position = table.find(Logs, Target)

						if Position then
							table.remove(Logs, Position)
						end

						table.insert(Logs, 1, Target)
					end

					if Target == Selected then
						DetailsDirty = true
					end
				else
					Log.History = {{Args = Log.Args, Count = Log.Count, Script = Log.Script, Time = Log.Time, Number = 1, Result = Log.Result, Signal = Log.Signal}}
					table.insert(Logs, 1, Log)
				end
			end

			while #Logs > Settings.MaxLogs do
				local Removed = table.remove(Logs)

				Unstack(Removed)

				if Removed == Selected then
					ShowDetails(nil)
				end
			end

			Rebuild()
		end

		-- the selected row got new calls: refresh its code now and then, not on every call
		if DetailsDirty and Selected and os.clock() - LastDetails > 0.5 then
			LastDetails = os.clock()
			DetailsDirty = false
			ShowDetails(Selected, true)
		end

		if Settings.Actors and Settings.WatchActors and os.clock() - LastActors > 3 then
			LastActors = os.clock()
			task.spawn(InjectActors, false)
		end
	end)
end

Connect(UserInputService.InputBegan, function(InputObject, Processed)
	if Processed then
		return
	end

	if Settings.PauseKey ~= "None" then
		local OkPause, PauseKey = pcall(function() return Enum.KeyCode[Settings.PauseKey] end)

		if OkPause and InputObject.KeyCode == PauseKey then
			Paused = not Paused
			UI.PauseButton.Text = Paused and "resume" or "pause"
			UI.PauseButton.TextColor3 = Paused and T.Accent or T.Text
			SetStatus(Paused and "paused" or "logging")

			return
		end
	end

	local Ok, Key = pcall(function() return Enum.KeyCode[Settings.ToggleKey] end)

	if Ok and InputObject.KeyCode == Key then
		Main.Visible = not Main.Visible
		CloseMenu()
	end
end)

Destroy = function()
	Active = false

	Shared.Capture = function() return false end
	Shared.Notify = function() end

	if Channel then
		pcall(function() Channel:Fire("stop") end)

		if Channel:IsA("BindableEvent") and Channel.Parent ~= nil then
			task.delay(1, function() pcall(function() Channel:Destroy() end) end)
		end
	end

	SetIncoming(false)

	for _, Connection in Connections do
		pcall(function() Connection:Disconnect() end)
	end

	Gui:Destroy()
	Env.LarpSpy = nil
end

Env.LarpSpy = {
	Destroy = Destroy,
	Settings = Settings,
	Logs = function() return Logs end,
	Block = SetBlocked,
	Ignore = SetIgnored,
}

if Settings.Incoming then
	SetIncoming(true)
end

if Settings.Actors then
	task.spawn(InjectActors, false)
end

SetStatus(HookStatus == "hooked" and "logging" or HookStatus)