-- ============================================================
--  TesterHelper  -  Hitmen Agency
--  Toggle: F4 or /thinfo
--  Needs:  MoonLoader, mimgui, SAMPFUNCS
-- ============================================================

local imgui = require 'mimgui'
local key   = require 'vkeys'
local ffi   = require 'ffi'

-- ============================================================
-- SETTINGS
-- ============================================================
local CFG = {
    fCmd     = '/f',
    cwCmd    = '/cw',
    maxWrong = 3,
    lang     = 'RO',
}

-- ============================================================
-- RULES
-- ============================================================
local theoryRules = {
    '/cw Salut! Eu sunt testerul cu care sustii testul de intrare in Hitmen Agency.',
    '/cw Iti voi oferi niste informatii inainte de a incepe testul, asa ca te rog [...]',
    '/cw [...] sa citesti cu atentie.',
    '/cw Primesti 0.5p pentru fiecare raspuns partial corect.',
    '/cw Primesti 1p pentru fiecare raspuns incorect.',
    '/cw Cand ai acumulat 3p, o sa fi declarat respins.',
    '/cw Asadar, raspunsul tau trebuie sa fie clar, precis si scris cat mai corect.',
    '/cw Ai la dispozitie un minut pentru fiecare intrebare, astfel primesti 1p.',
    '/cw La anumite intrebari o sa ai la dispozitie 90 secunde, o sa te anunt eu.',
    '/cw In momentul in care parasesti jocul de buna voie (/q) o sa fi declarat respins.',
    '/cw Daca ai luat CRASH, ai 3 minute sa revii sau o sa fi declarat respins.',
    '/cw Daca ai luat a doua oara CRASH, esti declarat respins.',
    '/cw In timpul testului nu ai voie AFK.',
    '/cw Ai inteles regulile prezentate mai sus?',
}

local practicalRules = {
    '/cw Bun, avand in vedere ca ai trecut proba teoretica, vom trece la proba practica.',
    '/cw Acum, trebuie sa executi un contract in silent mode.',
    '/cw In momentul in care parasesti jocul de buna voie (/q) o sa fi declarat respins.',
    '/cw Daca ai luat CRASH, ai 3 minute sa revii sau o sa fi declarat respins.',
    '/cw Daca ai luat a doua oara CRASH, esti declarat respins.',
    '/cw Inca o precizare de facut, aceasta este sa NU uiti de poza.',
    '/cw Poza trebuie sa o faci exact cand omori tinta, ca la The Silent One.',
}

-- ============================================================
-- QUESTIONS
-- ============================================================
local CFG_DIR       = getWorkingDirectory() .. '\\config\\TesterHelp\\'
local QUESTIONS_INI = CFG_DIR .. 'questions.ini'

local function parseIni(path)
    local t   = {}
    local sec = nil
    local f   = io.open(path, 'r')
    if not f then return t end
    for line in f:lines() do
        line = line:match('^%s*(.-)%s*$')
        if line:sub(1,1) == '[' then
            sec = line:match('%[(.-)%]')
            t[sec] = t[sec] or {}
        elseif sec and line ~= '' and line:sub(1,1) ~= ';' then
            local k, v = line:match('^(.-)%s*=%s*(.*)$')
            if k then t[sec][k] = v end
        end
    end
    f:close()
    return t
end

local function loadQuestions()
    local t  = parseIni(QUESTIONS_INI)
    local qs = {}
    local i  = 1
    while true do
        local sec = 'Question' .. i
        if not t[sec] then break end
        qs[i] = {
            question = t[sec].question or ('/cw ' .. i .. '. ?'),
            answer   = t[sec].answer   or '???',
            time     = tonumber(t[sec].time) or 30,
        }
        i = i + 1
    end
    if #qs == 0 then
        qs[1] = { question = '/cw Intrebarea 1?', answer = 'Raspuns 1', time = 30 }
    end
    return qs
end

-- ============================================================
-- STATE
-- ============================================================
local questions  = loadQuestions()

