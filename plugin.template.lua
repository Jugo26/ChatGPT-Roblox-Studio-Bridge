-- ChatGPT Studio Bridge v1.0 - local, explicit opt-in command bridge.
assert(plugin, "Use as a Roblox Studio plugin")

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local BASE = "http://127.0.0.1:48765"
local TOKEN = "__BRIDGE_TOKEN__"
local ROOTS = {
    Workspace = true, Lighting = true, ReplicatedStorage = true,
    ReplicatedFirst = true, ServerScriptService = true, ServerStorage = true,
    StarterPlayer = true, StarterGui = true, StarterPack = true,
    SoundService = true, Teams = true, TextChatService = true,
    MaterialService = true,
}
local CLASSES = {
    Folder=true, Model=true, Part=true, WedgePart=true, CornerWedgePart=true,
    SpawnLocation=true, MeshPart=true, TrussPart=true, Seat=true, VehicleSeat=true,
    Attachment=true, PointLight=true, SpotLight=true, SurfaceLight=true,
    Decal=true, Texture=true, Sound=true, ParticleEmitter=true, Beam=true, Trail=true,
    Script=true, LocalScript=true, ModuleScript=true, Configuration=true,
    RemoteEvent=true, RemoteFunction=true, BindableEvent=true, BindableFunction=true,
    BoolValue=true, IntValue=true, NumberValue=true, StringValue=true,
    Vector3Value=true, CFrameValue=true, Color3Value=true,
    ScreenGui=true, BillboardGui=true, SurfaceGui=true, Frame=true,
    TextLabel=true, TextButton=true, TextBox=true, ImageLabel=true,
    ImageButton=true, ScrollingFrame=true, UIListLayout=true,
    UIGridLayout=true, UICorner=true, UIStroke=true, UIPadding=true,
    ProximityPrompt=true, ClickDetector=true, Tool=true,
    Humanoid=true, Animation=true, Animator=true,
}

local function getPath(obj)
    local reversed = {}
    while obj and obj ~= game do
        table.insert(reversed, 1, obj.Name)
        obj = obj.Parent
    end
    return reversed
end

