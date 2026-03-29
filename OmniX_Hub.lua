local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

pcall(function()
    for _,g in pairs(player:WaitForChild("PlayerGui"):GetChildren()) do
        if g.Name == "OmniXV3" then g:Destroy() end
    end
end)

local RAIDS = {
    {name="Dr Animal", nivel=1, btn="Animal"},
    {name="Drone Gigante", nivel=50, btn="Drone"},
    {name="Grande Escorpiao", nivel=125, btn="Escorpi"},
    {name="Crakao", nivel=180, btn="Crakao"},
    {name="Vilgax Raid", nivel=400, btn="Vilgax"},
    {name="Totem de Puch", nivel=500, btn="Puch"},
    {name="Forever Knights", nivel=750, btn="Eternal"},
    {name="Highbreed DNA", nivel=750, btn="Highbreed"},
    {name="Rojo Boss", nivel=800, btn="Rojo"},
    {name="Dagon Raid", nivel=950, btn="Dagon"},
    {name="Templo do Sol", nivel=1000, btn="Sol"},
    {name="Fistrick Raid", nivel=1200, btn="Fistrick"},
    {name="Albedo", nivel=1500, btn="Albedo"},
    {name="Monstro Dimensional", nivel=1500, btn="Dimensional"},
}

local QUESTS = {
    {name="Defesa da Terra", lv=0, xp=100},
    {name="Defesa da Terra 2", lv=25, xp=150},
    {name="Instinto Primario", lv=50, xp=175},
    {name="Limaxes", lv=75, xp=200},
    {name="Grande Escorpiao", lv=125, xp=225},
    {name="Floresta do Terror", lv=150, xp=250},
    {name="Em Nosso Honor", lv=800, xp=400},
    {name="Templo do Sol", lv=1000, xp=1250},
    {name="Invasao Suprema", lv=1700, xp=800},
    {name="Infinito 1", lv=2500, xp=1750},
    {name="Perplexahedro", lv=2750, xp=3500},
}

local LOCS = {
    "Spawn","Escola","Garagem","Posto","Restaurante","Museu",
    "Torre","Loja","Floresta","Acampamento","Cratera","Ponte",
    "Encanadores","Soledad","Paradox","Castelo","Ascalon",
    "Lua","Marte","Perplexaedron","Aeroporto","Militar",
    "Dojo","Piscciss","Academia","Galvan","DNA","Omini",
    "Terra","Carteira","Criacao","Subterraneas",
}

local NPCS = {"Azmuth","Kevin","Anodite","Paradox","Galvan"}

local ALIENS = {
    "explosao de fogo","wildmutt","diamante","xrl8","greymatter",
    "quatrobracos","ripjaws","mosca fedorenta","melhoria","ghostfreak",
    "bala de canhao","vinha selvatica","blitzwolfer","snareoh",
    "ataque de Frankenstein","esputar","eyeguy","waybig","mesmo",
    "comentarios","buzzshock","articguana","lancador","relogio",
    "tempestade cerebral","spidermonkey","vai","lodestar","raiva",
}

local godOn = false
local farmOn = false
local replayOn = false
local killMobOn = false
local auraOn = false
local auraR = 35
local espOn = false
local infEn = false
local autoTr = false
local selAlien = 1
local curTab = "Farm"
local wSpd = 16
local jPow = 50
local perpOn = false
local axOn = false
local autoWatch = false
local autoMaster = false
local selRaid = nil

local gui = Instance.new("ScreenGui")
gui.Name = "OmniXV3"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() if syn then syn.protect_gui(gui) end end)
gui.Parent = player:WaitForChild("PlayerGui")

local function c3(r,g,b) return Color3.fromRGB(r,g,b) end
local purple = c3(120,60,200)
local purpleL = c3(170,120,255)
local purpleD = c3(80,40,140)
local dark = c3(14,12,20)
local dark2 = c3(22,18,32)
local dark3 = c3(30,25,45)
local white = c3(255,255,255)
local dimW = c3(170,165,190)
local red = c3(180,40,40)
local green = c3(50,200,80)
local yellow = c3(230,200,50)