local windowState = imgui.new.bool(false)
local curLang     = CFG.lang
local activeMenu  = 'theory'

local playerId    = -1
local playerIdBuf = imgui.new.char[8]('')
local lastIdStr   = ''
local wrongCount  = 0.0
local MAX_WRONG   = CFG.maxWrong
local selectedQ   = 1
local searchText  = ''

local session = {
    started  = false,
    name     = '',
    id       = 0,
    testType = 'theory',
}

local timer = {
    active    = false,
    remaining = 0,
    total     = 0,
    lastTick  = 0,
}

-- ============================================================
-- LABELS (bilingual)
-- ============================================================
local L = {
    RO = {
        title          = 'TesterHelper - Hitmen Agency',
        tabTheory      = 'Test teoretic',
        tabPractical   = 'Test practic',
        labelId        = 'ID:',
        labelPlayer    = 'Jucator:',
        offline        = 'offline',
        noId           = 'Introdu ID',
        btnStartTheory = 'Start teoretic',
        btnSendRules   = 'Trimite reguli',
        btnPass        = 'Trecut',
        btnFinish      = 'Finalizeaza testul',
        btnStartPrac   = 'Start practic',
        wrongLabel     = 'Greseli:',
        btnHalf        = '+0.5',
        btnOne         = '+1',
        btnReset       = 'Reset',
        secQuestions   = 'Intrebari',
        btnSelect      = 'Select',
        labelQ         = 'Intrebare:',
        labelA         = 'Raspuns:',
        labelTime      = 'Timp:',
        btnAsk         = 'Intreaba',
        btnAnswer      = 'Raspuns',
        btnTimer       = 'Timer',
        timerDone      = 'Timp expirat!',
        footer         = 'TesterHelper  |  Made by sLoww',
        noSession      = 'Niciun test activ.',
        reloadOk       = 'Config reincarcata.',
        invalidId      = 'ID invalid sau jucatorul nu este conectat.',
    },
    EN = {
        title          = 'TesterHelper - Hitmen Agency',
        tabTheory      = 'Theoretical test',
        tabPractical   = 'Practical test',
        labelId        = 'ID:',
        labelPlayer    = 'Player:',
        offline        = 'offline',
        noId           = 'Enter ID',
        btnStartTheory = 'Start theoretical',
        btnSendRules   = 'Send rules',
        btnPass        = 'Pass',
        btnFinish      = 'Finish the test',
        btnStartPrac   = 'Start practic',
        wrongLabel     = 'Wrong:',
        btnHalf        = '+0.5',
        btnOne         = '+1',
        btnReset       = 'Reset',
        secQuestions   = 'Questions',
        btnSelect      = 'Select',
        labelQ         = 'Question:',
        labelA         = 'Answer:',
        labelTime      = 'Time:',
        btnAsk         = 'Ask',
        btnAnswer      = 'Answer',
        btnTimer       = 'Timer',
        timerDone      = 'Time is up!',
        footer         = 'TesterHelper  |  Made by sLoww',
        noSession      = 'No active test.',
        reloadOk       = 'Config reloaded.',
        invalidId      = 'Invalid ID or player not connected.',
    },
}
local function T() return L[curLang] end

-- ============================================================
-- HELPERS
-- ============================================================
local function playerName(id)
    if id >= 0 and sampIsPlayerConnected(id) then
        return sampGetPlayerNickname(id)
    end
    return T().offline
end

local function isOnline(id)
    return id >= 0 and sampIsPlayerConnected(id)
end

local function getTypeLabel()
    return activeMenu == 'theory' and 'Teoretic' or 'Practic'
end

local function trunc(s, n)
    if #s <= n then return s end
    return s:sub(1, n) .. '...'
end

local function wrongColor()
    local ratio = wrongCount / MAX_WRONG
    if ratio == 0    then return imgui.ImVec4(0.40, 0.90, 0.40, 1.00) end
    if ratio <= 0.49 then return imgui.ImVec4(0.55, 0.85, 0.30, 1.00) end
    if ratio <= 0.74 then return imgui.ImVec4(1.00, 0.75, 0.20, 1.00) end
    return imgui.ImVec4(1.00, 0.30, 0.30, 1.00)
