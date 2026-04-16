-- made by @nfpw skidded from unknown source and sametexe001

local esp_module = {}

--// render utility
local utility = {}
function utility:render(class, properties)
    local instance = Instance.new(class)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

--// custom font
local custom_font = { }
do
    local http_service = cloneref(game:GetService("HttpService"))
    
    function custom_font:new(name, weight, style, data, assets_folder)
        local folder = assets_folder or "Enviro_Assets"
        
        if isfile(folder .. "/" .. name .. ".json") then
            return Font.new(getcustomasset(folder .. "/" .. name .. ".json"))
        end

        if not isfile(folder .. "/" .. name .. ".ttf") then 
            local request_func = (syn and syn.request) or (http and http.request) or request
            local response = request_func({
                Url = data.url,
                Method = "GET"
            })
            writefile(folder .. "/" .. name .. ".ttf", response.Body)
        end

        local font_data = {
            name = name,
            faces = { {
                name = "Regular",
                weight = weight,
                style = style,
                assetId = getcustomasset(folder .. "/" .. name .. ".ttf")
            } }
        }

        writefile(folder .. "/" .. name .. ".json", http_service:JSONEncode(font_data))
        return Font.new(getcustomasset(folder .. "/" .. name .. ".json"))
    end

    function custom_font:get(name, assets_folder)
        local folder = assets_folder or "Enviro_Assets"
        if isfile(folder .. "/" .. name .. ".json") then
            return Font.new(getcustomasset(folder .. "/" .. name .. ".json"))
        end
    end
end

--// create new esp instance
function esp_module.new(settings, parent_gui)
    local self = setmetatable({}, {__index = esp_module})
    
    self.settings = settings or {
        enabled = false,
        player_esp = {
            enabled = false,
            team_check = false,
            use_team_color = false,
            max_distance = 0,
            distance = {
                unit = "Meters",
                enabled = false,
                colors = {
                    text = Color3.fromRGB(255, 255, 255),
                    outline = Color3.fromRGB(0, 0, 0)
                }
            },
            username = {
                enabled = false,
                use_display_name = false,
                colors = {
                    text = Color3.fromRGB(255, 255, 255),
                    outline = Color3.fromRGB(0, 0, 0)
                },
                font_size = 14,
                font = nil
            },
            box = {
                enabled = false,
                colors = {
                    inline = Color3.fromRGB(255, 255, 255),
                    outline = Color3.fromRGB(0, 0, 0)
                },
                fill = {
                    enabled = false,
                    transparency = 0.5,
                    color = Color3.fromRGB(0, 0, 0),
                    custom_image = "None"
                }
            },
            health_bar = {
                enabled = false,
                colors = {
                    start = Color3.fromRGB(23, 255, 42),
                    finish = Color3.fromRGB(255, 35, 39),
                    outline = Color3.fromRGB(0, 0, 0)
                },
                health_text = {
                    enabled = false,
                    colors = {
                        match_health_color = true,
                        text = Color3.fromRGB(255, 255, 255),
                        outline = Color3.fromRGB(0, 0, 0)
                    },
                    font_size = 13
                }
            },
            tool = {
                enabled = false,
                colors = {
                    text = Color3.fromRGB(255, 255, 255),
                    outline = Color3.fromRGB(0, 0, 0)
                },
                font_size = 14
            }
        }
    }
    
    self.esp_gui = nil
    self.parent_gui = parent_gui or gethui()
    self.players_esp = {}
    self.players_data = {}
    self.last_state = true
    self.fonts = {}
    
    self:initialize()
    
    return self
end

function esp_module:initialize_fonts(assets_folder)
    local monaco_font = custom_font:new("Monaco", 400, "Regular", {
        url = "https://raw.githubusercontent.com/nfpw/Enviro/main/ui_library/assets/Monaco.ttf"
    }, assets_folder)
    
    self.fonts.default = monaco_font or Font.new()
    self.fonts.username = self.settings.player_esp.username.font or self.fonts.default
    self.fonts.health = self.fonts.default
    self.fonts.tool = self.fonts.default
    self.fonts.distance = self.fonts.default
