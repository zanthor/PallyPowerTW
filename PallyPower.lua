local initialized = false

-- SuperWoW detection (v1.38)
local PP_SuperWoW = SetAutoloot and true or false
local PP_TrackedGUIDs = {}

-- Nampower API detection
local PP_NampowerAPI = false
local PP_NampowerVersion = nil
local PP_NAMPOWER_MIN_VERSION = {2, 27, 2}

if GetNampowerVersion then
    local major, minor, patch = GetNampowerVersion()
    patch = patch or 0
    PP_NampowerVersion = string.format("%d.%d.%d", major, minor, patch)
    if major > PP_NAMPOWER_MIN_VERSION[1]
        or (major == PP_NAMPOWER_MIN_VERSION[1] and minor > PP_NAMPOWER_MIN_VERSION[2])
        or (major == PP_NAMPOWER_MIN_VERSION[1] and minor == PP_NAMPOWER_MIN_VERSION[2] and patch >= PP_NAMPOWER_MIN_VERSION[3]) then
        PP_NampowerAPI = true
    end
end

PALLYPOWER_GREATERBLESSINGDURATION = 30 * 60
PALLYPOWER_NORMALBLESSINGDURATION = 10 * 60
PALLYPOWER_SKIPBLESSINGDURATION = 30 -- When i implement blacklist for out of LoS -- Test 
PALLYPOWER_BLESSINGTRESHOLD = 60
PALLYPOWER_RESTARTAUTOBLESS = 2 * 60

PALLYPOWER_MAXCLASSES = 10
PALLYPOWER_MAXPERCLASS = 15
PALLYPOWER_AURA_CLASS = 10
PALLYPOWER_SEAL_CLASS = 11
PP_PREFIX = "PLPWR"

AllPallys = {}
AllPallysAuras = {}
AllPallysSeals = {}

PallyPower_Assignments = {}
PallyPower_AuraAssignments = {}
PallyPower_SealAssignments = {}
PallyPower_NormalAssignments = {}
PallyPower_Tanks = {}

PallyPower = {}

BlessingIcon = {}
BuffIcon = {}
AuraIcons = {}
SealIcons = {}
BuffIconSmall = {}

-- Aura and Seal spell names for Nampower matching
AuraNames = {}
SealNames = {}

PallyPower_LayOnHandsIcon = "Interface\\Icons\\Spell_Holy_LayOnHands"
PallyPower_DivineItervention = "Interface\\Icons\\Spell_Nature_TimeStop"

PP_PerUser = {
    scalemain = 1, -- corner of main window docked to
    scalebar = 1, -- corner menu window is docked from
    scanfreq = 10,
    scanperframe = 1,
    smartbuffs = 1,
    frameslocked = false,
    regularblessings = false,
    showrfbutton = true,
    showaurabutton = true,
    showsealbutton = true,
    minimapbuttonshow = true,
    playsoundwhen0 = true,
    minimapbuttonpos = 30,
    freeassign = true,
    horizontal = false,
    hideblizzaura = false,
    useunitxp_sp3 = false,
    usehdicons = false,
    transparency = 0.5
}
PP_NextScan = PP_PerUser.scanfreq
PP_UnitXPDllLoaded = false

PallyPower_ClassTexture = {}

LastCast = {}
LastCastPlayer = {}

-- Initialize LastCastOn
LastCastOn = {}
for iinit = 0, 9 do
    LastCastOn[iinit] = {}
end

PP_Symbols = 0
IsPally = 0
lastClassBtn = 1
lastClassBtnTime = PALLYPOWER_RESTARTAUTOBLESS
hasRighteousFury = false
nameRighteousFury = nil
versionBumpDisplayed = false

Assignment = {}

CurrentBuffs = {}

PP_ScanInfo = nil

local RestorSelfAutoCastTimeOut = 1
local RestorSelfAutoCast = false

-- Fix Shagu Tweaks displays error when trying to display boolean values
print = function(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. ( tostring(msg) or "nil" ))
end

function PallyPower_FramesLockedOption()
    if (FramesLockedOptionChk:GetChecked() == 1) then
        PP_PerUser.frameslocked = true
    else
        PP_PerUser.frameslocked = false
    end
    PallyPowerGrid_Update(1)
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_RighteousFuryOption()
    if (RighteousFuryOptionChk:GetChecked() == 1) then
        PP_PerUser.showrfbutton = true
    else
        PP_PerUser.showrfbutton = false
    end
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_AuraOption()
    if (AuraOptionChk:GetChecked() == 1) then
        PP_PerUser.showaurabutton = true
    else
        PP_PerUser.showaurabutton = false
    end
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_SealOption()
    if (SealOptionChk:GetChecked() == 1) then
        PP_PerUser.showsealbutton = true
    else
        PP_PerUser.showsealbutton = false
    end
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_MinimapButtonOption()
    if (MinimapButtonOptionChk:GetChecked() == 1) then
        PP_PerUser.minimapbuttonshow = true
        PallyPowerMinimapButtonFrame:Show();
    else
        PP_PerUser.minimapbuttonshow = false
        PallyPowerMinimapButtonFrame:Hide();
    end
end

function PallyPower_PlaySoundOption()
    if (PlaySoundOptionChk:GetChecked() == 1) then
        PP_PerUser.playsoundwhen0 = true
    else
        PP_PerUser.playsoundwhen0 = false
    end
end

function PallyPower_HorizontalLayoutOption()
    if (HorizontalLayoutOptionChk:GetChecked() == 1) then
        PP_PerUser.horizontal = true
    else
        PP_PerUser.horizontal = false
    end
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_HideBlizzardAuraFrameOption()
    if (HideBlizzardFrameOptionChk:GetChecked() == 1) then
        PP_PerUser.hideblizzaura = true
        ShapeshiftBarFrame:Hide()    
    else
        PP_PerUser.hideblizzaura = false
        ShapeshiftBarFrame:Show()
    end
end

function PallyPower_FreeAssignOption()
    if (FreeAssignOptionChk:GetChecked() == 1) then
        PP_PerUser.freeassign = true
	PallyPower_SendMessage("FREEASSIGN YES")
    else
        PP_PerUser.freeassign = false
	PallyPower_SendMessage("FREEASSIGN NO")
    end
end

function PallyPower_UseUnitXPSP3Option()
    if (UseUnitXPSP3OptionChk:GetChecked() == 1) then
        PP_PerUser.useunitxp_sp3 = true
    else
        PP_PerUser.useunitxp_sp3 = false
    end
end

function PallyPower_UseHDIconsOption()
    if (UseHDIconsOptionChk:GetChecked() == 1) then
        PP_PerUser.usehdicons = true
    else
        PP_PerUser.usehdicons = false
    end
    PallyPower_AdjustIcons()
end

local function PP_Debug(string)
    if not string then
        string = "(nil)"
    end
    if (PP_DebugEnabled) then
        DEFAULT_CHAT_FRAME:AddMessage("[PP] " .. string, 1, 0, 0)
    end
end

function PallyPower_ShowMemoryUsage()
    local mem = gcinfo() -- Returns memory in KB
    mem = mem / 1024 -- Convert to MB
    mem = math.floor(mem * 100) / 100 -- Round to two decimal place
    return mem
end

function PallyPower_CheckTargetLoS(target, maxRange)
    if not PP_PerUser or PP_PerUser.useunitxp_sp3 == false then return true end -- If we are not using UnitXP.dll, we assume we are in LoS
    if not target then target = "target" end
    if not maxRange then maxRange = 40 end -- Default blessing range is 40 yards
    
    local function debugLog(msg)
        if OGAALogger and OGAALogger.AddMessage and type(OGAALogger.AddMessage) == "function" then
            OGAALogger.AddMessage("PallyPower_LOS", msg)
        end
    end
    
    debugLog("CheckTargetLoS called for: " .. tostring(target) .. ", maxRange=" .. tostring(maxRange))
    debugLog("  PP_UnitXPDllLoaded: " .. tostring(PP_UnitXPDllLoaded))
    debugLog("  PP_PerUser.useunitxp_sp3: " .. tostring(PP_PerUser.useunitxp_sp3))
    
    if PP_UnitXPDllLoaded then
        -- Check connection and visibility first (like Puppeteer)
        if not UnitIsConnected(target) then
            debugLog("  Result: FALSE - UnitIsConnected returned false")
            return false
        end
        
        if not UnitIsVisible(target) then
            debugLog("  Result: FALSE - UnitIsVisible returned false")
            return false
        end
        
        -- Check line of sight
        local inSight = UnitXP("inSight","player",target)
        debugLog("  UnitXP('inSight'): " .. tostring(inSight))
        if not inSight then
            debugLog("  Result: FALSE - not in sight")
            return false
        end
        
        -- Check range
        local distance = UnitXP("distanceBetween","player",target)
        debugLog("  UnitXP('distanceBetween'): " .. tostring(distance))
        if distance and distance > maxRange then
            debugLog("  Result: FALSE - distance " .. distance .. " > " .. maxRange)
            return false
        end
        
        debugLog("  Result: TRUE - all checks passed")
        return true
    else
        debugLog("  Result: TRUE - PP_UnitXPDllLoaded is false, assuming in LOS")
        return true -- If UnitXP.dll is not loaded, we assume we are in LoS
    end
end

-- Helper function to get distance to a unit (returns nil if UnitXP not available or unit invalid)
function PallyPower_GetUnitDistance(unit)
    local function debugLog(msg)
        if OGAALogger and OGAALogger.AddMessage and type(OGAALogger.AddMessage) == "function" then
            OGAALogger.AddMessage("PallyPower_Dist", msg)
        end
    end
    
    debugLog("GetUnitDistance called for: " .. tostring(unit))
    
    if not PP_PerUser or not PP_UnitXPDllLoaded or PP_PerUser.useunitxp_sp3 == false then
        debugLog("  Result: nil - UnitXP not available or not enabled")
        return nil
    end
    
    if not unit or not UnitExists(unit) then
        debugLog("  Result: nil - unit doesn't exist")
        return nil
    end
    
    if not UnitIsConnected(unit) or not UnitIsVisible(unit) then
        debugLog("  Result: 9999 - unit not connected or not visible")
        return 9999
    end
    
    local distance = UnitXP("distanceBetween","player",unit)
    debugLog("  UnitXP('distanceBetween'): " .. tostring(distance))
    local result = math.max(distance or 9999, 0)
    debugLog("  Result: " .. tostring(result))
    return result
end

-- Sort units by distance (closest first), prioritizing those in range and LOS
function PallyPower_SortUnitsByProximity(unitsTable, maxRange)
    if not unitsTable then return {} end
    if not maxRange then maxRange = 40 end
    
    -- Convert the units table to an array with distance info
    local unitsArray = {}
    for unit, stats in pairs(unitsTable) do
        local distance = PallyPower_GetUnitDistance(unit)
        local inLOS = PallyPower_CheckTargetLoS(unit, maxRange)
        
        table.insert(unitsArray, {
            unit = unit,
            stats = stats,
            distance = distance or 9999, -- Units with unknown distance go to the end
            inLOS = inLOS
        })
    end
    
    -- Sort by: LOS first, then by distance
    table.sort(unitsArray, function(a, b)
        if a.inLOS ~= b.inLOS then
            return a.inLOS -- In LOS units come first
        end
        return a.distance < b.distance -- Then sort by distance
    end)
    
    return unitsArray
end