end

local function timerColor()
    if not timer.active then return imgui.ImVec4(0.60, 0.65, 0.80, 1.00) end
    local ratio = timer.remaining / timer.total
    if ratio > 0.5  then return imgui.ImVec4(0.40, 0.90, 0.40, 1.00) end
    if ratio > 0.25 then return imgui.ImVec4(1.00, 0.75, 0.20, 1.00) end
    return imgui.ImVec4(1.00, 0.30, 0.30, 1.00)
end

local function sendMultiLine(text)
    text = text:gsub('\\n', '\n')
    for line in text:gmatch('[^\n]+') do
        -- sendCmd(CFG.cwCmd .. ' ' .. line)
        sampSendChat(line)
    end
end

local watermarkFont = renderCreateFont('Arial', 10, 5)
function drawWatermark()
    renderFontDrawText(watermarkFont, '{AA3333}TesterHelp{FFFFFF} v1.0', 1680, 10, 0xFFFFFFFF)
end

-- ============================================================
-- BUTTON STYLE HELPERS
-- ============================================================
local function pushDimBtn()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.14, 0.18, 0.28, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.26, 0.38, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.28, 0.34, 0.48, 1.00))
end
local function pushGreenBtn()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.12, 0.42, 0.20, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16, 0.58, 0.28, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.20, 0.72, 0.34, 1.00))
end
local function pushRedBtn()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.50, 0.10, 0.10, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.70, 0.15, 0.15, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.90, 0.18, 0.18, 1.00))
end
local function pushOrangeBtn()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.55, 0.35, 0.08, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.75, 0.50, 0.12, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.90, 0.62, 0.18, 1.00))
end
local function pushBlueBtn()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.12, 0.28, 0.50, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16, 0.38, 0.68, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.20, 0.48, 0.82, 1.00))
end
local function pushCrimsonBtn()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.65, 0.16, 0.20, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.80, 0.22, 0.26, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.95, 0.26, 0.30, 1.00))
end

-- ============================================================
-- ACTIONS
-- ============================================================
local function sendCmd(cmd)
    sampSendChat(cmd)
end

local function localMsg(msg)
    sampAddChatMessage('{AA3333}[TesterHelp]{FFFFFF} ' .. msg, -1)
end

local function startTest(mode)
    if not isOnline(playerId) then
        localMsg(T().invalidId)
        return
    end
    local name = playerName(playerId)
    session.started  = true
    session.name     = name
    session.id       = playerId
    session.testType = mode
    wrongCount       = 0.0

    local typeLabel = mode == 'theory' and 'teoretic' or 'practic'
    sendCmd(CFG.fCmd .. ' ' .. name .. ' (' .. playerId .. ') a inceput testul ' .. typeLabel .. '. Mult succes!')
    localMsg('Test ' .. typeLabel .. ' inceput pentru ' .. name .. ' (' .. playerId .. ').')
end

local function sendRules(mode)
    local rules = mode == 'theory' and theoryRules or practicalRules

    lua_thread.create(function()
        for _, line in ipairs(rules) do
            sendCmd(line)
            wait(1200)
        end
    end)
end

local function finishTheoryTest(passed)
    if not session.started then localMsg(T().noSession) return end
    local name  = session.name
    local id    = session.id
    local wstr  = tostring(wrongCount) .. '/' .. MAX_WRONG
    if passed then
        sendCmd(CFG.fCmd .. ' ' .. name .. ' (' .. id .. ') a trecut testul teoretic cu ' .. wstr .. ' greseli.')
    else
        sendCmd(CFG.fCmd .. ' ' .. name .. ' (' .. id .. ') a picat testul teoretic cu ' .. wstr .. ' greseli.')
    end
    session.started = false
    wrongCount = 0.0
    timer.active = false
end

