--[[
# Library: LibDispel

Tells which auras the player can dispel, based on the player's class and known spells.
Adds the "Enrage" and "Bleed" types for auras that Blizzard reports without a dispel type.

## Notes

Dispel abilities are re-read on PLAYER_LOGIN, on PLAYER_SPECIALIZATION_CHANGED and SPELLS_CHANGED
(Retail), on PLAYER_TALENT_UPDATE (other clients) and on the player's UNIT_PET (warlocks only).
Secret values are never compared, see each function.

## Fields

.class   - the player's class token, set on PLAYER_LOGIN (string)
.buffs   - dispel type → whether the player can remove buffs of that type from enemies (table)
.debuffs - dispel type → whether the player can remove debuffs of that type from friends (table)
.enrage  - spell ID → name of the auras treated as "Enrage" (table)
.bleed   - spell ID → name of the auras treated as "Bleed" (table)
.notype  - spell ID → true, for auras without a dispel type that can still be dispelled (table)

## Examples

    local LibDispel = LibStub("LibDispel")

    local aura = C_UnitAuras.GetAuraDataByIndex(unit, 1, "HARMFUL")
    local dispelType = LibDispel:GetDispelType(aura.spellId, aura.dispelName)
    local isDispelable = LibDispel:IsDispelable(unit, aura.spellId, dispelType, true)
--]]

local MAJOR, MINOR = "LibDispel", 10200
assert(LibStub, MAJOR .. " requires LibStub")

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- Blizzard
local UnitCanAssist = _G.UnitCanAssist
local UnitCanAttack = _G.UnitCanAttack

-- reference: https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isMoP = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
local isForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

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

                -- fires when spells in the spellbook change in any way (talents, druid forms)
                self:RegisterEvent("SPELLS_CHANGED")
            else
                self:RegisterEvent("PLAYER_TALENT_UPDATE")
            end

            if class == "WARLOCK" then
                -- fired when the player's pet changes
                self:RegisterUnitEvent("UNIT_PET", "player")
            end
        end

        lib:UpdateDispels()
    end)
end

lib.buffs = lib.buffs or {}
lib.debuffs = lib.debuffs or {}
lib.enrage = lib.enrage or {}
lib.bleed = lib.bleed or {}

-- dispelable debuffs without dispel type
lib.notype = {
    -- Mithyc+ Affixes
    [409472] = true,            -- Diseased Spirit
    [440313] = true,            -- Void Rift
}

--[[ Function: lib:IsSpellKnown(spellID, pet)
Returns whether the player, or the player's pet, knows a spell.

* self    - LibDispel
* spellID - the spell to check (number)
* pet     - check the pet spellbook instead of the player's (boolean?)
--]]
function lib:IsSpellKnown(spellID, pet)
    local spellBank = pet and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player
    return C_SpellBook.IsSpellKnown(spellID, spellBank)
end

local issecretvalue = _G.issecretvalue

--[[ Function: lib:GetDispelType(spellID, dispelName)
Returns the aura's dispel type: `dispelName` when it is set or secret, otherwise "Enrage" or "Bleed"
when the spell is in `.enrage` or `.bleed`, otherwise "None" (string).

* self       - LibDispel
* spellID    - the aura's spell ID (number)
* dispelName - the aura's `dispelName` from its AuraData (string?)
--]]
function lib:GetDispelType(spellID, dispelName)
    if issecretvalue(spellID) or issecretvalue(dispelName) then
        return dispelName
    elseif dispelName and dispelName ~= "None" and dispelName ~= "" then
        return dispelName
    elseif self.enrage[spellID] then
        return "Enrage"
    elseif self.bleed[spellID] then
        return "Bleed"
    end
    return "None"
end