end

function esp_module:initialize()
    local get_service = function(instance) return cloneref(game.GetService(game, instance)); end
    self.services = {
        players = get_service('Players'),
        run_service = get_service('RunService'),
        core_gui = get_service('CoreGui'),
        teams = get_service('Teams'),
        workspace = get_service('Workspace')
    }
    self.local_player = self.services.players.LocalPlayer
    self.camera = self.services.workspace.CurrentCamera
    self.viewport_size = self.camera.ViewportSize
    self.esp_gui = utility:render('ScreenGui', {
        Name = 'ESP_Render',
        Parent = self.parent_gui
    })
    self:initialize_fonts()
end

function esp_module:get_team_color(player)
    if not self.settings.player_esp.use_team_color then return nil end
    local team = player.Team
    if team then return team.TeamColor.Color end
    return nil
end

function esp_module:is_teammate(player)
    if not self.settings.player_esp.team_check then return false end
    if not self.local_player.Team then return false end
    return player.Team == self.local_player.Team
end

function esp_module:is_within_max_distance(distance)
    local max_distance = self.settings.player_esp.max_distance
    if max_distance <= 0 then return true end
    return distance <= max_distance
end

function esp_module:clean_all()
    for player, data in pairs(self.players_esp) do
        if type(data) == "table" and player ~= "clean_all" and player ~= self.local_player then
            self:remove_player(player)
        end
    end
end

function esp_module:get_players()
    local players_list = {}
    for _, v in self.services.players:GetPlayers() do
        if v ~= self.local_player then table.insert(players_list, v) end
    end
    return players_list
end

function esp_module:get_character(player)
    return player and player.Character
end

function esp_module:get_health(player)
    local character = self:get_character(player)
    local humanoid = character and character:FindFirstChild('Humanoid')
    if humanoid and humanoid.Health and humanoid.MaxHealth then
        return humanoid.Health, humanoid.MaxHealth
    end
    return 100, 100
end

function esp_module:get_tool(player)
    local character = self:get_character(player)
    if not character then return "None" end
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then return child.Name end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then return tool.Name.." (Backpack)" end
        end
    end
    return "None"
end

function esp_module:get_distance(from, to, unit)
    if not (from and from.Position and to and to.Position) then return 0 end
    local distance = (from.Position - to.Position).Magnitude
    return unit == "Meters" and distance * 0.28 or distance
end

function esp_module:is_alive(player)
    local character = self:get_character(player)
    local root_part = character and character:FindFirstChild('HumanoidRootPart')
    return player and character and root_part and self:get_health(player) > 0
end

function esp_module:remove_player(object)
    if not self.players_esp[object] then return end
    local elements = self.players_esp[object]
    if elements.holder then elements.holder:Destroy() end
    if elements.bounding_box and elements.bounding_box.image then
        elements.bounding_box.image:Destroy()
    end
    self.players_esp[object] = nil
    self.players_data[object] = nil
end