local function finishPracticalTest(passed)
    if not session.started then localMsg(T().noSession) return end
    local name = session.name
    local id   = session.id
    if passed then
        sendCmd(CFG.fCmd .. ' ' .. name .. ' (' .. id .. ') te rog sa-mi trimiti poza prin PM pe forum.')
    end
    session.started = false
    timer.active = false
end

local function addWrong(amount)
    if not session.started then localMsg(T().noSession) return end
    if not isOnline(playerId) then
        localMsg(T().invalidId)
        return
    end
    wrongCount = wrongCount + amount
    if wrongCount >= MAX_WRONG then
        wrongCount = MAX_WRONG
        sendCmd(CFG.cwCmd .. ' Din pacate, ai acumulat prea multe raspunsuri gresite: ' .. wrongCount .. '/' .. MAX_WRONG .. '. Mult succes data viitoare!')
        sendCmd(CFG.fCmd .. ' ' .. playerName(playerId) .. ' (' .. playerId .. ') a picat testul teoretic cu ' .. wrongCount .. '/' .. MAX_WRONG .. '. Mult succes data viitoare!')
        session.started = false
        wrongCount = 0.0
        timer.active = false
        localMsg('Testul a fost finalizat automat! Au fost adunate prea multe greseli (3/3).')
    else
        local amtStr = (amount == 0.5) and '0.5' or '1'
        sendCmd(CFG.cwCmd .. ' Ai fost depunctat cu ' .. amtStr .. '/3. Te rog sa fi mai atent!')
        sendCmd(CFG.cwCmd .. ' Din pacate ai acumulat: ' .. wrongCount .. '/' .. MAX_WRONG .. '.')
    end
end

local function startTimer(seconds)
    if not session.started then localMsg(T().noSession) return end
    timer.active    = true
    timer.remaining = seconds
    timer.total     = seconds
    timer.lastTick  = os.clock()
end

-- ============================================================
-- THEME
-- ============================================================
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local style  = imgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding    = 8.0
    style.ChildRounding     = 6.0
    style.FrameRounding     = 5.0
    style.ScrollbarRounding = 6.0
    style.GrabRounding      = 5.0
    style.WindowPadding     = imgui.ImVec2(10, 10)
    style.FramePadding      = imgui.ImVec2(8, 4)
    style.ItemSpacing       = imgui.ImVec2(6, 5)

    colors[imgui.Col.WindowBg]             = imgui.ImVec4(0.07, 0.09, 0.14, 0.98)
    colors[imgui.Col.ChildBg]              = imgui.ImVec4(0.10, 0.12, 0.18, 1.00)
    colors[imgui.Col.PopupBg]              = imgui.ImVec4(0.09, 0.10, 0.16, 1.00)
    colors[imgui.Col.Border]               = imgui.ImVec4(0.30, 0.15, 0.20, 0.90)
    colors[imgui.Col.BorderShadow]         = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[imgui.Col.Text]                 = imgui.ImVec4(0.92, 0.94, 0.98, 1.00)
    colors[imgui.Col.TextDisabled]         = imgui.ImVec4(0.50, 0.55, 0.65, 1.00)
    colors[imgui.Col.TitleBg]              = imgui.ImVec4(0.32, 0.08, 0.12, 1.00)
    colors[imgui.Col.TitleBgActive]        = imgui.ImVec4(0.52, 0.10, 0.16, 1.00)
    colors[imgui.Col.FrameBg]              = imgui.ImVec4(0.14, 0.16, 0.24, 1.00)
    colors[imgui.Col.FrameBgHovered]       = imgui.ImVec4(0.20, 0.22, 0.32, 1.00)
    colors[imgui.Col.FrameBgActive]        = imgui.ImVec4(0.25, 0.28, 0.38, 1.00)
    colors[imgui.Col.Button]               = imgui.ImVec4(0.60, 0.16, 0.18, 1.00)
    colors[imgui.Col.ButtonHovered]        = imgui.ImVec4(0.78, 0.22, 0.24, 1.00)
    colors[imgui.Col.ButtonActive]         = imgui.ImVec4(0.95, 0.18, 0.18, 1.00)
    colors[imgui.Col.Header]               = imgui.ImVec4(0.45, 0.15, 0.20, 0.85)
    colors[imgui.Col.HeaderHovered]        = imgui.ImVec4(0.60, 0.18, 0.24, 0.95)
    colors[imgui.Col.HeaderActive]         = imgui.ImVec4(0.75, 0.20, 0.28, 1.00)
    colors[imgui.Col.ScrollbarBg]          = imgui.ImVec4(0.08, 0.09, 0.14, 1.00)
    colors[imgui.Col.ScrollbarGrab]        = imgui.ImVec4(0.45, 0.18, 0.24, 1.00)
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.60, 0.20, 0.28, 1.00)
    colors[imgui.Col.ScrollbarGrabActive]  = imgui.ImVec4(0.75, 0.22, 0.32, 1.00)
    colors[imgui.Col.Separator]            = imgui.ImVec4(0.35, 0.18, 0.22, 1.00)
    colors[imgui.Col.SeparatorHovered]     = imgui.ImVec4(0.55, 0.22, 0.28, 1.00)
    colors[imgui.Col.SeparatorActive]      = imgui.ImVec4(0.75, 0.25, 0.32, 1.00)
    colors[imgui.Col.CheckMark]            = imgui.ImVec4(0.95, 0.35, 0.35, 1.00)
