local Players = game:GetService("Players")
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
    TracerFromBottomOffset = 5, -- how many pixels above bottom of screen for tracers
    ShowQuads = true,
    ShowNametags = true,
    ShowTracers = true,
}


-- =========================
-- Drawing GC
-- =========================
local function SafeRemove(drawing)
    if drawing then
        drawing:Remove()
        drawing = nil
    end
end

local function UpdateDrawingsEnabled()
    for player, quad in pairs(quads) do
        if not Config.ShowQuads then SafeRemove(quad) end
    end
    for player, nametag in pairs(nametags) do
        if not Config.ShowNametags then SafeRemove(nametag) end
    end
    for player, tracer in pairs(tracers) do
        if not Config.ShowTracers then SafeRemove(tracer) end
    end
end


-- =========================
-- Drawing Creation
-- =========================
local function NewQuad(thickness, color)
    local quad = Drawing.new("Quad")
    quad.Visible = false
    quad.PointA = Vector2.new()
    quad.PointB = Vector2.new()
    quad.PointC = Vector2.new()
    quad.PointD = Vector2.new()
    quad.Color = color
    quad.Filled = false
    quad.Thickness = thickness
    quad.Transparency = 1
    return quad
end

local function NewNametag(text, color, size)
    local tag = Drawing.new("Text")
    tag.Visible = false
    tag.Text = text
    tag.Color = color
    tag.Size = size
    tag.Center = true
    tag.Outline = true
    return tag
end

local function NewTracer(thickness, color)
    local trace = Drawing.new("Line")
    trace.Visible = false
    trace.Color = color
    trace.Thickness = thickness
    trace.Transparency = 1
    return trace
end

-- =========================
-- Character Utilities
-- =========================
local function GetCharacterBoundingBoxNoAccessories(character)
    local accessories = {}

    for _, acc in ipairs(character:GetChildren()) do
        if acc:IsA("Accessory") and acc:FindFirstChild("Handle") then
            accessories[#accessories+1] = acc
            acc.Handle.Transparency = 1
        end
    end

    local bboxCF, bboxSize = character:GetBoundingBox()

    for _, acc in ipairs(accessories) do
        acc.Handle.Transparency = 0
    end

    bboxSize = Vector3.new(bboxSize.X, bboxSize.Y + 0.25, bboxSize.Z)
    return bboxCF, bboxSize
end

-- =========================
-- Quad / Nametag Update
-- =========================
local function UpdateQuad(quad, nametag, character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if Config.ShowQuads then quad.Visible = false end
        if nametag and Config.ShowNametags then nametag.Visible = false end
        return
    end

    local bboxCF, bboxSize = GetCharacterBoundingBoxNoAccessories(character)
    if not bboxCF then
        if Config.ShowQuads then quad.Visible = false end
        if nametag and Config.ShowNametags then nametag.Visible = false end
        return
    end

    local halfX, halfY, halfZ = bboxSize.X/2, bboxSize.Y/2, bboxSize.Z/2
    local corners = {
        bboxCF.Position + Vector3.new(-halfX,  halfY, -halfZ),
        bboxCF.Position + Vector3.new( halfX,  halfY, -halfZ),
        bboxCF.Position + Vector3.new( halfX,  halfY,  halfZ),
        bboxCF.Position + Vector3.new(-halfX,  halfY,  halfZ),
        bboxCF.Position + Vector3.new(-halfX, -halfY, -halfZ),
        bboxCF.Position + Vector3.new( halfX, -halfY, -halfZ),
        bboxCF.Position + Vector3.new( halfX, -halfY,  halfZ),
        bboxCF.Position + Vector3.new(-halfX, -halfY,  halfZ),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false

    for _, corner in ipairs(corners) do
        local screenPos, onScreen = Camera:WorldToViewportPoint(corner)
        if onScreen then
            visible = true
            minX = math.min(minX, screenPos.X)
            maxX = math.max(maxX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxY = math.max(maxY, screenPos.Y)
        end
    end

    if visible then
        if Config.ShowQuads then
            quad.PointA = Vector2.new(minX, minY)
            quad.PointB = Vector2.new(maxX, minY)
            quad.PointC = Vector2.new(maxX, maxY)
            quad.PointD = Vector2.new(minX, maxY)
            quad.Visible = true
        end

        if nametag and Config.ShowNametags then
            nametag.Position = Vector2.new((minX + maxX)/2, minY - 5)
            nametag.Visible = true
        end
    else
        if Config.ShowQuads then quad.Visible = false end
        if nametag and Config.ShowNametags then nametag.Visible = false end
    end
end

-- =========================
-- Player Management
-- =========================

local function AddPlayer(player)
    if player == LocalPlayer then return end

    local quad = NewQuad(Config.QuadThickness, Config.QuadColor)
    local nametag = NewNametag(player.Name, Config.NametagColor, Config.NametagSize)
    local tracer = NewTracer(Config.TracerThickness, Config.TracerColor)

    quads[player] = quad
    nametags[player] = nametag
    tracers[player] = tracer

    player.CharacterAdded:Connect(function()
        if Config.ShowQuads then quad.Visible = false end
        if Config.ShowNametags then nametag.Visible = false end
        if Config.ShowTracers then tracer.Visible = false end
    end)
end

local function RemovePlayer(player)
    if quads[player] then
        quads[player]:Remove()
        quads[player] = nil
    end
    if nametags[player] then
        nametags[player]:Remove()
        nametags[player] = nil
    end
    if tracers[player] then
        tracers[player]:Remove()
        tracers[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    AddPlayer(p)
end

Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- =========================
-- Main Render Loop
-- =========================
game:GetService("RunService").RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y - Config.TracerFromBottomOffset)
        UpdateDrawingsEnabled()

    for player, quad in pairs(quads) do
        local char = player.Character
        local tag = nametags[player]
        local tracer = tracers[player]

        if char and char:FindFirstChild("HumanoidRootPart") then
            UpdateQuad(quad, tag, char)

            if Config.ShowTracers and tracer then
                local hrpPos = char.HumanoidRootPart.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrpPos)
                if onScreen then
                    tracer.From = screenCenter
                    tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    tracer.Visible = true
                else
                    tracer.Visible = false
                end
            end
        else
            if Config.ShowQuads then quad.Visible = false end
            if Config.ShowNametags and tag then tag.Visible = false end
            if Config.ShowTracers and tracer then tracer.Visible = false end
        end
    end
end)

-- =========================
-- loadstring return
-- =========================
return Config