function esp_module:add_player(object)
    if self.players_esp[object] then return end

    self.players_esp[object] = {
        holder = utility:render('Frame', {
            Parent = self.esp_gui,
            Name = object.Name,
            BackgroundTransparency = 1,
            BorderSizePixel = 0
        }),
        bounding_box = {
            frame = utility:render("Frame", {
                Name = object.Name,
                BackgroundTransparency = 1,
                BorderSizePixel = 0
            }),
            outline = utility:render("UIStroke", {
                Enabled = false,
                Name = object.Name,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 3
            }),
            inline = utility:render("UIStroke", {
                Enabled = false,
                Name = object.Name,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 1
            }),
            image = utility:render("ImageLabel", {
                Name = object.Name .. "_BoxImage",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 1,
                ScaleType = Enum.ScaleType.Stretch
            })
        },
        health_bar = {
            outline = utility:render("Frame", {
                Name = object.Name,
                BackgroundTransparency = 1,
                BorderSizePixel = 0
            }),
            inline = utility:render("Frame", {
                Name = object.Name,
                BackgroundTransparency = 1,
                BorderSizePixel = 0
            }),
            gradient = utility:render("UIGradient", {
                Name = object.Name,
                Enabled = false
            }),
            value_text = utility:render("TextLabel", {
                Name = object.Name,
                BackgroundTransparency = 1,
                TextStrokeTransparency = 0,
                Font = self.fonts.health
            }),
            value_outline = utility:render("UIStroke", {
                Enabled = true,
                Name = object.Name,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 1
            })
        },
        username = {
            text = utility:render("TextLabel", {
                Name = object.Name,
                BackgroundTransparency = 1,
                TextStrokeTransparency = 0,
                Font = self.fonts.username
            }),
            outline = utility:render("UIStroke", {
                Enabled = true,
                Name = object.Name,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 1
            })
        },
        distance = {
            text = utility:render("TextLabel", {
                Name = object.Name,
                BackgroundTransparency = 1,
                TextStrokeTransparency = 0,
                Font = self.fonts.distance
            }),
            outline = utility:render("UIStroke", {
                Enabled = true,
                Name = object.Name,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 1
            })
        },
        tool = {
            text = utility:render("TextLabel", {
                Name = object.Name,
                BackgroundTransparency = 1,
                TextStrokeTransparency = 0,
                Font = self.fonts.tool
            }),
            outline = utility:render("UIStroke", {
                Enabled = true,
                Name = object.Name,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 1
            })
        }
    }

    self.players_data[object] = {
        health = 100,
        max_health = 100,
        is_alive = false,
        character = nil,
        root_part = nil,
        humanoid = nil,
        visible = false,
        position = Vector3.new(0, 0, 0),
        screen_position = Vector2.new(0, 0),
        on_screen = false,
        distance = 0,
        width = 0,
        height = 0,
        tool = "None",
        team_color = nil,
        within_max_distance = true
    }
end

function esp_module:check_for_left_players()
    local current_players = {}
    for _, player in pairs(self:get_players()) do
        current_players[player] = true
    end
    for player in pairs(self.players_data) do
        if not current_players[player] and player ~= self.local_player then
            self:remove_player(player)
        end
    end
end

function esp_module:update_player_data()
    while true do
        if self.settings.enabled and self.settings.player_esp.enabled then
            self:check_for_left_players()
            for _, player in pairs(self:get_players()) do
                if not self.players_data[player] then self:add_player(player) end
                local data = self.players_data[player]
                local character = self:get_character(player)
                local root_part = character and character:FindFirstChild('HumanoidRootPart')
                local humanoid = character and character:FindFirstChild('Humanoid')
                data.character = character
                data.root_part = root_part
                data.humanoid = humanoid
                data.is_alive = self:is_alive(player)
                data.health, data.max_health = self:get_health(player)
                data.tool = self:get_tool(player)
                data.team_color = self:get_team_color(player)
                data.is_teammate = self:is_teammate(player)
                if data.is_alive and data.root_part then
                    local camera_pos = self.camera.CFrame.Position
                    data.distance = (data.root_part.Position - camera_pos).Magnitude
                    if self.settings.player_esp.distance.unit == "Meters" then
                        data.distance = data.distance * 0.28
                    end
                    data.within_max_distance = self:is_within_max_distance(data.distance)
                else
                    data.visible = false
                    data.within_max_distance = false
                end
            end
            self.last_state = true
        elseif self.last_state then
            self:clean_all()
            self.last_state = false
        end
        task.wait(.1)
    end
end