end)

-- ============================================================
-- RENDER HELPERS
-- ============================================================
local function sectionLabel(text)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.80, 0.55, 0.55, 1.00))
    imgui.Text(text)
    imgui.PopStyleColor()
    imgui.Separator()
    imgui.Spacing()
end

local function dimText(text)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.60, 0.65, 0.78, 1.00))
    imgui.Text(text)
    imgui.PopStyleColor()
end

-- ============================================================
-- RENDER: TOP BAR
-- ============================================================
local function renderTopBar(drawList, p, w, titleH)
    drawList:AddRectFilled(
        imgui.ImVec2(p.x, p.y),
        imgui.ImVec2(p.x + w, p.y + titleH),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.18, 0.06, 0.09, 1.00)), 8)

    imgui.SetCursorPos(imgui.ImVec2(10, 10))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.92, 0.92, 1.00))
    imgui.Text(T().title)
    imgui.PopStyleColor()

    imgui.SetCursorPos(imgui.ImVec2(w - 90, 8))
    pushDimBtn()
    if imgui.Button(curLang == 'RO' and 'EN##lg' or 'RO##lg', imgui.ImVec2(36, 22)) then
        curLang = curLang == 'RO' and 'EN' or 'RO'
    end
    imgui.PopStyleColor(3)

    imgui.SetCursorPos(imgui.ImVec2(w - 32, 8))
    pushRedBtn()
    if imgui.Button('X##cls', imgui.ImVec2(24, 22)) then windowState[0] = false end
    imgui.PopStyleColor(3)

    imgui.SetCursorPosY(titleH + 6)
end

-- ============================================================
-- RENDER: PLAYER ROW
-- ============================================================
local function renderPlayerRow()
    dimText(T().labelId)
    imgui.SameLine()

    imgui.PushItemWidth(52)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.88, 0.50, 1.00))
    imgui.InputText('##pid', playerIdBuf, 8)
    imgui.PopStyleColor()
    imgui.PopItemWidth()

    local currentStr = ffi.string(playerIdBuf)
    if currentStr ~= lastIdStr then
        lastIdStr = currentStr
        local val = tonumber(currentStr)
        if val and val >= 0 and val <= 999 then
            local id = math.floor(val)
            if sampIsPlayerConnected(id) then
                playerId = id
            else
                playerId = -1
            end
        else
            playerId = -1
        end
    end

    imgui.SameLine(0, 12)
    dimText(T().labelPlayer)
    imgui.SameLine()

    local online = isOnline(playerId)
    local name
    if playerId < 0 then
        name = T().noId
    elseif online then
        name = playerName(playerId)
    else
        name = T().offline
    end

    imgui.PushStyleColor(imgui.Col.Text,
        online and imgui.ImVec4(0.40, 0.95, 0.55, 1.00)
               or  imgui.ImVec4(0.55, 0.55, 0.55, 1.00))
    imgui.Text(name)
    imgui.PopStyleColor()

    imgui.SameLine(0, 10)
    pushDimBtn()
    if imgui.Button('/id##idbtn', imgui.ImVec2(32, 22)) then
        if online then
            sendCmd('/id ' .. playerId)
        else
            localMsg(T().invalidId)
        end
    end
    imgui.PopStyleColor(3)
