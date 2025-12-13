local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Drawing tables - We ensure these three tables are always synchronized.
local quads = {}
local nametags = {}
local tracers = {}

-- Connections Table to manage cleanup of CharacterAdded connections
local connections = {}

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
}

-- =========================
-- Drawing GC & Utilities
-- =========================

local function SafeRemove(drawing)
    if drawing and typeof(drawing.Remove) == "function" then
        drawing:Remove()
    end
end

-- =========================
-- Player Management
-- This function is now the only way to destroy drawings permanently.
-- =========================
local function RemovePlayer(player)
    -- Remove character-added connection to prevent memory leak
    if connections[player] then
        connections[player]:Disconnect()
        connections[player] = nil
    end

    -- Safely remove all drawings and clear table references
    SafeRemove(quads[player])
    quads[player] = nil

    SafeRemove(nametags[player])
    nametags[player] = nil

    SafeRemove(tracers[player])
    tracers[player] = nil
end

local function AddPlayer(player)
    if player == LocalPlayer or quads[player] then return end -- Check if already added

    local quad = NewQuad(Config.QuadThickness, Config.QuadColor)
    local nametag = NewNametag(player.Name, Config.NametagColor, Config.NametagSize)
    local tracer = NewTracer(Config.TracerThickness, Config.TracerColor)

    quads[player] = quad
    nametags[player] = nametag
    tracers[player] = tracer

    -- Store connection to handle respawns, allowing immediate disabling
    connections[player] = player.CharacterAdded:Connect(function(character)
        -- Instantly hide if a new character spawns before the loop can update
        quad.Visible = false
        nametag.Visible = false
        tracer.Visible = false
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    AddPlayer(p)
end

Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- =========================
-- Drawing Visibility Management (Used for toggling config settings)
-- =========================
local function UpdateDrawingVisibility()
    for player, quad in pairs(quads) do
        local nametag = nametags[player]
        local tracer = tracers[player]

        -- If configuration is OFF, force the drawing invisible.
        if not Config.ShowQuads and quad then quad.Visible = false end
        if not Config.ShowNametags and nametag then nametag.Visible = false end
        if not Config.ShowTracers and tracer then tracer.Visible = false end
    end
end

-- =========================
-- Main Render Loop
-- =========================
game:GetService("RunService").RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y - Config.TracerFromBottomOffset)
    
    UpdateDrawingVisibility()

    -- Iterate safely. If an entry exists in quads, we assume it exists in the others.
    for player, quad in pairs(quads) do
        
        -- **CRITICAL** Check for stale/removed player object before accessing .Character
        if not player or not player:IsA("Player") then
            RemovePlayer(player) -- Clean up the drawings if the player object is invalid
            continue
        end

        local char = player.Character
        local tag = nametags[player]
        local tracer = tracers[player]

        if char and char:FindFirstChild("HumanoidRootPart") then
            -- 1. Quad and Nametag Update
            -- We only call this if the feature is ON AND the drawing object exists.
            if Config.ShowQuads and Config.ShowNametags and quad and tag then
                UpdateQuad(quad, tag, char)
            elseif Config.ShowQuads and quad then
                UpdateQuad(quad, nil, char) -- Update Quad only
                if tag then tag.Visible = false end -- Ensure nametag is hidden if config is off
            elseif Config.ShowNametags and tag then
                UpdateQuad(nil, tag, char) -- Update Nametag only (though UpdateQuad logic is built for both)
                if quad then quad.Visible = false end
            else
                -- If both are disabled by config, hide them
                if quad then quad.Visible = false end
                if tag then tag.Visible = false end
            end
            
            -- Re-calling UpdateQuad is complex if one is on and the other is off.
            -- Let's stick to the simpler, robust logic:
            if quad and tag then
                 UpdateQuad(quad, tag, char)
            end

            -- If features are toggled off, ensure they are hidden even after UpdateQuad runs
            if not Config.ShowQuads and quad then quad.Visible = false end
            if not Config.ShowNametags and tag then tag.Visible = false end
            
            -- 2. Tracer Update
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
            elseif tracer then
                tracer.Visible = false
            end
            
        else
            -- Character is dead or not loaded, hide all active drawings for this player
            if quad then quad.Visible = false end
            if tag then tag.Visible = false end
            if tracer then tracer.Visible = false end
        end
    end
end)

-- =========================
-- loadstring return
-- =========================
return Config
