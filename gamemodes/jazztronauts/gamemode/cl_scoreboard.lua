include("jazz_localize.lua")

if SERVER then return end

-- Color palette
local CLR_GOLD = Color(212, 175, 55)
local CLR_PINK = Color(255, 105, 180)
local CLR_WHITE = Color(255, 255, 255)
local CLR_CARD_BG = Color(40, 40, 45, 220)
local CLR_PLAYER_PINK = Color(100, 45, 80, 220)

-- Standard fonts
surface.CreateFont("JazzScoreboardHeader", {
    font = "KG Shake it Off Chunky",
    extended = true,
    size = ScreenScale(16),
    weight = 500,
    antialias = true,
})

surface.CreateFont("JazzScoreboardSub", {
    font = "KG Shake it Off Chunky",
    extended = true,
    size = ScreenScale(9),
    weight = 500,
    antialias = true,
})

surface.CreateFont("JazzScoreboardPlayer", {
    font = "KG Shake it Off Chunky",
    extended = true,
    size = ScreenScale(9),
    weight = 400,
    antialias = true,
})

surface.CreateFont( "JazzRespawnHint", {
	font	  = "KG Shake it Off Chunky",
	size	  = 30,
	weight	= 700,
	antialias = true,
	extended = true
})

local start = CurTime()
local draw_charts = false
local Radius = ScreenScale(22)
local XOff = ScreenScale(230)
local YOff = ScreenScale(80)
local logoMat = Material("gamemodes/jazztronauts/logo.png")

-- Background blur effect
local blur = Material("pp/blurscreen")
local function DrawBlur(panel, layers, density)
    local x, y = panel:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(blur)
    for i = 1, layers do
        blur:SetFloat("$blur", (i / layers) * density)
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