end

-- ============================================================
-- RENDER: TAB ROW
-- ============================================================
local function renderTabRow()
    imgui.Spacing()
    if activeMenu == 'theory' then pushCrimsonBtn() else pushDimBtn() end
    if imgui.Button(T().tabTheory .. '##tab1', imgui.ImVec2(188, 26)) then
        activeMenu = 'theory'
    end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 4)

    if activeMenu == 'practical' then pushCrimsonBtn() else pushDimBtn() end
    if imgui.Button(T().tabPractical .. '##tab2', imgui.ImVec2(188, 26)) then
        activeMenu = 'practical'
    end
    imgui.PopStyleColor(3)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

-- ============================================================
-- RENDER: WRONG ANSWER COUNTER
-- ============================================================
local function renderWrongCounter()
    sectionLabel('> ' .. T().wrongLabel .. '  ' .. string.format('%.1f', wrongCount) .. ' / ' .. MAX_WRONG)

    pushOrangeBtn()
    if imgui.Button(T().btnHalf .. '##h', imgui.ImVec2(64, 26)) then addWrong(0.5) end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 4)
    pushRedBtn()
    if imgui.Button(T().btnOne .. '##o', imgui.ImVec2(64, 26)) then addWrong(1) end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 4)
    pushDimBtn()
    if imgui.Button(T().btnReset .. '##wr', imgui.ImVec2(64, 26)) then
        wrongCount = 0.0
        localMsg('Contor resetat.')
    end
    imgui.PopStyleColor(3)

    local barW = 196
    local barH = 6
    local pos  = imgui.GetCursorScreenPos()
    local dl   = imgui.GetWindowDrawList()
    local ratio = math.min(wrongCount / MAX_WRONG, 1.0)
    local col   = wrongColor()

    imgui.Dummy(imgui.ImVec2(barW, barH + 4))
    dl:AddRectFilled(
        imgui.ImVec2(pos.x, pos.y + 2),
        imgui.ImVec2(pos.x + barW, pos.y + 2 + barH),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.15, 0.15, 0.22, 1.00)), 3)
    if ratio > 0 then
        dl:AddRectFilled(
            imgui.ImVec2(pos.x, pos.y + 2),
            imgui.ImVec2(pos.x + barW * ratio, pos.y + 2 + barH),
            imgui.ColorConvertFloat4ToU32(col), 3)
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