local function noti(msg)
    pcall(function()
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0,280,0,34)
        f.Position = UDim2.new(0.5,-140,0,-40)
        f.BackgroundColor3 = purple
        f.BorderSizePixel = 0
        f.ZIndex = 50
        f.Parent = gui
        Instance.new("UICorner",f).CornerRadius = UDim.new(0,8)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1,-10,1,0)
        t.Position = UDim2.new(0,5,0,0)
        t.BackgroundTransparency = 1
        t.Text = msg
        t.TextColor3 = white
        t.Font = Enum.Font.GothamBold
        t.TextSize = 11
        t.TextWrapped = true
        t.ZIndex = 51
        t.Parent = f
        TweenService:Create(f,TweenInfo.new(0.3,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-140,0,8)}):Play()
        task.delay(2.5,function()
            TweenService:Create(f,TweenInfo.new(0.3),{Position=UDim2.new(0.5,-140,0,-45)}):Play()
            task.wait(0.4)
            pcall(function() f:Destroy() end)
        end)
    end)
end

local function fireGameButton(keyword)
    local found = false
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if not pgui then return end
        for _,desc in pairs(pgui:GetDescendants()) do
            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                local txt = ""
                if desc:IsA("TextButton") then txt = desc.Text:lower() end
                if txt:find("ir para") or txt:find("teleport") or txt:find("go to") then
                    local parentChain = ""
                    local p = desc.Parent
                    for i=1,8 do
                        if p then
                            parentChain = parentChain .. " " .. p.Name:lower()
                            if p:IsA("TextLabel") then
                                parentChain = parentChain .. " " .. p.Text:lower()
                            end
                            p = p.Parent
                        end
                    end
                    for _,sib in pairs(desc.Parent:GetChildren()) do
                        if sib:IsA("TextLabel") then
                            parentChain = parentChain .. " " .. sib.Text:lower()
                        end
                    end
                    if parentChain:find(keyword:lower()) then
                        pcall(function()
                            desc.Visible = true
                            firesignal(desc.MouseButton1Click)
                        end)
                        pcall(function()
                            firesignal(desc.Activated)
                        end)
                        found = true
                        return
                    end
                end
            end
        end
    end)
    return found
end

local function fireRemoteTP(keyword)
    pcall(function()
        for _,obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n = obj.Name:lower()
                if n:find("teleport") or n:find("tp") or n:find("goto") or n:find("travel") or n:find("warp") then
                    pcall(function() obj:FireServer(keyword) end)
                    pcall(function() obj:FireServer("teleport", keyword) end)
                end
            end
        end
        for _,obj in pairs(game:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n = obj.Name:lower()
                if n:find("teleport") or n:find("tp") or n:find("goto") or n:find("warp") then
                    pcall(function() obj:FireServer(keyword) end)
                end
            end
        end
    end)
end

local function clickNearbyPrompts()
    pcall(function()
        if not rootPart then return end
        for _,obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local par = obj.Parent
                if par and par:IsA("BasePart") then
                    if (rootPart.Position - par.Position).Magnitude < 25 then
                        pcall(function() fireproximityprompt(obj) end)
                    end
                elseif par then
                    local bp = par:FindFirstChildWhichIsA("BasePart")
                    if bp and (rootPart.Position - bp.Position).Magnitude < 25 then
                        pcall(function() fireproximityprompt(obj) end)
                    end
                end
            end
            if obj:IsA("ClickDetector") then
                local par = obj.Parent
                if par and par:IsA("BasePart") then
                    if (rootPart.Position - par.Position).Magnitude < 25 then
                        pcall(function() fireclickdetector(obj) end)
                    end
                end
            end
        end
    end)
end

local function smartTP(keyword)
    noti("Buscando: "..keyword)
    local ok = fireGameButton(keyword)
    if not ok then
        fireRemoteTP(keyword)
    end
    pcall(function()
        for _,obj in pairs(Workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Name:lower():find(keyword:lower()) then
                local part
                if obj:IsA("Model") then
                    part = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                else
                    part = obj
                end
                if part and rootPart then
                    rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0,5,0))
                    noti("TP: "..keyword.." OK!")
                    return
                end
            end
        end
    end)
    task.delay(0.5, function()
        clickNearbyPrompts()
    end)
end

local function getMobs()
    local m = {}
    pcall(function()
        for _,o in pairs(Workspace:GetDescendants()) do
            if o:IsA("Humanoid") and o.Health > 0 and o.Parent ~= character then
                local isP = false
                for _,p in pairs(Players:GetPlayers()) do
                    if p.Character == o.Parent then isP = true break end
                end
                if not isP then
                    local hr = o.Parent:FindFirstChild("HumanoidRootPart") or o.Parent:FindFirstChild("Torso") or o.Parent:FindFirstChild("UpperTorso") or o.Parent:FindFirstChildWhichIsA("BasePart")
                    if hr then
                        table.insert(m,{h=o, r=hr, md=o.Parent})
                    end
                end
            end
        end
    end)
    return m
