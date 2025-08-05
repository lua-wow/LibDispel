local MAJOR, MINOR = "LibDispel", 1
assert(LibStub, MAJOR .. " requires LibStub")

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- Blizzard
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or _G.GetSpellInfo
local IsPlayerSpell = _G.IsPlayerSpell
local IsSpellKnown = _G.IsSpellKnown
local IsSpellKnownOrOverridesKnown = _G.IsSpellKnownOrOverridesKnown
local UnitCanAssist = _G.UnitCanAssist
local UnitCanAttack = _G.UnitCanAttack

-- reference: https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID
-- LE_EXPANSION_LEVEL_CURRENT
local LE_EXPANSION_CLASSIC = _G.LE_EXPANSION_CLASSIC or 0                               -- Vanilla / Classic Era
local LE_EXPANSION_BURNING_CRUSADE = _G.LE_EXPANSION_BURNING_CRUSADE or 1               -- The Burning Crusade
local LE_EXPANSION_WRATH_OF_THE_LICH_KING = _G.LE_EXPANSION_WRATH_OF_THE_LICH_KING or 2 -- Wrath of the Lich King
local LE_EXPANSION_CATACLYSM = _G.LE_EXPANSION_CATACLYSM or 3                           -- Cataclysm
local LE_EXPANSION_MISTS_OF_PANDARIA = _G.LE_EXPANSION_MISTS_OF_PANDARIA or 4           -- Mists of Pandaria
local LE_EXPANSION_WARLORDS_OF_DRAENOR = _G.LE_EXPANSION_WARLORDS_OF_DRAENOR or 5       -- Warlords of Draenor
local LE_EXPANSION_LEGION = _G.LE_EXPANSION_LEGION or 6                                 -- Legion
local LE_EXPANSION_BATTLE_FOR_AZEROTH = _G.LE_EXPANSION_BATTLE_FOR_AZEROTH or 7         -- Battle for Azeroth
local LE_EXPANSION_SHADOWLANDS = _G.LE_EXPANSION_SHADOWLANDS or 8                       -- Shadowlands
local LE_EXPANSION_DRAGONFLIGHT = _G.LE_EXPANSION_DRAGONFLIGHT or 9                     -- Dragonflight
local LE_EXPANSION_WAR_WITHIN = _G.LE_EXPANSION_WAR_WITHIN or 10                        -- The War WithIn

local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isMoP = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

-- Event Frame
if not lib.frame then
    lib.frame = CreateFrame("Frame", MAJOR)
    lib.frame:RegisterEvent("PLAYER_LOGIN")
    lib.frame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            local _, class = UnitClass("player")
            lib.class = class

            if isRetail then
                -- fired when the player's spec has changed (switching between specs)
                self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")

                -- when player changes some talents we need to listing to the spell "Changing Talents"
                -- self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
                self:RegisterEvent("SPELLS_CHANGED")
            else
                self:RegisterEvent("PLAYER_TALENT_UPDATE")
            end

            -- fires when spells in the spellbook change in any way
            -- fires when DRUID change form (annoying...)
            -- self:RegisterEvent("SPELLS_CHANGED")

            -- self:RegisterEvent("LEARNED_SPELL_IN_TAB")
            -- self:RegisterEvent("CHARACTER_POINTS_CHANGED")
            
            if class == "WARLOCK" then
                -- fired when a unit's pet changes
                self:RegisterEvent("UNIT_PET")
            end

            -- lib:ValidateSpells(lib.enrage)
            -- lib:ValidateSpells(lib.bleed)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, guid, spellID = ...
            if spellID ~= 384255 then return end
        end
        
        lib:UpdateDispels()
    end)
end

lib.buffs = lib.buffs or {}
lib.debuffs = lib.debuffs or {}
lib.spells = lib.spells or {}
lib.enrage = lib.enrage or {}
lib.bleed = lib.bleed or {}

-- dispelable debuffs without dispel type
lib.notype = {
    -- Mithyc+ Affixes
    [409472] = true,            -- Diseased Spirit
    [440313] = true,            -- Void Rift
}

function lib:GetDispelType(spellID, dispelName)
    if dispelName and dispelName ~= "none" and dispelName ~= "" then
        return dispelName
    elseif self.enrage[spellID] then
        return "Enrage"
    elseif self.bleed[spellID] then
        return "Bleed"
    end
    return "none"
end

function lib:IsDispelable(unit, spellID, dispelName, isHarmful)
    -- you can not remove debuffs from a enemy
    local canAttack = UnitCanAttack(unit, "player") and UnitCanAttack("player", unit)
    if (isHarmful and not UnitCanAssist("player", unit)) or (not isHarmful and not canAttack) then
        return false
    end
    local spell = self[isHarmful and "debuffs" or "buffs"][dispelName or "none"]
    return (spell ~= nil) or lib.notype[spellID] or false
end

function lib:IsSpellKnown(spellID, pet)
    if IsPlayerSpell and not pet then
        return IsPlayerSpell(spellID) and spellID or nil
    end
    return IsSpellKnown(spellID, pet) and spellID or nil
