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
    {name="Dr Animal", nivel=1},
    {name="Drone Gigante", nivel=50},
    {name="Grande Escorpiao", nivel=125},
    {name="Crakao", nivel=180},
    {name="Vilgax", nivel=400},
    {name="Totem de Puch", nivel=500},
    {name="Forever Knights", nivel=750},
    {name="Highbreed", nivel=750},
    {name="Rojo", nivel=800},
    {name="Dagon", nivel=950},
    {name="Templo do Sol", nivel=1000},
    {name="Fistrick", nivel=1200},
    {name="Albedo", nivel=1500},
    {name="Monstro Dimensional", nivel=1500},
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
local inRaid = false
local farmBusy = false

local gui = Instance.new("ScreenGui")
gui.Name = "OmniXV3"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
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
        f.ZIndex = 999
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
        t.ZIndex = 1000
        t.Parent = f
        TweenService:Create(f,TweenInfo.new(0.3,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-140,0,8)}):Play()
        task.delay(2.5,function()
            TweenService:Create(f,TweenInfo.new(0.3),{Position=UDim2.new(0.5,-140,0,-45)}):Play()
            task.wait(0.4)
            pcall(function() f:Destroy() end)
        end)
    end)
end

local function findPart(keyword)
    local result = nil
    pcall(function()
        local kw = keyword:lower()
        for _,o in pairs(Workspace:GetDescendants()) do
            if o:IsA("Model") and o.Name:lower():find(kw) then
                local p = o:FindFirstChild("HumanoidRootPart") or o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
                if p then result = p return end
            end
        end
        if not result then
            for _,o in pairs(Workspace:GetDescendants()) do
                if o:IsA("BasePart") and o.Name:lower():find(kw) then
                    result = o
                    return
                end
            end
        end
    end)
    return result
end

local function safeTP(keyword)
    if not rootPart then return false end
    local part = findPart(keyword)
    if part then
        rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0,5,0))
        return true
    end
    return false
end

local function clickPrompts()
    pcall(function()
        if not rootPart then return end
        for _,obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local par = obj.Parent
                if par then
                    local bp = par:IsA("BasePart") and par or par:FindFirstChildWhichIsA("BasePart")
                    if bp and (rootPart.Position - bp.Position).Magnitude < 20 then
                        pcall(function() fireproximityprompt(obj) end)
                    end
                end
            end
            if obj:IsA("ClickDetector") then
                local par = obj.Parent
                if par and par:IsA("BasePart") and (rootPart.Position - par.Position).Magnitude < 20 then
                    pcall(function() fireclickdetector(obj) end)
                end
            end
        end
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
                    local hr = o.Parent:FindFirstChild("HumanoidRootPart")
                        or o.Parent:FindFirstChild("Torso")
                        or o.Parent:FindFirstChild("UpperTorso")
                        or o.Parent:FindFirstChildWhichIsA("BasePart")
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
            rootPart.CFrame = CFrame.new(mob.r.Position + Vector3.new(0,2,0))
            task.wait(0.05)
            firetouchinterest(rootPart, mob.r, 0)
            task.wait()
            firetouchinterest(rootPart, mob.r, 1)
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
                    local t = d.Text or ""
                    local m = t:match("Lv%.%s*(%d+)")
                        or t:match("Level%s*(%d+)")
                        or t:match("Nivel%s*(%d+)")
                        or t:match("Lv%s*(%d+)")
                    if m and tonumber(m) > lv then
                        lv = tonumber(m)
                    end
                end
            end
        end
    end)
    pcall(function()
        local ls = player:FindFirstChild("leaderstats") or player:FindFirstChild("Data") or player:FindFirstChild("Stats")
        if ls then
            for _,v in pairs(ls:GetChildren()) do
                local n = v.Name:lower()
                if (n:find("lv") or n:find("level") or n:find("nivel")) and v.Value then
                    local val = tonumber(v.Value)
                    if val and val > lv then lv = val end
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

local function fireTransform(alienName)
    pcall(function()
        for _,obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n = obj.Name:lower()
                if n:find("transform") or n:find("omnitrix") or n:find("alien") or n:find("morph") or n:find("forma") then
                    pcall(function() obj:FireServer(alienName) end)
                    pcall(function() obj:FireServer("transform", alienName) end)
                    pcall(function() obj:FireServer(alienName, true) end)
                end
            end
            if obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                if n:find("transform") or n:find("omnitrix") or n:find("alien") then
                    pcall(function() obj:InvokeServer(alienName) end)
                end
            end
        end
    end)
    pcall(function()
        for _,obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n = obj.Name:lower()
                if n:find("transform") or n:find("omnitrix") then
                    pcall(function() obj:FireServer(alienName) end)
                end
            end
        end
    end)
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if pgui then
            for _,d in pairs(pgui:GetDescendants()) do
                if d:IsA("TextButton") then
                    local txt = d.Text:lower()
                    if txt == alienName:lower() or txt:find(alienName:lower()) then
                        pcall(function() firesignal(d.MouseButton1Click) end)
                    end
                end
            end
        end
    end)