end

local function kMob(mob)
    pcall(function() mob.h.Health = 0 end)
    pcall(function()
        if rootPart and mob.r then
            firetouchinterest(rootPart, mob.r, 0)
            task.wait()
            firetouchinterest(rootPart, mob.r, 1)
        end
    end)
    pcall(function()
        mob.md:Destroy()
    end)
end

local function tpToMob(mob)
    pcall(function()
        if rootPart and mob.r then
            rootPart.CFrame = CFrame.new(mob.r.Position + Vector3.new(0,3,0))
        end
    end)
end

local function getLvl()
    local lv = 0
    pcall(function()
        local g = player:FindFirstChild("PlayerGui")
        if g then
            for _,d in pairs(g:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t = d.Text
                    local m = t:match("Lv%.%s*(%d+)") or t:match("Level%s*(%d+)") or t:match("Nivel%s*(%d+)") or t:match("Lv%s*(%d+)")
                    if m then lv = tonumber(m) return end
                end
            end
        end
    end)
    pcall(function()
        local ls = player:FindFirstChild("leaderstats") or player:FindFirstChild("Data") or player:FindFirstChild("Stats")
        if ls then
            for _,v in pairs(ls:GetChildren()) do
                local n = v.Name:lower()
                if n:find("lv") or n:find("level") or n:find("nivel") then
                    if v.Value and tonumber(v.Value) then
                        lv = tonumber(v.Value)
                    end
                end
            end
        end
    end)
    return lv
end

local function bestRaid(lv)
    local b = nil
    for i=#RAIDS,1,-1 do
        if lv >= RAIDS[i].nivel then b = RAIDS[i] break end
    end
    return b
end

local function collectWatches()
    pcall(function()
        for _,obj in pairs(Workspace:GetDescendants()) do
            local n = obj.Name:lower()
            if n:find("relogio") or n:find("watch") or n:find("omnitrix") or n:find("clock") or n:find("colet") then
                if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                    if rootPart then
                        local old = rootPart.CFrame
                        rootPart.CFrame = CFrame.new(obj.Position)
                        task.wait(0.15)
                        pcall(function()
                            firetouchinterest(rootPart, obj, 0)
                            task.wait()
                            firetouchinterest(rootPart, obj, 1)
                        end)
                    end
                end
                if obj:IsA("Model") then
                    local bp = obj:FindFirstChildWhichIsA("BasePart")
                    if bp and rootPart then
                        rootPart.CFrame = CFrame.new(bp.Position)
                        task.wait(0.15)
                        pcall(function()
                            firetouchinterest(rootPart, bp, 0)
                            task.wait()
                            firetouchinterest(rootPart, bp, 1)
                        end)
                    end
                end
            end
            if obj:IsA("ProximityPrompt") then
                local pn = obj.Parent and obj.Parent.Name:lower() or ""
                if pn:find("relogio") or pn:find("watch") or pn:find("omnitrix") then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
            if obj:IsA("ClickDetector") then
                local pn = obj.Parent and obj.Parent.Name:lower() or ""
                if pn:find("relogio") or pn:find("watch") or pn:find("omnitrix") then
                    pcall(function() fireclickdetector(obj) end)
                end
            end
        end
    end)
end

local function tryMasterControl()
    pcall(function()
        for _,obj in pairs(game:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                if n:find("master") or n:find("control") or n:find("mastercontrol") then
                    if obj:IsA("RemoteEvent") then
                        obj:FireServer()
                        obj:FireServer(true)
                        obj:FireServer("activate")
                    else
                        pcall(function() obj:InvokeServer() end)
                        pcall(function() obj:InvokeServer(true) end)
                    end
                end
            end
        end
        for _,obj in pairs(game:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                if n:find("transform") or n:find("omnitrix") or n:find("alien") then
                    if obj:IsA("RemoteEvent") then
                        pcall(function() obj:FireServer("mastercontrol") end)
                        pcall(function() obj:FireServer("master_control") end)
                        pcall(function() obj:FireServer("MasterControl") end)
                    end
                end
            end
        end
    end)
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if pgui then
            for _,d in pairs(pgui:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) then
                    local txt = d:IsA("TextButton") and d.Text:lower() or d.Name:lower()
                    if txt:find("master") or txt:find("control") or txt:find("desbloque") then
                        pcall(function() firesignal(d.MouseButton1Click) end)
                        pcall(function() firesignal(d.Activated) end)
                    end
                end
            end
        end
    end)
end

local mf = Instance.new("Frame")
mf.Name = "Main"
mf.Size = UDim2.new(0,370,0,430)
mf.Position = UDim2.new(0.5,-185,0.5,-215)
mf.BackgroundColor3 = dark
mf.BorderSizePixel = 0
mf.Active = true
mf.Draggable = true
mf.Parent = gui
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,10)
local ms = Instance.new("UIStroke",mf)
ms.Color = purple
ms.Thickness = 1.5

local hd = Instance.new("Frame")
hd.Size = UDim2.new(1,0,0,32)
hd.BackgroundColor3 = dark2
hd.BorderSizePixel = 0
hd.Parent = mf
Instance.new("UICorner",hd).CornerRadius = UDim.new(0,10)
local hfix = Instance.new("Frame")
hfix.Size = UDim2.new(1,0,0,10)
hfix.Position = UDim2.new(0,0,1,-10)
hfix.BackgroundColor3 = dark2
hfix.BorderSizePixel = 0
hfix.Parent = hd

local tl = Instance.new("TextLabel")
tl.Size = UDim2.new(1,-70,1,0)
tl.Position = UDim2.new(0,10,0,0)
tl.BackgroundTransparency = 1
tl.Text = "Omni-X Hub v3.1"
tl.TextColor3 = purpleL
tl.Font = Enum.Font.GothamBold
tl.TextSize = 13
tl.TextXAlignment = Enum.TextXAlignment.Left
tl.Parent = hd

local xBtn = Instance.new("TextButton")
xBtn.Size = UDim2.new(0,24,0,24)
xBtn.Position = UDim2.new(1,-28,0,4)
xBtn.BackgroundColor3 = red
xBtn.Text = "X"
xBtn.TextColor3 = white
xBtn.Font = Enum.Font.GothamBold
xBtn.TextSize = 12
xBtn.BorderSizePixel = 0
xBtn.Parent = hd
Instance.new("UICorner",xBtn).CornerRadius = UDim.new(0,6)
xBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local mBtn = Instance.new("TextButton")
mBtn.Size = UDim2.new(0,24,0,24)
mBtn.Position = UDim2.new(1,-56,0,4)
mBtn.BackgroundColor3 = dark3
mBtn.Text = "_"
mBtn.TextColor3 = white
mBtn.Font = Enum.Font.GothamBold
mBtn.TextSize = 12
mBtn.BorderSizePixel = 0
mBtn.Parent = hd
Instance.new("UICorner",mBtn).CornerRadius = UDim.new(0,6)

local isMin = false
mBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        TweenService:Create(mf,TweenInfo.new(0.25),{Size=UDim2.new(0,370,0,32)}):Play()
    else
        TweenService:Create(mf,TweenInfo.new(0.25),{Size=UDim2.new(0,370,0,430)}):Play()
    end
end)