end

if isClassic then
    function lib:UpdateDispelsTypes(class)
        if class == "DRUID" then
            local remove_curse = self:IsSpellKnown(2782) -- Remove Curse
            local abolish_poison = self:IsSpellKnown(2893) -- Abolish Poison
            self.debuffs.Curse = remove_curse
            self.debuffs.Poison = abolish_poison

        elseif class == "HUNTER" then
            local tranquilizing_shot = self:IsSpellKnown(19801) -- Tranquilizing Shot
            self.buffs.Enrage = tranquilizing_shot

        elseif class == "MAGE" then
            local remove_curse = self:IsSpellKnown(475) -- Remove Curse
            self.debuffs.Curse = remove_curse

        elseif class == "PALADIN" then
            local purify = self:IsSpellKnown(1152) -- Purify
            local cleanse = self:IsSpellKnown(4987) -- Cleanse
            self.debuffs.Disease = cleanse or purify
            self.debuffs.Poison = cleanse or purify
            self.debuffs.Magic = cleanse

        elseif class == "PRIEST" then
            local dispel_magic = self:IsSpellKnown(527) -- Dispel Magic
            local cure_disease = self:IsSpellKnown(528) -- Cure Disease
            local abolish_disease = self:IsSpellKnown(552) -- Abolish Disease
            self.buffs.Magic = dispel_magic
            self.debuffs.Magic = dispel_magic
            self.debuffs.Disease = abolish_disease or cure_disease

        elseif class == "SHAMAN" then
            local purge = self:IsSpellKnown(370) -- Purge
            local poison_cleansing = self:IsSpellKnown(526) -- Poison Cleansing Totem
            local disease_cleansing = self:IsSpellKnown(8170) -- Disease Cleansing Totem
            self.debuffs.Poison = poison_cleansing
            self.debuffs.Disease = disease_cleansing
            self.buffs.Magic = purge
        end
    end
elseif isMoP then
    function lib:UpdateDispelsTypes(class)
        if class == "DRUID" then
            local remove_corruption = self:IsSpellKnown(2782) -- Remove Corruption
            local nature_cure = self:IsSpellKnown(88423) -- Nature's Cure
            local soothe = self:IsSpellKnown(2908) -- Soothe
            self.debuffs.Magic = nature_cure
            self.debuffs.Curse = nature_cure or remove_corruption
            self.debuffs.Poison = nature_cure or remove_corruption
            self.buffs.Enrage = soothe

        elseif class == "HUNTER" then
            local tranquilizing_shot = self:IsSpellKnown(19801) -- Tranquilizing Shot
            self.buffs.Magic = tranquilizing_shot
            self.buffs.Enrage = tranquilizing_shot

        elseif class == "MAGE" then
            self.buffs.Magic = self:IsSpellKnown(30449) -- Spellsteal
            self.debuffs.Curse = self:IsSpellKnown(475) -- Remove Curse

        elseif class == "MONK" then
            local revival = self:IsSpellKnown(115310) -- Revival (Mistweaver)
            local detox = self:IsSpellKnown(115450) -- Detox (Mistweaver)
            local internal_medicine = self:IsSpellKnown(115451) -- Internal Medicine (Mistweaver)
            self.debuffs.Magic = revival or (detox and internal_medicine)
            self.debuffs.Disease = revival or detox
            self.debuffs.Poison = revival or detox

        elseif class == "PALADIN" then
            local cleanse = self:IsSpellKnown(4987) -- Cleanse
            local sacred_cleansing = self:IsSpellKnown(53551) -- Sacred Cleansing
            local absolve = self:IsSpellKnown(140333) -- Absolve (Holy)
            local hand_of_sacrifice = self:IsSpellKnown(6940) -- Hand of Sacrifice
            self.debuffs.Magic = (cleanse and sacred_cleansing) or (hand_of_sacrifice and absolve)
            self.debuffs.Disease = cleanse
            self.debuffs.Poison = cleanse

        elseif class == "PRIEST" then
            local purify = self:IsSpellKnown(527) -- Purify
            local dispel_magic = self:IsSpellKnown(528) -- Dispel Magic
            local mass_dispel = self:IsSpellKnown(32375) -- Mass Dispel
            self.debuffs.Magic = purify or mass_dispel
            self.debuffs.Disease = purify
            self.buffs.Magic = dispel_magic or mass_dispel

        elseif class == "SHAMAN" then
            local purge = self:IsSpellKnown(370) -- Purge
            local purify_spirit = self:IsSpellKnown(77130) -- Purify Spirit (Resto)
            local cleanse_spirit = self:IsSpellKnown(51886) -- Cleanse Spirit
            self.debuffs.Magic = purify_spirit
            self.debuffs.Curse = cleanse_spirit
            self.buffs.Magic = purge
        end
    end