function PallyPower_InitConfig()
    -- Delayed Nampower status announcement (10s so it appears after login spam)
    local announceFrame = CreateFrame("Frame")
    announceFrame.elapsed = 0
    announceFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 10 then
            if PP_NampowerAPI then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00PallyPower:|r Nampower " .. PP_NampowerVersion .. " detected - using enhanced API", 0.5, 1, 0.5)
            elseif PP_NampowerVersion then
                local minVer = PP_NAMPOWER_MIN_VERSION[1] .. "." .. PP_NAMPOWER_MIN_VERSION[2] .. "." .. PP_NAMPOWER_MIN_VERSION[3]
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000PallyPower:|r Nampower " .. PP_NampowerVersion .. " is too old (need " .. minVer .. "+) - using fallback", 1, 0.5, 0.5)
            end
            this:SetScript("OnUpdate", nil)
        end
    end)
    
    if PP_PerUser.scalemain == nil then PP_PerUser.scalemain = 1 end
    if PP_PerUser.scalebar == nil then PP_PerUser.scalebar = 1 end
    if PP_PerUser.scanfreq == nil then PP_PerUser.scanfreq = 10 end
    if PP_PerUser.scanperframe == nil then PP_PerUser.scanperframe = 1 end
    if PP_PerUser.smartbuffs == nil then PP_PerUser.smartbuffs = 1 end
    if PP_PerUser.frameslocked == nil then PP_PerUser.frameslocked = false end
    if PP_PerUser.regularblessings == nil then PP_PerUser.regularblessings = false end
    if PP_PerUser.showrfbutton == nil then PP_PerUser.showrfbutton = true end
    if PP_PerUser.showaurabutton == nil then PP_PerUser.showaurabutton = true end
    if PP_PerUser.showsealbutton == nil then PP_PerUser.showsealbutton = true end
    if PP_PerUser.minimapbuttonshow == nil then PP_PerUser.minimapbuttonshow = true end
    if PP_PerUser.playsoundwhen0 == nil then PP_PerUser.playsoundwhen0 = true end
    if PP_PerUser.minimapbuttonpos == nil then PP_PerUser.minimapbuttonpos = 30 end
    if PP_PerUser.freeassign == nil then PP_PerUser.freeassign = true end
    if PP_PerUser.horizontal == nil then PP_PerUser.horizontal = false end
    if PP_PerUser.hideblizzaura == nil then PP_PerUser.hideblizzaura = false end
    if PP_PerUser.useunitxp_sp3 == nil then PP_PerUser.useunitxp_sp3 = false end
    if PP_PerUser.usehdicons == nil then PP_PerUser.usehdicons = false end
    if PP_PerUser.transparency == nil then PP_PerUser.transparency = 0.5 end
    
    -- UnitXP SP3 detection (using Puppeteer's safer method)
    if UnitXP and pcall(UnitXP, "inSight", "player", "player") then
       PP_UnitXPDllLoaded = true
       -- Auto-enable UnitXP SP3 if it was previously nil (first time detection)
       if PP_PerUser.useunitxp_sp3 == false and GetCVar("PP_AutoEnabledUnitXP") ~= "1" then
           PP_PerUser.useunitxp_sp3 = true
           SetCVar("PP_AutoEnabledUnitXP", "1")
           DEFAULT_CHAT_FRAME:AddMessage("[PallyPower] UnitXP SP3 detected and auto-enabled for range/LOS checking")
       end
    else
        PP_UnitXPDllLoaded = false
        UseUnitXPSP3OptionChk:SetChecked(false)
        PP_PerUser.useunitxp_sp3 = false
        UseUnitXPSP3OptionChk:Disable()
    end    
end

function PallyPower_OnLoad()
    this:RegisterEvent("SPELLS_CHANGED")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("CHAT_MSG_ADDON")
    this:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
    this:RegisterEvent("PLAYER_LOGIN")
    this:RegisterEvent("PARTY_MEMBERS_CHANGED")
    this:RegisterEvent("RAID_ROSTER_UPDATE")
    this:RegisterEvent("ADDON_LOADED")
    this:RegisterEvent("PLAYER_AURAS_CHANGED")
    PallyPower_SetFrameBackdropColor(this)
    this:SetScale(1)
    SlashCmdList["PALLYPOWER"] = function(msg)
        PallyPower_SlashCommandHandler(msg)
    end
    --Hide BuffBar if not paladin. You can still see the assignments grid
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then
        getglobal("PallyPowerBuffBar"):Hide()
    end    
end

function PallyPower_SetFrameBackdropColor(frame)
    if frame then
        frame:SetBackdropColor(0, 0, 0, PP_PerUser.transparency)
    end
end

function PallyPower_OnUpdate(tdiff)
    lastClassBtnTime = lastClassBtnTime - tdiff
    if lastClassBtnTime < 0 then
        lastClassBtnTime = PALLYPOWER_RESTARTAUTOBLESS
        lastClassBtn = 1
    end
    if (RestorSelfAutoCast) then
        RestorSelfAutoCastTimeOut = RestorSelfAutoCastTimeOut - tdiff
        if (RestorSelfAutoCastTimeOut < 0) then
            RestorSelfAutoCast = false
            SetCVar("autoSelfCast", "1")
        end
    end

    if (not PP_PerUser.scanfreq) then
        PP_PerUser.scanfreq = 10
        PP_PerUser.scanperframe = 1
    end
    PP_NextScan = PP_NextScan - tdiff
    if PP_NextScan < 0 and PP_IsPally then
        PP_Debug("Scanning")
        PallyPower_ScanRaid()
    end
    for i, k in LastCast do
        LastCast[i] = k - tdiff
        if LastCast[i] <= 0 then
            if PP_PerUser.playsoundwhen0 == true then
                PlaySoundFile("Interface\\Addons\\PallyPowerTW\\Sounds\\ding.mp3")
            end
            LastCast[i] = nil
        end
    end
    for i, k in LastCastPlayer do
        LastCastPlayer[i] = k - tdiff
        if LastCastPlayer[i] <= 0 then
            if PP_PerUser.playsoundwhen0 == true then
                PlaySoundFile("Interface\\Addons\\PallyPowerTW\\Sounds\\ding.mp3")
            end
            LastCastPlayer[i] = nil
        end
    end
end

-- Helper function: Check if spell ID matches expected buff by comparing against known blessing/buff names
-- This is used with Nampower to match spell IDs from auras to the buffs we're checking for
function PallyPower_GetBlessingNameFromTexture(texturePath)
    if not texturePath then return nil end
    
    -- Wisdom blessings
    if string.find(texturePath, "SealOfWisdom") or string.find(texturePath, "BlessingofWisdom") then
        return {"Blessing of Wisdom", "Greater Blessing of Wisdom"}
    -- Kings/Might
    elseif string.find(texturePath, "FistOfJustice") or string.find(texturePath, "BlessingofKings") or string.find(texturePath, "GreaterBlessingofKings") then
        return {"Blessing of Kings", "Greater Blessing of Kings", "Blessing of Might", "Greater Blessing of Might"}
    -- Salvation
    elseif string.find(texturePath, "SealOfSalvation") or string.find(texturePath, "BlessingofSalvation") then
        return {"Blessing of Salvation", "Greater Blessing of Salvation"}
    -- Light
    elseif string.find(texturePath, "PrayerOfHealing") or string.find(texturePath, "BlessingofLight") then
        return {"Blessing of Light", "Greater Blessing of Light"}
    -- Sanctuary
    elseif string.find(texturePath, "MageArmor") or string.find(texturePath, "BlessingofSanctuary") then
        return {"Blessing of Sanctuary", "Greater Blessing of Sanctuary"}
    -- Protection (Lightning Shield icon)
    elseif string.find(texturePath, "LightningShield") then
        return {"Blessing of Protection"}
    end
    
    return nil
end

function PallyPower_AdjustIcons()
    local icons_prefix
    if PP_PerUser.usehdicons == true then
        icons_prefix = "AddOns\\PallyPowerTW\\HD"
    else
        icons_prefix = "AddOns\\PallyPowerTW\\"
    end

    AuraIcons[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_DevotionAura"
    AuraIcons[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_AuraOfLight"
    AuraIcons[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_MindSooth"
    AuraIcons[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Shadow_SealOfKings"
    AuraIcons[4] = "Interface\\"..icons_prefix.."Icons\\Spell_Frost_WizardMark"
    AuraIcons[5] = "Interface\\"..icons_prefix.."Icons\\Spell_Fire_SealOfFire"
    AuraIcons[6] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_MindVision"
    
    -- Aura spell names for Nampower matching
    AuraNames[0] = "Devotion Aura"
    AuraNames[1] = "Retribution Aura"
    AuraNames[2] = "Concentration Aura"
    AuraNames[3] = "Shadow Resistance Aura"
    AuraNames[4] = "Frost Resistance Aura"
    AuraNames[5] = "Fire Resistance Aura"
    AuraNames[6] = "Sanctity Aura"

    SealIcons[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_RighteousnessAura"
    SealIcons[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_HolySmite"
    SealIcons[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_HealingAura"
    SealIcons[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfWrath"
    SealIcons[4] = "Interface\\"..icons_prefix.."Icons\\Ability_Warrior_InnerRage"
    SealIcons[5] = "Interface\\"..icons_prefix.."Icons\\Ability_ThunderBolt"
    
    -- Seal spell names for Nampower matching
    SealNames[0] = "Seal of Righteousness"
    SealNames[1] = "Seal of Light"
    SealNames[2] = "Seal of Wisdom"
    SealNames[3] = "Seal of Justice"
    SealNames[4] = "Seal of the Crusader"
    SealNames[5] = "Seal of Command"

    if (PP_PerUser.regularblessings == true) then
        RegularBlessings = true
        BlessingIcon[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfWisdom"
        BlessingIcon[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_FistOfJustice"
        BlessingIcon[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfSalvation"
        BlessingIcon[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_PrayerOfHealing02"
        BlessingIcon[4] = "Interface\\"..icons_prefix.."Icons\\Spell_Nature_LightningShield"
        BlessingIcon[5] = "Interface\\"..icons_prefix.."Icons\\Spell_Magic_MageArmor"
        BuffIcon[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfWisdom"
        BuffIcon[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_FistOfJustice"
        BuffIcon[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfSalvation"
        BuffIcon[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_PrayerOfHealing02"
        BuffIcon[4] = "Interface\\"..icons_prefix.."Icons\\Spell_Nature_LightningShield"
        BuffIcon[5] = "Interface\\"..icons_prefix.."Icons\\Spell_Magic_MageArmor"
        BuffIcon[9] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfFury"
    else
        RegularBlessings = false
        BlessingIcon[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofWisdom"
        BlessingIcon[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofKings"
        BlessingIcon[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofSalvation"
        BlessingIcon[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofLight"
        BlessingIcon[4] = "Interface\\"..icons_prefix.."Icons\\Spell_Magic_GreaterBlessingofKings"
        BlessingIcon[5] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofSanctuary"
        BuffIcon[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofWisdom"
        BuffIcon[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofKings"
        BuffIcon[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofSalvation"
        BuffIcon[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofLight"
        BuffIcon[4] = "Interface\\"..icons_prefix.."Icons\\Spell_Magic_GreaterBlessingofKings"
        BuffIcon[5] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_GreaterBlessingofSanctuary"
        BuffIcon[9] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfFury"
        BuffIconSmall[0] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfWisdom"
        BuffIconSmall[1] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_FistOfJustice"
        BuffIconSmall[2] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfSalvation"
        BuffIconSmall[3] = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_PrayerOfHealing02"
        BuffIconSmall[4] = "Interface\\"..icons_prefix.."Icons\\Spell_Nature_LightningShield"
        BuffIconSmall[5] = "Interface\\"..icons_prefix.."Icons\\Spell_Magic_MageArmor"
    end

    PallyPower_ClassTexture[0] = "Interface\\"..icons_prefix.."Icons\\Warrior"
    PallyPower_ClassTexture[1] = "Interface\\"..icons_prefix.."Icons\\Rogue"
    PallyPower_ClassTexture[2] = "Interface\\"..icons_prefix.."Icons\\Priest"
    PallyPower_ClassTexture[3] = "Interface\\"..icons_prefix.."Icons\\Druid"
    PallyPower_ClassTexture[4] = "Interface\\"..icons_prefix.."Icons\\Paladin"
    PallyPower_ClassTexture[5] = "Interface\\"..icons_prefix.."Icons\\Hunter"
    PallyPower_ClassTexture[6] = "Interface\\"..icons_prefix.."Icons\\Mage"
    PallyPower_ClassTexture[7] = "Interface\\"..icons_prefix.."Icons\\Warlock"
    PallyPower_ClassTexture[8] = "Interface\\"..icons_prefix.."Icons\\Shaman"
    PallyPower_ClassTexture[9] = "Interface\\"..icons_prefix.."Icons\\Pet" 
    
    PallyPower_RighteousFury = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_SealOfFury"
    PallyPower_AuraMastery = "Interface\\"..icons_prefix.."Icons\\Spell_Holy_AuraMastery"
    PallyPower_AbilitySeal = "Interface\\"..icons_prefix.."Icons\\Ability_Thunderbolt"
end

function PallyPower_OnEvent(event,arg1)
    local type, id

    if (event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD") then
        PallyPower_AdjustIcons()
        PallyPower_ScanSpells()
        if PP_PerUser.hideblizzaura == true then
            if ShapeshiftBarFrame:IsVisible() then ShapeshiftBarFrame:Hide() end
        else   
            if not ShapeshiftBarFrame:IsVisible() then ShapeshiftBarFrame:Show() end
        end         
    end

    if (event == "PLAYER_ENTERING_WORLD" and (not PallyPower_Assignments[UnitName("player")])) then
        PallyPower_Assignments[UnitName("player")] = {}
    end

    if (event == "PLAYER_ENTERING_WORLD" and (not PallyPower_SealAssignments[UnitName("player")])) then
        PallyPower_SealAssignments[UnitName("player")] = -1
    end

    if event == "CHAT_MSG_ADDON" and arg1 == PP_PREFIX and (arg3 == "PARTY" or arg3 == "RAID") then
        PallyPower_ParseMessage(arg4, arg2)
    end

    if event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" and PP_NextScan > 1 then
        PP_NextScan = 1
    end

    if event == "PLAYER_LOGIN" and PP_NextScan > 1 then
        PP_NextScan = 1 --PallyPower_UpdateUI()
    end

    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if PallyPower_PaladinLeftGroup() then
            AllPallys = {}       
            AllPallysAuras = {} 
            AllPallysSeals = {}
            for name in PallyPower_Assignments do
                if (name ~= UnitName("player")) then
                    PallyPower_Assignments[name] = nil
                end
            end
            for name in PallyPower_AuraAssignments do
                if (name ~= UnitName("player")) then
                    PallyPower_AuraAssignments[name] = nil
                end
            end
            for name in PallyPower_SealAssignments do
                if (name ~= UnitName("player")) then
                    PallyPower_SealAssignments[name] = nil
                end
            end
        end
        local _, class = UnitClass("player")
        if class == "PALADIN" then
            PallyPower_ScanSpells()
            PallyPower_SendSelf()
        end        
        PallyPower_SendVersion()
        PallyPower_RequestSend()
        PallyPower_ScanRaid()
    end

    if event == "ADDON_LOADED" and arg1 == "PallyPowerTW" then
        PallyPower_AdjustIcons()
        PallyPower_MinimapButton_Init();
        PallyPower_InitConfig();   
        PallyPower_AdjustTransparency();
    end

    if event == "PLAYER_AURAS_CHANGED" then
        if PallyPower_CheckRigteousFurry() then
            PallyPower_CancelSalvationBuff()
        end
    end
end

function PallyPower_CheckRigteousFurry()
    local buff = "Spell_Holy_SealOfFury"
    
    -- Use Nampower API if available for better performance
    if PP_NampowerAPI then
        local auras = GetUnitField("player", "aura")
        if auras then
            for i = 1, table.getn(auras) do
                local spellId = auras[i]
                if spellId and spellId > 0 then
                    -- Get spell name and check if it's Righteous Fury
                    local spellName = GetSpellRecField(spellId, "name")
                    if spellName and spellName == "Righteous Fury" then
                        return true
                    end
                end
            end
        end
        return false
    end
    
    -- Fallback to original method
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled == 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then  
                if string.find(texture, buff) then
                	return true
            	end
            end
        end
        counter = counter + 1
    end
    return false
end

function PallyPower_CancelSalvationBuff()
    local buff = {"Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation"}
    
    -- Use Nampower API if available for better performance
    if PP_NampowerAPI then
        local auras = GetUnitField("player", "aura")
        if auras then
            for auraIdx = 1, table.getn(auras) do
                local spellId = auras[auraIdx]
                if spellId and spellId > 0 then
                    local spellName = GetSpellRecField(spellId, "name")
                    if spellName and (spellName == "Blessing of Salvation" or spellName == "Greater Blessing of Salvation") then
                        -- Cancel using buff index (1-based for UnitBuff compatibility)
                        CancelPlayerBuff(auraIdx - 1);
                        UIErrorsFrame:Clear();
                        UIErrorsFrame:AddMessage("Salvation Removed");
                        return
                    end
                end
            end
        end
        return nil
    end
    
    -- Fallback to original method
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled ~= 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then 
                local i = 1
                while buff[i] do
                    if string.find(texture, buff[i]) then
                        CancelPlayerBuff(index);
                        UIErrorsFrame:Clear();
                        UIErrorsFrame:AddMessage("Salvation Removed");
                        return
                    end
                    i = i + 1
                end
            end
        end
        counter = counter + 1
    end
    return nil
end

function PallyPower_AdjustTransparency()
    PallyPower_SetFrameBackdropColor(PallyPower_OptionsFrame)
    PallyPower_SetFrameBackdropColor(PallyPowerFrame)
    PallyPower_SetFrameBackdropColor(PallyPowerBuffBar)
    PallyPower_SetFrameBackdropColor(PallyPowerWarningFrame)
    PallyPower_SetFrameBackdropColor(PallyPowerSaveMenu)
end

function PallyPower_SlashCommandHandler(msg)
    if (msg == "debug") then
        if PP_DebugEnabled then
            PP_DebugEnabled = nil
        else
            PP_DebugEnabled = true
        end
	return true
    end
    if (msg == "report") then
        PallyPower_Report()
        return true
    end
    if (msg == "buff" or msg == "autobuff") then
        PallyPower_AutoBuffAll()
        return true
    end
    if PallyPowerFrame:IsVisible() then
        PallyPowerFrame:Hide()
    else
        PallyPowerFrame:Show()
    end
    PP_NextScan = 0.1 --PallyPower_UpdateUI()
end

function PallyPower_Report()
    if PallyPower_CanControl(UnitName("player")) then
        local type
        if GetNumRaidMembers() > 0 then
            type = "RAID"
        else
            type = "PARTY"
        end
        PP_Debug(type)
        SendChatMessage(PallyPower_Assignments1, type)
        for name in AllPallys do
            local blessings = nil
            for id = 0, 9 do
                local bid = PallyPower_Assignments[name][id]
                if bid ~= nil and bid >= 0 then
                    if (blessings) then
                        blessings = blessings .. ", "..PallyPower_ClassID[id]
                    else
                        blessings = ""..PallyPower_ClassID[id]
                    end
                    blessings = blessings .. "("..PallyPower_BlessingID[bid]..")"
                end
            end
            if not (blessings) then
                blessings = "Nothing"
            end
            if PallyPower_AuraAssignments[name] and PallyPower_AuraAssignments[name] ~= -1 then
                blessings = blessings.." --- Aura: "..PallyPower_AuraID[PallyPower_AuraAssignments[name]]
            end
            if PallyPower_SealAssignments[name] and PallyPower_SealAssignments[name] ~= -1 then
                blessings = blessings.." --- Seal: "..PallyPower_SealID[PallyPower_SealAssignments[name]]
            end
            SendChatMessage(name .. ": " .. blessings, type)
            PP_Debug(name .. ": " .. blessings)
        end
        SendChatMessage(PallyPower_Assignments2, type)
    end
end

function PallyPower_FormatTime(time)
    if not time or time < 0 then
        return ""
    end
    mins = floor(time / 60)
    secs = time - (mins * 60)
    return string.format("%d:%02d", mins, secs)
end

function PallyPower_TableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
 end

 function PallyPower_RemoveFromTable(itab, ivalue)
    for i, v in ipairs(itab) do
        if v == ivalue then
            table.remove(itab, i)
            break -- Exit the loop after removing the value
        end
    end
end

function PallyPowerGrid_Update(tdiff)
    if not initialized then
        PallyPower_ScanSpells()
    end
    if PP_PerUser.frameslocked == true then
        PallyPowerFrameResizeButton:Hide()
    else
        PallyPowerFrameResizeButton:Show()
    end

    for i = 0, 9 do
        getglobal("PallyPowerFrameClass" .. i):SetTexture(PallyPower_ClassTexture[i])
    end
    getglobal("PallyPowerFrameClassA"):SetTexture(PallyPower_AuraMastery)
    getglobal("PallyPowerFrameClassS"):SetTexture(PallyPower_AbilitySeal)

    -- Pally 1 is always myself
    local i = 1
    local numPallys = 0
    local name, skills
    if PallyPowerFrame:IsVisible() then
        PallyPowerFrame:SetScale(PP_PerUser.scalemain)
        for name, skills in AllPallys do
            getglobal("PallyPowerFramePlayer" .. i .. "Name"):SetText(name)
            getglobal("PallyPowerFramePlayer" .. i .. "InGroup"):SetText(PallyPower_GetPlayerGroupID(name))

            -- Set icons about Lay on Hands and Divine Intervention here ( communicated via messages )
            if skills["LayOnHands"] ~= nil  and skills["LayOnHands"] == true then
                getglobal("PallyPowerFramePlayer" .. i .. "IconLH"):SetTexture(PallyPower_LayOnHandsIcon)
                getglobal("PallyPowerFramePlayer" .. i .. "IconLH"):Show()
            else
                getglobal("PallyPowerFramePlayer" .. i .. "IconLH"):Hide()
            end
            if skills["DivineIntervention"] ~= nil  and skills["DivineIntervention"] == true then
                getglobal("PallyPowerFramePlayer" .. i .. "IconDI"):SetTexture(PallyPower_DivineItervention)
                getglobal("PallyPowerFramePlayer" .. i .. "IconDI"):Show()
            else
                getglobal("PallyPowerFramePlayer" .. i .. "IconDI"):Hide()
            end

            getglobal("PallyPowerFramePlayer" .. i .. "Symbols"):SetText(skills["symbols"])
            getglobal("PallyPowerFramePlayer" .. i .. "Symbols"):SetTextColor(1, 1, 0.5)
            if (PallyPower_CanControl(name)) then
                getglobal("PallyPowerFramePlayer" .. i .. "Name"):SetTextColor(1, 1, 1)
            else
                if (PallyPower_CheckRaidLeader(name)) then
                    getglobal("PallyPowerFramePlayer" .. i .. "Name"):SetTextColor(0, 1, 0)
                else
                    getglobal("PallyPowerFramePlayer" .. i .. "Name"):SetTextColor(1, 0, 0)
                end
            end
            for id = 0, 5 do -- Blessings Icons and skills
                if (skills[id]) then
                    getglobal("PallyPowerFramePlayer" .. i .. "Icon" .. id):Show()
                    getglobal("PallyPowerFramePlayer" .. i .. "Skill" .. id):Show()
                    txt = skills[id]["rank"]
                    if (skills[id]["talent"] + 0 > 0) then
                        txt = txt .. "+" .. skills[id]["talent"]
                    end
                    getglobal("PallyPowerFramePlayer" .. i .. "Skill" .. id):SetText(txt)
                else
                    getglobal("PallyPowerFramePlayer" .. i .. "Icon" .. id):Hide()
                    getglobal("PallyPowerFramePlayer" .. i .. "Skill" .. id):Hide()
                end
            end
            for id = 6, 8 do -- Aura Icons and skills (Auras start from 0 and icon start at 6)
                if AllPallysAuras[name] and AllPallysAuras[name][id-6] then
                    getglobal("PallyPowerFramePlayer" .. i .. "Icon" .. id):Show()
                    getglobal("PallyPowerFramePlayer" .. i .. "Skill" .. id):Show()
                    txt = AllPallysAuras[name][id-6].rank
                    if (AllPallysAuras[name][id-6].talent + 0 > 0) then
                        txt = txt .. "+" .. AllPallysAuras[name][id-6].talent
                    end
                    getglobal("PallyPowerFramePlayer" .. i .. "Skill" .. id):SetText(txt)
                else
                    getglobal("PallyPowerFramePlayer" .. i .. "Icon" .. id):Hide()
                    getglobal("PallyPowerFramePlayer" .. i .. "Skill" .. id):Hide()
                end
            end
            for id = 0, 9 do
                if (PallyPower_Assignments[name]) then
                    getglobal("PallyPowerFramePlayer" .. i .. "Class" .. id .. "Icon"):SetTexture(
                        BlessingIcon[PallyPower_Assignments[name][id]]
                    )
                else
                    getglobal("PallyPowerFramePlayer" .. i .. "Class" .. id .. "Icon"):SetTexture(nil)
                end
            end
            if (PallyPower_AuraAssignments[name]) then
                getglobal("PallyPowerFramePlayer" .. i .. "ClassAIcon"):SetTexture(
                    AuraIcons[PallyPower_AuraAssignments[name]]
                )
            else
                getglobal("PallyPowerFramePlayer" .. i .. "ClassAIcon"):SetTexture(nil)
            end
            if (PallyPower_SealAssignments[name]) then
                getglobal("PallyPowerFramePlayer" .. i .. "ClassSIcon"):SetTexture(
                    SealIcons[PallyPower_SealAssignments[name]]
                )
            else
                getglobal("PallyPowerFramePlayer" .. i .. "ClassSIcon"):SetTexture(nil)
            end
            i = i + 1
            numPallys = numPallys + 1
        end

        local numMaxClass = 0
        local currentPlayer = 0
        local assign = PallyPower_Assignments[UnitName("player")]
        local player = UnitName("player")

        for ii = 1, PALLYPOWER_MAXCLASSES do
            currentPlayer = 0

            local fname = "PallyPowerFrameClassGroup" .. ii

            for jj = 1, PALLYPOWER_MAXPERCLASS do
                local pbnt = fname .. "PlayerButton" .. jj
                getglobal(pbnt):SetFrameStrata("BACKGROUND")
                getglobal(pbnt):SetAlpha(0)
            end    
            
            if CurrentBuffs[ii - 1] then

                for unit, stats in CurrentBuffs[ii - 1] do

                    local pbnt = fname .. "PlayerButton" .. (currentPlayer + 1) -- Index is based on 1

                    if unit then
                        local shortname = stats.name
                        if string.find(unit,"pet") then
                            getglobal(pbnt .. "Text"):SetText(shortname) --"|T132242:0|t "..shortname
                        else
                            getglobal(pbnt .. "Text"):SetText(shortname)
                        end
                        local blessing = GetNormalBlessings(player,ii - 1, shortname) --class 0 == button 1
                        if blessing ~= -1 then
                            getglobal(pbnt .. "Icon"):SetTexture(BuffIconSmall[blessing])
                        else
                            getglobal(pbnt .. "Icon"):SetTexture("")
                        end
                        if PallyPower_Tanks[shortname] and PallyPower_Tanks[shortname] == true then
                            getglobal(pbnt .. "Text"):SetTextColor(1, 0.65, 0)
                        else
                            getglobal(pbnt .. "Text"):SetTextColor(1, 1, 1)
                        end
                        getglobal(pbnt):SetFrameStrata("DIALOG")
                        getglobal(pbnt):SetAlpha(1)        
                        currentPlayer = currentPlayer + 1
                        if currentPlayer > PALLYPOWER_MAXPERCLASS then
                            currentPlayer = PALLYPOWER_MAXPERCLASS
                        end
                    else
                        getglobal(pbnt .. "Icon"):SetTexture("")
                        getglobal(pbnt):SetFrameStrata("BACKGROUND")
                        getglobal(pbnt):SetAlpha(0)
                    end

                end

                numMaxClass = math.max(numMaxClass, currentPlayer)

            end

        end           

        PallyPowerFrame:SetHeight(10 + 14 + 24 + 56 + (numPallys * 76) + 22 + (13 * numMaxClass)) -- 14 from border, 24 from Title, 56 from space for class icons, 56 per paladin, 22 for Buttons at bottom
        getglobal("PallyPowerFramePlayer1"):SetPoint("TOPLEFT", 8, -84 - 13 * numMaxClass)
		for i = 1, PALLYPOWER_MAXCLASSES do
			getglobal("PallyPowerFrameClassGroup" .. i .. "Line"):SetHeight( 2 + 13 * numMaxClass)
        end        
        getglobal("PallyPowerFrameClassGroupALine"):SetHeight( 2 + 13 * numMaxClass)
        getglobal("PallyPowerFrameClassGroupSLine"):SetHeight( 2 + 13 * numMaxClass)
        for i = 1, 12 do
            if i <= numPallys then
                getglobal("PallyPowerFramePlayer" .. i):Show()
            else
                getglobal("PallyPowerFramePlayer" .. i):Hide()
            end
        end
    end
end

function GetNormalBlessings(pname, class, tname)
    if PallyPower_NormalAssignments[pname] and PallyPower_NormalAssignments[pname][class] and PallyPower_NormalAssignments[pname][class][tname] then
		local blessing = PallyPower_NormalAssignments[pname][class][tname]
		if blessing then
			return blessing
		else
			return -1
		end
    else
        return -1
    end
end

function SetNormalBlessings(pname, class, tname, value)
	if not PallyPower_NormalAssignments[pname] then
		PallyPower_NormalAssignments[pname] = {}
	end
	if not PallyPower_NormalAssignments[pname][class] then
		PallyPower_NormalAssignments[pname][class] = {}
	end
	PallyPower_NormalAssignments[pname][class][tname] = value
end

function PallyPower_mod(a, b)
    return a - math.floor(a / b) * b
end

function PallyPower_PerformPlayerCycle(delta, pname, class)
    if PallyPower_Assignments[UnitName("player")][class] == -1 then return end
	local blessing = 0
    local player = UnitName("player")
	if not PP_IsPally then
		return
	end
	if PallyPower_NormalAssignments[player] and PallyPower_NormalAssignments[player][class] and PallyPower_NormalAssignments[player][class][pname] then
		blessing = PallyPower_NormalAssignments[player][class][pname]
    else
        blessing = -1
	end

    for test = blessing + 1, 6 do
        if PallyPower_CanBuff(player, test) and (PallyPower_NeedsBuff(class, test) or IsShiftKeyDown()) then
            blessing = test
            do
                break
            end
        end
    end

    if (blessing == 6) then
        blessing = -1
    end

    SetNormalBlessings(player, class, pname, blessing)
end

function PallyPowerPlayerButton_OnMouseWheel(btn, arg1)
    if btn then
        local _, _, class, pnum = strfind(btn:GetName(), "PallyPowerFrameClassGroup(.+)PlayerButton(.+)")
        class = tonumber(class) - 1 --class 0 == button 1
        local pname = getglobal(btn:GetName() .. "Text"):GetText()
        PallyPower_PerformPlayerCycle(arg1, pname, class)
    end
end

function PallyPower_GetRaidIdByName(name)
    -- If in a raid, look through raid roster
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local raidName = GetRaidRosterInfo(i)
            if raidName == name then
                return "raid" .. i
            end
        end
    else
        -- Not in a raid: check player and party members
        if name == UnitName("player") then
            return "player"
        end
        for i = 1, GetNumPartyMembers() do
            if UnitName("party" .. i) == name then
                return "party" .. i
            end
        end
    end
    return nil
end

function PallyPowerPlayerButton_OnClick(plbtn, mouseBtn)
    if plbtn then
        local _, _, class, pnum = strfind(plbtn:GetName(), "PallyPowerFrameClassGroup(.+)PlayerButton(.+)")
        class = tonumber(class) - 1 --class 0 == button 1
        local pname = getglobal(plbtn:GetName() .. "Text"):GetText()
        if mouseBtn == "RightButton" then
            if PallyPower_NormalAssignments[UnitName("player")] and 
               PallyPower_NormalAssignments[UnitName("player")][class] and 
               PallyPower_NormalAssignments[UnitName("player")][class][pname] then
                PallyPower_NormalAssignments[UnitName("player")][class][pname] = -1
            end
            PP_NextScan = 0.1 --PallyPower_UpdateUI()
        elseif mouseBtn == "LeftButton" then
            PallyPower_PerformPlayerCycle(nil, pname, class)
        else
            if PallyPower_Tanks[pname] and PallyPower_Tanks[pname] == true then
                PallyPower_Tanks[pname] = nil
                if pfUI ~= nil and pfUI.uf ~= nil and pfUI.uf.raid ~= nil and pfUI.uf.raid.tankrole ~= nil then
                    pfUI.uf.raid.tankrole[pname] = nil
                    pfUI.uf.raid:Show()
                end
                PallyPower_SendMessage("CLTNK "..pname)
                -- Clear raid icon when tank is unassigned
                if PallyPower_CheckRaidLeader(UnitName("player")) or UnitIsPartyLeader("player") then
                    local unitId = PallyPower_GetRaidIdByName(pname)
                    if unitId then
                        SetRaidTarget(unitId, 0) -- 0 = clear icon
                    end
                end
            else
                PallyPower_Tanks[pname] = true
                if pfUI ~= nil and pfUI.uf ~= nil and pfUI.uf.raid ~= nil and pfUI.uf.raid.tankrole ~= nil then
                    pfUI.uf.raid.tankrole[pname] = true
                    pfUI.uf.raid:Show()
                end
                PallyPower_SendMessage("TANK "..pname)
                -- Assign raid icon if not already set
                if PallyPower_CheckRaidLeader(UnitName("player")) or UnitIsPartyLeader("player") then
                    local unitId = PallyPower_GetRaidIdByName(pname)
                    if unitId and (GetRaidTargetIndex(unitId) == nil or GetRaidTargetIndex(unitId) == 0) then
                        -- Find used icons
                        local usedIcons = {}
                        for j = 1, 40 do
                            if UnitExists("raid"..j) then
                                local iconIdx = GetRaidTargetIndex("raid"..j)
                                if iconIdx and iconIdx > 0 then
                                    usedIcons[iconIdx] = true
                                end
                            end
                        end
                        -- Find first available icon (1-8)
                        local iconToSet = nil
                        for icon = 1, 8 do
                            if not usedIcons[icon] then
                                iconToSet = icon
                                break
                            end
                        end
                        if iconToSet then
                            SetRaidTarget(unitId, iconToSet)
                        end
                    end
                end
            end
        end
    end
end

function PallyPowerPlayerButton_OnLeave(plbtn)
    GameTooltip:Hide()
end

function PallyPowerPlayerButton_OnEnter(plbtn)
    if not plbtn then return end
    
    local btnName = plbtn:GetName()
    if not btnName then return end
    
    -- Parse button name: PallyPowerFrameClassGroup#PlayerButton#
    local _, _, class, pnum = string.find(btnName, "PallyPowerFrameClassGroup(.+)PlayerButton(.+)")
    if not class then return end
    
    local classIndex = tonumber(class) - 1 -- class 0 == button 1
    local playerName = getglobal(btnName .. "Text"):GetText()
    if not playerName then return end
    
    -- Get the current player's blessing assignments
    local currentPlayer = UnitName("player")
    if not currentPlayer or not PallyPower_NormalAssignments[currentPlayer] then return end
    
    local assignments = PallyPower_NormalAssignments[currentPlayer][classIndex]
    if not assignments or not assignments[playerName] then return end
    
    local blessingIndex = assignments[playerName]
    if blessingIndex >= 0 and PallyPower_BlessingID[blessingIndex] then
        local spellName = "Blessing of " .. PallyPower_BlessingID[blessingIndex]
        GameTooltip:SetOwner(plbtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(spellName, 1, 1, 1)
        GameTooltip:Show()
    end
end

function PallyPower_UpdateLayout()
    local addAura = 0
    local addHeight = 0
    local hasAura = false
    local hasSeal = false
    local namePlayer = UnitName("player")

    if PallyPower_AuraAssignments[namePlayer] and PallyPower_AuraAssignments[namePlayer] ~= -1 then
        hasAura = true
    end

    if PallyPower_SealAssignments[namePlayer] and PallyPower_SealAssignments[namePlayer] ~= -1 then
        hasSeal = true
    end

    -- Calculate which buttons should be shown
    local showRF = (PP_PerUser.showrfbutton == true and hasRighteousFury == true) and (IsPally == 1)
    local showAura = (PP_PerUser.showaurabutton == true and hasAura == true) and (IsPally == 1)
    local showSeal = (PP_PerUser.showsealbutton == true and hasSeal == true) and (IsPally == 1)
    
    -- Hide all buttons initially
    PallyPowerBuffBarRF:Hide()
    PallyPowerBuffBarAura:Hide()
    PallyPowerBuffBarSeal:Hide()
    
    -- Count visible buttons and set up positioning
    local visibleButtons = {}
    if showRF then table.insert(visibleButtons, "PallyPowerBuffBarRF") end
    if showAura then table.insert(visibleButtons, "PallyPowerBuffBarAura") end
    if showSeal then table.insert(visibleButtons, "PallyPowerBuffBarSeal") end
    
    local numVisible = table.getn(visibleButtons)
    
    if numVisible == 0 then
        -- No special buttons visible
        addAura = 0
        addHeight = 0
        getglobal("PallyPowerBuffBarBuff1"):ClearAllPoints()
        getglobal("PallyPowerBuffBarBuff1"):SetPoint("TOPLEFT",5,-28)
    else
        -- Calculate dimensions based on layout
        if PP_PerUser.horizontal == false then
            addAura = 36 * numVisible
            addHeight = 0
        else
            addAura = 100 * numVisible
            addHeight = 0
        end
        
        -- Show and position buttons
        local lastButton = nil
        for i = 1, numVisible do
            local buttonName = visibleButtons[i]
            local button = getglobal(buttonName)
            button:Show()
            button:ClearAllPoints()
            
            if i == 1 then
                -- First button
                button:SetPoint("TOPLEFT", 5, -28)
                lastButton = buttonName
            else
                -- Subsequent buttons
                if PP_PerUser.horizontal == false then
                    button:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, 0)
                else
                    button:SetPoint("TOPLEFT", lastButton, "TOPRIGHT", 0, 0)
                end
                lastButton = buttonName
            end
        end
        
        -- Position first blessing button after the last special button
        getglobal("PallyPowerBuffBarBuff1"):ClearAllPoints()
        if PP_PerUser.horizontal == false then
            getglobal("PallyPowerBuffBarBuff1"):SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, 0)
        else
            getglobal("PallyPowerBuffBarBuff1"):SetPoint("TOPLEFT", lastButton, "TOPRIGHT", 0, 0)
        end
    end

    for rest = 2, 10 do
        local btn = getglobal("PallyPowerBuffBarBuff" .. rest)
        btn:ClearAllPoints()

        if PP_PerUser.horizontal == false then
            btn:SetPoint("TOPLEFT","PallyPowerBuffBarBuff"..rest - 1,"BOTTOMLEFT",0,0)
        else
            btn:SetPoint("TOPLEFT","PallyPowerBuffBarBuff"..rest - 1,"TOPRIGHT",0,0)
        end
        btn:Hide()
    end

    return addHeight, addAura
end

function PallyPower_UpdateUI()
    if not initialized then
        PallyPower_ScanSpells()
    end

    if PP_PerUser.hideblizzaura == true then
	    if ShapeshiftBarFrame:IsVisible() then ShapeshiftBarFrame:Hide() end
    else   
        if not ShapeshiftBarFrame:IsVisible() then ShapeshiftBarFrame:Show() end
    end 
	
    -- Buff Bar
    PallyPowerBuffBar:SetScale(PP_PerUser.scalebar)
    getglobal("PallyPowerBuffBarRFBuffIcon"):SetTexture(PallyPower_RighteousFury)


    local pclass, eclass = UnitClass("player")
    local namePlayer = UnitName("player")

    if eclass == "PALADIN" then
        IsPally = 1
    end

    local addAura = 0
    local addHeight = 0

    if ((IsPally == 1) or (GetNumRaidMembers() > 0 and GetNumPartyMembers() > 0)) then
        if PP_PerUser.frameslocked == true then
            PallyPowerBuffBarResizeButton:Hide()
        else
            PallyPowerBuffBarResizeButton:Show()
        end

        addHeight, addAura = PallyPower_UpdateLayout()

        local icons_prefix
        if PP_PerUser.usehdicons == true then
            icons_prefix = "AddOns\\PallyPowerTW\\HD"
        else
            icons_prefix = "AddOns\\PallyPowerTW\\"
        end
        
        PallyPowerBuffBarRF:SetBackdropColor(0, 0, 0, PP_PerUser.transparency)
        local i
        local testUnitBuff
        
        -- Use Nampower API if available for better performance
        if PP_NampowerAPI then
            local auras = GetUnitField("player", "aura")
            if auras then
                for i = 1, table.getn(auras) do
                    local spellId = auras[i]
                    if spellId and spellId > 0 then
                        local spellName = GetSpellRecField(spellId, "name")
                        if spellName and spellName == "Righteous Fury" then
                            PallyPowerBuffBarRF:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                            break
                        end
                    end
                end
            end
        else
            -- Fallback to original method
            for i = 1,40 do 
                testUnitBuff = UnitBuff("player",i) 
                if (testUnitBuff and testUnitBuff == string.gsub(BuffIcon[9],icons_prefix,"")) then 
                    PallyPowerBuffBarRF:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                    break
                end 
            end
        end 
    
        PallyPowerBuffBarAura:SetBackdropColor(0, 0, 0, PP_PerUser.transparency)
        if PallyPower_AuraAssignments[namePlayer] then
            getglobal("PallyPowerBuffBarAuraBuffIcon"):SetTexture(AuraIcons[PallyPower_AuraAssignments[namePlayer]])
            
            -- Use Nampower API if available for better performance
            if PP_NampowerAPI then
                local auras = GetUnitField("player", "aura")
                if auras and AuraNames[PallyPower_AuraAssignments[namePlayer]] then
                    local targetAuraName = AuraNames[PallyPower_AuraAssignments[namePlayer]]
                    for i = 1, table.getn(auras) do
                        local spellId = auras[i]
                        if spellId and spellId > 0 then
                            local spellName = GetSpellRecField(spellId, "name")
                            if spellName and spellName == targetAuraName then
                                PallyPowerBuffBarAura:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                                break
                            end
                        end
                    end
                end
            else
                -- Fallback to original method
                for i=1,40 do 
                    testUnitBuff = UnitBuff("player",i) 
                    if (testUnitBuff and PallyPower_AuraAssignments[namePlayer] ~= nil and 
                        AuraIcons[PallyPower_AuraAssignments[namePlayer]] ~= nil and
                        testUnitBuff == string.gsub(AuraIcons[PallyPower_AuraAssignments[namePlayer]],icons_prefix,"")) then 
                        PallyPowerBuffBarAura:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                        break
                    end 
                end
            end
        else
            getglobal("PallyPowerBuffBarAuraBuffIcon"):SetTexture(nil)
        end

        PallyPowerBuffBarSeal:SetBackdropColor(0, 0, 0, PP_PerUser.transparency)
        if PallyPower_SealAssignments[namePlayer] then
            getglobal("PallyPowerBuffBarSealBuffIcon"):SetTexture(SealIcons[PallyPower_SealAssignments[namePlayer]])
            
            -- Use Nampower API if available for better performance
            if PP_NampowerAPI then
                local auras = GetUnitField("player", "aura")
                if auras and SealNames[PallyPower_SealAssignments[namePlayer]] then
                    local targetSealName = SealNames[PallyPower_SealAssignments[namePlayer]]
                    for i = 1, table.getn(auras) do
                        local spellId = auras[i]
                        if spellId and spellId > 0 then
                            local spellName = GetSpellRecField(spellId, "name")
                            if spellName and spellName == targetSealName then
                                PallyPowerBuffBarSeal:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                                break
                            end
                        end
                    end
                end
            else
                -- Fallback to original method
                for i=1,40 do 
                    testUnitBuff = UnitBuff("player",i) 
                    if (testUnitBuff and PallyPower_SealAssignments[namePlayer] ~= nil and 
                        SealIcons[PallyPower_SealAssignments[namePlayer]] ~= nil and
                        testUnitBuff == string.gsub(SealIcons[PallyPower_SealAssignments[namePlayer]],icons_prefix,"")) then 
                        PallyPowerBuffBarSeal:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                        break
                    end 
                end
            end
        else
            getglobal("PallyPowerBuffBarSealBuffIcon"):SetTexture(nil)
        end

        PallyPowerBuffBar:Show()
        PallyPowerBuffBarTitleText:SetText(format(PallyPower_BuffBarTitle, PP_Symbols))
        BuffNum = 1
        if PallyPower_Assignments[namePlayer] then
            local assign = PallyPower_Assignments[namePlayer]
            for class = 0, 9 do
                if (assign[class] and assign[class] ~= -1) then
                    getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "ClassIcon"):SetTexture(
                        PallyPower_ClassTexture[class]
                    )
                    getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "BuffIcon"):SetTexture(BlessingIcon[assign[class]])

                    local btn = getglobal("PallyPowerBuffBarBuff" .. BuffNum)
                    btn.classID = class
                    btn.buffID = assign[class]
                    btn.need = {}
                    btn.have = {}
                    btn.range = {}
                    btn.dead = {}
                    -- Calculate number of people who need buff.
                    local nneed = 0
                    local nhave = 0
                    local ndead = 0
                    local naway = 0
                    if CurrentBuffs[class] then
                        for member, stats in CurrentBuffs[class] do
                            if stats["visible"] then
                                local hasBuffs = false
                                if GetNormalBlessings(namePlayer,class, UnitName(member)) ~= -1 then
                                    if stats[GetNormalBlessings(namePlayer,class, UnitName(member))] then
                                        hasBuffs = true
                                    end
                                elseif stats[assign[class]] then
                                    hasBuffs = true
                                end
                                
                                if not hasBuffs then
                                    if UnitIsDeadOrGhost(member) then
                                        ndead = ndead + 1
                                        tinsert(btn.dead, stats["name"])
                                    else
                                        -- If Salvation is assigned, user is tank, and no individual blessings, do not count against nneed 
                                        -- ( So the buffbar button stays green even with tank missing Salvation)
                                        if not (assign[class] == 2 and PallyPower_Tanks[stats["name"]] == true and GetNormalBlessings(namePlayer, class, UnitName(member)) == -1) then
                                            nneed = nneed + 1
                                            tinsert(btn.need, stats["name"])
                                        end
                                    end
                                else
                                    tinsert(btn.have, stats["name"])
                                    nhave = nhave + 1
                                end
                            else
                                tinsert(btn.range, stats["name"])
                                nhave = nhave + 1
                                naway = naway + 1
                            end
                        end
                    end

                    --Cleanup timers if no Have
                    if nhave == 0 then
                        LastCast[assign[btn.classID] .. btn.classID] = nil
                        if CurrentBuffs[btn.classID] then
                            for unit, stats in CurrentBuffs[btn.classID] do
                                if LastCastPlayer[stats.name] then
                                    LastCastPlayer[stats.name] = nil
                                end
                            end
                        end
                    end

                    local individual_time = PALLYPOWER_GREATERBLESSINGDURATION    
                    if CurrentBuffs[btn.classID] then
                        for unit, stats in CurrentBuffs[btn.classID] do
                            if LastCastPlayer[stats.name] and LastCastPlayer[stats.name] < individual_time then
                                individual_time = LastCastPlayer[stats.name]
                            end 
                        end    
                    end
                    if individual_time ~= PALLYPOWER_GREATERBLESSINGDURATION then
                        getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "Time2"):SetText(PallyPower_FormatTime(individual_time))
                    else
                        getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "Time2"):SetText("")
                    end    

                    if ndead > 0 then
                        getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "Text"):SetText(nneed .. " (" .. ndead .. ")")
                    else
                        getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "Text"):SetText(nneed)
                    end
                    getglobal("PallyPowerBuffBarBuff" .. BuffNum .. "Time"):SetText(
                        PallyPower_FormatTime(LastCast[assign[class] .. class])
                    )
                    if not (nneed > 0 or nhave > 0 or ndead > 0) then
                    else
                        BuffNum = BuffNum + 1
                        if (nhave == 0) then
                            btn:SetBackdropColor(1, 0, 0, PP_PerUser.transparency)
                        elseif (nneed > 0 or ndead > 0) then
                            btn:SetBackdropColor(1, 1, 0.5, PP_PerUser.transparency)
                        elseif (nneed == 0 and ndead == 0 and naway == 0) then
                            btn:SetBackdropColor(0, 1, 0, PP_PerUser.transparency)
                        else
                            btn:SetBackdropColor(0, 0, 0, PP_PerUser.transparency)
                        end
                        btn:Show()
                    end
                end
            end
        end
        for rest = BuffNum, 10 do
            local btn = getglobal("PallyPowerBuffBarBuff" .. rest)
            btn.classID = {}
            btn.buffID = {}
            btn.need = {}
            btn.have = {}
            btn.range = {}
            btn.dead = {}
            btn:Hide()
        end
        if PP_PerUser.horizontal == false then
            PallyPowerBuffBar:SetHeight(32 + (36 * (BuffNum - 1)) + addHeight + addAura)
            PallyPowerBuffBar:SetWidth(110)
        else
            PallyPowerBuffBar:SetWidth((100 * (BuffNum - 1)) + addHeight + addAura + 10)
            PallyPowerBuffBar:SetHeight(68)
        end
    else
        PallyPowerBuffBar:Hide()
    end
end

function PallyPower_ScanSpells()
    local RankInfo = {}
    local AuraRankInfo = {}
    local SealRankInfo = {}
    local i = 1

    local icons_prefix
    if PP_PerUser.usehdicons == true then
        icons_prefix = "AddOns\\PallyPowerTW\\HD"
    else
        icons_prefix = "AddOns\\PallyPowerTW\\"
    end

    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        local spellTexture = GetSpellTexture(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end

        if spellTexture == string.gsub(BuffIcon[9],icons_prefix,"") then
            hasRighteousFury = true
            nameRighteousFury = spellName
        end

        if spellTexture == PallyPower_DivineItervention then
            if GetSpellCooldown(i, BOOKTYPE_SPELL) == 0 then
                RankInfo["DivineIntervention"] = true
            end
        end
        if spellTexture == PallyPower_LayOnHandsIcon then
            if GetSpellCooldown(i, BOOKTYPE_SPELL) == 0 then
                RankInfo["LayOnHands"] = true
            end
        end

        if not spellRank or spellRank == "" then
            spellRank = PallyPower_Rank1
        end

        local _, _, aura = string.find(spellName, PallyPower_AuraSpellSearch)
        if aura then
            for id, name in PallyPower_AuraID do
                if (name == aura) then
                    local _, _, rank = string.find(spellRank, PallyPower_RankSearch)
                    if (AuraRankInfo[id] and spellRank < AuraRankInfo[id]["rank"]) then
                    else
                        AuraRankInfo[id] = {}
                        AuraRankInfo[id]["rank"] = rank
                        AuraRankInfo[id]["id"] = i
                        AuraRankInfo[id]["name"] = name
                        AuraRankInfo[id]["talent"] = 0
                    end
                end
            end
        end

        local _, _, seal = string.find(spellName, PallyPower_SealSpellSearch)
        if seal then
            for id, name in PallyPower_SealID do
                if (name == seal) then
                    local _, _, rank = string.find(spellRank, PallyPower_RankSearch)
                    if (SealRankInfo[id] and spellRank < SealRankInfo[id]["rank"]) then
                    else
                        SealRankInfo[id] = {}
                        SealRankInfo[id]["rank"] = rank
                        SealRankInfo[id]["id"] = i
                        SealRankInfo[id]["name"] = name
                        SealRankInfo[id]["talent"] = 0
                    end
                end
            end
        end

        local _, _, bless = string.find(spellName, PallyPower_BlessingSpellSearch)
        if bless then
            local greaterBless, _ = string.find(spellName, PallyPower_Greater)
            for id, name in PallyPower_BlessingID do
                if ((name == bless) and (not greaterBless)) then
                    local _, _, rank = string.find(spellRank, PallyPower_RankSearch)
                    if (RankInfo[id] and spellRank < RankInfo[id]["rank"]) then
                    else
                        RankInfo[id] = {}
                        RankInfo[id]["rank"] = rank
                        RankInfo[id]["id"] = i
                        RankInfo[id]["idsmall"] = i
                        RankInfo[id]["name"] = name
                        RankInfo[id]["talent"] = 0
                    end
                end
            end
        end

        if (RegularBlessings == false) then
            local _, _, bless = string.find(spellName, PallyPower_BlessingSpellSearch)
            if bless then
                local greaterBless, _ = string.find(spellName, PallyPower_Greater)
                for id, name in PallyPower_BlessingID do
                    if ((name == bless) and (greaterBless)) then
                        local _, _, rank = string.find(spellRank, PallyPower_RankSearch)
                        if (RankInfo[id] and spellRank < RankInfo[id]["rank"]) then
                        else
                            RankInfo[id]["id"] = i
                            RankInfo[id]["name"] = name
                        end
                    end
                end
            end
        end
        i = i + 1
    end

    --Improved Blessings
    nameTalent, icon, iconx, icony, currRank, maxRank = GetTalentInfo(3, 1);
    if currRank > 0 then
        for id = 0, 1 do -- wisdom & might
            if (RankInfo[id]) then
                RankInfo[id]["talent"] = currRank
            end
        end
    end
    --Improved Concentration Aura
    nameTalent, icon, iconx, icony, currRank, maxRank = GetTalentInfo(1, 10);
    if currRank > 0 then
        for id, name in pairs(PallyPower_AuraID) do
            if (id == 2) then
                if AuraRankInfo and AuraRankInfo[id] and AuraRankInfo[id]["rank"] then
                    AuraRankInfo[id]["talent"] = currRank
                end
            end
        end
    end
    --Improved Devotion Aura
    nameTalent, icon, iconx, icony, currRank, maxRank = GetTalentInfo(2, 1);
    if currRank > 0 then
        for id, name in pairs(PallyPower_AuraID) do
            if (id == 0) then
                if AuraRankInfo and AuraRankInfo[id] and AuraRankInfo[id]["rank"] then
                    AuraRankInfo[id]["talent"] = currRank
                end
            end
        end
    end
    --Improved Retribution Aura
    nameTalent, icon, iconx, icony, currRank, maxRank = GetTalentInfo(3, 6);
    if currRank > 0 then
        for id, name in pairs(PallyPower_AuraID) do
            if (id == 1) then
                if AuraRankInfo and AuraRankInfo[id] and AuraRankInfo[id]["rank"] then
                    AuraRankInfo[id]["talent"] = currRank
                end
            end
        end
    end

    local _, class = UnitClass("player")
    if class == "PALADIN" then
        AllPallys[UnitName("player")] = RankInfo
        AllPallysAuras[UnitName("player")] = AuraRankInfo
        AllPallysSeals[UnitName("player")] = SealRankInfo
        PP_IsPally = true
        if initialized then
            PallyPower_SendSelf()
        end
    else
        PP_Debug("I'm not a paladin?? " .. class)
        PP_IsPally = nil
        initialized = true
    end

    nameTalent, icon, iconx, icony, currRank, maxRank = GetTalentInfo(3, 1);
    if nameTalent ~= nil then 
        initialized = true
    end

    PallyPower_ScanInventory()
    return RankInfo
end

function PallyPower_Refresh()
    AllPallys = {}       
    AllPallysAuras = {} 
    AllPallysSeals = {} 

    --[[for name in PallyPower_Assignments do
        if (name ~= UnitName("player")) then
            PallyPower_Assignments[name] = nil
        end
    end
    for name in PallyPower_AuraAssignments do
        if (name ~= UnitName("player")) then
            PallyPower_AuraAssignments[name] = nil
        end
    end]]

    local _, class = UnitClass("player")
    if class == "PALADIN" then
        PallyPower_ScanSpells()
        PallyPower_SendSelf()
    end
    PallyPower_SendVersion()
    PallyPower_RequestSend()
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_Clear(fromupdate, who)
    if not who then
        who = UnitName("player")
    end
    for name, skills in PallyPower_Assignments do
        if (PallyPower_CheckRaidLeader(who) or PP_PerUser.freeassign or name == who) then
            for class, id in PallyPower_Assignments[name] do
                PallyPower_Assignments[name][class] = -1
            end
            PallyPower_NormalAssignments = {}
            PallyPower_AuraAssignments = {}
            PallyPower_Tanks = {}
        end
    end
    PP_NextScan = 0 --PallyPower_UpdateUI()
    if not fromupdate then
        PallyPower_SendMessage("CLEAR")
    end
end

function PallyPower_RequestSend()
    PallyPower_SendMessage("REQ")
end

function PallyPower_SendSelf()
    if not initialized then
        PallyPower_ScanSpells()
    end
    if not AllPallys[UnitName("player")] and not AllPallysAuras[UnitName("player")] then
        return
    end
    msg = "SELF "
    local RankInfo = AllPallys[UnitName("player")]
    local i
    for id = 0, 5 do
        if (not RankInfo[id]) then
            msg = msg .. "nn"
        else
            msg = msg .. RankInfo[id]["rank"]
            msg = msg .. RankInfo[id]["talent"]
        end
    end
    msg = msg .. "@"
    for id = 0, 9 do
        if
            (not PallyPower_Assignments[UnitName("player")]) or (not PallyPower_Assignments[UnitName("player")][id]) or
                PallyPower_Assignments[UnitName("player")][id] == -1
         then
            msg = msg .. "n"
        else
            msg = msg .. PallyPower_Assignments[UnitName("player")][id]
        end
    end
    PallyPower_SendMessage(msg)
    PallyPower_SendMessage("SYMCOUNT " .. PP_Symbols ) 
    local cooldownsString = ""
    if RankInfo["DivineIntervention"] and RankInfo["DivineIntervention"] == true then
        cooldownsString = cooldownsString .. "1"
    else
        cooldownsString = cooldownsString .. "0"
    end
    if RankInfo["LayOnHands"] and RankInfo["LayOnHands"] == true then
        cooldownsString = cooldownsString .. "1"
    else
        cooldownsString = cooldownsString .. "0"
    end
    PallyPower_SendMessage("COOLDOWNS " .. cooldownsString)
    if PP_PerUser.freeassign == true then
        PallyPower_SendMessage("FREEASSIGN YES")
    else
        PallyPower_SendMessage("FREEASSIGN NO")
    end
    msg = "ASELF "
    local RankInfo = AllPallysAuras[UnitName("player")]
    local i
    for id = 0, 6 do
        if (not RankInfo[id]) then
            msg = msg .. "nn"
        else
            msg = msg .. RankInfo[id]["rank"]
            msg = msg .. RankInfo[id]["talent"]
        end
    end
    msg = msg .. "@"
    if
        (not PallyPower_AuraAssignments[UnitName("player")]) or 
            PallyPower_AuraAssignments[UnitName("player")] == -1
        then
        msg = msg .. "n"
    else
        msg = msg .. PallyPower_AuraAssignments[UnitName("player")]
    end
    PallyPower_SendMessage(msg)
    
    -- Send seal data
    msg = "SSELF "
    local SealRankInfo = AllPallysSeals[UnitName("player")]
    if SealRankInfo then
        for id = 0, 5 do
            if (not SealRankInfo[id]) then
                msg = msg .. "nn"
            else
                msg = msg .. SealRankInfo[id]["rank"]
                msg = msg .. SealRankInfo[id]["talent"]
            end
        end
        msg = msg .. "@"
        if
            (not PallyPower_SealAssignments[UnitName("player")]) or 
                PallyPower_SealAssignments[UnitName("player")] == -1
            then
            msg = msg .. "n"
        else
            msg = msg .. PallyPower_SealAssignments[UnitName("player")]
        end
        PallyPower_SendMessage(msg)
    end
    
    for name, _ in pairs(PallyPower_Tanks) do
        msg = "TANK " .. name
        PallyPower_SendMessage(msg)
    end    
end

function PallyPower_SendVersion()
    PallyPower_SendMessage("VERSION " .. PallyPower_Version)
end

function PallyPower_SendMessage(msg)
    if GetNumRaidMembers() == 0 then
        SendAddonMessage(PP_PREFIX, msg, "PARTY", UnitName("player"))
    else
        SendAddonMessage(PP_PREFIX, msg, "RAID", UnitName("player"))
    end
end

function PallyPower_ParseMessage(sender, msg)
    local nameplayer = UnitName("player")
    if not (sender == nameplayer) then
        if msg == "REQ" then
            PallyPower_SendSelf()
        end
        if string.find(msg, "^SELF") then
            PallyPower_Assignments[sender] = {}
            AllPallys[sender] = {}
            local _, _, numbers, assign = string.find(msg, "SELF ([0-9n]*)@?([0-9n]*)")
            for id = 0, 5 do
                rank = string.sub(numbers, id * 2 + 1, id * 2 + 1)
                talent = string.sub(numbers, id * 2 + 2, id * 2 + 2)
                if not (rank == "n") then
                    AllPallys[sender][id] = {}
                    AllPallys[sender][id]["rank"] = rank
                    AllPallys[sender][id]["talent"] = talent
                end
            end
            if assign then
                for id = 0, 9 do
                    tmp = string.sub(assign, id + 1, id + 1)
                    if (tmp == "n" or tmp == "") then
                        tmp = -1
                    end
                    PallyPower_Assignments[sender][id] = tmp + 0
                end
            end
            PP_NextScan = 0.1 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^ASELF") then
            PallyPower_AuraAssignments[sender] = {}
            AllPallysAuras[sender] = {}
            local _, _, numbers, assign = string.find(msg, "ASELF ([0-9n]*)@?([0-9n]*)")
            for id = 0, 6 do
                rank = string.sub(numbers, id * 2 + 1, id * 2 + 1)
                talent = string.sub(numbers, id * 2 + 2, id * 2 + 2)
                if not (rank == "n") then
                    AllPallysAuras[sender][id] = {}
                    if PallyPower_AuraID[id] then
                        AllPallysAuras[sender][id]["name"] = PallyPower_AuraID[id]
                        AllPallysAuras[sender][id]["rank"] = rank
                        AllPallysAuras[sender][id]["talent"] = talent
                    end
                end
            end
            if assign then
                tmp = string.sub(assign, 1, 1)
                if (tmp == "n" or tmp == "") then
                    tmp = -1
                end
                PallyPower_AuraAssignments[sender] = tmp + 0
            end
            PP_NextScan = 0 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^SSELF") then
            PallyPower_SealAssignments[sender] = -1
            AllPallysSeals[sender] = {}
            local _, _, numbers, assign = string.find(msg, "SSELF ([0-9n]*)@?([0-9n]*)")
            for id = 0, 5 do
                rank = string.sub(numbers, id * 2 + 1, id * 2 + 1)
                talent = string.sub(numbers, id * 2 + 2, id * 2 + 2)
                if not (rank == "n") then
                    AllPallysSeals[sender][id] = {}
                    if PallyPower_SealID[id] then
                        AllPallysSeals[sender][id]["name"] = PallyPower_SealID[id]
                        AllPallysSeals[sender][id]["rank"] = rank
                        AllPallysSeals[sender][id]["talent"] = talent
                    end
                end
            end
            if assign then
                tmp = string.sub(assign, 1, 1)
                if (tmp == "n" or tmp == "") then
                    tmp = -1
                end
                PallyPower_SealAssignments[sender] = tmp + 0
            end
            PP_NextScan = 0 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^ASSIGN") then
           local  _, _, name, class, skill = string.find(msg, "^ASSIGN (.*) (.*) (.*)")
            if (not (name == sender)) and (not (PallyPower_CheckRaidLeader(sender) or PP_PerUser.freeassign)) then
                return false
            end
            if (not PallyPower_Assignments[name]) then
                PallyPower_Assignments[name] = {}
            end
            class = class + 0
            skill = skill + 0
            PallyPower_Assignments[name][class] = skill
            if name == nameplayer then
                if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][class]) then
                    for lname in pairs(PallyPower_NormalAssignments[nameplayer][class]) do
                        if skill == -1 or PallyPower_NormalAssignments[nameplayer][class][lname] == skill then
                            PallyPower_NormalAssignments[nameplayer][class][lname] = -1
                        end
                    end                    
                end
            end
            PP_NextScan = 0.1 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^AASSIGN") then
            local _, _, name, skill = string.find(msg, "^AASSIGN (.*) (.*)")
            if (not (name == sender)) and (not (PallyPower_CheckRaidLeader(sender) or PP_PerUser.freeassign)) then
                return false
            end
            if (not PallyPower_AuraAssignments[name]) then
                PallyPower_AuraAssignments[name] = {}
            end
            skill = skill + 0
            PallyPower_AuraAssignments[name] = skill
            PP_NextScan = 0 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^SASSIGN") then
            local _, _, name, skill = string.find(msg, "^SASSIGN (.*) (.*)")
            if (not (name == sender)) and (not (PallyPower_CheckRaidLeader(sender) or PP_PerUser.freeassign)) then
                return false
            end
            if (not PallyPower_SealAssignments[name]) then
                PallyPower_SealAssignments[name] = -1
            end
            skill = skill + 0
            PallyPower_SealAssignments[name] = skill
            PP_NextScan = 0 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^MASSIGN") then
            local _, _, name, skill = string.find(msg, "^MASSIGN (.*) (.*)")
            if (not (name == sender)) and (not (PallyPower_CheckRaidLeader(sender) or PP_PerUser.freeassign)) then
                return false
            end
            if (not PallyPower_Assignments[name]) then
                PallyPower_Assignments[name] = {}
            end
            skill = skill + 0
            for class = 0, 9 do
                PallyPower_Assignments[name][class] = skill
                if name == nameplayer then
                    if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][class]) then
                        for lname in pairs(PallyPower_NormalAssignments[nameplayer][class]) do
                            if skill == -1 or PallyPower_NormalAssignments[nameplayer][class][lname] == skill then
                                PallyPower_NormalAssignments[nameplayer][class][lname] = -1
                            end
                        end                    
                    end
                end
            end
            PP_NextScan = 0.1 --PallyPower_UpdateUI()
        end
        if string.find(msg, "^SYMCOUNT ([0-9]*)") then
            local _, _, count = string.find(msg, "^SYMCOUNT ([0-9]*)")
            if AllPallys[sender] then
                if count == nil or count == "0" then
                    AllPallys[sender]["symbols"] = 0
                else
                    AllPallys[sender]["symbols"] = count
                end
            else
                PallyPower_SendMessage("REQ")
            end
        end
	    if strfind(msg, "^COOLDOWNS ([0-9]*)") then
            local _, _, cooldowns = string.find(msg, "^COOLDOWNS ([0-9]*)")
            local diAvailable = string.sub(cooldowns, 1, 1)
            local lhAvailable = string.sub(cooldowns, 2, 2)
            AllPallys[sender]["DivineIntervention"] = (diAvailable == "1")
            AllPallys[sender]["LayOnHands"] = (lhAvailable == "1")
        end
        if string.find(msg, "FREEASSIGN YES") then
            if AllPallys[sender] then
                AllPallys[sender]["freeassign"] = true
            else
                PallyPower_SendMessage("REQ")
            end
        end
        if string.find(msg, "FREEASSIGN NO") then
            if AllPallys[sender] then
                AllPallys[sender]["freeassign"] = false
            else
                PallyPower_SendMessage("REQ")
            end
        end
        if string.find(msg, "^TANK") then
            local _, _, name = string.find(msg, "^TANK (.*)")
            if (not (name == sender)) and (not (PallyPower_CheckRaidLeader(sender) or PP_PerUser.freeassign)) then
                return false
            end
            PallyPower_Tanks[name] = true
            if pfUI ~= nil and pfUI.uf ~= nil and pfUI.uf.raid ~= nil and pfUI.uf.raid.tankrole ~= nil then
                pfUI.uf.raid.tankrole[name] = true
				pfUI.uf.raid:Show()
            end
        end
        if string.find(msg, "^CLTNK") then
            local _, _, name = string.find(msg, "^CLTNK (.*)")
            if (not (name == sender)) and (not (PallyPower_CheckRaidLeader(sender) or PP_PerUser.freeassign)) then
                return false
            end
            if PallyPower_Tanks[name] then
                PallyPower_Tanks[name] = nil
                if pfUI ~= nil and pfUI.uf ~= nil and pfUI.uf.raid ~= nil and pfUI.uf.raid.tankrole ~= nil then
                    pfUI.uf.raid.tankrole[name] = nil
                    pfUI.uf.raid:Show()					
                end
            end
        end
        if string.find(msg, "^CLEAR") then
            PallyPower_Clear(true, sender)
        end
        if string.find(msg, "^VERSION") then
            local  _, _, msgVer = string.find(msg, "^VERSION (.*)")
            if msgVer > PallyPower_Version and not(versionBumpDisplayed) then
                versionBumpDisplayed = true
                DEFAULT_CHAT_FRAME:AddMessage(PALLYPOWER_MESSAGE_NEWVERSION.." ("..msgVer..")")
            end
        end
    end
end

function PallyPower_ResetPosition()
    if PP_PerUser.frameslocked == false then
        local frame = PallyPowerBuffBar
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", 0, 0)
            DEFAULT_CHAT_FRAME:AddMessage(PALLYPOWER_MESSAGE_BB_CENTERED)
        else
            DEFAULT_CHAT_FRAME:AddMessage(PALLYPOWER_MESSAGE_BB_NOTFOUND)
        end
    end
end

function PallyPower_ShowCredits()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(PallyPower_Credits1, 1, 1, 1)
    GameTooltip:AddLine(PallyPower_Credits2, 1, 1, 1)
    GameTooltip:AddLine(PallyPower_Credits3)
    GameTooltip:AddLine(PallyPower_Credits4, 0, 1, 0)
    GameTooltip:AddLine(PallyPower_Credits5)
    GameTooltip:AddLine(tostring(PallyPower_ShowMemoryUsage()) .. "MB")
    GameTooltip:Show()
end

function PallyPower_ShowAuras(btn)
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    _, _, pnum, _ = string.find(btn:GetName(), "PallyPowerFramePlayer(.+)Class")
    pname = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
    local auras = AllPallysAuras[pname]
    if auras then
        GameTooltip:SetText(pname..PallyPower_Auras, 1, 1, 1)
        for i = 3, 6 do
            if auras[i] then
                local strAura = auras[i].name.." "..auras[i].rank.."+"..auras[i].talent            
                GameTooltip:AddLine(strAura)
            end
        end    
        GameTooltip:Show()
    end
end

function PallyPower_ShowSeals(btn)
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    _, _, pnum, _ = string.find(btn:GetName(), "PallyPowerFramePlayer(.+)Class")
    pname = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
    local seals = AllPallysSeals[pname]
    if seals then
        GameTooltip:SetText(pname..PallyPower_Seals, 1, 1, 1)
        for i = 0, 5 do
            if seals[i] then
                local strSeal = PallyPower_SealSpellPrefix..seals[i].name.." "..seals[i].rank
                GameTooltip:AddLine(strSeal)
            end
        end    
        GameTooltip:Show()
    end
end


function PallyPowerFrame_MouseDown(arg1)
    if (((not PallyPowerFrame.isLocked) or (PallyPowerFrame.isLocked == 0)) and (arg1 == "LeftButton" and (PP_PerUser.frameslocked == false))) then
        PallyPowerFrame:StartMoving()
        PallyPowerFrame.isMoving = true
    end
end

function PallyPowerFrame_MouseUp()
    if (PallyPowerFrame.isMoving) then
        PallyPowerFrame:StopMovingOrSizing()
        PallyPowerFrame.isMoving = false
    end
end

function PallyPowerBuffBar_MouseDown(arg1)
    if
        (((not PallyPowerBuffBar.isLocked) or (PallyPowerBuffBar.isLocked == 0)) and
            ((arg1 == "LeftButton") or (arg1 == "RightButton")) and  (PP_PerUser.frameslocked == false))
     then
        PallyPowerBuffBar:StartMoving()
        PallyPowerBuffBar.isMoving = true
        PallyPowerBuffBar.startPosX = PallyPowerBuffBar:GetLeft()
        PallyPowerBuffBar.startPosY = PallyPowerBuffBar:GetTop()
    end
end

function PallyPowerBuffBar_MouseUp()
    if (PallyPowerBuffBar.isMoving) then
        PallyPowerBuffBar:StopMovingOrSizing()
        PallyPowerBuffBar.isMoving = false
    end
    if PP_PerUser.frameslocked == false then
        if
            abs(PallyPowerBuffBar.startPosX - PallyPowerBuffBar:GetLeft()) < 2 and
                abs(PallyPowerBuffBar.startPosY - PallyPowerBuffBar:GetTop()) < 2
        then
            PallyPowerFrame:Show()
            PP_NextScan = 0 --PallyPower_UpdateUI()
        end
    else
        PallyPowerFrame:Show()
        PP_NextScan = 0 --PallyPower_UpdateUI()
    end
end

function PallyPowerGridButton_OnLoad(btn)
end

function PallyPowerGridButton_OnClick(btn, mouseBtn)
    local nameplayer = UnitName("player")
    local _, _, pnum, class = string.find(btn:GetName(), "PallyPowerFramePlayer(.+)Class(.+)")
    if class == "A" then class = 10 end
    if class == "S" then class = 11 end
    pnum = pnum + 0
    class = class + 0
    pname = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
    if not PallyPower_CanControl(pname) then
        return false
    end

    if (mouseBtn == "RightButton") then
        if class ~= PALLYPOWER_AURA_CLASS and class ~= PALLYPOWER_SEAL_CLASS then
            PallyPower_Assignments[pname][class] = -1
            if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][class]) then
                for lname in pairs(PallyPower_NormalAssignments[nameplayer][class]) do
                    PallyPower_NormalAssignments[nameplayer][class][lname] = -1
                end                    
            end
            PP_NextScan = 0 --PallyPower_UpdateUI()
            PallyPower_SendMessage("ASSIGN " .. pname .. " " .. class .. " -1")
        elseif class == PALLYPOWER_AURA_CLASS then
            PallyPower_AuraAssignments[pname] = -1
            PP_NextScan = 0 --PallyPower_UpdateUI()
            PallyPower_SendMessage("AASSIGN " .. pname .. " " .. "-1")
        elseif class == PALLYPOWER_SEAL_CLASS then
            PallyPower_SealAssignments[pname] = -1
            PP_NextScan = 0 --PallyPower_UpdateUI()
            PallyPower_SendMessage("SASSIGN " .. pname .. " " .. "-1")
        end
    else
        PallyPower_PerformCycle(pname, class, false)
    end
end

function PallyPowerGridButton_OnLeave(btn)
    GameTooltip:Hide()
end

function PallyPowerGridButton_OnEnter(btn)
    local btnName = btn:GetName()
    if not btnName then return end
    
    -- Parse button name: PallyPowerFramePlayer#Class# or PallyPowerFramePlayer#ClassA/S
    local _, _, pnum, class = string.find(btnName, "PallyPowerFramePlayer(.+)Class(.+)")
    if not class then return end
    
    local spellName = nil
    
    -- Check if it's an Aura assignment (ClassA)
    if class == "A" then
        -- Get the paladin name from the row
        local pallyName = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
        if pallyName and PallyPower_AuraAssignments[pallyName] then
            local auraIndex = PallyPower_AuraAssignments[pallyName]
            if auraIndex >= 0 and PallyPower_AuraID[auraIndex] then
                spellName = PallyPower_AuraID[auraIndex] .. " Aura"
            end
        end
    -- Check if it's a Seal assignment (ClassS)
    elseif class == "S" then
        -- Get the paladin name from the row
        local pallyName = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
        if pallyName and PallyPower_SealAssignments[pallyName] then
            local sealIndex = PallyPower_SealAssignments[pallyName]
            if sealIndex >= 0 and PallyPower_SealID[sealIndex] then
                spellName = "Seal of " .. PallyPower_SealID[sealIndex]
            end
        end
    -- It's a Blessing assignment (Class0-9)
    else
        local classIndex = tonumber(class)
        if classIndex then
            -- Get the paladin name from the row
            local pallyName = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
            if pallyName and PallyPower_Assignments[pallyName] and PallyPower_Assignments[pallyName][classIndex] then
                local blessingIndex = PallyPower_Assignments[pallyName][classIndex]
                if blessingIndex >= 0 and PallyPower_BlessingID[blessingIndex] then
                    spellName = "Blessing of " .. PallyPower_BlessingID[blessingIndex]
                end
            end
        end
    end
    
    -- Show tooltip if we found a spell name
    if spellName then
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(spellName, 1, 1, 1)
        GameTooltip:Show()
    end
end

function PallyPower_PerformAuraCycleBackwards(name, skipempty)
    local shift = IsShiftKeyDown()
    if not PallyPower_AuraAssignments[name] then
        cur = 7
    else
        cur = PallyPower_AuraAssignments[name]
        if skipempty == false then
            if cur == -1 then
                cur = 7
            end
        else
            if cur == 0 then
                cur = 7
            end
        end
    end

    local stoploop = -1

    if skipempty == false then
        PallyPower_AuraAssignments[name] = -1
        stoploop = -1
    else
        PallyPower_AuraAssignments[name] = 0
        stoploop = 0
    end

    for test = cur - 1, stoploop, -1 do
        cur = test
        if PallyPower_AuraCanBuff(name, test) and ( PallyPower_AuraNeedsBuff(test) or shift) then
            do
                break
            end
        end
    end

    PallyPower_AuraAssignments[name] = cur
    PallyPower_SendMessage("AASSIGN " .. name .. " "  .. cur)

    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_PerformAuraCycle(name, skipempty)
    local shift = IsShiftKeyDown()
    if not PallyPower_AuraAssignments[name] then
        if skipempty == false then
            cur = -1
        else
            cur = 0
        end
    else
        cur = PallyPower_AuraAssignments[name]
    end
    PallyPower_AuraAssignments[name] = -1
    for test = cur + 1, 7 do
        if PallyPower_AuraCanBuff(name, test) and ( PallyPower_AuraNeedsBuff(test) or shift)  then
            cur = test
            do
                break
            end
        end
    end

    if (cur == 7) then
        if skipempty == false then
            cur = -1
        else
            cur = 0
        end
    end

    PallyPower_AuraAssignments[name] = cur
    PallyPower_SendMessage("AASSIGN " .. name .. " " .. cur)

    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_PerformSealCycleBackwards(name, skipempty)
    local shift = IsShiftKeyDown()
    if not PallyPower_SealAssignments[name] then
        cur = 6
    else
        cur = PallyPower_SealAssignments[name]
        if skipempty == false then
            if cur == -1 then
                cur = 6
            end
        else
            if cur == 0 then
                cur = 6
            end
        end
    end

    local stoploop = -1

    if skipempty == false then
        PallyPower_SealAssignments[name] = -1
        stoploop = -1
    else
        PallyPower_SealAssignments[name] = 0
        stoploop = 0
    end

    for test = cur - 1, stoploop, -1 do
        cur = test
        if PallyPower_SealCanBuff(name, test) and ( PallyPower_SealNeedsBuff(test) or shift) then
            do
                break
            end
        end
    end

    PallyPower_SealAssignments[name] = cur
    PallyPower_SendMessage("SASSIGN " .. name .. " "  .. cur)

    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_PerformSealCycle(name, skipempty)
    local shift = IsShiftKeyDown()
    if not PallyPower_SealAssignments[name] then
        if skipempty == false then
            cur = -1
        else
            cur = 0
        end
    else
        cur = PallyPower_SealAssignments[name]
    end
    PallyPower_SealAssignments[name] = -1
    for test = cur + 1, 6 do
        if PallyPower_SealCanBuff(name, test) and ( PallyPower_SealNeedsBuff(test) or shift)  then
            cur = test
            do
                break
            end
        end
    end

    if (cur == 6) then
        if skipempty == false then
            cur = -1
        else
            cur = 0
        end
    end

    PallyPower_SealAssignments[name] = cur
    PallyPower_SendMessage("SASSIGN " .. name .. " " .. cur)

    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_PerformCycleBackwards(name, class, skipempty)
    local nameplayer = UnitName("player")
    if class == PALLYPOWER_AURA_CLASS then
        PallyPower_PerformAuraCycleBackwards(name, skipempty)
        return
    end
    if class == PALLYPOWER_SEAL_CLASS then
        PallyPower_PerformSealCycleBackwards(name, skipempty)
        return
    end

    if skipempty == false then
        shift = IsShiftKeyDown()
    end

    --force pala (all buff possible) when shift wheeling
    if shift then
        class = 4
    end

    if not PallyPower_Assignments[name][class] then
        cur = 6
    else
        cur = PallyPower_Assignments[name][class]
        if skipempty == false then
            if cur == -1 then
                cur = 6
            end
        else
            if cur == 0 then
                cur = 6
            end
        end
    end

    local stoploop = -1

    if skipempty == false then
        PallyPower_Assignments[name][class] = -1
        stoploop = -1
    else
        PallyPower_Assignments[name][class] = 0
        stoploop = 0
    end

    for test = cur - 1, stoploop, -1 do
        cur = test
        if PallyPower_CanBuff(name, test) and (PallyPower_NeedsBuff(class, test) or shift) then
            do
                break
            end
        end
    end

    if shift then
        for test = 0, 9 do
            PallyPower_Assignments[name][test] = cur
            if name == nameplayer then
                if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][test]) then
                    for lname in pairs(PallyPower_NormalAssignments[nameplayer][test]) do
                        if cur == -1 or PallyPower_NormalAssignments[nameplayer][test][lname] == cur then
                            PallyPower_NormalAssignments[nameplayer][test][lname] = -1
                        end
                    end                    
                end
            end
        end
        PallyPower_SendMessage("MASSIGN " .. name .. " " .. cur)
    else
        PallyPower_Assignments[name][class] = cur
        if name == nameplayer then
            if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][class]) then
                for lname in pairs(PallyPower_NormalAssignments[nameplayer][class]) do
                    if cur == -1 or PallyPower_NormalAssignments[nameplayer][class][lname] == cur then
                        PallyPower_NormalAssignments[nameplayer][class][lname] = -1
                    end
                end                    
            end
        end
        PallyPower_SendMessage("ASSIGN " .. name .. " " .. class .. " " .. cur)
    end    
    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_PerformCycle(name, class, skipempty)
    local nameplayer = UnitName("player")

    if class == PALLYPOWER_AURA_CLASS then
        PallyPower_PerformAuraCycle(name, skipempty)
        return
    end

    if class == PALLYPOWER_SEAL_CLASS then
        PallyPower_PerformSealCycle(name, skipempty)
        return
    end

    if skipempty == false then
        shift = IsShiftKeyDown()
    end    

    --force pala (all buff possible) when shift wheeling
    if shift then
        class = 4
    end

    if not PallyPower_Assignments[name][class] then
        if skipempty == false then
            cur = -1
        else
            cur = 0
        end
    else
        cur = PallyPower_Assignments[name][class]
    end
    if skipempty == false then
        PallyPower_Assignments[name][class] = -1
    else
        PallyPower_Assignments[name][class] = 0
    end
    for test = cur + 1, 6 do
        if PallyPower_CanBuff(name, test) and (PallyPower_NeedsBuff(class, test) or shift) then
            cur = test
            do
                break
            end
        end
    end

    if (cur == 6) then
        if skipempty == false then
            cur = -1
        else
            cur = 0
        end
    end

    if shift then
        for test = 0, 9 do
            PallyPower_Assignments[name][test] = cur
            if name == nameplayer then
                if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][test]) then
                    for lname in pairs(PallyPower_NormalAssignments[nameplayer][test]) do
                        if cur == -1 or PallyPower_NormalAssignments[nameplayer][test][lname] == cur then
                            PallyPower_NormalAssignments[nameplayer][test][lname] = -1
                        end
                    end                    
                end
            end
        end
        PallyPower_SendMessage("MASSIGN " .. name .. " " .. cur)
    else
        PallyPower_Assignments[name][class] = cur
        if name == nameplayer then
            if (PallyPower_NormalAssignments[nameplayer] and PallyPower_NormalAssignments[nameplayer][class]) then
                for lname in pairs(PallyPower_NormalAssignments[nameplayer][class]) do
                    if cur == -1 or PallyPower_NormalAssignments[nameplayer][class][lname] == cur then
                        PallyPower_NormalAssignments[nameplayer][class][lname] = -1
                    end
                end                    
            end
        end
        PallyPower_SendMessage("ASSIGN " .. name .. " " .. class .. " " .. cur)
    end

    PP_NextScan = 0 --PallyPower_UpdateUI()
end

function PallyPower_AuraCanBuff(name, test)
    if test == 7 then
        return true
    end
    if (not AllPallysAuras[name]) or (not AllPallysAuras[name][test]) or (AllPallysAuras[name][test]["rank"] == 0) then
        return false
    end
    return true
end

function PallyPower_AuraNeedsBuff(test)
    if test == 7 then
        return true
    end
    if test == -1 then
        return true
    end

    for name, skills in PallyPower_AuraAssignments do
        if (AllPallysAuras[name]) and (skills == test) then
            return false
        end
    end
    return true
end

function PallyPower_SealCanBuff(name, test)
   if test == 6 then
        return true
    end
    if (not AllPallysSeals[name]) or (not AllPallysSeals[name][test]) or (AllPallysSeals[name][test]["rank"] == 0) then
        return false
    end
    return true
end

function PallyPower_SealNeedsBuff(test)
    if test == 5 then
        return true
    end
    if test == -1 then
        return true
    end

    for name, skills in PallyPower_SealAssignments do
        if (AllPallysSeals[name]) and (skills == test) then
            return false
        end
    end
    return true
end

function PallyPower_CanBuff(name, test)
    if test == 6 then
        return true
    end
    if (not AllPallys[name][test]) or (AllPallys[name][test]["rank"] == 0) then
        return false
    end
    return true
end

function PallyPower_NeedsBuff(class, test)
    if test == 6 then
        return true
    end
    if test == -1 then
        return true
    end
    if PP_PerUser.smartbuffs then
        -- no wisdom for warriors and rogues
        if (class == 0 or class == 1) and test == 0 then
            return false
        end
        -- no salv for warriors
        --if class == 0 and test == 2 then
        --    return false
        --end
        -- no might for casters
        if (class == 2 or class == 6 or class == 7) and test == 1 then --class == 5 or allow Might on Hunters
            return false
        end
    end

    for name, skills in PallyPower_Assignments do
        if (AllPallys[name]) and ((skills[class]) and (skills[class] == test)) then
            return false
        end
    end
    return true
end

function PallyPower_GetPlayerGroupID(pname)
    if GetNumRaidMembers() == 0 then
        return "" --Party
    end
    for i = 1, GetNumRaidMembers(), 1 do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
        if (name == pname) then
            return "G"..subgroup --G1, G2 ... G8
        end
    end
end

function PallyPower_CheckRaidLeader(nick)
    if GetNumRaidMembers() == 0 then
        for i = 1, GetNumPartyMembers(), 1 do
            if nick == UnitName("party" .. i) and UnitIsPartyLeader("party" .. i) then
                return true
            end
        end
        return false
    end
    for i = 1, GetNumRaidMembers(), 1 do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
        if (rank >= 1 and name == nick) then
            return true
        end
    end
    return false
end

function PallyPower_CanControl(name)
    return (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer() or (name == UnitName("player") or (AllPallys[name] and (AllPallys[name].freeassign == true))))
end

function PallyPower_ScanInventory()
    if not PP_IsPally then
        return
    end
    PP_Debug("Scanning for symbols")
    oldcount = PP_Symbols
    PP_Symbols = 0
    for bag = 0, 4 do
        local bagslots = GetContainerNumSlots(bag)
        if (bagslots) then
            for slot = 1, bagslots do
                local link = GetContainerItemLink(bag, slot)
                if (link and string.find(link, PallyPower_Symbol)) then
                    local _, count, locked = GetContainerItemInfo(bag, slot)
                    PP_Symbols = PP_Symbols + count
                end
            end
        end
    end
    if PP_Symbols ~= oldcount then
        PallyPower_SendMessage("SYMCOUNT " .. PP_Symbols)
    end
    AllPallys[UnitName("player")]["symbols"] = PP_Symbols
    AllPallys[UnitName("player")]["freeassign"] = PP_PerUser.freeassign
end

function PallyPower_PaladinLeftGroup()
    local AllPallysScanned = {}
    local Scan_Paladins = {}
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            tinsert(Scan_Paladins, "raid" .. i)
        end
    else
        tinsert(Scan_Paladins, "player")
        for i = 1, GetNumPartyMembers() do
            tinsert(Scan_Paladins, "party" .. i)
        end
    end
    while Scan_Paladins[1] do
        local unit = Scan_Paladins[1]
        local _,class = UnitClass(unit)
        if class == "PALADIN" then
            local name = UnitName(unit)
            AllPallysScanned[name] = true
        end
        tremove(Scan_Paladins, 1)
    end
    for name, _ in pairs(PallyPower_Assignments) do
        if AllPallysScanned[name] == nil then
            return true -- a paladin left the group
        end
    end
end

-- Helper function for Nampower: Convert spell name to buff ID
function PallyPower_GetBuffIDFromSpellName(spellName)
    if not spellName then return -2 end
    
    -- Use pattern matching to handle ranks (e.g., "Blessing of Wisdom (Rank 3)")
    -- Wisdom
    if string.find(spellName, "Greater Blessing of Wisdom") then
        return 0
    elseif string.find(spellName, "Blessing of Wisdom") then
        return 0
    -- Might
    elseif string.find(spellName, "Greater Blessing of Might") then
        return 1
    elseif string.find(spellName, "Blessing of Might") then
        return 1
    -- Salvation
    elseif string.find(spellName, "Greater Blessing of Salvation") then
        return 2
    elseif string.find(spellName, "Blessing of Salvation") then
        return 2
    -- Light
    elseif string.find(spellName, "Greater Blessing of Light") then
        return 3
    elseif string.find(spellName, "Blessing of Light") then
        return 3
    -- Kings
    elseif string.find(spellName, "Greater Blessing of Kings") then
        return 4
    elseif string.find(spellName, "Blessing of Kings") then
        return 4
    -- Sanctuary
    elseif string.find(spellName, "Greater Blessing of Sanctuary") then
        return 5
    elseif string.find(spellName, "Blessing of Sanctuary") then
        return 5
    -- Protection
    elseif string.find(spellName, "Blessing of Protection") then
        return 5
    end
    
    return -2
end

function PallyPower_ScanRaid()
    if not PP_IsPally then
        return
    end
    if not (PP_ScanInfo) then
        PP_Scanners = {}
        PP_ScanInfo = {}
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                tinsert(PP_Scanners, "raid" .. i)
            end
            INRAID = 1
        else
            tinsert(PP_Scanners, "player")
            for i = 1, GetNumPartyMembers() do
                tinsert(PP_Scanners, "party" .. i)
            end
            INRAID = 0
        end
    end
    local tests = PP_PerUser.scanperframe
    if (not tests) then
        tests = 1
    end

    while PP_Scanners[1] do
        unit = PP_Scanners[1]
        local name = UnitName(unit)
        local class = UnitClass(unit)
        if (name and class) then
            local cid = PallyPower_GetClassID(class)
            if cid == 5 then -- hunters
                if GetNumRaidMembers() > 0 then
                    local petId = "raidpet" .. string.sub(unit, 5)
                    local pet_name = UnitName(petId)

                    if pet_name then
                        local classID = 9
                        if not PP_ScanInfo[classID] then
                            PP_ScanInfo[classID] = {}
                        end

                        PP_ScanInfo[classID][petId] = {}
                        PP_ScanInfo[classID][petId]["name"] = pet_name
                        PP_ScanInfo[classID][petId]["visible"] = UnitIsVisible(petId)

                        -- Use Nampower API if available for better performance
                        if PP_NampowerAPI then
                            local auras = GetUnitField(petId, "aura")
                            if auras then
                                for i = 1, table.getn(auras) do
                                    local spellId = auras[i]
                                    if spellId and spellId > 0 then
                                        local spellName = GetSpellRecField(spellId, "name")
                                        if spellName then
                                            local txtID = PallyPower_GetBuffIDFromSpellName(spellName)
                                            if txtID > 5 then
                                                txtID = txtID - 6
                                            end
                                            PP_ScanInfo[classID][petId][txtID] = true
                                        end
                                    end
                                end
                            end
                        else
                            -- Fallback to original method
                            local j = 1
                            while UnitBuff(petId, j, true) do
                                local buffIcon, _ = UnitBuff(petId, j, true)
                                local txtID = PallyPower_GetBuffTextureID(buffIcon)
                                if txtID > 5 then
                                    txtID = txtID - 6
                                end
                                PP_ScanInfo[classID][petId][txtID] = true
                                j = j + 1
                            end
                        end
                    end
                else
                    local petId = "partypet" .. string.sub(unit, 6)
                    local pet_name = UnitName(petId)

                    if pet_name then
                        local classID = 9
                        if not PP_ScanInfo[classID] then
                            PP_ScanInfo[classID] = {}
                        end

                        PP_ScanInfo[classID][petId] = {}
                        PP_ScanInfo[classID][petId]["name"] = pet_name
                        PP_ScanInfo[classID][petId]["visible"] = UnitIsVisible(petId)

                        -- Enhanced: Try GUID-based scanning (v1.38)
                        local scanTarget = petId
                        if PP_SuperWoW then
                            local exists, guid = UnitExists(petId)
                            if exists and guid then
                                if type(guid) == "string" and string.sub(guid, 1, 2) ~= "0x" then
                                    guid = "0x" .. guid
                                end
                                scanTarget = guid
                            end
                        end

                        -- Use Nampower API if available for better performance
                        if PP_NampowerAPI then
                            local auras = GetUnitField(scanTarget, "aura")
                            if auras then
                                for i = 1, table.getn(auras) do
                                    local spellId = auras[i]
                                    if spellId and spellId > 0 then
                                        local spellName = GetSpellRecField(spellId, "name")
                                        if spellName then
                                            local txtID = PallyPower_GetBuffIDFromSpellName(spellName)
                                            if txtID > 5 then
                                                txtID = txtID - 6
                                            end
                                            PP_ScanInfo[classID][petId][txtID] = true
                                        end
                                    end
                                end
                            end
                        else
                            -- Fallback to original method
                            local j = 1
                            while UnitBuff(scanTarget, j, true) do
                                local buffIcon, _ = UnitBuff(scanTarget, j, true)
                                local txtID = PallyPower_GetBuffTextureID(buffIcon)
                                if txtID > 5 then
                                    txtID = txtID - 6
                                end
                                PP_ScanInfo[classID][petId][txtID] = true
                                j = j + 1
                            end
                        end
                    end
                end
            end

            if not PP_ScanInfo[cid] then
                PP_ScanInfo[cid] = {}
            end
            PP_ScanInfo[cid][unit] = {}
            PP_ScanInfo[cid][unit]["name"] = name
            PP_ScanInfo[cid][unit]["visible"] = UnitIsVisible(unit)

            -- Enhanced: Try GUID-based scanning for better reliability (v1.38)
            local scanTarget = unit
            if PP_SuperWoW then
                local exists, guid = UnitExists(unit)
                if exists and guid then
                    if type(guid) == "string" and string.sub(guid, 1, 2) ~= "0x" then
                        guid = "0x" .. guid
                    end
                    scanTarget = guid
                end
            end

            -- Use Nampower API if available for better performance
            if PP_NampowerAPI then
                local auras = GetUnitField(scanTarget, "aura")
                if auras then
                    for i = 1, table.getn(auras) do
                        local spellId = auras[i]
                        if spellId and spellId > 0 then
                            local spellName = GetSpellRecField(spellId, "name")
                            if spellName then
                                local txtID = PallyPower_GetBuffIDFromSpellName(spellName)
                                if txtID > 5 then
                                    txtID = txtID - 6
                                end
                                PP_ScanInfo[cid][unit][txtID] = true
                            end
                        end
                    end
                end
            else
                -- Fallback to original method
                local j = 1
                while UnitBuff(scanTarget, j, true) do
                    local buffIcon, _ = UnitBuff(scanTarget, j, true)
                    local txtID = PallyPower_GetBuffTextureID(buffIcon)
                    if txtID > 5 then
                        txtID = txtID - 6
                    end
                    PP_ScanInfo[cid][unit][txtID] = true
                    j = j + 1
                end
            end
        end
        tremove(PP_Scanners, 1)
        tests = tests - 1
        PP_Debug("Scanning " .. unit .. " and " .. tests .. " remain")
        if (tests <= 0) then
            return
        end
    end
    CurrentBuffs = PP_ScanInfo
    PP_ScanInfo = nil
    PP_NextScan = PP_PerUser.scanfreq
    PallyPower_ScanInventory()
    PallyPower_UpdateUI()
end

function PallyPower_GetClassID(class)
    for id, name in PallyPower_ClassID do
        if (name == class) then
            return id
        end
    end
    return -1
end

function PallyPower_GetBuffTextureID(text)
    local icons_prefix
    if PP_PerUser.usehdicons == true then
        icons_prefix = "AddOns\\PallyPowerTW\\HD"
    else
        icons_prefix = "AddOns\\PallyPowerTW\\"
    end

    for id, name in BuffIcon do
        if (string.gsub(name,icons_prefix,"") == text) then
            return id
        end
    end
    -- Check also the small buffs
    for id, name in BuffIconSmall do
        if (string.gsub(name,icons_prefix,"") == text) then
            return id
        end
    end
    return -2
end

function PallyPowerBuffButton_OnLoad(btn)
    this:SetBackdropColor(0, 0, 0, PP_PerUser.transparency)
end

function PallyPowerBuffButton_OnClick(btn, mousebtn)
    if (btn == getglobal("PallyPowerBuffBarRF")) and (hasRighteousFury == true) and 
       (nameRighteousFury ~= nil)
    then
        CastSpellByName(nameRighteousFury)
        return
    end

    if btn == getglobal("PallyPowerBuffBarAura") then
        local auraId = PallyPower_AuraAssignments[UnitName("player")]
        if auraId ~= -1 and 
           AllPallysAuras[UnitName("player")] and 
           AllPallysAuras[UnitName("player")][auraId] and
           AllPallysAuras[UnitName("player")][auraId]["id"]
        then
            if GetSpellCooldown(AllPallysAuras[UnitName("player")][auraId]["id"], BOOKTYPE_SPELL) < 1 then
                CastSpell(AllPallysAuras[UnitName("player")][auraId]["id"], BOOKTYPE_SPELL)
            else
                return
            end
        end    
        return
    end

    if btn == getglobal("PallyPowerBuffBarSeal") then
        PallyPower_CastSeal()
        return
    end

    local rankInfo = PallyPower_ScanSpells()

    RestorSelfAutoCastTimeOut = 1
    if (GetCVar("autoSelfCast") == "1") then
        RestorSelfAutoCast = true
        SetCVar("autoSelfCast", "0")
    end

    DoEmote("STAND") -- Force player stand

    ClearTarget()
    local castspellid = -1
    local castspelloverride = -1    

    if AllPallys[UnitName("player")][btn.buffID] == nil then return end
    PP_Debug("Casting " .. btn.buffID .. " on " .. btn.classID)
    
    -- Check mana before attempting to cast
    local blessingType = PALLYPOWER_SMALLBLESSING
    if (mousebtn == "LeftButton") then
        if not RegularBlessings and AllPallys[UnitName("player")][btn.buffID]["id"] ~= AllPallys[UnitName("player")][btn.buffID]["idsmall"] then
            blessingType = PALLYPOWER_GREATERBLESSING
        end
    end
    
    if not PallyPower_HasEnoughMana(btn.buffID, blessingType) then
        SpellStopTargeting()
        TargetLastTarget()
        PallyPower_ShowFeedback("Not enough mana to cast blessing", 1, 0, 0)
        return
    end
    
    if (mousebtn == "RightButton") then
        if GetSpellCooldown(AllPallys[UnitName("player")][btn.buffID]["idsmall"], BOOKTYPE_SPELL) < 1 then
            CastSpell(AllPallys[UnitName("player")][btn.buffID]["idsmall"], BOOKTYPE_SPELL)
            castspellid = btn.buffID
        else
            return
        end
    elseif (mousebtn == "LeftButton") then
        if GetSpellCooldown(AllPallys[UnitName("player")][btn.buffID]["id"], BOOKTYPE_SPELL) < 1 then
            CastSpell(AllPallys[UnitName("player")][btn.buffID]["id"], BOOKTYPE_SPELL)
            castspellid = btn.buffID
        else
            return
        end
    end

    local RecentCast = false
    local skipclear = false
    -- Skip recentCast protection when Shift key is held down
    if not IsShiftKeyDown() then
        if (RegularBlessings == true) then
            if LastCast[btn.buffID .. btn.classID] and LastCast[btn.buffID .. btn.classID] > (PALLYPOWER_NORMALBLESSINGDURATION) - PALLYPOWER_BLESSINGTRESHOLD then
                RecentCast = true
            end
        else
            if (mousebtn == "LeftButton" and not (AllPallys[UnitName("player")][btn.buffID]["id"] == AllPallys[UnitName("player")][btn.buffID]["idsmall"])) then
                if LastCast[btn.buffID .. btn.classID] and LastCast[btn.buffID .. btn.classID] > (PALLYPOWER_GREATERBLESSINGDURATION) - PALLYPOWER_BLESSINGTRESHOLD then
                    RecentCast = true
                end
            else
                if LastCast[btn.buffID .. btn.classID] and LastCast[btn.buffID .. btn.classID] > (PALLYPOWER_NORMALBLESSINGDURATION) - PALLYPOWER_BLESSINGTRESHOLD then
                    RecentCast = true
                end
            end
        end
    end
    local LastRecentCast = RecentCast
    
    -- Track failure reasons for better error messages
    local failureReasons = {}
    
    -- Check for reagents if trying to cast Greater Blessing (LeftButton on Greater mode)
    local missingReagent = nil
    if not RegularBlessings and mousebtn == "LeftButton" and AllPallys[UnitName("player")][btn.buffID] then
        if AllPallys[UnitName("player")][btn.buffID]["id"] ~= AllPallys[UnitName("player")][btn.buffID]["idsmall"] then
            -- This is a Greater Blessing, check for Symbol of Kings (Wisdom, Kings, Might need it)
            if btn.buffID == 0 or btn.buffID == 1 or btn.buffID == 4 then
                local count = PP_Symbols
                if count == 0 then
                    missingReagent = "Symbol of Kings"
                end
            end
        end
    end
    
    if missingReagent then
        SpellStopTargeting()
        TargetLastTarget()
        PallyPower_ShowFeedback("Out of " .. missingReagent, 1, 0, 0) -- Red color
        return
    end
    
    -- Sort units by proximity if UnitXP is available, otherwise use original iteration
    local sortedUnits
    if PP_PerUser and PP_UnitXPDllLoaded and PP_PerUser.useunitxp_sp3 then
        sortedUnits = PallyPower_SortUnitsByProximity(CurrentBuffs[btn.classID], 40)
    else
        -- Fallback: convert to simple array for consistent iteration
        sortedUnits = {}
        for unit, stats in pairs(CurrentBuffs[btn.classID]) do
            table.insert(sortedUnits, {unit = unit, stats = stats})
        end
    end
    
    for _, unitData in ipairs(sortedUnits) do
        local unit = unitData.unit
        local stats = unitData.stats
        
        castspelloverride = -1
        if RecentCast ~= LastRecentCast then
            RecentCast = LastRecentCast
        end
        skipclear = false
        if mousebtn == "LeftButton" and GetNormalBlessings(UnitName("player"),btn.classID,UnitName(unit)) ~= -1 then
            --continue with next unit if GB and unit has Individual blessings assigned
        else 
            -- Disable Greater Blessing LeftButton for pets if assignments differ
            if (btn.classID == 9) and (mousebtn == "LeftButton") then
                local player = UnitName("player")
                if PallyPower_Assignments[player][0] ~= PallyPower_Assignments[player][9] then
                    SpellStopTargeting()
                    TargetLastTarget()
                    PallyPower_ShowFeedback(
                        format(PallyPower_BlessingsDiffer),
                        1, 1, 0 -- Yellow color for feedback
                    )
                    return
                end
            end

            if mousebtn == "RightButton" then
                local bltest = GetNormalBlessings(UnitName("player"),btn.classID, stats.name)
                if string.find(table.concat(btn.need, " "), stats.name) or 
                   (bltest ~= -1 and LastCastPlayer[stats.name] and ( LastCastPlayer[stats.name] < PALLYPOWER_NORMALBLESSINGDURATION - PALLYPOWER_BLESSINGTRESHOLD ) ) then 
                    RecentCast = false
                    skipclear = true
                    castspelloverride = bltest
                end
            end

            -- Debug cast checks
            -- Check mana before targeting
            local blessingType = (mousebtn == "LeftButton" and not RegularBlessings and 
                                 AllPallys[UnitName("player")][btn.buffID] and
                                 AllPallys[UnitName("player")][btn.buffID]["id"] ~= AllPallys[UnitName("player")][btn.buffID]["idsmall"]) 
                                 and PALLYPOWER_GREATERBLESSING or PALLYPOWER_SMALLBLESSING
            local hasMana = PallyPower_HasEnoughMana(btn.buffID, blessingType)
            local canTarget = SpellCanTargetUnit(unit)
            local notDead = not UnitIsDeadOrGhost(unit)
            local hasLoS = PallyPower_CheckTargetLoS(unit)
            local lastCastString = LastCastOn[btn.classID] and table.concat(LastCastOn[btn.classID], " ") or ""
            local foundInRecent = lastCastString ~= "" and string.find(lastCastString, unit) ~= nil
            local notRecent = not (RecentCast and foundInRecent)
            local notSalvOnTank = not PallyPower_CastingSalvationOnTank(unit, castspellid, castspelloverride)
            
            -- Track failure reason
            local failureReason = nil
            if not hasMana then
                failureReason = "not enough mana"
            elseif not canTarget then
                failureReason = "can't target"
            elseif not notDead then
                failureReason = "dead/ghost"
            elseif not hasLoS then
                failureReason = "out of range/LOS"
            elseif not notRecent then
                failureReason = "recast_blocked"
            elseif not notSalvOnTank then
                failureReason = "salvation on tank"
            end
            
            if failureReason then
                if not failureReasons[failureReason] then
                    failureReasons[failureReason] = {}
                end
                table.insert(failureReasons[failureReason], UnitName(unit) or unit)
            end
            
            if OGAALogger and OGAALogger.AddMessage then
                OGAALogger.AddMessage("PallyPower_Cast", "=== Cast Check for " .. unit .. " ===")
                OGAALogger.AddMessage("PallyPower_Cast", "  Has Mana: " .. tostring(hasMana))
                OGAALogger.AddMessage("PallyPower_Cast", "  SpellCanTargetUnit: " .. tostring(canTarget))
                OGAALogger.AddMessage("PallyPower_Cast", "  Not Dead/Ghost: " .. tostring(notDead))
                OGAALogger.AddMessage("PallyPower_Cast", "  Has LOS: " .. tostring(hasLoS))
                OGAALogger.AddMessage("PallyPower_Cast", "  RecentCast flag: " .. tostring(RecentCast))
                OGAALogger.AddMessage("PallyPower_Cast", "  LastCastOn[" .. btn.classID .. "]: " .. lastCastString)
                OGAALogger.AddMessage("PallyPower_Cast", "  Found in recent: " .. tostring(foundInRecent))
                OGAALogger.AddMessage("PallyPower_Cast", "  Not Recent Cast: " .. tostring(notRecent))
                OGAALogger.AddMessage("PallyPower_Cast", "  Not Salv on Tank: " .. tostring(notSalvOnTank))
                local allPass = hasMana and canTarget and notDead and hasLoS and notRecent and notSalvOnTank
                OGAALogger.AddMessage("PallyPower_Cast", "  ALL CHECKS PASS: " .. tostring(allPass))
                if failureReason then
                    OGAALogger.AddMessage("PallyPower_Cast", "  FAIL REASON: " .. failureReason)
                end
            end
            
            if hasMana and canTarget and notDead and hasLoS and notRecent and notSalvOnTank then
                PP_Debug("Trying to cast on " .. unit)
                local blessing = GetNormalBlessings(UnitName("player"),btn.classID, stats.name)
                if blessing ~= -1 and mousebtn == "RightButton" then
                    if GetSpellCooldown(AllPallys[UnitName("player")][blessing]["idsmall"], BOOKTYPE_SPELL) < 1 then
                        CastSpell(AllPallys[UnitName("player")][blessing]["idsmall"], BOOKTYPE_SPELL)
                    else
                        return
                    end
                end    

                SpellTargetUnit(unit)

                PP_NextScan = 1
                if (RegularBlessings == true) then
                    LastCast[btn.buffID .. btn.classID] = PALLYPOWER_NORMALBLESSINGDURATION
                    LastCastPlayer[stats.name] = PALLYPOWER_NORMALBLESSINGDURATION
                else
                    if (mousebtn == "LeftButton" and not(AllPallys[UnitName("player")][btn.buffID]["id"] == AllPallys[UnitName("player")][btn.buffID]["idsmall"])) then
                        LastCast[btn.buffID .. btn.classID] = PALLYPOWER_GREATERBLESSINGDURATION
                    else
                        if LastCast[btn.buffID .. btn.classID] == nil or LastCast[btn.buffID .. btn.classID] < PALLYPOWER_NORMALBLESSINGDURATION then 
                            LastCast[btn.buffID .. btn.classID] = PALLYPOWER_NORMALBLESSINGDURATION
                        elseif LastCast[btn.buffID .. btn.classID] ~= nil and LastCast[btn.buffID .. btn.classID] > PALLYPOWER_NORMALBLESSINGDURATION and mousebtn == "RightButton" then 
                            LastCastPlayer[stats.name] = PALLYPOWER_NORMALBLESSINGDURATION
                        end
                        if blessing ~= -1 and mousebtn == "RightButton" then
                            LastCastPlayer[stats.name] = PALLYPOWER_NORMALBLESSINGDURATION
                        end
                    end
                end
                
                if not skipclear and not RecentCast then 
                    LastCastOn[btn.classID] = {} 
                end            
                if skipclear then
                    PallyPower_RemoveFromTable(btn.need,UnitName(unit))
                end
                if (RegularBlessings == false and mousebtn == "LeftButton" and not(AllPallys[UnitName("player")][btn.buffID]["id"] == AllPallys[UnitName("player")][btn.buffID]["idsmall"])) then
                    for unit, stats in CurrentBuffs[btn.classID] do
                        if GetNormalBlessings(UnitName("player"),btn.classID,UnitName(unit)) == -1 then   
                            if UnitIsVisible(unit) then
                                tinsert(LastCastOn[btn.classID], unit)
                            end
                        end
                    end
                    if (btn.classID == 0 or btn.classID == 9) and (PallyPower_Assignments[UnitName("player")][0] == PallyPower_Assignments[UnitName("player")][9]) then
                        local classIDToFill = (btn.classID == 9) and 0 or 9
                        if CurrentBuffs[classIDToFill] ~= nil then
                            for unit, stats in CurrentBuffs[classIDToFill] do
                                if UnitIsVisible(unit) then
                                    tinsert(LastCastOn[classIDToFill], unit)
                                end
                            end
                            LastCast[btn.buffID .. classIDToFill] = PALLYPOWER_GREATERBLESSINGDURATION
                        end
                    end
                else
                    tinsert(LastCastOn[btn.classID], unit)
                end

                if blessing ~= -1 and mousebtn == "RightButton" then
                    PallyPower_ShowFeedback(
                        format(
                            PallyPower_Casting,
                            PallyPower_BlessingID[blessing],
                            PallyPower_ClassID[btn.classID],
                            UnitName(unit)
                        ), 0, 1, 0 -- Green color for feedback
                    )
                else
                    PallyPower_ShowFeedback(
                        format(
                            PallyPower_Casting,
                            PallyPower_BlessingID[btn.buffID],
                            PallyPower_ClassID[btn.classID],
                            UnitName(unit)
                        ), 0, 1, 0 -- Green color for feedback
                    )
                end
                PP_NextScan = 1 --PallyPower_UpdateUI()
                TargetLastTarget()
                return
            end
        end
    end
    SpellStopTargeting()
    TargetLastTarget()
    
    -- Build helpful error message based on failure reasons
    local errorMsg = ""
    if failureReasons["not enough mana"] and table.getn(failureReasons["not enough mana"]) > 0 then
        errorMsg = "Not enough mana to cast blessing"
    elseif failureReasons["recast_blocked"] and table.getn(failureReasons["recast_blocked"]) > 0 then
        local names = table.concat(failureReasons["recast_blocked"], ", ")
        errorMsg = "Recast blocked on " .. names .. " (hold Shift to bypass)"
    elseif failureReasons["out of range/LOS"] and table.getn(failureReasons["out of range/LOS"]) > 0 then
        local names = table.concat(failureReasons["out of range/LOS"], ", ")
        errorMsg = names .. " out of range or line of sight"
    elseif failureReasons["dead/ghost"] and table.getn(failureReasons["dead/ghost"]) > 0 then
        local names = table.concat(failureReasons["dead/ghost"], ", ")
        errorMsg = names .. " is dead or ghost"
    elseif failureReasons["salvation on tank"] and table.getn(failureReasons["salvation on tank"]) > 0 then
        local names = table.concat(failureReasons["salvation on tank"], ", ")
        errorMsg = "Won't cast Salvation on tank: " .. names
    elseif failureReasons["can't target"] and table.getn(failureReasons["can't target"]) > 0 then
        local names = table.concat(failureReasons["can't target"], ", ")
        errorMsg = "Can't target: " .. names
    else
        errorMsg = format(PallyPower_CouldntFind, PallyPower_BlessingID[btn.buffID], PallyPower_ClassID[btn.classID])
    end
    
    PallyPower_ShowFeedback(errorMsg, 1, 1, 0)
end

function PallyPower_CastingSalvationOnTank(punit, castspell, overridespell)
    if ( castspell == 2 and overridespell == -1 ) or overridespell == 2 then --Salvation
        local pname = UnitName(punit)
        if PallyPower_Tanks[pname] and PallyPower_Tanks[pname] == true then
            return true
        else
            return false    
        end
    else
        return false
    end
end

function PallyPower_AutoBless(mousebutton)
    local rankInfo = PallyPower_ScanSpells()

    RestorSelfAutoCastTimeOut = 1
    if (GetCVar("autoSelfCast") == "1") then
        RestorSelfAutoCast = true
        SetCVar("autoSelfCast", "0")
    end

    DoEmote("STAND") -- Force player stand

    classbtn = lastClassBtn
    lastClassBtnTime = PALLYPOWER_RESTARTAUTOBLESS
    local btn = getglobal("PallyPowerBuffBarBuff" .. classbtn)

    if (btn ~= nil and btn.classID and 
        PallyPower_Assignments[UnitName("player")][btn.classID] and 
        PallyPower_Assignments[UnitName("player")][btn.classID] ~= -1) then
    
        ClearTarget()
        local castspellid = -1
        local castspelloverride = -1
        
        if AllPallys[UnitName("player")][btn.buffID] == nil then 
            lastClassBtn = lastClassBtn + 1
            -- classID == 9 is for pets
            if (lastClassBtn > 10 or btn.classID == 9) then lastClassBtn = 1 end 
            return 
        end

        PP_Debug("Casting " .. btn.buffID .. " on " .. btn.classID)
        if (mousebutton == "Hotkey1") then
            if GetSpellCooldown(AllPallys[UnitName("player")][btn.buffID]["idsmall"], BOOKTYPE_SPELL) < 1 then
                CastSpell(AllPallys[UnitName("player")][btn.buffID]["idsmall"], BOOKTYPE_SPELL)
                castspellid = btn.buffID
            else
                return
            end
        elseif (mousebutton == "Hotkey2") then
            if GetSpellCooldown(AllPallys[UnitName("player")][btn.buffID]["id"], BOOKTYPE_SPELL) < 1 then
                CastSpell(AllPallys[UnitName("player")][btn.buffID]["id"], BOOKTYPE_SPELL)
                castspellid = btn.buffID
            else
                return
            end
        end

        local RecentCast = false
        local skipclear = false
        if (RegularBlessings == true) then
            if LastCast[btn.buffID .. btn.classID] and LastCast[btn.buffID .. btn.classID] > (PALLYPOWER_NORMALBLESSINGDURATION) - PALLYPOWER_BLESSINGTRESHOLD then
                RecentCast = true
            end
        else
            if (mousebutton == "Hotkey2" and not (AllPallys[UnitName("player")][btn.buffID]["id"] == AllPallys[UnitName("player")][btn.buffID]["idsmall"])) then
                if LastCast[btn.buffID .. btn.classID] and LastCast[btn.buffID .. btn.classID] > (PALLYPOWER_GREATERBLESSINGDURATION) - PALLYPOWER_BLESSINGTRESHOLD then
                    RecentCast = true
                end
            else
                if LastCast[btn.buffID .. btn.classID] and LastCast[btn.buffID .. btn.classID] > (PALLYPOWER_NORMALBLESSINGDURATION) - PALLYPOWER_BLESSINGTRESHOLD then
                    RecentCast = true
                end
            end
        end
        local LastRecentCast = RecentCast
        if (btn.classID ~= nil and CurrentBuffs[btn.classID]) then
            
            -- Sort units by proximity if UnitXP is available, otherwise use original iteration
            local sortedUnits
            if PP_PerUser and PP_UnitXPDllLoaded and PP_PerUser.useunitxp_sp3 then
                sortedUnits = PallyPower_SortUnitsByProximity(CurrentBuffs[btn.classID], 40)
            else
                -- Fallback: convert to simple array for consistent iteration
                sortedUnits = {}
                for unit, stats in pairs(CurrentBuffs[btn.classID]) do
                    table.insert(sortedUnits, {unit = unit, stats = stats})
                end
            end
            
            for _, unitData in ipairs(sortedUnits) do
                local unit = unitData.unit
                local stats = unitData.stats
                
                castspelloverride = -1
                if RecentCast ~= LastRecentCast then
                    RecentCast = LastRecentCast
                end
                skipclear = false
                if mousebutton == "Hotkey2" and GetNormalBlessings(UnitName("player"),btn.classID,UnitName(unit)) ~= -1 then
                    --continue with next unit if GB and unit has Individual blessings assigned
                else
                    -- Disable Greater Blessing Hotkey2 for pets if assignments differ
                    if (btn.classID == 9) and (mousebutton == "Hotkey2") then
                        local player = UnitName("player")
                        if PallyPower_Assignments[player][0] ~= PallyPower_Assignments[player][9] then
                            SpellStopTargeting()
                            TargetLastTarget()
                            PallyPower_ShowFeedback(
                                format(PallyPower_BlessingsDiffer),
                                1, 1, 0 -- Yellow color for feedback
                            )
                            return
                        end
                    end

                    if mousebutton == "Hotkey1" then
                        local bltest = GetNormalBlessings(UnitName("player"),btn.classID, stats.name)
                        if string.find(table.concat(btn.need, " "), stats.name) or 
                           (bltest ~= -1 and LastCastPlayer[stats.name] and ( LastCastPlayer[stats.name] < PALLYPOWER_NORMALBLESSINGDURATION - PALLYPOWER_BLESSINGTRESHOLD ) ) then 
                            RecentCast = false
                            skipclear = true
                            castspelloverride = bltest
                        end
                    end
                        
                    if
                            SpellCanTargetUnit(unit) and (not UnitIsDeadOrGhost(unit)) and PallyPower_CheckTargetLoS(unit) and
                                not (RecentCast and string.find(table.concat(LastCastOn[btn.classID], " "), unit)) and 
                                (not PallyPower_CastingSalvationOnTank(unit, castspellid, castspelloverride))
                    then
                        PP_Debug("Trying to cast on " .. unit)
                        local blessing = GetNormalBlessings(UnitName("player"),btn.classID, stats.name)
                        if blessing ~= -1 and mousebutton == "Hotkey1" then
                            if GetSpellCooldown(AllPallys[UnitName("player")][blessing]["idsmall"], BOOKTYPE_SPELL) < 1 then
                                CastSpell(AllPallys[UnitName("player")][blessing]["idsmall"], BOOKTYPE_SPELL)
                            else
                                return
                            end
                        end    

                        SpellTargetUnit(unit)

                        PP_NextScan = 1
                        if (RegularBlessings == true) then
                            LastCast[btn.buffID .. btn.classID] = PALLYPOWER_NORMALBLESSINGDURATION
                            LastCastPlayer[stats.name] = PALLYPOWER_NORMALBLESSINGDURATION
                        else
                            if (mousebutton == "Hotkey2" and not(AllPallys[UnitName("player")][btn.buffID]["id"] == AllPallys[UnitName("player")][btn.buffID]["idsmall"])) then
                                LastCast[btn.buffID .. btn.classID] = PALLYPOWER_GREATERBLESSINGDURATION
                            else
                                if LastCast[btn.buffID .. btn.classID] == nil or LastCast[btn.buffID .. btn.classID] < PALLYPOWER_NORMALBLESSINGDURATION then 
                                    LastCast[btn.buffID .. btn.classID] = PALLYPOWER_NORMALBLESSINGDURATION
                                elseif LastCast[btn.buffID .. btn.classID] ~= nil and LastCast[btn.buffID .. btn.classID] > PALLYPOWER_NORMALBLESSINGDURATION and mousebtn == "Hotkey1" then 
                                    LastCastPlayer[stats.name] = PALLYPOWER_NORMALBLESSINGDURATION
                                end
                                if blessing ~= -1 and mousebutton == "Hotkey1" then
                                    LastCastPlayer[stats.name] = PALLYPOWER_NORMALBLESSINGDURATION
                                end
                            end
                        end
                        if not skipclear and not RecentCast then 
                            LastCastOn[btn.classID] = {} 
                        end
                        if skipclear then
                            PallyPower_RemoveFromTable(btn.need,UnitName(unit))
                        end
        
                        if (RegularBlessings == false and mousebutton == "Hotkey2" and not(AllPallys[UnitName("player")][btn.buffID]["id"] == AllPallys[UnitName("player")][btn.buffID]["idsmall"])) then
                            for unit, stats in CurrentBuffs[btn.classID] do
                                if GetNormalBlessings(UnitName("player"),btn.classID,UnitName(unit)) == -1 then   
                                    if UnitIsVisible(unit) then
                                        tinsert(LastCastOn[btn.classID], unit)
                                    end
                                end
                            end
                            if (btn.classID == 0 or btn.classID == 9) and (PallyPower_Assignments[UnitName("player")][0] == PallyPower_Assignments[UnitName("player")][9]) then
                                local classIDToFill = (btn.classID == 9) and 0 or 9
                                if CurrentBuffs[classIDToFill] ~= nil then
                                    for unit, stats in CurrentBuffs[classIDToFill] do
                                        if UnitIsVisible(unit) then
                                            tinsert(LastCastOn[classIDToFill], unit)
                                        end
                                    end
                                    LastCast[btn.buffID .. classIDToFill] = PALLYPOWER_GREATERBLESSINGDURATION
                                end
                            end
                        else
                            tinsert(LastCastOn[btn.classID], unit)
                        end
                        if blessing ~= -1 and mousebutton == "Hotkey1" then
                            PallyPower_ShowFeedback(
                                format(
                                    PallyPower_Casting,
                                    PallyPower_BlessingID[blessing],
                                    PallyPower_ClassID[btn.classID],
                                    UnitName(unit)
                                ), 0, 1, 0 --Green feedback for casting
                            )
                        else
                            PallyPower_ShowFeedback(
                                format(
                                    PallyPower_Casting,
                                    PallyPower_BlessingID[btn.buffID],
                                    PallyPower_ClassID[btn.classID],
                                    UnitName(unit)
                                ), 0, 1, 0 --Green feedback for casting
                            )
                        end         
                        PP_NextScan = 1 --PallyPower_UpdateUI()
                        TargetLastTarget()
                        return
                    end
                end
            end
        end
        SpellStopTargeting()
        TargetLastTarget()
        PallyPower_ShowFeedback(
            format(PallyPower_CouldntFind, PallyPower_BlessingID[btn.buffID], PallyPower_ClassID[btn.classID]),
            1, 1, 0 --Yellow feedback for not finding a target
        )
        lastClassBtn = lastClassBtn + 1
        -- classID == 9 is for pets
        if (lastClassBtn > 10 or btn.classID == 9) then lastClassBtn = 1 end 
    else
        lastClassBtn = 1
    end
end

function PallyPower_HasBlessingActive(unit,class)
    local i
    local testUnitBuff
    for i=1,40 do 
        testUnitBuff = UnitBuff(unit,i) 
        if (testUnitBuff and testUnitBuff == BlessingIcon[PallyPower_Assignments[UnitName("player")][id]]) then 
            return true
        end 
    end 
    return false
end

function PallyPowerBuffButton_OnEnter(btn)
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(
        PallyPower_ClassID[btn.classID] .. PallyPower_BuffFrameText .. PallyPower_BlessingID[btn.buffID],
        1,
        1,
        1
    )
    GameTooltip:AddLine(PallyPower_Have .. table.concat(btn.have, ", "), 0.5, 1, 0.5)
    GameTooltip:AddLine(PallyPower_Need .. table.concat(btn.need, ", "), 1, 0.5, 0.5)
    GameTooltip:AddLine(PallyPower_NotHere .. table.concat(btn.range, ", "), 0.5, 0.5, 1)
    GameTooltip:AddLine(PallyPower_Dead .. table.concat(btn.dead, ", "), 1, 0, 0)
    GameTooltip:Show()
end

function PallyPowerBuffButton_OnLeave(btn)
    GameTooltip:Hide()
end
 --

--[[ MainFrame and MenuFrame Scaling ]] 
function PallyPower_StartScaling(arg1)
    if arg1 == "LeftButton" then
        this:LockHighlight()
        PallyPower.FrameToScale = this:GetParent()
        PallyPower.ScalingWidth = this:GetParent():GetWidth() * PallyPower.FrameToScale:GetParent():GetEffectiveScale()
        PallyPower.ScalingHeight =
            this:GetParent():GetHeight() * PallyPower.FrameToScale:GetParent():GetEffectiveScale()
        PallyPower_ScalingFrame:Show()
    end
end

function PallyPower_StopScaling(arg1)
    if arg1 == "LeftButton" then
        PallyPower_ScalingFrame:Hide()
        PallyPower.FrameToScale = nil
        this:UnlockHighlight()
    end
end

local function really_setpoint(frame, point, relativeTo, relativePoint, xoff, yoff)
    frame:SetPoint(point, relativeTo, relativePoint, xoff, yoff)
end

function PallyPower_ScaleFrame(scale)
    local frame = PallyPower.FrameToScale
    local oldscale = frame:GetScale() or 1
    local framex = (frame:GetLeft() or PallyPowerPerOptions.XPos) * oldscale
    local framey = (frame:GetTop() or PallyPowerPerOptions.YPos) * oldscale

    frame:SetScale(scale)
    if frame:GetName() == "PallyPowerFrame" then
        really_setpoint(PallyPowerFrame, "TOPLEFT", "UIParent", "BOTTOMLEFT", framex / scale, framey / scale)
        PP_PerUser.scalemain = scale
    end
    if frame:GetName() == "PallyPowerBuffBar" then
        really_setpoint(PallyPowerBuffBar, "TOPLEFT", "UIParent", "BOTTOMLEFT", framex / scale, framey / scale)
        PP_PerUser.scalebar = scale
    end
end

function PallyPower_ScalingFrame_OnUpdate(arg1)
    if not PallyPower.ScalingTime then
        PallyPower.ScalingTime = 0
    end
    PallyPower.ScalingTime = PallyPower.ScalingTime + arg1
    if PallyPower.ScalingTime > 0.25 then
        PallyPower.ScalingTime = 0
        local frame = PallyPower.FrameToScale
        local oldscale = frame:GetEffectiveScale()
        local framex, framey, cursorx, cursory =
            frame:GetLeft() * oldscale,
            frame:GetTop() * oldscale,
            GetCursorPosition()
        if PallyPower.ScalingWidth > PallyPower.ScalingHeight then
            if (cursorx - framex) > 32 then
                local newscale = (cursorx - framex) / PallyPower.ScalingWidth
                PallyPower_ScaleFrame(newscale)
            end
        else
            if (framey - cursory) > 32 then
                local newscale = (framey - cursory) / PallyPower.ScalingHeight
                PallyPower_ScaleFrame(newscale)
            end
        end
    end
end

function PallyPower_SetOption(opt, value)
    PP_PerUser[opt] = value
end

function PallyPower_Options()
    MinimapButtonOptionSlider:SetValue(PP_PerUser.minimapbuttonpos);
    TransparencyOptionSlider:SetValue(PP_PerUser.transparency);
    PallyPower_OptionsFrame:Show()
end

function PallyPower_ShowFeedback(msg, r, g, b, a)
    if PP_PerUser.chatfeedback then
        DEFAULT_CHAT_FRAME:AddMessage(PALLYPOWER_MSG_PREFIX .. msg, r, g, b, a)
    else
        UIErrorsFrame:AddMessage(msg, r, g, b, a)
    end
end

function PallyPowerBuffBarButton_OnMouseWheel(btn, arg1)
    pname = UnitName("player")

    if btn:GetName() == "PallyPowerBuffBarRF" or btn:GetName() == "PallyPowerBuffBarTitle" then return end

    if btn == getglobal("PallyPowerBuffBarAura") then 
        class = PALLYPOWER_AURA_CLASS 
    elseif btn == getglobal("PallyPowerBuffBarSeal") then 
        class = PALLYPOWER_SEAL_CLASS 
    else
        class = btn.classID
    end

    if not PallyPower_CanControl(pname) then
        return false
    end

    if (arg1 == -1) then
        --mouse wheel down
        PallyPower_PerformCycle(pname, class, true)
    else
        PallyPower_PerformCycleBackwards(pname, class, true)
    end
end

function PallyPowerGridButton_OnMouseWheel(btn, arg1)
    local _, _, pnum, class = string.find(btn:GetName(), "PallyPowerFramePlayer(.+)Class(.+)")
    if class == "A" then class = PALLYPOWER_AURA_CLASS end
    if class == "S" then class = PALLYPOWER_SEAL_CLASS end
    pnum = pnum + 0
    class = class + 0
    pname = getglobal("PallyPowerFramePlayer" .. pnum .. "Name"):GetText()
    if not PallyPower_CanControl(pname) then
        return false
    end

    if (arg1 == -1) then
        --mouse wheel down
        PallyPower_PerformCycle(pname, class, false)
    else
        PallyPower_PerformCycleBackwards(pname, class, false)
    end
end

function PallyPower_BarToggle()
    if ((GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0) or (PP_IsPally == false)) then
        PallyPower_ShowFeedback(PALLYPOWER_MSG_NOTPALLYORRAID, 0.5, 1, 1, 1)
    else
        if PallyPowerBuffBar:IsVisible() then
            PallyPowerBuffBar:Hide()
            PallyPower_ShowFeedback(PALLYPOWER_MSG_BARHIDDEN, 0.5, 1, 1, 1)
        else
            PallyPowerBuffBar:Show()
            PallyPower_ShowFeedback(PALLYPOWER_MSG_BARVISIBLE, 0.5, 1, 1, 1)
        end
    end
end

function PallyPower_AutoBuffAll() --Test
    if not PP_IsPally then
        DEFAULT_CHAT_FRAME:AddMessage(PALLYPOWER_MSG_NOTPALLY)
        return
    end

    local nameplayer = UnitName("player")
    if not PallyPower_Assignments[nameplayer] then
        DEFAULT_CHAT_FRAME:AddMessage(PALLYPOWER_MSG_NOASSIGNMENTS)
        return
    end

    -- Iterate through all buff buttons and simulate clicks
    for i = 1, 10 do
        local btn = getglobal("PallyPowerBuffBarBuff" .. i)
        if btn and btn:IsVisible() then
            local nneed = getglobal("PallyPowerBuffBarBuff" .. i .. "Text"):GetText()
            if nneed and nneed ~= "" and tonumber(nneed) > 0 then
                -- Simulate a left-click to cast the greater blessing
                PallyPowerBuffButton_OnClick(btn, "LeftButton")
                -- Simulate a right-click to cast the normal blessing if needed
                PallyPowerBuffButton_OnClick(btn, "RightButton")
            end
        end
    end
end

function PallyPower_CastSeal()
    local playerName = UnitName("player")
    local _, class = UnitClass("player")
    local sealId = PallyPower_SealAssignments[playerName]

    if class == "PALADIN" and sealId and sealId ~= -1 then
        -- Determine icon prefix (matches other checks in this file)
        local icons_prefix
        if PP_PerUser and PP_PerUser.usehdicons == true then
            icons_prefix = "AddOns\\PallyPowerTW\\HD"
        else
            icons_prefix = "AddOns\\PallyPowerTW\\"
        end

        -- If the player already has the seal buff active, don't re-cast
        local alreadyActive = false
        if SealIcons[sealId] then
            -- Use Nampower API if available for better performance
            if PP_NampowerAPI then
                local auras = GetUnitField("player", "aura")
                if auras and SealNames[sealId] then
                    local targetSealName = SealNames[sealId]
                    for i = 1, table.getn(auras) do
                        local spellId = auras[i]
                        if spellId and spellId > 0 then
                            local spellName = GetSpellRecField(spellId, "name")
                            if spellName and spellName == targetSealName then
                                alreadyActive = true
                                break
                            end
                        end
                    end
                end
            else
                -- Fallback to original method
                for i = 1, 40 do
                    local testUnitBuff = UnitBuff("player", i)
                    if (testUnitBuff and SealIcons[sealId] ~= nil and
                        testUnitBuff == string.gsub(SealIcons[sealId], icons_prefix, "")) then
                        alreadyActive = true
                        break
                    end
                end
            end
        end

        if alreadyActive then
            return
        end

        local sealInfo = AllPallysSeals[playerName] and AllPallysSeals[playerName][sealId]
        if sealInfo and sealInfo.id then
            if GetSpellCooldown(sealInfo.id, BOOKTYPE_SPELL) < 1 then
                CastSpell(sealInfo.id, BOOKTYPE_SPELL)
            end
        end
    end
end

---------------------------------------------------
-- GUID Tracking System (v1.38 - like Cursive)
---------------------------------------------------
if PP_SuperWoW then
  local PP_GUIDTracker = CreateFrame("Frame")
  PP_GUIDTracker:RegisterEvent("PLAYER_TARGET_CHANGED")
  PP_GUIDTracker:RegisterEvent("UNIT_COMBAT")
  PP_GUIDTracker:RegisterEvent("UNIT_MODEL_CHANGED")
  
  PP_GUIDTracker:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
      local exists, guid = UnitExists("target")
      if exists and guid and not UnitIsDead("target") then
        if type(guid) == "string" and string.sub(guid, 1, 2) ~= "0x" then
          guid = "0x" .. guid
        end
        PP_TrackedGUIDs[guid] = GetTime()
      end
    elseif event == "UNIT_COMBAT" or event == "UNIT_MODEL_CHANGED" then
      local guid = arg1
      if guid then
        if type(guid) == "string" and string.sub(guid, 1, 2) ~= "0x" then
          guid = "0x" .. guid
        end
        if UnitExists(guid) and not UnitIsDead(guid) then
          PP_TrackedGUIDs[guid] = GetTime()
        end
      end
    end
    
    -- Cleanup old GUIDs (older than 30 seconds)
    local now = GetTime()
    for guid, timestamp in pairs(PP_TrackedGUIDs) do
      if (now - timestamp) > 30 then
        PP_TrackedGUIDs[guid] = nil
      end
    end
  end)
end

-- UnitXP Toggle Command
SLASH_PPUNITXP1 = "/ppunitxp"
SlashCmdList["PPUNITXP"] = function(msg)
  msg = string.lower(msg or "")
  
  if not PP_UnitXPDllLoaded then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PallyPower] UnitXP SP3 is not detected/loaded|r")
    return
  end
  
  if msg == "on" or msg == "enable" or msg == "1" or msg == "true" then
    PP_PerUser.useunitxp_sp3 = true
    UseUnitXPSP3OptionChk:SetChecked(true)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PallyPower] UnitXP SP3 range/LOS checking ENABLED|r")
  elseif msg == "off" or msg == "disable" or msg == "0" or msg == "false" then
    PP_PerUser.useunitxp_sp3 = false
    UseUnitXPSP3OptionChk:SetChecked(false)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[PallyPower] UnitXP SP3 range/LOS checking DISABLED|r")
  else
    -- Toggle
    PP_PerUser.useunitxp_sp3 = not PP_PerUser.useunitxp_sp3
    UseUnitXPSP3OptionChk:SetChecked(PP_PerUser.useunitxp_sp3)
    if PP_PerUser.useunitxp_sp3 then
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PallyPower] UnitXP SP3 range/LOS checking ENABLED|r")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[PallyPower] UnitXP SP3 range/LOS checking DISABLED|r")
    end
  end
end

-- Debug Command
SLASH_PPDBG1 = "/ppdbg"
SlashCmdList["PPDBG"] = function()
  local function log(msg)
    if OGAALogger and OGAALogger.AddMessage and type(OGAALogger.AddMessage) == "function" then
      OGAALogger.AddMessage("PallyPower", msg)
    else
      DEFAULT_CHAT_FRAME:AddMessage("[PallyPower] " .. msg)
    end
  end
  
  log("=== PALLYPOWER DEBUG ===")
  log("Time: " .. date("%H:%M:%S"))
  
  -- Core Status
  log("")
  log("--- Core Status ---")
  log("PP_IsPally: " .. tostring(PP_IsPally))
  log("PP_NampowerAPI: " .. tostring(PP_NampowerAPI))
  log("RegularBlessings: " .. tostring(RegularBlessings))
  if PP_PerUser then
    log("PP_PerUser.regularblessings: " .. tostring(PP_PerUser.regularblessings))
    log("PP_PerUser.useunitxp_sp3: " .. tostring(PP_PerUser.useunitxp_sp3))
  else
    log("PP_PerUser: nil")
  end
  log("PP_UnitXPDllLoaded: " .. tostring(PP_UnitXPDllLoaded))
  
  -- UnitXP SP3 Status
  log("")
  log("--- UnitXP SP3 Status ---")
  if UnitXP then
    log("UnitXP function exists: true")
    
    -- Test basic functions
    local success, result = pcall(UnitXP, "inSight", "player", "player")
    log("UnitXP('inSight','player','player'): success=" .. tostring(success) .. ", result=" .. tostring(result))
    
    if success then
      -- Test distance
      local distSuccess, dist = pcall(UnitXP, "distanceBetween", "player", "player")
      log("UnitXP('distanceBetween','player','player'): success=" .. tostring(distSuccess) .. ", result=" .. tostring(dist))
      
      -- Test with target if exists
      if UnitExists("target") then
        local losSuccess, los = pcall(UnitXP, "inSight", "player", "target")
        log("UnitXP('inSight','player','target'): success=" .. tostring(losSuccess) .. ", result=" .. tostring(los))
        
        local tdSuccess, tdist = pcall(UnitXP, "distanceBetween", "player", "target")
        log("UnitXP('distanceBetween','player','target'): success=" .. tostring(tdSuccess) .. ", result=" .. tostring(tdist))
        
        log("UnitIsConnected('target'): " .. tostring(UnitIsConnected("target")))
        log("UnitIsVisible('target'): " .. tostring(UnitIsVisible("target")))
      else
        log("No target selected for UnitXP target tests")
      end
    end
  else
    log("UnitXP function exists: false")
  end
  
  -- BuffIcon Array
  log("")
  log("--- BuffIcon Array ---")
  if BuffIcon then
    for i = 0, 9 do
      if BuffIcon[i] then
        local short = string.gsub(BuffIcon[i], "Interface\\AddOns\\PallyPowerTW\\", "")
        short = string.gsub(short, "Interface\\AddOns\\PallyPowerTW\\HD", "HD")
        log("BuffIcon[" .. i .. "]: " .. short)
      end
    end
  else
    log("BuffIcon: nil")
  end
  
  -- BlessingIcon Array
  log("")
  log("--- BlessingIcon Array ---")
  if BlessingIcon then
    for i = 0, 9 do
      if BlessingIcon[i] then
        local short = string.gsub(BlessingIcon[i], "Interface\\AddOns\\PallyPowerTW\\", "")
        short = string.gsub(short, "Interface\\AddOns\\PallyPowerTW\\HD", "HD")
        log("BlessingIcon[" .. i .. "]: " .. short)
      end
    end
  else
    log("BlessingIcon: nil")
  end
  
  -- BuffIconSmall Array
  log("")
  log("--- BuffIconSmall Array ---")
  if BuffIconSmall then
    for i = 0, 9 do
      if BuffIconSmall[i] then
        local short = string.gsub(BuffIconSmall[i], "Interface\\AddOns\\PallyPowerTW\\", "")
        short = string.gsub(short, "Interface\\AddOns\\PallyPowerTW\\HD", "HD")
        log("BuffIconSmall[" .. i .. "]: " .. short)
      end
    end
  else
    log("BuffIconSmall: nil")
  end
  
  -- Current Buffs
  log("")
  log("--- Current Buffs (UnitBuff) ---")
  local i = 1
  while UnitBuff("player", i) do
    local icon = UnitBuff("player", i)
    if icon then
      local short = string.gsub(icon, "Interface\\Icons\\", "")
      log("Buff " .. i .. ": " .. short)
      
      -- Check if it matches any BuffIcon
      for idx = 0, 9 do
        if BuffIcon and BuffIcon[idx] then
          local checkIcon = string.gsub(BuffIcon[idx], "Interface\\AddOns\\PallyPowerTW\\Icons\\", "Interface\\Icons\\")
          checkIcon = string.gsub(checkIcon, "Interface\\AddOns\\PallyPowerTW\\HDIcons\\", "Interface\\Icons\\")
          if checkIcon == icon then
            log("  -> Matches BuffIcon[" .. idx .. "]")
          end
        end
      end
    end
    i = i + 1
    if i > 40 then break end
  end
  
  -- Spell Name Tests
  log("")
  log("--- PallyPower_GetBuffIDFromSpellName Tests ---")
  if PallyPower_GetBuffIDFromSpellName then
    local tests = {
      "Blessing of Wisdom",
      "Greater Blessing of Wisdom",
      "Blessing of Kings",
      "Greater Blessing of Kings",
      "Blessing of Might",
      "Greater Blessing of Might",
      "Blessing of Salvation",
      "Greater Blessing of Salvation",
      "Blessing of Light",
      "Greater Blessing of Light",
      "Blessing of Sanctuary",
      "Greater Blessing of Sanctuary",
    }
    
    for _, spell in ipairs(tests) do
      local result = PallyPower_GetBuffIDFromSpellName(spell)
      log(spell .. " -> " .. tostring(result))
    end
  else
    log("PallyPower_GetBuffIDFromSpellName: nil")
  end
  
  -- Scan Info
  log("")
  log("--- Scan Info (Player) ---")
  if PP_ScanInfo then
    local class = UnitClass("player")
    local cid = PallyPower_GetClassID and PallyPower_GetClassID(class)
    if cid and PP_ScanInfo[cid] and PP_ScanInfo[cid]["player"] then
      log("Found scan data for player:")
      for k, v in pairs(PP_ScanInfo[cid]["player"]) do
        if type(k) == "number" then
          log("  Buff index " .. k .. ": " .. tostring(v))
        end
      end
    else
      log("No scan data for player")
      if cid then log("  ClassID: " .. cid) end
    end
  else
    log("PP_ScanInfo: nil")
  end
  
  -- Nampower Tests
  if PP_NampowerAPI then
    log("")
    log("--- Nampower Tests ---")
    
    if GetUnitField then
      local auras = GetUnitField("player", "aura")
      if auras then
        log("GetUnitField('player', 'aura') returned " .. table.getn(auras) .. " entries")
        for i = 1, math.min(10, table.getn(auras)) do
          if auras[i] and auras[i] > 0 then
            log("  Aura[" .. i .. "]: SpellID " .. auras[i])
            if GetSpellRecField then
              local name = GetSpellRecField(auras[i], "name")
              if name then
                log("    Name: " .. name)
              end
            end
          end
        end
      else
        log("GetUnitField('player', 'aura') returned nil")
      end
    else
      log("GetUnitField: nil")
    end
    
    if GetSpellRecField then
      log("")
      log("GetSpellRecField test on known spell IDs:")
      local testIds = {20911, 25899, 1038, 25782, 20217, 20911}
      for _, id in ipairs(testIds) do
        local name = GetSpellRecField(id, "name")
        log("  SpellID " .. id .. ": " .. tostring(name))
      end
    else
      log("GetSpellRecField: nil")
    end
  end
  
  log("")
  log("=== END DEBUG ===")
  
  if OGAALogger and OGAALogger.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00PallyPower debug output sent to _OGAALogger|r")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900PallyPower debug output (install _OGAALogger for copy/paste)|r")
  end
end