local tabF = Instance.new("Frame")
tabF.Size = UDim2.new(1,-6,0,24)
tabF.Position = UDim2.new(0,3,0,34)
tabF.BackgroundTransparency = 1
tabF.Parent = mf

local TABS = {"Farm","Raids","Quests","TP","Player","ESP"}
local tabBtns = {}
local tabPages = {}
local tabW = math.floor(364 / #TABS)

for i,tn in ipairs(TABS) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0,tabW,1,0)
    tb.Position = UDim2.new(0,(i-1)*tabW,0,0)
    tb.BackgroundColor3 = (tn==curTab) and purple or dark3
    tb.Text = tn
    tb.TextColor3 = (tn==curTab) and white or dimW
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 10
    tb.BorderSizePixel = 0
    tb.Parent = tabF
    Instance.new("UICorner",tb).CornerRadius = UDim.new(0,5)
    tabBtns[tn] = tb

    local pg = Instance.new("ScrollingFrame")
    pg.Name = tn
    pg.Size = UDim2.new(1,-6,1,-62)
    pg.Position = UDim2.new(0,3,0,60)
    pg.BackgroundTransparency = 1
    pg.ScrollBarThickness = 3
    pg.ScrollBarImageColor3 = purple
    pg.CanvasSize = UDim2.new(0,0,0,0)
    pg.AutomaticCanvasSize = Enum.AutomaticSize.Y
    pg.Visible = (tn==curTab)
    pg.BorderSizePixel = 0
    pg.Parent = mf
    Instance.new("UIListLayout",pg).Padding = UDim.new(0,4)
    local pd = Instance.new("UIPadding",pg)
    pd.PaddingLeft = UDim.new(0,3)
    pd.PaddingRight = UDim.new(0,3)
    pd.PaddingTop = UDim.new(0,3)
    tabPages[tn] = pg
