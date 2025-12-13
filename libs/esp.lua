local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local quads = {}
local nametags = {}
local tracers = {}

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
    TracerFromBottomOffset = 50, -- pixels from bottom of screen
    ShowQuads = true,
    ShowNametags = true,
    ShowTracers = true,
}

-- =========================
-- Drawing Creation
-- =========================
local function NewQuad()
    local quad = Drawing.new("Quad")
    quad.Visible = false
    quad.Color = Config.QuadColor
    quad.Thickness = Config.QuadThickness
    quad.Transparency = 1
    quad.Filled = false
    return quad
end

local function NewNametag()
    local tag = Drawing.new("Text")
    tag.Visible = false
    tag.Color = Config.NametagColor
    tag.Size = Config.NametagSize
    tag.Center = true
    tag.Outline = true
    tag.Font = 2
    return tag
end

local function NewTracer()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Config.TracerColor
    line.Thickness = Config.TracerThickness
    line.Transparency = 1
    return line
end

-- =========================
-- Better Bounding Box (avoids modifying accessories)
-- =========================
local function GetBoundingBox(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end

    local parts = {}
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            table.insert(parts, part)
        end
    end

    if #parts == 0 then
        -- Fallback to approximate size
        return root.CFrame, Vector3.new(4, 6, 3)
    end

    local min, max = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, part in ipairs(parts) do
        local cf, size = part.CFrame, part.Size
        local corners = {
            cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2).Position,
            cf * CFrame.new( size.X/2, -size.Y/2, -size.Z/2).Position,
            cf * CFrame.new( size.X/2,  size.Y/2, -size.Z/2).Position,
            cf * CFrame.new(-size.X/2,  size.Y/2, -size.Z/2).Position,
            cf * CFrame.new(-size.X/2, -size.Y/2,  size.Z/2).Position,
            cf * CFrame.new( size.X/2, -size.Y/2,  size.Z/2).Position,
            cf * CFrame.new( size.X/2,  size.Y/2,  size.Z/2).Position,
            cf * CFrame.new(-size.X/2,  size.Y/2,  size.Z/2).Position,
        }
        for _, corner in ipairs(corners) do
            min = min:Min(corner)
            max = max:Max(corner)
        end
    end

    local center = (min + max) / 2
    local size = max - min
    return CFrame.new(center), Vector3.new(size.X, size.Y + 0.5, size.Z) -- slight height boost
end

-- =========================
-- Update Visuals
-- =========================
local function UpdatePlayerVisuals(player)
    local quad = quads[player]
    local nametag = nametags[player]
    local tracer = tracers[player]
    local character = player.Character

    if not character or not character:FindFirstChild("HumanoidRootPart") then
        if quad then quad.Visible = false end
        if nametag then nametag.Visible = false end
        if tracer then tracer.Visible = false end
        return
    end

    local cf, size = GetBoundingBox(character)
    if not cf then
        quad.Visible = false
        nametag.Visible = false
        tracer.Visible = false
        return
    end

    local half = size / 2
    local corners = {
        cf.Position + Vector3.new(-half.X,  half.Y, -half.Z),
        cf.Position + Vector3.new( half.X,  half.Y, -half.Z),
        cf.Position + Vector3.new( half.X,  half.Y,  half.Z),
        cf.Position + Vector3.new(-half.X,  half.Y,  half.Z),
        cf.Position + Vector3.new(-half.X, -half.Y, -half.Z),
        cf.Position + Vector3.new( half.X, -half.Y, -half.Z),
        cf.Position + Vector3.new( half.X, -half.Y,  half.Z),
        cf.Position + Vector3.new(-half.X, -half.Y,  half.Z),
    }

    local screenPoints = {}
    local visibleCount = 0
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, worldPos in ipairs(corners) do
        local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
        if onScreen then
            visibleCount += 1
            minX = math.min(minX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxX = math.max(maxX, screenPos.X)
            maxY = math.max(maxY, screenPos.Y)
            table.insert(screenPoints, screenPos)
        end
    end

    local isVisible = visibleCount > 0

    -- Quad
    if Config.ShowQuads and isVisible and quad then
        quad.PointA = Vector2.new(minX, minY)
        quad.PointB = Vector2.new(maxX, minY)
        quad.PointC = Vector2.new(maxX, maxY)
        quad.PointD = Vector2.new(minX, maxY)
        quad.Visible = true
    elseif quad then
        quad.Visible = false
    end

    -- Nametag
    if Config.ShowNametags and isVisible and nametag then
        nametag.Text = player.DisplayName or player.Name
        nametag.Position = Vector2.new((minX + maxX) / 2, minY - 20) -- above head
        nametag.Visible = true
    elseif nametag then
        nametag.Visible = false
    end

    -- Tracer
    if Config.ShowTracers and tracer then
        local rootPos = character.HumanoidRootPart.Position
        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos + Vector3.new(0, -2, 0)) -- slightly lower
        local tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - Config.TracerFromBottomOffset)

        if onScreen then
            tracer.From = tracerStart
            tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            tracer.Visible = true
        else
            tracer.Visible = false
        end
    elseif tracer then
        tracer.Visible = false
    end
end

-- =========================
-- Player Management
-- =========================
local function AddPlayer(player)
    if player == LocalPlayer then return end

    quads[player] = NewQuad()
    nametags[player] = NewNametag()
    tracers[player] = NewTracer()

    -- Handle character respawn
    player.CharacterAdded:Connect(function()
        -- Reset visibility
        if quads[player] then quads[player].Visible = false end
        if nametags[player] then nametags[player].Visible = false end
        if tracers[player] then tracers[player].Visible = false end
    end)
end

local function RemovePlayer(player)
    if quads[player] then quads[player]:Remove() quads[player] = nil end
    if nametags[player] then nametags[player]:Remove() nametags[player] = nil end
    if tracers[player] then tracers[player]:Remove() tracers[player] = nil end
end

-- Initial players
for _, player in ipairs(Players:GetPlayers()) do
    AddPlayer(player)
end

Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- =========================
-- Render Loop
-- =========================
RunService.RenderStepped:Connect(function()
    for player, _ in pairs(quads) do
        if player.Parent then -- still in game
            UpdatePlayerVisuals(player)
        else
            RemovePlayer(player)
        end
    end
end)

return Config
