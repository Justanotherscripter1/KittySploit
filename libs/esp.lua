local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

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

local function NewHealthBar(thickness)
    local bar = Drawing.new("Line")
    bar.Visible = false
    bar.Color = Color3.fromRGB(0, 255, 0)
    bar.Thickness = thickness
    bar.Transparency = 1
    return bar
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
local function UpdateDrawings(quad, nametag, tracer, healthbar, character, screenCenter)
    if not (Config.ShowQuads or Config.ShowNametags or Config.ShowTracers or Config.ShowHealth) then
        if quad then quad.Visible = false end
        if nametag then nametag.Visible = false end
        if tracer then tracer.Visible = false end
        if healthbar then healthbar.Visible = false end
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if quad then quad.Visible = false end
        if nametag then nametag.Visible = false end
        if tracer then tracer.Visible = false end
        if healthbar then healthbar.Visible = false end
        return
    end

    -- 🔧 HEALTH FIX: HRP onscreen check (added, nothing else touched)
    local _, hrpOnScreen = Camera:WorldToViewportPoint(hrp.Position)

    if Config.ShowQuads or Config.ShowNametags or Config.ShowHealth then
        local bboxCF, bboxSize = GetCharacterBoundingBoxNoAccessories(character)
        if bboxCF then
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

            -- 🔧 HEALTH FIX: moved OUT of `if visible` and gated by HRP
            if Config.ShowHealth and healthbar then
                if hrpOnScreen then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.MaxHealth > 0 then
                        local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

                        local barHeight = maxY - minY
                        local filledHeight = barHeight * healthPercent

                        local barX = minX - 6
                        local barBottom = maxY
                        local barTop = barBottom - filledHeight

                        healthbar.From = Vector2.new(barX, barBottom)
                        healthbar.To = Vector2.new(barX, barTop)

                        healthbar.Color = Color3.fromRGB(
                            255 * (1 - healthPercent),
                            255 * healthPercent,
                            0
                        )

                        healthbar.Visible = true
                    else
                        healthbar.Visible = false
                    end
                else
                    healthbar.Visible = false
                end
            end

            if visible then
                if Config.ShowQuads and quad then
                    quad.PointA = Vector2.new(minX, minY)
                    quad.PointB = Vector2.new(maxX, minY)
                    quad.PointC = Vector2.new(maxX, maxY)
                    quad.PointD = Vector2.new(minX, maxY)
                    quad.Visible = true
                elseif quad then
                    quad.Visible = false
                end

                if Config.ShowNametags and nametag then
                    nametag.Position = Vector2.new((minX + maxX)/2, minY - 5)
                    nametag.Visible = true
                elseif nametag then
                    nametag.Visible = false
                end
            else
                if quad then quad.Visible = false end
                if nametag then nametag.Visible = false end
            end
        end
    end

    -- Tracers (unchanged)
    if tracer then
        if Config.ShowTracers then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                tracer.From = screenCenter
                tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                tracer.Visible = true
            else
                tracer.Visible = false
            end
        else
            tracer.Visible = false
        end
    end

    if quad then
        quad.Color = Config.QuadColor
        quad.Thickness = Config.QuadThickness
    end
    if nametag then
        nametag.Color = Config.NametagColor
        nametag.Size = Config.NametagSize
    end
end

-- =========================
-- Player Management
-- =========================
local quads = {}
local nametags = {}
local tracers = {}
local healthbars = {}

local function AddPlayer(player)
    if player == LocalPlayer then return end

    quads[player] = NewQuad(Config.QuadThickness, Config.QuadColor)
    nametags[player] = NewNametag(player.Name, Config.NametagColor, Config.NametagSize)
    tracers[player] = NewTracer(Config.TracerThickness, Config.TracerColor)
    healthbars[player] = NewHealthBar(3)
end

local function RemovePlayer(player)
    if quads[player] then quads[player]:Remove() end
    if nametags[player] then nametags[player]:Remove() end
    if tracers[player] then tracers[player]:Remove() end
    if healthbars[player] then healthbars[player]:Remove() end
end

for _, p in ipairs(Players:GetPlayers()) do AddPlayer(p) end
Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- =========================
-- Main Render Loop
-- =========================
game:GetService("RunService").RenderStepped:Connect(function()
    local screenCenter = Vector2.new(
        Camera.ViewportSize.X/2,
        Camera.ViewportSize.Y - Config.TracerFromBottomOffset
    )

    for player, quad in pairs(quads) do
        local char = player.Character
        if char then
            UpdateDrawings(
                quad,
                nametags[player],
                tracers[player],
                healthbars[player],
                char,
                screenCenter
            )
        end
    end
end)

return Config