end

local function collectWatches()
    pcall(function()
        for _,obj in pairs(Workspace:GetDescendants()) do
            local n = obj.Name:lower()
            if n:find("relogio") or n:find("watch") or n:find("omnitrix") or n:find("colet") then
                if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                    if rootPart then
                        rootPart.CFrame = CFrame.new(obj.Position)
                        task.wait(0.2)
                        pcall(function()
                            firetouchinterest(rootPart, obj, 0)
                            task.wait(0.1)
                            firetouchinterest(rootPart, obj, 1)
                        end)
                    end
                end
            end
            if obj:IsA("ProximityPrompt") then
                local pn = obj.Parent and obj.Parent.Name:lower() or ""
                if pn:find("relogio") or pn:find("watch") or pn:find("omnitrix") or pn:find("colet") then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
        end
    end)
end

local function tryMasterControl()
    pcall(function()
        for _,obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n = obj.Name:lower()
                if n:find("master") or n:find("control") then
                    pcall(function() obj:FireServer() end)
                    pcall(function() obj:FireServer(true) end)
                end
            end
        end
    end)
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if pgui then
            for _,d in pairs(pgui:GetDescendants()) do
                if d:IsA("TextButton") then
                    local txt = d.Text:lower()
                    if txt:find("master") or txt:find("control") then
                        pcall(function() firesignal(d.MouseButton1Click) end)
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
mf.ZIndex = 100
mf.Parent = gui
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke",mf).Color = purple
Instance.new("UIStroke",mf).Thickness = 1.5

local hd = Instance.new("Frame")
hd.Size = UDim2.new(1,0,0,32)
hd.BackgroundColor3 = dark2
hd.BorderSizePixel = 0
hd.ZIndex = 101
hd.Parent = mf
Instance.new("UICorner",hd).CornerRadius = UDim.new(0,10)
local hfix = Instance.new("Frame")
hfix.Size = UDim2.new(1,0,0,10)
hfix.Position = UDim2.new(0,0,1,-10)
hfix.BackgroundColor3 = dark2
hfix.BorderSizePixel = 0
hfix.ZIndex = 101
hfix.Parent = hd

local tl = Instance.new("TextLabel")
tl.Size = UDim2.new(1,-40,1,0)
tl.Position = UDim2.new(0,10,0,0)
tl.BackgroundTransparency = 1
tl.Text = "Omni-X Hub v3.2"
tl.TextColor3 = purpleL
tl.Font = Enum.Font.GothamBold
tl.TextSize = 13
tl.TextXAlignment = Enum.TextXAlignment.Left
tl.ZIndex = 102
tl.Parent = hd

local mBtn = Instance.new("TextButton")
mBtn.Size = UDim2.new(0,28,0,28)
mBtn.Position = UDim2.new(1,-32,0,2)
mBtn.BackgroundColor3 = purple
mBtn.Text = "_"
mBtn.TextColor3 = white
mBtn.Font = Enum.Font.GothamBold
mBtn.TextSize = 14
mBtn.BorderSizePixel = 0
mBtn.ZIndex = 103
mBtn.Parent = hd
Instance.new("UICorner",mBtn).CornerRadius = UDim.new(0,6)

local isMin = false
mBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        TweenService:Create(mf,TweenInfo.new(0.25),{Size=UDim2.new(0,370,0,32)}):Play()
        mBtn.Text = "+"
    else
        TweenService:Create(mf,TweenInfo.new(0.25),{Size=UDim2.new(0,370,0,430)}):Play()
        mBtn.Text = "_"
    end
end)