function esp_module:start()
    self.services.players.PlayerRemoving:Connect(function(player)
        if player ~= self.local_player and self.players_esp[player] then
            self:remove_player(player)
        end
    end)

    spawn(function() self:update_player_data() end)

    self.services.run_service.Heartbeat:Connect(function()
        local esp_table = self.settings.player_esp
        if not self.settings.enabled or not esp_table.enabled then return end
        
        for player, elements in pairs(self.players_esp) do
            if type(elements) ~= 'table' or not elements.holder then continue end
            local data = self.players_data[player]
            if not data then continue end
            
            if esp_table.team_check and data.is_teammate and player ~= self.local_player then
                elements.holder.Visible = false
                continue
            end
            
            if not data.within_max_distance then
                elements.holder.Visible = false
                continue
            end
            
            if data.is_alive and data.root_part then
                local position, on_screen = self.camera:WorldToScreenPoint(data.root_part.Position)
                data.position = position
                data.on_screen = on_screen
                
                if on_screen then
                    local d = 3 * position.Z * math.tan(math.rad(self.camera.FieldOfView) / 2)
                    local scale = (data.root_part.Size.Y * self.viewport_size.Y) / d
                    data.height = 4.4 * scale
                    data.width = 3.2 * scale
                    data.visible = true
                    
                    elements.holder.Position = UDim2.fromOffset(position.X - data.width / 2, position.Y - data.height / 2.40)
                    elements.holder.Size = UDim2.fromOffset(data.width, data.height)
                    
                    -- Health bar
                    if esp_table.health_bar.enabled then
                        local health_scale = data.health / data.max_health
                        local health_inline = elements.health_bar.inline
                        local health_value = elements.health_bar.value_text
                        health_inline.Size = UDim2.new(1, -2, health_scale, -2)
                        health_inline.Position = UDim2.new(0, 1, 1 - health_scale, 1)
                        if esp_table.health_bar.health_text.enabled then
                            health_value.Position = UDim2.fromOffset(-34, data.height * (1 - health_scale) - 7)
                        end
                    end
                else
                    data.visible = false
                    elements.holder.Visible = false
                end
            else
                data.visible = false
                elements.holder.Visible = false
            end
        end
    end)
    
    -- update loop
    task.spawn(function()
        while task.wait(.1) do
            local esp_table = self.settings.player_esp
            if not self.settings.enabled or not esp_table.enabled then continue end
            
            for player, elements in pairs(self.players_esp) do
                if type(elements) ~= 'table' or not elements.holder then continue end
                if not player or not player.Parent then
                    self:remove_player(player)
                    continue
                end
                
                local data = self.players_data[player]
                if not data or not data.visible then continue end
                
                if self.settings.player_esp.team_check and data.is_teammate then
                    elements.holder.Visible = false
                    continue
                end
                
                if not data.within_max_distance then
                    elements.holder.Visible = false
                    continue
                end
                
                local holder = elements.holder
                local box = elements.bounding_box.frame
                local inline = elements.bounding_box.inline
                local outline = elements.bounding_box.outline
                local health_inline = elements.health_bar.inline
                local health_outline = elements.health_bar.outline
                local health_gradient = elements.health_bar.gradient
                local health_value = elements.health_bar.value_text
                local health_value_outline = elements.health_bar.value_outline
                local username_text = elements.username.text
                local username_outline = elements.username.outline
                local distance_text = elements.distance.text
                local distance_outline = elements.distance.outline
                local tool_text = elements.tool.text
                local tool_outline = elements.tool.outline
                local team_color = data.team_color
                local default_color = Color3.fromRGB(255, 255, 255)
                local player_name = esp_table.username.use_display_name and (player.DisplayName or player.Name) or player.Name
                local health, max_health = data.health, data.max_health
                local tool_name = data.tool or "None"
                local distance_text_value = esp_table.distance.unit == "Meters" and string.format("%.1fm", data.distance) or string.format("%d studs", math.floor(data.distance))
                
                holder.Visible = true
                
                -- Update fonts if changed
                if username_text.Font ~= self.fonts.username then
                    username_text.Font = self.fonts.username
                end
                if health_value.Font ~= self.fonts.health then
                    health_value.Font = self.fonts.health
                end
                if tool_text.Font ~= self.fonts.tool then
                    tool_text.Font = self.fonts.tool
                end
                if distance_text.Font ~= self.fonts.distance then
                    distance_text.Font = self.fonts.distance
                end
                
                -- Box rendering
                if esp_table.box.enabled then
                    local inline_color = team_color or esp_table.box.colors.inline or default_color
                    local outline_color = esp_table.box.colors.outline or Color3.fromRGB(0, 0, 0)
                    local fill_color = esp_table.box.fill.color or Color3.fromRGB(0, 0, 0)
                    local fill_transparency = esp_table.box.fill.transparency
                    box.Visible = true
                    box.Parent = holder
                    box.Position = UDim2.fromOffset(-1, -1)
                    box.Size = UDim2.new(1, 2, 1, 2)
                    inline.Enabled = true
                    inline.Parent = box
                    inline.Color = inline_color
                    outline.Enabled = true
                    outline.Parent = holder
                    outline.Color = outline_color
                    
                    if esp_table.box.fill.enabled then
                        if esp_table.box.fill.custom_image and esp_table.box.fill.custom_image ~= "None" then
                            if not elements.bounding_box.image then
                                elements.bounding_box.image = utility:render("ImageLabel", {
                                    Name = player.Name .. "_BoxImage",
                                    BackgroundTransparency = 1,
                                    BorderSizePixel = 0,
                                    ZIndex = 1,
                                    ScaleType = Enum.ScaleType.Stretch
                                })
                            end
                            local image = elements.bounding_box.image
                            image.Visible = true
                            image.Parent = holder
                            image.Position = UDim2.fromScale(0, 0)
                            image.Size = UDim2.fromScale(1, 1)
                            image.Image = esp_table.box.fill.custom_image
                            image.ImageTransparency = fill_transparency
                            image.ImageColor3 = fill_color
                            holder.BackgroundTransparency = 1
                        else
                            if elements.bounding_box.image then
                                elements.bounding_box.image.Visible = false
                            end
                            holder.BackgroundColor3 = fill_color
                            holder.BackgroundTransparency = fill_transparency
                        end
                    else
                        if elements.bounding_box.image then
                            elements.bounding_box.image.Visible = false
                        end
                        holder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                        holder.BackgroundTransparency = 1
                    end
                else
                    inline.Enabled = false
                    outline.Enabled = false
                    if elements.bounding_box.image then
                        elements.bounding_box.image.Visible = false
                    end
                end
                
                -- Health bar rendering
                if esp_table.health_bar.enabled then
                    local health_scale = health / max_health
                    local low_health = esp_table.health_bar.colors.finish or Color3.fromRGB(255, 35, 39)
                    local high_health = esp_table.health_bar.colors.start or Color3.fromRGB(23, 255, 42)
                    local outline_color = esp_table.health_bar.colors.outline or Color3.fromRGB(0, 0, 0)
                    local health_color = high_health:Lerp(low_health, 1 - health_scale)
                    health_outline.Visible = true
                    health_outline.Parent = holder
                    health_outline.BackgroundTransparency = 0
                    health_outline.BackgroundColor3 = outline_color
                    health_outline.Size = UDim2.fromOffset(4, data.height + 6)
                    health_outline.Position = UDim2.fromOffset(-9, -3)
                    health_inline.Visible = true
                    health_inline.Parent = health_outline
                    health_inline.BackgroundTransparency = 0
                    health_inline.BackgroundColor3 = health_color
                    health_gradient.Enabled = false
                    
                    if esp_table.health_bar.health_text.enabled then
                        local text_color = esp_table.health_bar.health_text.colors.match_health_color and health_color or (team_color or esp_table.health_bar.health_text.colors.text or default_color)
                        local outline_color_text = esp_table.health_bar.health_text.colors.outline or Color3.fromRGB(0, 0, 0)
                        health_value.Visible = true
                        health_value.Parent = holder
                        health_value.Text = math.floor(health)
                        health_value.TextColor3 = text_color
                        health_value.TextSize = esp_table.health_bar.health_text.font_size or 13
                        health_value.TextTransparency = 0
                        health_value.TextStrokeTransparency = 0.5
                        health_value.Size = UDim2.fromOffset(30, 15)
                        health_value.TextXAlignment = Enum.TextXAlignment.Center
                        health_value_outline.Enabled = true
                        health_value_outline.Parent = health_value
                        health_value_outline.Color = outline_color_text
                    else
                        health_value.Visible = false
                        health_value_outline.Enabled = false
                    end
                else
                    health_outline.Visible = false
                    health_inline.Visible = false
                    health_gradient.Enabled = false
                    health_value.Visible = false
                    health_value_outline.Enabled = false
                end
                
                -- Username rendering
                if esp_table.username.enabled then
                    local text_color = team_color or esp_table.username.colors.text or default_color
                    local outline_color = esp_table.username.colors.outline or Color3.fromRGB(0, 0, 0)
                    username_text.Visible = true
                    username_text.Parent = holder
                    username_text.TextColor3 = text_color
                    username_text.TextSize = esp_table.username.font_size or 14
                    username_text.TextTransparency = 0
                    username_text.TextStrokeTransparency = 1
                    username_text.Text = player_name
                    username_text.Size = UDim2.fromOffset(100, 0)
                    username_text.AutomaticSize = Enum.AutomaticSize.XY
                    username_text.TextXAlignment = Enum.TextXAlignment.Center
                    username_text.Position = UDim2.new(0.5, -username_text.Size.X.Offset/2, 0, -17)
                    username_outline.Enabled = true
                    username_outline.Parent = username_text
                    username_outline.Color = outline_color
                else
                    username_text.Visible = false
                    username_outline.Enabled = false
                end
                
                -- Distance rendering
                if esp_table.distance.enabled then
                    local text_color = team_color or esp_table.distance.colors.text or default_color
                    local outline_color = esp_table.distance.colors.outline or Color3.fromRGB(0, 0, 0)
                    distance_text.Visible = true
                    distance_text.Parent = holder
                    distance_text.Text = distance_text_value
                    distance_text.TextColor3 = text_color
                    distance_text.TextSize = 13
                    distance_text.TextTransparency = 0
                    distance_text.TextStrokeTransparency = 1
                    distance_text.Size = UDim2.fromOffset(60, 15)
                    distance_text.AutomaticSize = Enum.AutomaticSize.X
                    distance_text.TextXAlignment = Enum.TextXAlignment.Center
                    distance_text.Position = UDim2.new(1, -5, 0, -5)
                    distance_outline.Enabled = true
                    distance_outline.Parent = distance_text
                    distance_outline.Color = outline_color
                else
                    distance_text.Visible = false
                    distance_outline.Enabled = false
                end
                
                -- Tool rendering
                if esp_table.tool.enabled then
                    local text_color = team_color or esp_table.tool.colors.text or default_color
                    local outline_color = esp_table.tool.colors.outline or Color3.fromRGB(0, 0, 0)
                    tool_text.Visible = true
                    tool_text.Parent = holder
                    tool_text.Text = tool_name
                    tool_text.TextColor3 = text_color
                    tool_text.TextSize = esp_table.tool.font_size or 14
                    tool_text.TextTransparency = 0
                    tool_text.TextStrokeTransparency = 1
                    tool_text.Size = UDim2.fromOffset(100, 0)
                    tool_text.AutomaticSize = Enum.AutomaticSize.XY
                    tool_text.TextXAlignment = Enum.TextXAlignment.Center
                    tool_text.Position = UDim2.new(0.5, -tool_text.Size.X.Offset/2, 1, 2)
                    tool_outline.Enabled = true
                    tool_outline.Parent = tool_text
                    tool_outline.Color = outline_color
                else
                    tool_text.Visible = false
                    tool_outline.Enabled = false
                end
            end
        end
    end)
end

function esp_module:update_settings(new_settings)
    self.settings = new_settings
    if new_settings.player_esp.username.font then
        self.fonts.username = new_settings.player_esp.username.font
    end
    if new_settings.player_esp.tool.font then
        self.fonts.tool = new_settings.player_esp.tool.font
    end
end

function esp_module:toggle(toggle)
    self.settings.enabled = toggle
    if not toggle then
        self:clean_all()
    end
end

function esp_module:set_font(font_type, font)
    if font_type == "username" then
        self.fonts.username = font
        self.settings.player_esp.username.font = font
    elseif font_type == "health" then
        self.fonts.health = font
    elseif font_type == "tool" then
        self.fonts.tool = font
        self.settings.player_esp.tool.font = font
    elseif font_type == "distance" then
        self.fonts.distance = font
    end
end

return esp_module