-- Helper functions for charts
local function getLocalValues(src, ...)
	local values = {}
	for k, v in pairs( player.GetAll() ) do
		local data = src[v:SteamID64()]
		if data then
			local entry = { v:GetName() }
            if type(data) == "table" then
                for _, field in pairs({ ... }) do table.insert(entry, data[field]) end
            else
                table.insert(entry, data)
            end
			values[#values + 1] = entry
		else
			table.insert(values, { v:GetName(), 0, 0 })
		end
	end
	return values
end

local SCOREBOARD = {}

function SCOREBOARD:Init()
    local w, h = ScrW() * 0.4, ScrH() * 0.7
    self:SetSize(w, h)
    self:SetPos((ScrW() - w) / 2, (ScrH() - h) / 2)
    self:SetZPos(100)

    self.Header = self:Add("DPanel")
    self.Header:Dock(TOP)
    self.Header:SetHeight(ScreenScale(40))
    self.Header.Paint = function(p, w, h)
        DrawBlur(p, 3, 6)
        draw.RoundedBox(12, 0, 0, w, h, CLR_GOLD)
        draw.RoundedBox(12, 1, 1, w-2, h-2, Color(CLR_CARD_BG.r, CLR_CARD_BG.g, CLR_CARD_BG.b, 255))
        
        local logoHeight = h * 0.5
        local logoWidth = logoHeight * (logoMat:Width() / logoMat:Height()) 
        surface.SetMaterial(logoMat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(20, (h - logoHeight) / 2, logoWidth, logoHeight)

        local hostName = GetHostName()
        local startX = logoWidth + 40
        
        surface.SetFont("JazzScoreboardHeader")
        draw.SimpleText(hostName, "JazzScoreboardHeader", startX, h * 0.15, CLR_GOLD, TEXT_ALIGN_LEFT)
        
        surface.SetFont("JazzScoreboardSub")
        local label = JazzLocalize("jazz.hud.scoreboard.map") .. " "
        local mapName = game.GetMap()
        local lw, _ = surface.GetTextSize(label)
        draw.SimpleText(label, "JazzScoreboardSub", startX, h * 0.55, CLR_PINK, TEXT_ALIGN_LEFT)
        draw.SimpleText(mapName, "JazzScoreboardSub", startX + lw, h * 0.55, CLR_WHITE, TEXT_ALIGN_LEFT)
    end

    self.Cols = self:Add("DPanel")
    self.Cols:Dock(TOP)
    self.Cols:SetHeight(25)
    self.Cols:DockMargin(0, 10, 0, 0)
    self.Cols.Paint = function(p, w, h)
        draw.SimpleText(JazzLocalize("jazz.hud.scoreboard.player"), "JazzScoreboardSub", 15, h/2, CLR_GOLD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(JazzLocalize("jazz.hud.scoreboard.deaths"), "JazzScoreboardSub", w * 0.75, h/2, CLR_GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(JazzLocalize("jazz.hud.scoreboard.ping"), "JazzScoreboardSub", w - 15, h/2, CLR_GOLD, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    self.PlayerList = self:Add("DScrollPanel")
    self.PlayerList:Dock(FILL)
    
    local sbar = self.PlayerList:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(0, 0, 0, w, h, CLR_GOLD) end

    self:Refresh()
end

function SCOREBOARD:Refresh()
    self.PlayerList:Clear()

    for _, ply in ipairs(player.GetAll()) do
        local pnl = self.PlayerList:Add("DPanel")
        pnl:Dock(TOP)
        pnl:SetHeight(ScreenScale(18))
        pnl:DockMargin(0, 2, 0, 2)

        local avatarSize = pnl:GetTall() - 8
        
        local avatarBtn = pnl:Add("DButton")
        avatarBtn:SetSize(avatarSize, avatarSize)
        avatarBtn:SetPos(8, 4)
        avatarBtn:SetText("")
        avatarBtn.Paint = nil
        avatarBtn.DoClick = function()
            if IsValid(ply) then ply:ShowProfile() end
        end

        local avatar = pnl:Add("AvatarImage")
        avatar:SetSize(avatarSize, avatarSize)
        avatar:SetPos(8, 4)
        avatar:SetPlayer(ply, 64)
        avatar:SetMouseInputEnabled(false)

        pnl.Paint = function(p, w, h)
            if not IsValid(ply) then return end
            DrawBlur(p, 2, 4)

            local bgCol = CLR_PLAYER_PINK
            if ply == LocalPlayer() then bgCol = Color(130, 60, 110, 240) end
            
            draw.RoundedBox(8, 0, 0, w, h, Color(CLR_GOLD.r, CLR_GOLD.g, CLR_GOLD.b, 100))
            draw.RoundedBox(8, 1, 1, w-2, h-2, bgCol)

            draw.SimpleText(ply:Nick(), "JazzScoreboardPlayer", avatarSize + 20, h/2, CLR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			
            draw.SimpleText(ply:Deaths(), "JazzScoreboardPlayer", w * 0.75, h/2, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local ping = ply:Ping()
            local pingCol = Color(100, 255, 100)
            if ping > 150 then pingCol = Color(255, 50, 50)
            elseif ping > 80 then pingCol = Color(255, 200, 50) end
            draw.SimpleText(ping, "JazzScoreboardPlayer", w - 15, h/2, pingCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end
vgui.Register("JazzScoreboardNew", SCOREBOARD, "EditablePanel")

hook.Add("HUDPaint", "graph_test", function()
	if not draw_charts then return end
	local showGlobal = input.IsMouseDown(MOUSE_RIGHT)

	local allMoney = jazzmoney.GetAllNotes()
	local moneyValues = getLocalValues(allMoney, "earned", "spent")
	local shardValues = getLocalValues(mapgen.GetPlayerShards())

	local cx, cy = ScrW() / 2, ScrH() / 2
	local duration = 4
	local dt = math.Clamp((CurTime() - (start + 0.1)) / duration, 0, 1)
	local dt2 = math.Clamp((CurTime() - (start + 0.2)) / duration, 0, 1)

	local bounce = Bounce(dt, 0.25, 1.8, 0.6)
	local bounce2 = Bounce(dt2, 0.25, 1.8, 0.6)

    -- Render Pie Charts
	graph.drawPieChart( cx + XOff, YOff, Radius, moneyValues, 1-bounce, 2, function(v) return JazzLocalize("jazz.hud.earned", v[1], v[2]) end )
	graph.drawPieChart( cx + XOff, YOff * 2.4, Radius, moneyValues, 1-bounce2, 3, function(v) return JazzLocalize("jazz.hud.spent", v[1], v[3]) end )
	graph.drawPieChart( cx + XOff, YOff * 3.8, Radius, shardValues, 1-bounce2, 2, function(v) return JazzLocalize("jazz.hud.found", v[1], v[2]) end )

    draw.SimpleText(JazzLocalize("jazz.hud.earned.title"), "JazzScoreboardSub", cx + XOff, YOff - Radius - 30, CLR_GOLD, TEXT_ALIGN_CENTER)
    draw.SimpleText(JazzLocalize("jazz.hud.spent.title"), "JazzScoreboardSub", cx + XOff, YOff*2.4 - Radius - 30, CLR_PINK, TEXT_ALIGN_CENTER)
    draw.SimpleText(JazzLocalize("jazz.hud.found.title"), "JazzScoreboardSub", cx + XOff, YOff*3.8 - Radius - 30, CLR_WHITE, TEXT_ALIGN_CENTER)

	draw.SimpleText(JazzLocalize("jazz.hud.kys"), "JazzRespawnHint", ScrW()/2, ScrH() - 30, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end)

function GM:ScoreboardShow()
    start = CurTime()
	draw_charts = true
    if not IsValid(g_JazzScoreboard) then g_JazzScoreboard = vgui.Create("JazzScoreboardNew") end
    g_JazzScoreboard:SetVisible(true)
    g_JazzScoreboard:Refresh()
    gui.EnableScreenClicker(true)
end

function GM:ScoreboardHide()
    draw_charts = false
    if IsValid(g_JazzScoreboard) then g_JazzScoreboard:SetVisible(false) end
    gui.EnableScreenClicker(false)
end

hook.Add( "HUDDrawScoreboard", "graph_test", function() return true end )

-- Respawn logic
local function isHoldingCombo()
	return LocalPlayer():KeyDown(IN_SCORE) and input.IsMouseDown(MOUSE_LEFT) and input.IsMouseDown(MOUSE_RIGHT)
end

local buildupTime, comboTime, killsound, killed = 3, 0, nil, false
hook.Add("Think", "RespawnKeyComboThink", function()
	local comboHeld = isHoldingCombo()
	if not comboHeld or killed then
		comboTime = 0
		if killsound then killsound:Stop() killsound = nil end
		if not comboHeld then killed = false end
		return
	end
	if not killsound then
		killsound = CreateSound(Entity(0), "ambient/levels/labs/teleport_preblast_suckin1.wav")
		killsound:PlayEx(1, 75)
	end

	local p = comboTime / buildupTime
	util.ScreenShake(LocalPlayer():GetPos(), p * 5, p * 5, 0.1, 256)
	comboTime = comboTime + FrameTime()
	if comboTime > buildupTime then
		RunConsoleCommand("kill")
		killed = true
	end
end )