local tabF = Instance.new("Frame")
tabF.Size = UDim2.new(1,-6,0,26)
tabF.Position = UDim2.new(0,3,0,34)
tabF.BackgroundTransparency = 1
tabF.ZIndex = 101
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
    tb.TextSize = 11
    tb.BorderSizePixel = 0
    tb.ZIndex = 102
    tb.Parent = tabF
    Instance.new("UICorner",tb).CornerRadius = UDim.new(0,5)
    tabBtns[tn] = tb

    local pg = Instance.new("ScrollingFrame")
    pg.Name = tn
    pg.Size = UDim2.new(1,-6,1,-64)
    pg.Position = UDim2.new(0,3,0,62)
    pg.BackgroundTransparency = 1
    pg.ScrollBarThickness = 4
    pg.ScrollBarImageColor3 = purple
    pg.CanvasSize = UDim2.new(0,0,0,0)
    pg.AutomaticCanvasSize = Enum.AutomaticSize.Y
    pg.Visible = (tn==curTab)
    pg.BorderSizePixel = 0
    pg.ZIndex = 101
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
    f.Size = UDim2.new(1,0,0,24)
    f.BackgroundColor3 = dark2
    f.BorderSizePixel = 0
    f.LayoutOrder = nxO()
    f.ZIndex = 102
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
    l.ZIndex = 103
    l.Parent = f
end

local function mkTog(pg,txt,val,cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,32)
    f.BackgroundColor3 = dark2
    f.BorderSizePixel = 0
    f.LayoutOrder = nxO()
    f.ZIndex = 102
    f.Parent = pg
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,5)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-56,1,0)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = white
    l.Font = Enum.Font.Gotham
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 103
    l.Parent = f
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0,38,0,20)
    bg.Position = UDim2.new(1,-46,0.5,-10)
    bg.BackgroundColor3 = val and purple or dark3
    bg.BorderSizePixel = 0
    bg.ZIndex = 103
    bg.Parent = f
    Instance.new("UICorner",bg).CornerRadius = UDim.new(1,0)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0,16,0,16)
    dot.Position = val and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    dot.BackgroundColor3 = white
    dot.BorderSizePixel = 0
    dot.ZIndex = 104
    dot.Parent = bg
    Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
    local on = val
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 105
    btn.Parent = f
    btn.MouseButton1Click:Connect(function()
        on = not on
        bg.BackgroundColor3 = on and purple or dark3
        dot.Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
        if cb then cb(on) end
        noti(txt..": "..(on and "ON" or "OFF"))
    end)
end

local function mkBtn(pg,txt,cb,col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,30)
    b.BackgroundColor3 = col or purple
    b.Text = txt
    b.TextColor3 = white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    b.LayoutOrder = nxO()
    b.ZIndex = 103
    b.Parent = pg
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
    return b
end

lo = 0
local fp = tabPages["Farm"]
mkSec(fp,"AUTO FARM")
mkTog(fp,"Auto Farm Raid (1 Raid, repete)",false,function(v) farmOn=v end)
mkTog(fp,"Auto Kill Mob (so em Raid)",false,function(v) killMobOn=v end)
mkTog(fp,"Kill Aura (perto de voce)",false,function(v) auraOn=v end)

mkSec(fp,"RELOGIOS E MASTER")
mkTog(fp,"Auto Coletar Relogios",false,function(v) autoWatch=v end)
mkTog(fp,"Auto Master Control",false,function(v) autoMaster=v end)

mkSec(fp,"TRANSFORM")
mkTog(fp,"Auto Transform",false,function(v) autoTr=v end)

local alLbl = Instance.new("TextLabel")
alLbl.Size = UDim2.new(1,0,0,26)
alLbl.BackgroundColor3 = dark2
alLbl.BorderSizePixel = 0
alLbl.Text = "  Alien: "..ALIENS[selAlien]
alLbl.TextColor3 = white
alLbl.Font = Enum.Font.GothamBold
alLbl.TextSize = 11
alLbl.TextXAlignment = Enum.TextXAlignment.Left
alLbl.LayoutOrder = nxO()
alLbl.ZIndex = 103
alLbl.Parent = fp
Instance.new("UICorner",alLbl).CornerRadius = UDim.new(0,5)

mkBtn(fp,"<< Alien Anterior",function()
    selAlien = selAlien - 1
    if selAlien < 1 then selAlien = #ALIENS end
    alLbl.Text = "  Alien: "..ALIENS[selAlien]
    noti("Alien: "..ALIENS[selAlien])
end, dark3)
mkBtn(fp,"Proximo Alien >>",function()
    selAlien = selAlien + 1
    if selAlien > #ALIENS then selAlien = 1 end
    alLbl.Text = "  Alien: "..ALIENS[selAlien]
    noti("Alien: "..ALIENS[selAlien])
end, dark3)
mkBtn(fp,"TRANSFORMAR AGORA",function()
    noti("Transformando: "..ALIENS[selAlien])
    fireTransform(ALIENS[selAlien])
end)