end

local function swTab(name)
    curTab = name
    for n,p in pairs(tabPages) do p.Visible = (n==name) end
    for n,b in pairs(tabBtns) do
        b.BackgroundColor3 = (n==name) and purple or dark3
        b.TextColor3 = (n==name) and white or dimW
    end
end
for n,b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function() swTab(n) end)
end

local lo = 0
local function nxO() lo=lo+1 return lo end

local function mkSec(pg,txt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,22)
    f.BackgroundColor3 = dark2
    f.BorderSizePixel = 0
    f.LayoutOrder = nxO()
    f.Parent = pg
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,5)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-8,1,0)
    l.Position = UDim2.new(0,6,0,0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = purpleL
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
end

local function mkTog(pg,txt,val,cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,28)
    f.BackgroundColor3 = dark2
    f.BorderSizePixel = 0
    f.LayoutOrder = nxO()
    f.Parent = pg
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,5)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-52,1,0)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = white
    l.Font = Enum.Font.Gotham
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0,34,0,16)
    bg.Position = UDim2.new(1,-42,0.5,-8)
    bg.BackgroundColor3 = val and purple or dark3
    bg.BorderSizePixel = 0
    bg.Parent = f
    Instance.new("UICorner",bg).CornerRadius = UDim.new(1,0)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0,12,0,12)
    dot.Position = val and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
    dot.BackgroundColor3 = white
    dot.BorderSizePixel = 0
    dot.Parent = bg
    Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
    local on = val
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = f
    btn.MouseButton1Click:Connect(function()
        on = not on
        bg.BackgroundColor3 = on and purple or dark3
        dot.Position = on and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
        if cb then cb(on) end
        noti(txt..": "..(on and "ON" or "OFF"))
    end)
end

local function mkBtn(pg,txt,cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,26)
    b.BackgroundColor3 = purple
    b.Text = txt
    b.TextColor3 = white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.BorderSizePixel = 0
    b.LayoutOrder = nxO()
    b.Parent = pg
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,5)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function mkBtn2(pg,txt,cb,col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,26)
    b.BackgroundColor3 = col or purpleD
    b.Text = txt
    b.TextColor3 = white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.BorderSizePixel = 0
    b.LayoutOrder = nxO()
    b.Parent = pg
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,5)
    b.MouseButton1Click:Connect(cb)
    return b
end

lo = 0
local fp = tabPages["Farm"]
mkSec(fp,"-- AUTO FARM RAID --")
mkTog(fp,"Auto Farm Raid (Melhor p/ Nivel)",false,function(v) farmOn=v end)
mkTog(fp,"Auto Replay Raid",false,function(v) replayOn=v end)
mkTog(fp,"Auto Kill Mob (Mata Tudo)",false,function(v) killMobOn=v end)
mkTog(fp,"Kill Aura (Perto de Voce)",false,function(v) auraOn=v end)

mkSec(fp,"-- RELOGIOS E MASTER --")
mkTog(fp,"Auto Coletar Relogios",false,function(v) autoWatch=v end)
mkTog(fp,"Auto Master Control (1%)",false,function(v) autoMaster=v end)

mkSec(fp,"-- TRANSFORM --")
mkTog(fp,"Auto Transform",false,function(v) autoTr=v end)

local alLbl = Instance.new("TextLabel")
alLbl.Size = UDim2.new(1,0,0,24)
alLbl.BackgroundColor3 = dark2
alLbl.BorderSizePixel = 0
alLbl.Text = "  Alien: "..ALIENS[selAlien]
alLbl.TextColor3 = white
alLbl.Font = Enum.Font.Gotham
alLbl.TextSize = 10
alLbl.TextXAlignment = Enum.TextXAlignment.Left
alLbl.LayoutOrder = nxO()
alLbl.Parent = fp
Instance.new("UICorner",alLbl).CornerRadius = UDim.new(0,5)