local function resolve(path)
    assert(type(path) == "table" and #path >= 1 and #path <= 40, "path must be a 1-40 element array")
    assert(ROOTS[path[1]], "root not allowed: " .. tostring(path[1]))
    local current = game:GetService(path[1])
    for index = 2, #path do
        assert(type(path[index]) == "string", "invalid path segment")
        current = current:FindFirstChild(path[index])
        assert(current, "instance not found: " .. table.concat(path, "/"))
    end
    return current
end

local function decodeValue(value)
    if type(value) ~= "table" then return value end
    local t = value.type
    if t == "Vector3" then return Vector3.new(value.x, value.y, value.z) end
    if t == "Vector2" then return Vector2.new(value.x, value.y) end
    if t == "Color3" then return Color3.new(value.r, value.g, value.b) end
    if t == "BrickColor" then return BrickColor.new(value.name) end
    if t == "UDim" then return UDim.new(value.scale, value.offset) end
    if t == "UDim2" then return UDim2.new(value.xScale, value.xOffset, value.yScale, value.yOffset) end
    if t == "CFrame" then
        if type(value.components) == "table" then return CFrame.new(table.unpack(value.components)) end
        return CFrame.new(value.x, value.y, value.z)
    end
    if t == "Enum" then
        local group = Enum[value.enum]
        assert(group and group[value.name], "unknown enum")
        return group[value.name]
    end
    if t == "Instance" then return resolve(value.path) end
    error("unsupported value type: " .. tostring(t))
end

local function encodeValue(value)
    local kind = typeof(value)
    if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then return value end
    if kind == "Vector3" then return {type="Vector3",x=value.X,y=value.Y,z=value.Z} end
    if kind == "Vector2" then return {type="Vector2",x=value.X,y=value.Y} end
    if kind == "Color3" then return {type="Color3",r=value.R,g=value.G,b=value.B} end
    if kind == "CFrame" then return {type="CFrame",components={value:GetComponents()}} end
    if kind == "EnumItem" then
        return {type="Enum",enum=tostring(value.EnumType):gsub("Enum%." ,""),name=value.Name}
    end
    if kind == "Instance" then return {type="Instance",path=getPath(value)} end
    return tostring(value)
end

local function describe(obj)
    local result = {name=obj.Name,class=obj.ClassName,path=getPath(obj),children=#obj:GetChildren()}
    if obj:IsA("BasePart") then
        result.position = encodeValue(obj.Position)
        result.size = encodeValue(obj.Size)
    end
    return result
end

local function tree(obj, depth, budget)
    budget.n += 1
    local item = describe(obj)
    if depth > 0 and budget.n < 200 then
        item.items = {}
        for _,child in ipairs(obj:GetChildren()) do
            if budget.n >= 200 then item.truncated = true; break end
            table.insert(item.items, tree(child, depth - 1, budget))
        end
    end
    return item
end

local function setProperties(obj, properties)
    assert(type(properties) == "table", "properties object expected")
    for key, value in pairs(properties) do
        assert(type(key)=="string" and key ~= "Parent" and key ~= "Source" and key ~= "ClassName", "property not editable")
        obj[key] = decodeValue(value)
    end
end

local function perform(cmd)
    assert(type(cmd) == "table" and type(cmd.op) == "string", "op is required")
    local op = cmd.op
    if op == "ping" then
        return {ok=true,place=game.Name,placeId=game.PlaceId,version="1.0"}
    elseif op == "tree" then
        local obj = resolve(cmd.path or {"Workspace"})
        return tree(obj, math.clamp(tonumber(cmd.depth) or 2, 0, 5), {n=0})
    elseif op == "selection" then
        local list = {}
        for _,obj in ipairs(Selection:Get()) do table.insert(list, describe(obj)) end
        return list
    elseif op == "get" then
        local obj = resolve(cmd.path)
        local result = describe(obj)
        result.properties = {}
        for _, key in ipairs(cmd.properties or {"Name"}) do
            if key == "Source" and obj:IsA("LuaSourceContainer") then
                result.properties[key] = ScriptEditorService:GetEditorSource(obj)
            else
                local success, value = pcall(function() return obj[key] end)
                if success then result.properties[key] = encodeValue(value) end
            end
        end
        return result
    elseif op == "select" then
        local selected = {}
        for _,path in ipairs(cmd.paths or {}) do table.insert(selected, resolve(path)) end
        Selection:Set(selected)
        return {count=#selected}
    elseif op == "create" then
        assert(CLASSES[cmd.class], "class not allowed: " .. tostring(cmd.class))
        local parent = resolve(cmd.parent)
        local newObj = Instance.new(cmd.class)
        local success, err = pcall(function()
            if cmd.name then newObj.Name=cmd.name end
            if cmd.properties then setProperties(newObj,cmd.properties) end
            newObj.Parent = parent
            if cmd.source ~= nil then
                assert(newObj:IsA("LuaSourceContainer"), "source only for scripts")
                ScriptEditorService:UpdateSourceAsync(newObj, function() return cmd.source end)
            end
        end)
        if not success then newObj:Destroy(); error(err) end
        return describe(newObj)
    elseif op == "set" then
        local obj = resolve(cmd.path)
        setProperties(obj, cmd.properties)
        return describe(obj)
    elseif op == "script" then
        local obj = resolve(cmd.path)
        assert(obj:IsA("LuaSourceContainer") and type(cmd.source)=="string", "script and source required")
        ScriptEditorService:UpdateSourceAsync(obj, function() return cmd.source end)
        return {path=getPath(obj),length=#cmd.source}
    elseif op == "rename" then
        local obj = resolve(cmd.path)
        assert(type(cmd.name)=="string", "name required")
        obj.Name = cmd.name
        return describe(obj)
    elseif op == "clone" then
        local obj = resolve(cmd.path)
        local copy = obj:Clone()
        assert(copy, "cannot clone")
        if cmd.name then copy.Name=cmd.name end
        copy.Parent = cmd.parent and resolve(cmd.parent) or obj.Parent
        return describe(copy)
    elseif op == "move" then
        local obj = resolve(cmd.path)
        obj.Parent = resolve(cmd.parent)
        return describe(obj)
    elseif op == "delete" then
        local obj = resolve(cmd.path)
        local before = describe(obj)
        assert(obj.Parent ~= game, "cannot delete root services")
        obj:Destroy()
        return before
    elseif op == "batch" then
        assert(type(cmd.commands)=="table" and #cmd.commands > 0 and #cmd.commands<=80, "batch needs 1-80 commands")
        local result={}
        for _,subcommand in ipairs(cmd.commands) do
            assert(subcommand.op ~= "batch", "nested batches disabled")
            table.insert(result, perform(subcommand))
        end
        return result
    end
    error("unknown operation: " .. op)
end

local function execute(cmd)
    local readonly = {ping=true,tree=true,selection=true,get=true,select=true}
    if readonly[cmd.op] then return perform(cmd) end
    local recording = ChangeHistoryService:TryBeginRecording("ChatGPT_Bridge_" .. cmd.op, "ChatGPT Bridge: " .. cmd.op)
    assert(recording, "cannot edit during playtest or while recording")
    local success, result = pcall(perform, cmd)
    ChangeHistoryService:FinishRecording(recording, success and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    if not success then error(result) end
    return result
end

local toolbar = plugin:CreateToolbar("ChatGPT Bridge")
local openButton = toolbar:CreateButton("ChatGPT Bridge", "Abrir painel de conexão com o ChatGPT", "")
local widget = plugin:CreateDockWidgetPluginGuiAsync("ChatGPTStudioBridgeV1", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, true, false, 330, 330, 270, 250))
widget.Title = "ChatGPT Studio Bridge"

local function make(className, attributes, parent)
    local instance = Instance.new(className)
    for k,v in pairs(attributes) do instance[k]=v end
    instance.Parent=parent
    return instance
end
local background = make("Frame", {Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(20,24,34),BorderSizePixel=0},widget)
local layout = make("UIListLayout", {Padding=UDim.new(0,12),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},background)
make("UIPadding",{PaddingTop=UDim.new(0,18),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},background)
local heading=make("TextLabel",{LayoutOrder=1,Size=UDim2.new(1,0,0,38),BackgroundTransparency=1,Text="STUDIO BRIDGE",Font=Enum.Font.GothamBold,TextSize=21,TextColor3=Color3.fromRGB(225,234,255)},background)
local detail=make("TextLabel",{LayoutOrder=2,Size=UDim2.new(1,0,0,54),BackgroundTransparency=1,TextWrapped=true,Text="ponte local para editar objetos, scripts e mapas pelo ChatGPT",Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(158,172,195)},background)
local status=make("TextLabel",{LayoutOrder=3,Size=UDim2.new(1,0,0,48),BackgroundColor3=Color3.fromRGB(34,39,53),Text="desativado",TextWrapped=true,Font=Enum.Font.Gotham,TextSize=14,TextColor3=Color3.fromRGB(249,200,126)},background)
make("UICorner",{CornerRadius=UDim.new(0,9)},status)
local toggle=make("TextButton",{LayoutOrder=4,Size=UDim2.new(1,0,0,44),BackgroundColor3=Color3.fromRGB(54,109,229),Text="CONECTAR",Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.new(1,1,1)},background)
make("UICorner",{CornerRadius=UDim.new(0,9)},toggle)
local last=make("TextLabel",{LayoutOrder=5,Size=UDim2.new(1,0,0,72),BackgroundTransparency=1,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,Text="nenhuma alteração realizada nesta sessão",Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(160,177,196)},background)

local enabled=false
local function updateButton()
    toggle.Text = enabled and "DESCONECTAR" or "CONECTAR"
    toggle.BackgroundColor3 = enabled and Color3.fromRGB(160,68,83) or Color3.fromRGB(54,109,229)
end
openButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)
toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    status.Text = enabled and "conectando à ponte local..." or "desativado"
    updateButton()
end)

local function request(path, method, payload)
    local opts = {
        Url = BASE .. path, Method = method,
        Headers = {["X-Bridge-Token"] = TOKEN, ["Content-Type"] = "application/json"},
    }
    if payload then opts.Body = HttpService:JSONEncode(payload) end
    local response = HttpService:RequestAsync(opts)
    assert(response.Success, "HTTP " .. tostring(response.StatusCode))
    return HttpService:JSONDecode(response.Body)
end

task.spawn(function()
    local cycle=0
    while true do
        task.wait(1.0)
        if enabled then
            cycle+=1
            local ok, result=pcall(function()
                if cycle%5==1 then
                    request("/heartbeat", "POST", {place=game.Name,placeId=game.PlaceId,enabled=true})
                end
                return request("/next", "GET")
            end)
            if not ok then
                status.Text="sem conexão: inicie run_bridge.bat\n" .. tostring(result):sub(1,110)
            else
                status.Text="conectado • " .. game.Name
                local job=result.job
                if job then
                    local complete,data=pcall(execute,job.command)
                    local report = {id=job.id,ok=complete,result=complete and data or nil,error=not complete and tostring(data) or nil}
                    local posted,postErr=pcall(function() request("/result", "POST", report) end)
                    last.Text=job.command.op .. " • " .. (complete and "concluído" or ("erro: " .. tostring(data)))
                    if not posted then status.Text="erro ao enviar resultado: " .. tostring(postErr):sub(1,90) end
                end
            end
        end
    end
end)