mkSec(fp,"ENERGIA")
mkTog(fp,"Energia Infinita",false,function(v) infEn=v end)

lo = 0
local rp = tabPages["Raids"]
mkSec(rp,"RAID INTELIGENTE")

local rInfo = Instance.new("TextLabel")
rInfo.Size = UDim2.new(1,0,0,26)
rInfo.BackgroundColor3 = dark2
rInfo.BorderSizePixel = 0
rInfo.Text = "  Toque Detectar para comecar"
rInfo.TextColor3 = dimW
rInfo.Font = Enum.Font.GothamBold
rInfo.TextSize = 10
rInfo.TextXAlignment = Enum.TextXAlignment.Left
rInfo.LayoutOrder = nxO()
rInfo.ZIndex = 103
rInfo.Parent = rp
Instance.new("UICorner",rInfo).CornerRadius = UDim.new(0,5)

mkBtn(rp,"DETECTAR NIVEL + MELHOR RAID",function()
    local lv = getLvl()
    local br = bestRaid(lv)
    if br then
        rInfo.Text = "  Lv "..lv.." -> "..br.name.." (Lv"..br.nivel..")"
        selRaid = br
        noti("Selecionada: "..br.name)
    else
        rInfo.Text = "  Lv "..lv.." -> Nenhuma raid"
        noti("Nenhuma raid para seu nivel")
    end
end)

mkSec(rp,"SELECIONAR RAID MANUAL")
for _,rd in ipairs(RAIDS) do
    mkBtn(rp,rd.name.." (Lv"..rd.nivel..")",function()
        selRaid = rd
        rInfo.Text = "  Selecionada: "..rd.name
        noti("Raid: "..rd.name)
    end, purpleD)
end

mkSec(rp,"MISSOES ESPECIAIS")
mkTog(rp,"Auto Perplexahedro",false,function(v) perpOn=v end)
mkTog(rp,"Auto Alien X Quests",false,function(v) axOn=v end)

lo = 0
local qp = tabPages["Quests"]
mkSec(qp,"MISSOES SOLO")
for _,q in ipairs(QUESTS) do
    mkBtn(qp,q.name.." (Lv"..q.lv.." "..q.xp.."XP)",function()
        noti("Buscando: "..q.name)
        local ok = safeTP(q.name)
        if ok then
            noti("TP: "..q.name.." OK!")
        else
            noti(q.name.." nao encontrado no mapa")
        end
    end, purpleD)
end

lo = 0
local tp2 = tabPages["TP"]
mkSec(tp2,"LOCALIZACOES")
for _,loc in ipairs(LOCS) do
    mkBtn(tp2,loc,function()
        local ok = safeTP(loc)
        if ok then
            noti("TP: "..loc.." OK!")
        else
            noti(loc.." nao encontrado")
        end
    end, purpleD)
end

mkSec(tp2,"NPCS IMPORTANTES")
for _,npc in ipairs(NPCS) do
    mkBtn(tp2,"-> "..npc,function()
        local ok = safeTP(npc)
        if ok then
            noti("NPC: "..npc.." OK!")
            task.wait(0.5)
            clickPrompts()
        else
            noti(npc.." nao encontrado")
        end
    end)
end

lo = 0
local pp = tabPages["Player"]
mkSec(pp,"PLAYER STATUS")
mkTog(pp,"God Mode",false,function(v) godOn=v end)

mkSec(pp,"WALKSPEED")
mkBtn(pp,"Speed 50",function() wSpd=50 noti("Speed: 50") end, dark3)
mkBtn(pp,"Speed 100",function() wSpd=100 noti("Speed: 100") end, dark3)
mkBtn(pp,"Speed 200",function() wSpd=200 noti("Speed: 200") end, dark3)
mkBtn(pp,"Speed NORMAL",function() wSpd=16 noti("Speed: Normal") end)

mkSec(pp,"JUMP POWER")
mkBtn(pp,"Jump 100",function() jPow=100 noti("Jump: 100") end, dark3)
mkBtn(pp,"Jump 200",function() jPow=200 noti("Jump: 200") end, dark3)
mkBtn(pp,"Jump NORMAL",function() jPow=50 noti("Jump: Normal") end)

