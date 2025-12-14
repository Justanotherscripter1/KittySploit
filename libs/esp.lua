local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

-- =========================
-- Config
-- =========================
local Config = {
    QuadColor = Color3.fromRGB(255, 0, 0),
    QuadThickness = 2,
    NametagColor = Color3.fromRGB(255, 255, 255),
    NametagSize = 16,
    TracerColor = Color3.fromRGB(0, 255, 0),
    TracerThickness = 1,
    TracerFromBottomOffset = 5,
    ShowQuads = true,
    ShowNametags = true,
    ShowTracers = true,
    ShowHealth = true,
}

-- =========================
-- Drawing Creation
-- =========================
local function NewQuad(thickness, color)
    local q = Drawing.new("Quad")
    q.Visible = false
    q.Filled = false
    q.Color = color
    q.Thickness = thickness
    q.Transparency = 1
    return q
end

local function NewNametag(text, color, size)
    local t = Drawing.new("Text")
    t.Visible = false
    t.Text = text
    t.Color = color
    t.Size = size
    t.Center = true
    t.Outline = true
    return t
end

local function NewTracer(thickness, color)
    local l = Drawing.new("Line")
    l.Visible = false
    l.Color = color
    l.Thickness = thickness
    l.Transparency = 1
    return l
end

local function NewHealthBar(outerThick, innerThick)
    local bar = {
        outer = Drawing.new("Line"),
        inner = Drawing.new("Line")
    }
    bar.outer.Visible = false
    bar.outer.Color = Color3.fromRGB(0,0,0)
    bar.outer.Thickness = outerThick
    bar.outer.Transparency = 1

    bar.inner.Visible = false
    bar.inner.Color = Color3.fromRGB(0,255,0)
    bar.inner.Thickness = innerThick
    bar.inner.Transparency = 1

    return bar
end

-- =========================
-- Bounding Box
-- =========================
local function GetBoundingBox(character)
    local cf, size = character:GetBoundingBox()
    return cf, size + Vector3.new(0,0.25,0)
end

-- =========================
-- Update Drawings
-- =========================
local function UpdateDrawings(quad, tag, tracer, healthbar, char, screenCenter)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hrp or not hum or not head then
        quad.Visible = false
        tag.Visible = false
        tracer.Visible = false
        healthbar.outer.Visible = false
        healthbar.inner.Visible = false
        return
    end

    local cf, size = GetBoundingBox(char)
    local hx, hy, hz = size.X/2, size.Y/2, size.Z/2

    local corners = {
        cf.Position + Vector3.new(-hx,  hy, -hz),
        cf.Position + Vector3.new( hx,  hy, -hz),
        cf.Position + Vector3.new( hx, -hy, -hz),
        cf.Position + Vector3.new(-hx, -hy, -hz),
        cf.Position + Vector3.new(-hx,  hy,  hz),
        cf.Position + Vector3.new( hx,  hy,  hz),
        cf.Position + Vector3.new( hx, -hy,  hz),
        cf.Position + Vector3.new(-hx, -hy,  hz),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = true

    for _, corner in ipairs(corners) do
        local v, onScreen = Camera:WorldToViewportPoint(corner)
        if not onScreen or v.Z <= 0 then
            visible = false
            break
        end
        minX = math.min(minX, v.X)
        minY = math.min(minY, v.Y)
        maxX = math.max(maxX, v.X)
        maxY = math.max(maxY, v.Y)
    end

    if not visible then
        quad.Visible = false
        tag.Visible = false
        tracer.Visible = false
        healthbar.outer.Visible = false
        healthbar.inner.Visible = false
        return
    end

    -- Quad
    if Config.ShowQuads then
        quad.PointA = Vector2.new(minX, minY)
        quad.PointB = Vector2.new(maxX, minY)
        quad.PointC = Vector2.new(maxX, maxY)
        quad.PointD = Vector2.new(minX, maxY)
        quad.Visible = true
    end

    -- Nametag
    if Config.ShowNametags then
        tag.Position = Vector2.new((minX+maxX)/2, minY - 6)
        tag.Visible = true
    end

    -- Healthbar (Blissful style)
    if Config.ShowHealth then
        local height = maxY - minY
        local healthLength = height * (hum.Health / hum.MaxHealth)
        local barX = minX - 6

        -- Outer black bar
        healthbar.outer.From = Vector2.new(barX, maxY)
        healthbar.outer.To = Vector2.new(barX, minY)
        healthbar.outer.Visible = true

        -- Inner green bar
        healthbar.inner.From = Vector2.new(barX, maxY)
        healthbar.inner.To = Vector2.new(barX, maxY - healthLength)
        healthbar.inner.Color = Color3.fromRGB(255*(1-hum.Health/hum.MaxHealth), 255*(hum.Health/hum.MaxHealth),0)
        healthbar.inner.Visible = true
    end

    -- Tracer
    if Config.ShowTracers then
        local v, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if onScreen and v.Z>0 then
            tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y - Config.TracerFromBottomOffset)
            tracer.To = Vector2.new(v.X, v.Y)
            tracer.Visible = true
        else
            tracer.Visible = false
        end
    end
end

-- =========================
-- Player Management
-- =========================
local quads, tags, tracers, healthbars = {}, {}, {}, {}

local function AddPlayer(p)
    if p == LocalPlayer then return end
    quads[p] = NewQuad(Config.QuadThickness, Config.QuadColor)
    tags[p] = NewNametag(p.Name, Config.NametagColor, Config.NametagSize)
    tracers[p] = NewTracer(Config.TracerThickness, Config.TracerColor)
    healthbars[p] = NewHealthBar(3,1.5)
end

local function RemovePlayer(p)
    if quads[p] then quads[p]:Remove() quads[p]=nil end
    if tags[p] then tags[p]:Remove() tags[p]=nil end
    if tracers[p] then tracers[p]:Remove() tracers[p]=nil end
    if healthbars[p] then healthbars[p].outer:Remove() healthbars[p].inner:Remove() healthbars[p]=nil end
end

for _, p in ipairs(Players:GetPlayers()) do AddPlayer(p) end
Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- =========================
-- Render Loop
-- =========================
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y - Config.TracerFromBottomOffset)
    for p, quad in pairs(quads) do
        local char = p.Character
        if char then
            UpdateDrawings(quad, tags[p], tracers[p], healthbars[p], char, screenCenter)
        end
    end
end)

return Config