mkBtn2(fp,"< Alien Anterior",function()
    selAlien = selAlien - 1
    if selAlien < 1 then selAlien = #ALIENS end
    alLbl.Text = "  Alien: "..ALIENS[selAlien]
end, dark3)
mkBtn2(fp,"Proximo Alien >",function()
    selAlien = selAlien + 1
    if selAlien > #ALIENS then selAlien = 1 end
    alLbl.Text = "  Alien: "..ALIENS[selAlien]
end, dark3)

mkSec(fp,"-- ENERGIA --")
mkTog(fp,"Energia Infinita",false,function(v) infEn=v end)

lo = 0
local rp = tabPages["Raids"]
mkSec(rp,"-- RAID INTELIGENTE --")

local rInfo = Instance.new("TextLabel")
rInfo.Size = UDim2.new(1,0,0,22)
rInfo.BackgroundColor3 = dark2
rInfo.BorderSizePixel = 0
rInfo.Text = "  Nivel: ? | Raid: ?"
rInfo.TextColor3 = dimW
rInfo.Font = Enum.Font.Gotham
rInfo.TextSize = 10
rInfo.TextXAlignment = Enum.TextXAlignment.Left
rInfo.LayoutOrder = nxO()
rInfo.Parent = rp
Instance.new("UICorner",rInfo).CornerRadius = UDim.new(0,5)

mkBtn(rp,"DETECTAR NIVEL + MELHOR RAID",function()
    local lv = getLvl()
    local br = bestRaid(lv)
    if br then
        rInfo.Text = "  Lv "..lv.." -> "..br.name
        selRaid = br
        noti("Raid: "..br.name)
    else
        rInfo.Text = "  Lv "..lv.." -> Nenhuma raid"
    end
end)

mkBtn(rp,"IR PARA RAID SELECIONADA",function()
    if selRaid then
        noti("Indo para: "..selRaid.name)
        smartTP(selRaid.btn)
    else
        noti("Detecte seu nivel primeiro!")
    end
end)

mkSec(rp,"-- TODAS AS RAIDS --")
for _,rd in ipairs(RAIDS) do
    mkBtn(rp,rd.name.." (Lv"..rd.nivel..")",function()
        noti("Indo: "..rd.name)
        smartTP(rd.btn)
    end)
end

mkSec(rp,"-- MISSOES ESPECIAIS --")
mkTog(rp,"Auto Perplexahedro (Completo)",false,function(v) perpOn=v end)
mkTog(rp,"Auto Alien X Quests",false,function(v) axOn=v end)
mkBtn(rp,"TP Perplexaedron AGORA",function()
    smartTP("Perplexaedron")
    smartTP("Perplexahedro")
end)
mkBtn(rp,"TP Torre Omini (Alien X) AGORA",function()
    smartTP("Omini")
    smartTP("Alien")
end)

lo = 0
local qp = tabPages["Quests"]
mkSec(qp,"-- MISSOES SOLO --")
for _,q in ipairs(QUESTS) do
    mkBtn(qp,q.name.." (Lv"..q.lv.." "..q.xp.."XP)",function()
        noti("Missao: "..q.name)
        smartTP(q.name)
    end)
end

lo = 0
local tp2 = tabPages["TP"]
mkSec(tp2,"-- LOCALIZACOES --")
for _,loc in ipairs(LOCS) do
    mkBtn2(tp2,loc,function()
        smartTP(loc)
    end, purpleD)
end

mkSec(tp2,"-- NPCS IMPORTANTES --")
for _,npc in ipairs(NPCS) do
    mkBtn(tp2,"-> "..npc,function()
        smartTP(npc)
    end)
end

lo = 0
local pp = tabPages["Player"]
mkSec(pp,"-- PLAYER --")
mkTog(pp,"God Mode",false,function(v) godOn=v end)

mkSec(pp,"-- WALKSPEED --")
mkBtn2(pp,"Speed 50",function() wSpd=50 noti("Speed: 50") end, dark3)
mkBtn2(pp,"Speed 100",function() wSpd=100 noti("Speed: 100") end, dark3)
mkBtn2(pp,"Speed 200",function() wSpd=200 noti("Speed: 200") end, dark3)
mkBtn(pp,"Speed NORMAL (16)",function() wSpd=16 noti("Speed: Normal") end)