mkSec(pp,"INFO")
local pInfo = Instance.new("TextLabel")
pInfo.Size = UDim2.new(1,0,0,24)
pInfo.BackgroundColor3 = dark2
pInfo.BorderSizePixel = 0
pInfo.Text = "  "..player.Name
pInfo.TextColor3 = dimW
pInfo.Font = Enum.Font.Gotham
pInfo.TextSize = 10
pInfo.TextXAlignment = Enum.TextXAlignment.Left
pInfo.LayoutOrder = nxO()
pInfo.ZIndex = 103
pInfo.Parent = pp
Instance.new("UICorner",pInfo).CornerRadius = UDim.new(0,5)

mkBtn(pp,"Mostrar Nivel",function()
    local lv = getLvl()
    pInfo.Text = "  "..player.Name.." | Nivel: "..lv
    noti("Nivel: "..lv)
end)

lo = 0
local ep = tabPages["ESP"]
mkSec(ep,"ESP")
mkTog(ep,"ESP Inimigos (Vermelho)",false,function(v) espOn=v end)

mkSec(ep,"DEBUG REMOTES")
mkBtn(ep,"Ver RemoteEvents no Console",function()
    local count = 0
    for _,o in pairs(ReplicatedStorage:GetDescendants()) do
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
            count = count + 1
            print("[OmniX] "..o.ClassName..": "..o:GetFullName())
        end
    end
    noti(count.." remotes encontrados (F9)")
end)

mkBtn(ep,"Ver Botoes do Jogo no Console",function()
    local count = 0
    local pgui = player:FindFirstChild("PlayerGui")
    if pgui then
        for _,d in pairs(pgui:GetDescendants()) do
            if d:IsA("TextButton") and d.Text ~= "" then
                count = count + 1
                print("[OmniX] BTN: "..d.Text.." | "..d:GetFullName())
            end
        end
    end
    noti(count.." botoes encontrados (F9)")
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
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        if auraOn and rootPart then
            pcall(function()
                for _,mob in pairs(getMobs()) do
                    if mob.r and (rootPart.Position - mob.r.Position).Magnitude <= auraR then
                        kMob(mob)
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if killMobOn and inRaid and rootPart then
            pcall(function()
                for _,mob in pairs(getMobs()) do
                    kMob(mob)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(2) do
        if autoTr then
            fireTransform(ALIENS[selAlien])
        end
    end
end)

task.spawn(function()
    while task.wait(5) do
        if farmOn and not farmBusy then
            farmBusy = true
            pcall(function()
                if not selRaid then
                    local lv = getLvl()
                    selRaid = bestRaid(lv)
                end
                if selRaid then
                    inRaid = true
                    local mobs = getMobs()
                    if #mobs > 0 then
                        for _,mob in pairs(mobs) do
                            kMob(mob)
                            task.wait(0.1)
                        end
                    end
                    clickPrompts()
                end
            end)
            farmBusy = false
        end
    end
end)

task.spawn(function()
    while task.wait(1.5) do
        if perpOn or axOn then
            inRaid = true
            pcall(function()
                local mobs = getMobs()
                for _,mob in pairs(mobs) do
                    kMob(mob)
                    task.wait(0.05)
                end
                clickPrompts()
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(6) do
        if autoWatch then collectWatches() end
    end
end)

task.spawn(function()
    while task.wait(12) do
        if autoMaster then tryMasterControl() end
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
    if i.KeyCode == Enum.KeyCode.Insert then
        isMin = not isMin
        if isMin then
            TweenService:Create(mf,TweenInfo.new(0.25),{Size=UDim2.new(0,370,0,32)}):Play()
            mBtn.Text = "+"
        else
            TweenService:Create(mf,TweenInfo.new(0.25),{Size=UDim2.new(0,370,0,430)}):Play()
            mBtn.Text = "_"
        end
    end
end)

local wm = Instance.new("TextLabel")
wm.Size = UDim2.new(0,230,0,20)
wm.Position = UDim2.new(0,6,0,3)
wm.BackgroundColor3 = dark
wm.BackgroundTransparency = 0.3
wm.Text = " Omni-X v3.2 | "..player.Name
wm.TextColor3 = purpleL
wm.Font = Enum.Font.GothamBold
wm.TextSize = 10
wm.TextXAlignment = Enum.TextXAlignment.Left
wm.BorderSizePixel = 0
wm.ZIndex = 100
wm.Parent = gui
Instance.new("UICorner",wm).CornerRadius = UDim.new(0,5)

noti("Omni-X Hub v3.2 Carregado!")
task.wait(1.5)
noti("Selecione Raid na aba Raids antes de ligar Farm")