-- ============================================================
-- RENDER: QUESTION LIST + PREVIEW + TIMER
-- ============================================================
local function renderQuestions()
    sectionLabel(T().secQuestions)

    if imgui.BeginChild('##qlist', imgui.ImVec2(0, 130), true) then
        for i, q in ipairs(questions) do
            local qFirst = q.question:gsub('/cw%s*', ''):match('^([^\n]+)') or ''
            if searchText == '' or qFirst:lower():find(searchText:lower(), 1, true) then
                local isActive = (selectedQ == i)

                imgui.PushStyleColor(imgui.Col.Text,
                    isActive and imgui.ImVec4(1.00, 0.55, 0.55, 1.00)
                             or  imgui.ImVec4(0.50, 0.55, 0.68, 1.00))
                imgui.Text(string.format('%02d', i))
                imgui.PopStyleColor()

                imgui.SameLine(0, 6)

                imgui.PushStyleColor(imgui.Col.Text,
                    isActive and imgui.ImVec4(0.98, 0.86, 0.86, 1.00)
                             or  imgui.ImVec4(0.80, 0.84, 0.94, 1.00))
                imgui.Text(trunc(qFirst, 28))
                imgui.PopStyleColor()

                local availW = imgui.GetContentRegionAvail().x
                imgui.SameLine(availW - 58)

                if isActive then pushCrimsonBtn() else pushDimBtn() end
                if imgui.Button(T().btnSelect .. '##sel' .. i, imgui.ImVec2(58, 19)) then
                    selectedQ = i
                end
                imgui.PopStyleColor(3)
            end
        end
        imgui.EndChild()
    end

    imgui.Spacing()

    local q = questions[selectedQ]
    if q then
        local qDisplay = q.question:gsub('/cw%s*', ''):gsub('\\n', '\n')
        dimText(T().labelQ)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.88, 0.90, 0.98, 1.00))
        imgui.TextWrapped(qDisplay)
        imgui.PopStyleColor()

        local aDisplay = q.answer:gsub('\\n', '\n')
        dimText(T().labelA)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.50, 0.50, 1.00))
        imgui.TextWrapped(aDisplay)
        imgui.PopStyleColor()

        dimText(T().labelTime)
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.65, 0.85, 1.00, 1.00))
        imgui.Text(q.time .. 's')
        imgui.PopStyleColor()

        imgui.Spacing()

        if imgui.Button(T().btnAsk .. '##ask', imgui.ImVec2(100, 26)) then
            sendMultiLine(q.question)
        end

        imgui.SameLine(0, 6)


        imgui.SameLine(0, 6)

        if timer.active then
            pushOrangeBtn()
            imgui.PushStyleColor(imgui.Col.Text, timerColor())
            if imgui.Button(string.format('%ds##tmr', math.ceil(timer.remaining)), imgui.ImVec2(80, 26)) then
                timer.active = false
            end
            imgui.PopStyleColor(4)
        else
            pushBlueBtn()
            if imgui.Button(T().btnTimer .. '##tmr', imgui.ImVec2(80, 26)) then
                startTimer(q.time)
            end
            imgui.PopStyleColor(3)
        end
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

-- ============================================================
-- RENDER: THEORY MENU
-- ============================================================
local function renderTheoryMenu()
    sectionLabel('> TEST TEORETIC')

    pushGreenBtn()
    if imgui.Button(T().btnStartTheory .. '##sth', imgui.ImVec2(200, 28)) then
        startTest('theory')
    end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 6)

    pushBlueBtn()
    if imgui.Button(T().btnSendRules .. '##srth', imgui.ImVec2(130, 28)) then
        sendRules('theory')
    end
    imgui.PopStyleColor(3)

    imgui.Spacing()

    if session.started and session.testType == 'theory' then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.40, 0.95, 0.55, 1.00))
        imgui.Text('Activ: ' .. session.name .. ' (' .. session.id .. ')')
        imgui.PopStyleColor()
    else
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.45, 0.45, 0.55, 1.00))
        imgui.Text(T().noSession)
        imgui.PopStyleColor()
    end

    imgui.Spacing()

    pushGreenBtn()
    if imgui.Button(T().btnPass .. '  ##thpass', imgui.ImVec2(184, 26)) then
        finishTheoryTest(true)
    end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 6)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    renderWrongCounter()
    renderQuestions()
end

-- ============================================================
-- RENDER: PRACTICAL MENU
-- ============================================================
local function renderPracticalMenu()
    sectionLabel('> TEST PRACTIC')

    pushGreenBtn()
    if imgui.Button(T().btnStartPrac .. '##spr', imgui.ImVec2(200, 28)) then
        startTest('practical')
    end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 6)

    pushBlueBtn()
    if imgui.Button(T().btnSendRules .. '##srpr', imgui.ImVec2(130, 28)) then
        sendRules('practical')
    end
    imgui.PopStyleColor(3)

    imgui.Spacing()

    if session.started and session.testType == 'practical' then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.40, 0.95, 0.55, 1.00))
        imgui.Text('Activ: ' .. session.name .. ' (' .. session.id .. ')')
        imgui.PopStyleColor()
    else
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.45, 0.45, 0.55, 1.00))
        imgui.Text(T().noSession)
        imgui.PopStyleColor()
    end

    pushGreenBtn()
    if imgui.Button(T().btnFinish .. '  ##prpass', imgui.ImVec2(184, 26)) then
        finishPracticalTest(true)
    end
    imgui.PopStyleColor(3)

    imgui.SameLine(0, 6)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