mkSec(pp,"-- JUMP --")
mkBtn2(pp,"Jump 100",function() jPow=100 noti("Jump: 100") end, dark3)
mkBtn2(pp,"Jump 200",function() jPow=200 noti("Jump: 200") end, dark3)
mkBtn(pp,"Jump NORMAL (50)",function() jPow=50 noti("Jump: Normal") end)

mkSec(pp,"-- INFO --")
local pInfo = Instance.new("TextLabel")
pInfo.Size = UDim2.new(1,0,0,22)
pInfo.BackgroundColor3 = dark2
pInfo.BorderSizePixel = 0
pInfo.Text = "  "..player.Name
pInfo.TextColor3 = dimW
pInfo.Font = Enum.Font.Gotham
pInfo.TextSize = 10
pInfo.TextXAlignment = Enum.TextXAlignment.Left
pInfo.LayoutOrder = nxO()
pInfo.Parent = pp
Instance.new("UICorner",pInfo).CornerRadius = UDim.new(0,5)

mkBtn(pp,"Mostrar Nivel",function()
    local lv = getLvl()
    pInfo.Text = "  "..player.Name.." | Nivel: "..lv
    noti("Nivel: "..lv)
end)

lo = 0
local ep = tabPages["ESP"]
mkSec(ep,"-- ESP --")
mkTog(ep,"ESP Inimigos (Vermelho)",false,function(v) espOn=v end)

mkSec(ep,"-- DEBUG --")
mkBtn(ep,"Listar RemoteEvents",function()
    local count = 0
    for _,o in pairs(game:GetDescendants()) do
        if o:IsA("RemoteEvent") then
            local n = o.Name:lower()
            if n:find("tp") or n:find("teleport") or n:find("warp") or n:find("travel") or n:find("goto") or n:find("raid") or n:find("mission") or n:find("quest") or n:find("boss") or n:find("master") or n:find("transform") then
                count = count + 1
                print("[OmniX] Remote: "..o:GetFullName())
            end
        end
    end
    noti("Encontrados "..count.." remotes (ver console F9)")
end)

mkBtn(ep,"Listar Botoes GUI do Jogo",function()
    local count = 0
    local pgui = player:FindFirstChild("PlayerGui")
    if pgui then
        for _,d in pairs(pgui:GetDescendants()) do
            if d:IsA("TextButton") then
                local t = d.Text:lower()
                if t:find("ir para") or t:find("teleport") or t:find("go to") or t:find("iniciar") or t:find("entrar") then
                    count = count + 1
                    print("[OmniX] Btn: "..d:GetFullName().." = "..d.Text)
                end
            end
        end
    end
    noti("Encontrados "..count.." botoes (ver console F9)")
end)

local function refreshChar()
    pcall(function()
        character = player.Character or player.CharacterAdded:Wait()
        humanoid = character:WaitForChild("Humanoid")
        rootPart = character:WaitForChild("HumanoidRootPart")
    end)
end

player.CharacterAdded:Connect(function(c)
    character = c
    task.wait(1)
    pcall(function()
        humanoid = c:WaitForChild("Humanoid")
        rootPart = c:WaitForChild("HumanoidRootPart")
    end)
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        if not character or not humanoid or humanoid.Health <= 0 then
            refreshChar()
            return
        end
        if godOn then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
        end
        if wSpd ~= 16 then humanoid.WalkSpeed = wSpd end
        if jPow ~= 50 then humanoid.JumpPower = jPow end
    end)
end)