--[[ Function: lib:IsDispelable(unit, spellID, dispelName, isHarmful)
Returns whether the player can remove the aura (boolean): debuffs from units the player can assist,
buffs from units the player can attack. Returns false when any argument is secret.

* self       - LibDispel
* unit       - the unit holding the aura (string)
* spellID    - the aura's spell ID (number)
* dispelName - the aura's dispel type, usually from `GetDispelType` (string?)
* isHarmful  - whether the aura is a debuff (boolean)
--]]
function lib:IsDispelable(unit, spellID, dispelName, isHarmful)
    if issecretvalue(spellID) or issecretvalue(dispelName) or issecretvalue(isHarmful) then return false end

    -- you can not remove debuffs from a enemy
    local canAttack = UnitCanAttack(unit, "player") and UnitCanAttack("player", unit)
    if (isHarmful and not UnitCanAssist("player", unit)) or (not isHarmful and not canAttack) then
        return false
    end
    return self[isHarmful and "debuffs" or "buffs"][dispelName or "None"] or self.notype[spellID] or false
end

--[[ Function: lib:UpdateDispelsTypes(class)
Fills `.buffs` and `.debuffs` with the dispel types the player can remove. Defined per client.

* self  - LibDispel
* class - the player's class token (string)
--]]

-- Forever runs Classic content: spell IDs unverified
if isClassic or isForever or isTBC or isWrath then
    function lib:UpdateDispelsTypes(class)
        if class == "DRUID" then
            local remove_curse = self:IsSpellKnown(2782) -- Remove Curse
            local abolish_poison = self:IsSpellKnown(2893) -- Abolish Poison
            local cure_poison = self:IsSpellKnown(8946) -- Cure Poison
            self.debuffs.Curse = remove_curse
            self.debuffs.Poison = abolish_poison or cure_poison

        elseif class == "HUNTER" then
            local tranquilizing_shot = self:IsSpellKnown(19801) -- Tranquilizing Shot
            self.buffs.Enrage = tranquilizing_shot

        elseif class == "MAGE" then
            local remove_curse = self:IsSpellKnown(475) -- Remove Curse
            self.debuffs.Curse = remove_curse
            self.buffs.Magic = self:IsSpellKnown(30449) -- Spellsteal (TBC+)

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
            local mass_dispel = self:IsSpellKnown(32375) -- Mass Dispel (TBC+)
            self.buffs.Magic = dispel_magic or mass_dispel
            self.debuffs.Magic = dispel_magic or mass_dispel
            self.debuffs.Disease = abolish_disease or cure_disease

        elseif class == "SHAMAN" then
            local purge = self:IsSpellKnown(370) -- Purge
            local cure_poison = self:IsSpellKnown(526) -- Cure Poison / Cure Toxins (Wrath: also disease)
            local cure_disease = self:IsSpellKnown(2870) -- Cure Disease
            local poison_cleansing = self:IsSpellKnown(8166) -- Poison Cleansing Totem
            local cleansing = self:IsSpellKnown(8170) -- Disease Cleansing Totem / Cleansing Totem (Wrath: also poison)
            local cleanse_spirit = self:IsSpellKnown(51886) -- Cleanse Spirit (Wrath)
            self.debuffs.Poison = cure_poison or poison_cleansing or (isWrath and cleansing) or cleanse_spirit
            self.debuffs.Disease = cure_disease or cleansing or (isWrath and cure_poison) or cleanse_spirit
            self.debuffs.Curse = cleanse_spirit
            self.buffs.Magic = purge

        elseif class == "WARLOCK" then
            local devour_magic = self:IsSpellKnown(19505, true) -- Devour Magic (Felhunter)
            self.buffs.Magic = devour_magic
            self.debuffs.Magic = devour_magic
        end
    end
elseif isMoP or isCata then -- Cata spell IDs unverified
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
            local cure = self:IsSpellKnown(88423) -- Nature's Cure
            local corruption = cure or self:IsSpellKnown(2782) -- Remove Corruption
            local soothe = self:IsSpellKnown(2908) -- Soothe
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

--[[ Function: lib:UpdateDispels()
Clears and rebuilds `.buffs` and `.debuffs`. Called by the library's events.

* self - LibDispel
--]]
function lib:UpdateDispels()
    table.wipe(self.buffs)
    table.wipe(self.debuffs)

    self:UpdateDispelsTypes(self.class)
end