end

-- ============================================================
-- MAIN RENDER FRAME
-- ============================================================
imgui.OnFrame(
    function() return windowState[0] end,
    function()
        if timer.active then
            local now  = os.clock()
            local dt   = now - timer.lastTick
            timer.lastTick = now
            timer.remaining = timer.remaining - dt
            if timer.remaining <= 0 then
                timer.remaining = 0
                timer.active    = false
                localMsg(T().timerDone)
            end
        end

        local WIN_W = 400
        local WIN_H = 580
        imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.FirstUseEver)

        if imgui.Begin('##thwin', windowState,
            imgui.WindowFlags.NoResize +
            imgui.WindowFlags.NoTitleBar
        ) then
            local drawList = imgui.GetWindowDrawList()
            local p = imgui.GetWindowPos()
            local w = imgui.GetWindowWidth()
            local titleH  = 34
            local footerH = 30

            renderTopBar(drawList, p, w, titleH)
            renderPlayerRow()
            renderTabRow()

            local contentH = WIN_H - titleH - footerH - 80
            if imgui.BeginChild('##content', imgui.ImVec2(0, contentH), false) then
                if activeMenu == 'theory' then
                    renderTheoryMenu()
                else
                    renderPracticalMenu()
                end
                imgui.EndChild()
            end

            local footerText = T().footer
            local tsz = imgui.CalcTextSize(footerText)
            drawList:AddRectFilled(
                imgui.ImVec2(p.x, p.y + WIN_H - footerH),
                imgui.ImVec2(p.x + w, p.y + WIN_H),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.16, 0.06, 0.09, 1.00)), 8)
            drawList:AddText(
                imgui.ImVec2(
                    p.x + w / 2 - tsz.x / 2,
                    p.y + WIN_H - footerH / 2 - tsz.y / 2),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.75, 0.78, 0.88, 1.00)),
                footerText)

            imgui.End()
        end
    end
)

-- ============================================================
-- ENTRY POINT
-- ============================================================
function main()
    while not isSampAvailable() do wait(100) end

    localMsg('Mod successfully loaded. | Made by{AA3333} sLoww')
    localMsg('Use /thinfo or press F4 to use it. | Discord:{AA3333} sloww')

    sampRegisterChatCommand('tq', function(args)
        local idx, text = args:match('^(%d+)%s+(.+)$')
        idx = tonumber(idx)
        if idx and idx >= 1 and idx <= #questions and text then
            questions[idx].question = text
            localMsg('Intrebarea #' .. idx .. ' actualizata.')
        else
            localMsg('Folosire: /tq <1-' .. #questions .. '> <text>')
        end
    end)

    sampRegisterChatCommand('ta', function(args)
        local idx, text = args:match('^(%d+)%s+(.+)$')
        idx = tonumber(idx)
        if idx and idx >= 1 and idx <= #questions and text then
            questions[idx].answer = text
            localMsg('Raspunsul #' .. idx .. ' actualizat.')
        else
            localMsg('Folosire: /ta <1-' .. #questions .. '> <text>')
        end
    end)

    sampRegisterChatCommand('treload', function()
        questions = loadQuestions()
        localMsg(T().reloadOk .. ' (' .. #questions .. ' intrebari incarcate)')
    end)

    sampRegisterChatCommand('thinfo', function()
        windowState[0] = not windowState[0]
    end)

    while true do
        wait(0)

        drawWatermark()

        if wasKeyPressed(key.VK_F4) then
            windowState[0] = not windowState[0]
        end
    end
end