task.spawn(function()
    while task.wait(0.15) do
        if infEn then
            pcall(function()
                for _,o in pairs(player:GetDescendants()) do
                    local n = o.Name:lower()
                    if (n:find("energy") or n:find("energia") or n:find("stamina") or n:find("mana")) and (o:IsA("NumberValue") or o:IsA("IntValue")) then
                        o.Value = 9999
                    end
                end
                if character then
                    for _,o in pairs(character:GetDescendants()) do
                        local n = o.Name:lower()
                        if (n:find("energy") or n:find("energia")) and (o:IsA("NumberValue") or o:IsA("IntValue")) then
                            o.Value = 9999
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.25) do
        if auraOn then
            pcall(function()
                for _,mob in pairs(getMobs()) do
                    if rootPart and mob.r then
                        if (rootPart.Position - mob.r.Position).Magnitude <= auraR then
                            tpToMob(mob)
                            task.wait(0.05)
                            kMob(mob)
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.4) do
        if killMobOn then
            pcall(function()
                for _,mob in pairs(getMobs()) do
                    tpToMob(mob)
                    task.wait(0.05)
                    kMob(mob)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if autoTr then
            pcall(function()
                for _,o in pairs(game:GetDescendants()) do
                    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                        local n = o.Name:lower()
                        if n:find("transform") or n:find("alien") or n:find("omnitrix") then
                            pcall(function()
                                if o:IsA("RemoteEvent") then
                                    o:FireServer(ALIENS[selAlien])
                                else
                                    o:InvokeServer(ALIENS[selAlien])
                                end
                            end)
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(3) do
        if farmOn then
            pcall(function()
                local lv = getLvl()
                local br = selRaid or bestRaid(lv)
                if br then
                    smartTP(br.btn)
                    task.wait(3)
                    for _,mob in pairs(getMobs()) do
                        tpToMob(mob)
                        task.wait(0.1)
                        kMob(mob)
                    end
                    clickNearbyPrompts()
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1.5) do
        if perpOn or axOn then
            pcall(function()
                for _,mob in pairs(getMobs()) do
                    tpToMob(mob)
                    task.wait(0.05)
                    kMob(mob)
                end
                clickNearbyPrompts()
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(5) do
        if autoWatch then
            pcall(function()
                collectWatches()
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(10) do
        if autoMaster then
            pcall(function()
                tryMasterControl()
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(4) do
        if espOn then
            pcall(function()
                for _,o in pairs(Workspace:GetDescendants()) do
                    if o:IsA("Humanoid") and o.Health > 0 and o.Parent ~= character then
                        local isP = false
                        for _,p in pairs(Players:GetPlayers()) do
                            if p.Character == o.Parent then isP=true break end
                        end
                        if not isP and not o.Parent:FindFirstChild("ESPB") then
                            local bx = Instance.new("SelectionBox")
                            bx.Name = "ESPB"
                            bx.Adornee = o.Parent
                            bx.Color3 = c3(255,50,50)
                            bx.LineThickness = 0.03
                            bx.Parent = o.Parent
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "ESPBB"
                            bb.Size = UDim2.new(0,100,0,30)
                            bb.StudsOffset = Vector3.new(0,3,0)
                            bb.AlwaysOnTop = true
                            bb.Adornee = o.Parent:FindFirstChild("HumanoidRootPart") or o.Parent:FindFirstChildWhichIsA("BasePart")
                            bb.Parent = o.Parent
                            local tl2 = Instance.new("TextLabel")
                            tl2.Size = UDim2.new(1,0,1,0)
                            tl2.BackgroundTransparency = 1
                            tl2.Text = o.Parent.Name.." "..math.floor(o.Health).."HP"
                            tl2.TextColor3 = c3(255,80,80)
                            tl2.Font = Enum.Font.GothamBold
                            tl2.TextSize = 11
                            tl2.TextStrokeTransparency = 0.5
                            tl2.Parent = bb
                        end
                    end
                end
            end)
        else
            pcall(function()
                for _,o in pairs(Workspace:GetDescendants()) do
                    if o.Name == "ESPB" or o.Name == "ESPBB" then o:Destroy() end
                end
            end)
        end
    end
end)

UserInputService.InputBegan:Connect(function(i,p)
    if p then return end
    if i.KeyCode == Enum.KeyCode.Insert then mf.Visible = not mf.Visible end
    if i.KeyCode == Enum.KeyCode.F6 then godOn = not godOn noti("God: "..(godOn and "ON" or "OFF")) end
    if i.KeyCode == Enum.KeyCode.F7 then farmOn = not farmOn noti("Farm: "..(farmOn and "ON" or "OFF")) end
end)

local wm = Instance.new("TextLabel")
wm.Size = UDim2.new(0,230,0,20)
wm.Position = UDim2.new(0,6,0,3)
wm.BackgroundColor3 = dark
wm.BackgroundTransparency = 0.3
wm.Text = " Omni-X v3.1 | "..player.Name
wm.TextColor3 = purpleL
wm.Font = Enum.Font.GothamBold
wm.TextSize = 10
wm.TextXAlignment = Enum.TextXAlignment.Left
wm.BorderSizePixel = 0
wm.Parent = gui
Instance.new("UICorner",wm).CornerRadius = UDim.new(0,5)

noti("Omni-X Hub v3.1 Carregado!")
task.wait(1)
noti("Use aba ESP > Debug para ver remotes do jogo")