else
    function lib:UpdateDispelsTypes(class)
        if class == "DEMONHUNTER" then
            self.debuffs.Magic = self:IsSpellKnown(205604)  -- Reverse Magic (PvP)
            self.buffs.Magic = self:IsSpellKnown(278326) -- Consume Magic

        elseif class == "DEATHKNIGHT" then

        elseif class == "EVOKER" then
            local naturalize = self:IsSpellKnown(360823) -- Naturalize (Preservation)
            local expunge = self:IsSpellKnown(365585) -- Expunge (Devastation)
            local cauterizing = self:IsSpellKnown(374251) -- Cauterizing Flame
            local scouring_flame = self:IsSpellKnown(378438) -- Scouring Flame (PvP Talent)
            self.debuffs.Magic = naturalize or scouring_flame
            self.debuffs.Poison = naturalize or expunge or cauterizing
            self.debuffs.Disease = cauterizing
            self.debuffs.Curse = cauterizing
            self.debuffs.Bleed = cauterizing

        elseif class == "DRUID" then
            local corruption = cure or self:IsSpellKnown(2782) -- Remove Corruption
            local soothe = self:IsSpellKnown(2908) -- Soothe
            local cure = self:IsSpellKnown(88423) -- Nature's Cure
            local improved_cure = self:IsSpellKnown(392378) -- Improved Nature's Cure (Restoration Talent)
            self.debuffs.Magic = cure or improved_cure
            self.debuffs.Curse = corruption or improved_cure
            self.debuffs.Poison = corruption or improved_cure
            self.buffs.Enrage = soothe

        elseif class == "HUNTER" then
            local tranquilizing_shot = self:IsSpellKnown(19801) -- Tranquilizing Shot
            local mending_bandage = self:IsSpellKnown(212640) -- Mending Bandage (PvP)
            self.debuffs.Disease = mending_bandage
            self.debuffs.Poison = mending_bandage
            self.buffs.Magic = tranquilizing_shot
            self.buffs.Enrage = tranquilizing_shot

        elseif class == "MAGE" then
            self.buffs.Magic = self:IsSpellKnown(30449) -- Spellsteal
            self.debuffs.Curse = self:IsSpellKnown(475) -- Remove Curse

        elseif class == "MONK" then
            local detox_magic = self:IsSpellKnown(115450) -- Detox (Mistweaver)
            local improved_detox = self:IsSpellKnown(388874) -- Improved Detox (Mistweaver Talent)
            local detox = detox_magic or self:IsSpellKnown(218164) -- Detox (Brewmaster or Windwalker)
            self.debuffs.Magic = detox_magic
            self.debuffs.Disease = detox or improved_detox
            self.debuffs.Poison = detox or improved_detox

        elseif class == "PALADIN" then
            local cleanse = self:IsSpellKnown(4987) -- Cleanse (Holy)
            local improved_cleanse = self:IsSpellKnown(393024) -- Improved Cleanse (Holy Talent)
            local toxins = self:IsSpellKnown(213644) -- Cleanse Toxins (Protection or Retribution)
            self.debuffs.Magic = cleanse
            self.debuffs.Poison = toxins or improved_cleanse
            self.debuffs.Disease = toxins or improved_cleanse

        elseif class == "PRIEST" then
            local purify = self:IsSpellKnown(527) -- Purify
            local dispel_magic = self:IsSpellKnown(528) -- Dispel Magic
            local mass_dispel = self:IsSpellKnown(32375) -- Mass Dispel
            local improved_purify = self:IsSpellKnown(390632) -- Improved Purify (Discipline or Holy)
            local disease = self:IsSpellKnown(213634) -- Purify Disease (Shadow)
            self.buffs.Magic = dispel_magic or mass_dispel
            self.debuffs.Magic = purify or mass_dispel
            self.debuffs.Disease = disease or improved_purify

        elseif class == "SHAMAN" then
            local purge = self:IsSpellKnown(370) -- Purge
            local purify = self:IsSpellKnown(77130) -- Purify Spirit
            local improved_purify = self:IsSpellKnown(383016) -- Imroved Purify Spirit (Restoration Talent)
            local cleanse = self:IsSpellKnown(51886) -- Cleanse Spirit
            self.debuffs.Magic = purify
            self.debuffs.Curse = cleanse or improved_purify
            self.buffs.Magic = purge

        elseif class == "WARLOCK" then
            self.buffs.Magic = self:IsSpellKnown(171021, true) -- Torch Magic (Infernal)
            self.debuffs.Magic = self:IsSpellKnown(89808, true) or self:IsSpellKnown(212623) -- Singe Magic (Imp) / (PvP)
        end
    end
end

function lib:UpdateDispels()
    table.wipe(self.buffs)
    table.wipe(self.debuffs)
    table.wipe(self.spells)

    local class = self.class

    self:UpdateDispelsTypes(class)

    if self.buffs.Magic then
        self.spells[self.buffs.Magic] = "offensive"
    end
end

function lib:ValidateSpells(dest)
    for spellID, _ in next, dest do
        local data = GetSpellInfo(spellID)
        if not data then
            self:print("Spell " .. spellID .. " do not exists.")
            dest[spellID] = nil
        end
    end
end

function lib:print(...)
    print("|cffffa1a1" .. MAJOR .. ":|r", ...)
end
